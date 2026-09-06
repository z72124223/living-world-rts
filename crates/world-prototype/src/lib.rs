//! Persistence service for the loopback-only executable.
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};
use world_core::prototype::{Action, Command, Snapshot, World};

pub const MAX_SAVE_BYTES: u64 = 8 * 1024 * 1024;
pub const MAX_REQUESTS: usize = 4096;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct State {
    format_version: u32,
    world: World,
    #[serde(deserialize_with = "world_core::prototype::unique_map")]
    requests: BTreeMap<String, Command>,
}
impl State {
    fn validate(&self) -> Result<(), String> {
        if self.format_version != 1 {
            return Err("unsupported save format version".into());
        }
        if self.requests.len() > MAX_REQUESTS {
            return Err("too many saved requests".into());
        }
        for (id, command) in &self.requests {
            command.validate_request_id()?;
            if id != &command.request_id {
                return Err("saved request ID mismatch".into());
            }
        }
        self.world.validate()
    }
}

#[derive(Debug)]
pub struct ServiceError {
    pub status: u16,
    pub message: String,
}
impl ServiceError {
    fn bad(message: impl Into<String>) -> Self {
        Self {
            status: 400,
            message: message.into(),
        }
    }
    fn io(message: impl Into<String>) -> Self {
        Self {
            status: 500,
            message: message.into(),
        }
    }
}

pub struct Engine {
    state: State,
    directory: PathBuf,
    _lock: File,
}

fn slot_filename(slot: &str) -> Result<String, ServiceError> {
    if !matches!(
        slot,
        "slot-1"
            | "slot-2"
            | "slot-3"
            | "slot-4"
            | "slot-5"
            | "slot-6"
            | "slot-7"
            | "slot-8"
            | "slot-9"
    ) {
        return Err(ServiceError::bad(
            "slot must be slot-1 through slot-9; paths are not accepted",
        ));
    }
    Ok(format!("{slot}.json"))
}

fn read_state(path: &Path) -> Result<State, String> {
    let file = File::open(path).map_err(|e| format!("cannot open saved world: {e}"))?;
    if file.metadata().map_err(|e| e.to_string())?.len() > MAX_SAVE_BYTES {
        return Err("save file exceeds size limit".into());
    }
    let mut bytes = vec![];
    file.take(MAX_SAVE_BYTES + 1)
        .read_to_end(&mut bytes)
        .map_err(|e| e.to_string())?;
    if bytes.len() as u64 > MAX_SAVE_BYTES {
        return Err("save file exceeds size limit".into());
    }
    let state: State =
        serde_json::from_slice(&bytes).map_err(|e| format!("corrupt save JSON: {e}"))?;
    state.validate()?;
    Ok(state)
}

/// Temporary file is on the destination volume; persist replaces atomically on Windows.
fn write_state(path: &Path, state: &State) -> Result<(), String> {
    let bytes = serde_json::to_vec(state).map_err(|e| e.to_string())?;
    if bytes.len() as u64 > MAX_SAVE_BYTES {
        return Err("world exceeds save size limit; existing save retained".into());
    }
    let mut temporary =
        tempfile::NamedTempFile::new_in(path.parent().ok_or("invalid save directory")?)
            .map_err(|e| e.to_string())?;
    temporary.write_all(&bytes).map_err(|e| e.to_string())?;
    temporary.as_file().sync_all().map_err(|e| e.to_string())?;
    let file = temporary.persist(path).map_err(|e| e.error.to_string())?;
    file.sync_all().map_err(|e| e.to_string())?;
    Ok(())
}

impl Engine {
    pub fn open(directory: &Path) -> Result<Self, String> {
        fs::create_dir_all(directory).map_err(|e| e.to_string())?;
        let directory = directory.canonicalize().map_err(|e| e.to_string())?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(directory.join("world.lock"))
            .map_err(|e| e.to_string())?;
        lock.try_lock()
            .map_err(|e| format!("save directory is already in use: {e}"))?;
        let current = directory.join("current.json");
        let state = if current.exists() {
            read_state(&current)?
        } else {
            let state = State {
                format_version: 1,
                world: World::demo(),
                requests: BTreeMap::new(),
            };
            state.validate()?;
            write_state(&current, &state)?;
            state
        };
        state.world.activate_allocator();
        Ok(Self {
            state,
            directory,
            _lock: lock,
        })
    }

    pub fn snapshot(&self) -> Snapshot {
        self.state.world.snapshot()
    }

    pub fn flush(&self) -> Result<(), String> {
        write_state(&self.directory.join("current.json"), &self.state)
    }

    pub fn command(&mut self, command: Command) -> Result<Snapshot, ServiceError> {
        command.validate_request_id().map_err(ServiceError::bad)?;
        if let Some(previous) = self.state.requests.get(&command.request_id) {
            if previous == &command {
                return Ok(self.snapshot());
            }
            return Err(ServiceError {
                status: 409,
                message: "request_id was already used for a different command".into(),
            });
        }
        if self.state.requests.len() >= MAX_REQUESTS {
            return Err(ServiceError {
                status: 409,
                message: "prototype request capacity reached; saved history retained".into(),
            });
        }
        let mut candidate = self.state.clone();
        let mut save_path = None;
        match &command.action {
            Action::Save { slot } => {
                save_path = Some(self.directory.join(slot_filename(slot)?));
            }
            Action::Load { slot } => {
                let path = self.directory.join(slot_filename(slot)?);
                if !path.exists() {
                    return Err(ServiceError {
                        status: 404,
                        message: "save slot does not exist".into(),
                    });
                }
                let mut loaded = read_state(&path).map_err(|e| ServiceError {
                    status: 422,
                    message: e,
                })?;
                loaded.world.retain_allocation_floor(&self.state.world);
                // Retain retry receipts across rollback so an old request can never clone a squad/event.
                for (id, receipt) in &self.state.requests {
                    if let Some(old) = loaded.requests.get(id)
                        && old != receipt
                    {
                        return Err(ServiceError::bad("save receipt conflict"));
                    }
                    loaded.requests.insert(id.clone(), receipt.clone());
                }
                candidate = loaded;
            }
            action => candidate.world.apply(action).map_err(ServiceError::bad)?,
        }
        candidate
            .requests
            .insert(command.request_id.clone(), command);
        candidate.validate().map_err(ServiceError::bad)?;
        if let Some(path) = save_path {
            write_state(&path, &candidate).map_err(ServiceError::io)?;
        }
        write_state(&self.directory.join("current.json"), &candidate).map_err(ServiceError::io)?;
        candidate.world.activate_allocator();
        self.state = candidate;
        Ok(self.snapshot())
    }

    pub fn advance(&mut self, elapsed_ms: u64) -> Result<(), String> {
        let moving = self.state.world.is_moving();
        let mut candidate = self.state.clone();
        candidate.world.advance(elapsed_ms)?;
        // Commit each simulation step that changes a route/position. Idle clock does not write to disk.
        if moving {
            write_state(&self.directory.join("current.json"), &candidate)?;
        }
        self.state = candidate;
        Ok(())
    }

    /// Core-only extension point; the HTTP command contract stays limited to SESSION_BRIEF.
    pub fn update_world<T>(
        &mut self,
        update: impl FnOnce(&mut World) -> Result<T, String>,
    ) -> Result<T, String> {
        let mut candidate = self.state.clone();
        let value = update(&mut candidate.world)?;
        candidate.validate()?;
        write_state(&self.directory.join("current.json"), &candidate)?;
        self.state = candidate;
        Ok(value)
    }
}

pub mod http;
