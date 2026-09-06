//! Local four-person prototype. Characters remain the sole identity records;
//! squads only hold references. No combat or automatic command succession policy.
use crate::character::{Character, CharacterId};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet, VecDeque};

pub const MAX_CHARACTERS: usize = 256;
pub const MAX_EVENTS: usize = 10_000;
pub const MAX_ROUTE_POINTS: usize = 512;
pub type Result<T> = std::result::Result<T, String>;

/// A corrupt JSON object must not silently overwrite an earlier identity/receipt.
pub fn unique_map<'de, D, K, V>(deserializer: D) -> std::result::Result<BTreeMap<K, V>, D::Error>
where
    D: serde::Deserializer<'de>,
    K: Deserialize<'de> + Ord,
    V: Deserialize<'de>,
{
    struct Visitor<K, V>(std::marker::PhantomData<(K, V)>);
    impl<'de, K: Deserialize<'de> + Ord, V: Deserialize<'de>> serde::de::Visitor<'de>
        for Visitor<K, V>
    {
        type Value = BTreeMap<K, V>;
        fn expecting(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
            f.write_str("an object with unique keys")
        }
        fn visit_map<A: serde::de::MapAccess<'de>>(
            self,
            mut access: A,
        ) -> std::result::Result<Self::Value, A::Error> {
            let mut map = BTreeMap::new();
            while let Some((key, value)) = access.next_entry()? {
                if map.insert(key, value).is_some() {
                    return Err(serde::de::Error::custom("duplicate object key"));
                }
            }
            Ok(map)
        }
    }
    deserializer.deserialize_map(Visitor(std::marker::PhantomData))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Gender {
    Male,
    Female,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Loadout {
    pub clothing: String,
    pub armor: String,
    pub weapon: String,
}
impl Default for Loadout {
    fn default() -> Self {
        Self {
            clothing: "cloth".into(),
            armor: "none".into(),
            weapon: "none".into(),
        }
    }
}
impl Loadout {
    fn validate(&self) -> Result<()> {
        if self.clothing != "cloth"
            || !matches!(self.armor.as_str(), "none" | "chest")
            || !matches!(self.weapon.as_str(), "none" | "sword")
        {
            return Err("unsupported loadout".into());
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Pace {
    Walk,
    Run,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Route {
    pub character_id: String,
    pub points: Vec<[f64; 2]>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Command {
    pub request_id: String,
    #[serde(flatten)]
    pub action: Action,
}
impl Command {
    pub fn validate_request_id(&self) -> Result<()> {
        if self.request_id.is_empty()
            || self.request_id.len() > 96
            || !self
                .request_id
                .bytes()
                .all(|c| c.is_ascii_alphanumeric() || b"-_.:".contains(&c))
        {
            return Err("request_id must be 1..96 ASCII letters, digits, -_.:".into());
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
pub enum Action {
    Move {
        routes: Vec<Route>,
        pace: Pace,
    },
    Stop {
        character_ids: Vec<String>,
    },
    Split {
        character_ids: Vec<String>,
        name: String,
    },
    Merge {
        source_squad_id: String,
        target_squad_id: String,
    },
    SetEquipment {
        character_id: String,
        loadout: Loadout,
    },
    Interact {
        character_id: String,
        event_key: String,
    },
    Save {
        slot: String,
    },
    Load {
        slot: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub width: f64,
    pub height: f64,
    pub walk_speed: f64,
    pub run_speed: f64,
    pub interaction_radius: f64,
    pub scout_north: [f64; 2],
    pub scout_east: [f64; 2],
    pub camp: [f64; 2],
}
impl Default for Config {
    fn default() -> Self {
        Self {
            width: 2048.0,
            height: 1536.0,
            walk_speed: 32.0,
            run_speed: 56.0,
            interaction_radius: 64.0,
            scout_north: [1040.0, 304.0],
            scout_east: [1712.0, 848.0],
            camp: [336.0, 848.0],
        }
    }
}
impl Config {
    fn position(&self, p: [f64; 2]) -> Result<()> {
        if !p.iter().all(|n| n.is_finite())
            || p[0] < 0.0
            || p[1] < 0.0
            || p[0] >= self.width
            || p[1] >= self.height
        {
            return Err("position outside finite map bounds".into());
        }
        Ok(())
    }
    fn validate(&self) -> Result<()> {
        for v in [
            self.width,
            self.height,
            self.walk_speed,
            self.run_speed,
            self.interaction_radius,
        ] {
            if !v.is_finite() || v <= 0.0 || v > 16384.0 {
                return Err("invalid simulation config".into());
            }
        }
        for p in [self.scout_north, self.scout_east, self.camp] {
            self.position(p)?;
        }
        Ok(())
    }
    fn speed(&self, pace: Pace) -> f64 {
        match pace {
            Pace::Walk => self.walk_speed,
            Pace::Run => self.run_speed,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Person {
    character: Character,
    gender: Gender,
    position: [f64; 2],
    loadout: Loadout,
    squad_id: Option<String>,
    route: VecDeque<[f64; 2]>,
    pace: Pace,
    observed: BTreeSet<String>,
    unreported: BTreeSet<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Squad {
    pub id: String,
    pub name: String,
    pub member_ids: Vec<String>,
    pub nominal_commander_id: Option<String>,
    pub parent_squad_id: Option<String>,
    pub child_squad_ids: Vec<String>,
}
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Event {
    pub id: String,
    pub sim_time_ms: u64,
    pub text: String,
    pub character_id: Option<String>,
    pub event_key: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct World {
    schema_version: u32,
    revision: u64,
    sim_time_ms: u64,
    next_character_id: u64,
    next_squad_id: u64,
    next_event_id: u64,
    config: Config,
    #[serde(deserialize_with = "unique_map")]
    characters: BTreeMap<String, Person>,
    #[serde(deserialize_with = "unique_map")]
    squads: BTreeMap<String, Squad>,
    events: Vec<Event>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::character::{Consciousness, ControllerKind};

    fn action(json: serde_json::Value) -> Action {
        serde_json::from_value(json).unwrap()
    }
    fn ids(world: &World) -> Vec<String> {
        world
            .snapshot()
            .characters
            .iter()
            .map(|p| p.id.clone())
            .collect()
    }

    #[test]
    fn split_merge_preserve_four_character_records_and_history() {
        let mut w = World::demo();
        let ids = ids(&w);
        w.apply(&action(serde_json::json!({"type":"set_equipment","character_id":ids[2],"loadout":{"clothing":"cloth","armor":"chest","weapon":"sword"}}))).unwrap();
        let before = w.characters.clone();
        let events = w.events.clone();
        for _ in 0..8 {
            w.apply(&Action::Split {
                character_ids: ids[2..].to_vec(),
                name: "側翼".into(),
            })
            .unwrap();
            let source = w.characters[&ids[2]].squad_id.clone().unwrap();
            w.apply(&Action::Merge {
                source_squad_id: source,
                target_squad_id: "squad-1".into(),
            })
            .unwrap();
        }
        assert_eq!(ids.len(), w.characters.len());
        for id in ids {
            assert_eq!(before[&id].character, w.characters[&id].character);
            assert_eq!(before[&id].loadout, w.characters[&id].loadout);
        }
        assert_eq!(&w.events[..events.len()], events.as_slice());
        w.validate().unwrap();
    }
    #[test]
    fn join_leave_references_and_commander_eligibility_are_explicit() {
        let mut w = World::demo();
        w.leave_squad("1").unwrap();
        assert!(w.effective_commander("squad-1").is_none());
        assert_eq!(
            w.squads["squad-1"].nominal_commander_id.as_deref(),
            Some("1")
        );
        w.assign_commander("squad-1", "2").unwrap();
        w.characters
            .get_mut("2")
            .unwrap()
            .character
            .set_consciousness(Consciousness::Unconscious);
        assert!(w.effective_commander("squad-1").is_none());
        assert_eq!(
            w.squads["squad-1"].nominal_commander_id.as_deref(),
            Some("2")
        );
        assert!(w.assign_commander("squad-1", "2").is_err());
        w.join_squad("1", "squad-1").unwrap();
        let before = w.snapshot();
        assert!(w.join_squad("1", "squad-1").is_err());
        assert_eq!(w.snapshot(), before);
        w.assign_commander("squad-1", "1").unwrap();
        assert_eq!(w.effective_commander("squad-1").as_deref(), Some("1"));
    }
    #[test]
    fn hierarchy_rejects_cycles_duplicate_parent_and_flat_merge() {
        let mut w = World::demo();
        w.apply(&Action::Split {
            character_ids: vec!["3".into(), "4".into()],
            name: "B".into(),
        })
        .unwrap();
        w.attach_squad("squad-2", "squad-1").unwrap();
        let before = w.snapshot();
        assert!(w.attach_squad("squad-1", "squad-2").is_err());
        assert!(w.attach_squad("squad-2", "squad-1").is_err());
        assert!(
            w.apply(&Action::Merge {
                source_squad_id: "squad-1".into(),
                target_squad_id: "squad-2".into()
            })
            .is_err()
        );
        assert_eq!(w.snapshot(), before);
        w.detach_squad("squad-2").unwrap();
        w.apply(&Action::Merge {
            source_squad_id: "squad-2".into(),
            target_squad_id: "squad-1".into(),
        })
        .unwrap();
        w.validate().unwrap();
    }
    #[test]
    fn simulation_route_corners_speed_stop_and_frame_independence() {
        let mut a = World::demo();
        let move_action = Action::Move {
            routes: vec![Route {
                character_id: "1".into(),
                points: vec![[336.0, 816.0], [336.0, 848.0]],
            }],
            pace: Pace::Walk,
        };
        a.apply(&move_action).unwrap();
        let mut b = a.clone();
        a.advance(1500).unwrap();
        for _ in 0..15 {
            b.advance(100).unwrap();
        }
        assert!((a.characters["1"].position[1] - 832.0).abs() < 1e-8);
        assert!(distance(a.characters["1"].position, b.characters["1"].position) < 1e-8);
        a.apply(&Action::Stop {
            character_ids: vec!["1".into()],
        })
        .unwrap();
        let position = a.characters["1"].position;
        a.advance(9000).unwrap();
        assert_eq!(a.characters["1"].position, position);
        assert_eq!(a.snapshot().characters[0].velocity, [0.0, 0.0]);
        b.advance(10000).unwrap();
        assert_eq!(b.characters["1"].position, [336.0, 848.0]);
        assert!(!b.is_moving());
    }
    #[test]
    fn invalid_commands_leave_every_character_and_history_unchanged() {
        let mut w = World::demo();
        let before = w.snapshot();
        for command in [
            Action::Move {
                routes: vec![
                    Route {
                        character_id: "1".into(),
                        points: vec![[336.0, 816.0]],
                    },
                    Route {
                        character_id: "missing".into(),
                        points: vec![[0.0, 0.0]],
                    },
                ],
                pace: Pace::Run,
            },
            Action::Move {
                routes: vec![Route {
                    character_id: "1".into(),
                    points: vec![[f64::NAN, 0.0]],
                }],
                pace: Pace::Run,
            },
            Action::Move {
                routes: vec![Route {
                    character_id: "1".into(),
                    points: vec![[2048.0, 0.0]],
                }],
                pace: Pace::Run,
            },
            Action::Move {
                routes: vec![Route {
                    character_id: "1".into(),
                    points: vec![[0.0, 0.0]; 513],
                }],
                pace: Pace::Run,
            },
            Action::Split {
                character_ids: vec!["1".into(), "1".into()],
                name: "X".into(),
            },
            Action::Merge {
                source_squad_id: "squad-1".into(),
                target_squad_id: "squad-1".into(),
            },
            Action::Stop {
                character_ids: vec![],
            },
            Action::Interact {
                character_id: "1".into(),
                event_key: "scout-north".into(),
            },
        ] {
            assert!(w.apply(&command).is_err());
            assert_eq!(w.snapshot(), before);
        }
    }
    #[test]
    fn observed_information_and_return_events_are_persistent_and_not_duplicated() {
        let mut w = World::demo();
        w.apply(&Action::Move {
            routes: vec![Route {
                character_id: "1".into(),
                points: vec![w.config.scout_north],
            }],
            pace: Pace::Run,
        })
        .unwrap();
        w.advance(30000).unwrap();
        let scout = Action::Interact {
            character_id: "1".into(),
            event_key: "scout-north".into(),
        };
        w.apply(&scout).unwrap();
        let events = w.events.clone();
        w.apply(&scout).unwrap();
        assert_eq!(w.events, events);
        w.apply(&Action::Move {
            routes: vec![Route {
                character_id: "1".into(),
                points: vec![w.config.camp],
            }],
            pace: Pace::Run,
        })
        .unwrap();
        w.advance(30000).unwrap();
        let back = Action::Interact {
            character_id: "1".into(),
            event_key: "return-camp".into(),
        };
        w.apply(&back).unwrap();
        let mut loaded: World = serde_json::from_slice(&serde_json::to_vec(&w).unwrap()).unwrap();
        loaded.validate().unwrap();
        let events = loaded.events.clone();
        loaded.apply(&back).unwrap();
        assert_eq!(events, loaded.events);
        assert!(
            events
                .iter()
                .any(|e| e.event_key.as_deref() == Some("return-camp"))
        );
    }
    #[test]
    fn save_restores_identity_allocators_and_existing_character_model() {
        let w = World::demo();
        let mut loaded: World = serde_json::from_slice(&serde_json::to_vec(&w).unwrap()).unwrap();
        loaded.validate().unwrap();
        loaded.activate_allocator();
        assert_eq!(w.snapshot(), loaded.snapshot());
        assert_eq!(
            loaded
                .add_character("新人物".into(), Gender::Male, [400.0, 900.0])
                .unwrap(),
            "5"
        );
        let legacy = Character::new("Legacy", ControllerKind::Npc, 1.0, 1.0).unwrap();
        assert!(legacy.id().get() > 5);
    }
    #[test]
    fn corrupt_saved_graph_allocator_and_observations_are_rejected() {
        let base = serde_json::to_value(World::demo()).unwrap();
        for mutation in [0, 1, 2, 3, 4, 5] {
            let mut value = base.clone();
            match mutation {
                0 => value["next_character_id"] = serde_json::json!(1),
                1 => value["characters"]["1"]["character"]["id"] = serde_json::json!("2"),
                2 => {
                    value["squads"]["squad-1"]["member_ids"] =
                        serde_json::json!(["1", "1", "2", "3", "4"])
                }
                3 => {
                    value["squads"]["squad-1"]["parent_squad_id"] = serde_json::json!("squad-1");
                    value["squads"]["squad-1"]["child_squad_ids"] = serde_json::json!(["squad-1"]);
                }
                4 => value["characters"]["1"]["observed"] = serde_json::json!(["scout-north"]),
                _ => value["schema_version"] = serde_json::json!(2),
            }
            assert!(
                serde_json::from_value::<World>(value)
                    .unwrap()
                    .validate()
                    .is_err()
            );
        }
    }
    #[test]
    fn duplicate_json_identity_keys_are_rejected() {
        let w = World::demo();
        let text = serde_json::to_string(&w).unwrap();
        let person = serde_json::to_string(&w.characters["1"]).unwrap();
        let bad = text.replacen(
            "\"characters\":{",
            &format!("\"characters\":{{\"1\":{person},"),
            1,
        );
        assert!(serde_json::from_str::<World>(&bad).is_err());
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CharacterSnapshot {
    pub id: String,
    pub name: String,
    pub gender: Gender,
    pub position: [f64; 2],
    pub velocity: [f64; 2],
    pub loadout: Loadout,
    pub squad_id: Option<String>,
}
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SquadSnapshot {
    pub id: String,
    pub name: String,
    pub member_ids: Vec<String>,
    pub commander_id: Option<String>,
    pub nominal_commander_id: Option<String>,
    pub parent_squad_id: Option<String>,
    pub child_squad_ids: Vec<String>,
}
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Snapshot {
    pub schema_version: u32,
    pub revision: u64,
    pub sim_time_ms: u64,
    pub characters: Vec<CharacterSnapshot>,
    pub squads: Vec<SquadSnapshot>,
    pub events: Vec<Event>,
}

fn name_valid(name: &str) -> Result<()> {
    if name.trim().is_empty() || name.len() > 256 || name.chars().any(char::is_control) {
        return Err("invalid name".into());
    }
    Ok(())
}
fn numbered_id(id: &str, prefix: &str) -> Result<u64> {
    let n: u64 = id
        .strip_prefix(prefix)
        .ok_or("invalid ID prefix")?
        .parse()
        .map_err(|_| "invalid ID")?;
    if n == 0 || n == u64::MAX || format!("{prefix}{n}") != id {
        return Err("invalid ID".into());
    }
    Ok(n)
}
fn distance(a: [f64; 2], b: [f64; 2]) -> f64 {
    (a[0] - b[0]).hypot(a[1] - b[1])
}

impl World {
    pub fn demo() -> Self {
        let mut world = Self {
            schema_version: 1,
            revision: 1,
            sim_time_ms: 0,
            next_character_id: 1,
            next_squad_id: 1,
            next_event_id: 1,
            config: Config::default(),
            characters: BTreeMap::new(),
            squads: BTreeMap::new(),
            events: vec![],
        };
        let mut ids = vec![];
        for (name, gender, position) in [
            ("林岑", Gender::Female, [304.0, 816.0]),
            ("陳岳", Gender::Male, [352.0, 816.0]),
            ("蘇禾", Gender::Female, [304.0, 864.0]),
            ("周衡", Gender::Male, [352.0, 864.0]),
        ] {
            ids.push(
                world
                    .add_person_inner(name.into(), gender, position)
                    .unwrap(),
            );
        }
        world.split_inner(&ids, "第一小隊".into()).unwrap();
        world.events.clear();
        world.next_event_id = 1;
        world.event("隊伍在營地集合。".into(), None, None).unwrap();
        world.activate_allocator();
        world
    }

    pub fn snapshot(&self) -> Snapshot {
        Snapshot {
            schema_version: 1,
            revision: self.revision,
            sim_time_ms: self.sim_time_ms,
            characters: self
                .characters
                .iter()
                .map(|(id, p)| CharacterSnapshot {
                    id: id.clone(),
                    name: p.character.name().into(),
                    gender: p.gender,
                    position: p.position,
                    velocity: self.velocity(p),
                    loadout: p.loadout.clone(),
                    squad_id: p.squad_id.clone(),
                })
                .collect(),
            squads: self
                .squads
                .values()
                .map(|s| SquadSnapshot {
                    id: s.id.clone(),
                    name: s.name.clone(),
                    member_ids: s.member_ids.clone(),
                    commander_id: self.effective_commander(&s.id),
                    nominal_commander_id: s.nominal_commander_id.clone(),
                    parent_squad_id: s.parent_squad_id.clone(),
                    child_squad_ids: s.child_squad_ids.clone(),
                })
                .collect(),
            events: self.events.clone(),
        }
    }

    fn velocity(&self, p: &Person) -> [f64; 2] {
        for point in &p.route {
            let d = distance(p.position, *point);
            if d > 1e-8 {
                let v = self.config.speed(p.pace);
                return [
                    (point[0] - p.position[0]) / d * v,
                    (point[1] - p.position[1]) / d * v,
                ];
            }
        }
        [0.0, 0.0]
    }

    pub fn character(&self, id: &str) -> Option<&Character> {
        self.characters.get(id).map(|p| &p.character)
    }

    pub fn configure(&mut self, config: Config) -> Result<()> {
        self.transaction(|world| {
            world.config = config;
            Ok(())
        })
    }
    pub fn is_moving(&self) -> bool {
        self.characters.values().any(|p| !p.route.is_empty())
    }

    pub fn activate_allocator(&self) {
        CharacterId::reserve_through(self.next_character_id - 1);
    }

    /// Loading an older slot cannot reuse IDs consumed since that slot was saved.
    pub fn retain_allocation_floor(&mut self, other: &Self) {
        self.next_character_id = self.next_character_id.max(other.next_character_id);
        self.next_squad_id = self.next_squad_id.max(other.next_squad_id);
        self.next_event_id = self.next_event_id.max(other.next_event_id);
        self.revision = self.revision.max(other.revision).saturating_add(1);
    }

    fn transaction<T>(&mut self, f: impl FnOnce(&mut Self) -> Result<T>) -> Result<T> {
        let mut candidate = self.clone();
        let value = f(&mut candidate)?;
        candidate.revision = candidate
            .revision
            .checked_add(1)
            .ok_or("revision exhausted")?;
        candidate.validate()?;
        candidate.activate_allocator();
        *self = candidate;
        Ok(value)
    }

    pub fn add_character(
        &mut self,
        name: String,
        gender: Gender,
        position: [f64; 2],
    ) -> Result<String> {
        self.transaction(|w| {
            let id = w.add_person_inner(name, gender, position)?;
            w.event("一名人物加入世界。".into(), Some(id.clone()), None)?;
            Ok(id)
        })
    }
    fn add_person_inner(
        &mut self,
        name: String,
        gender: Gender,
        position: [f64; 2],
    ) -> Result<String> {
        name_valid(&name)?;
        self.config.position(position)?;
        if self.characters.len() >= MAX_CHARACTERS {
            return Err("character capacity reached".into());
        }
        let id = self.next_character_id.to_string();
        let character = Character::with_persistent_id(self.next_character_id, name)?;
        self.next_character_id = self
            .next_character_id
            .checked_add(1)
            .ok_or("character IDs exhausted")?;
        self.characters.insert(
            id.clone(),
            Person {
                character,
                gender,
                position,
                loadout: Loadout::default(),
                squad_id: None,
                route: VecDeque::new(),
                pace: Pace::Walk,
                observed: BTreeSet::new(),
                unreported: BTreeSet::new(),
            },
        );
        Ok(id)
    }

    pub fn join_squad(&mut self, character_id: &str, squad_id: &str) -> Result<()> {
        self.transaction(|w| {
            if !w.squads.contains_key(squad_id) {
                return Err("unknown squad".into());
            }
            let p = w.characters.get(character_id).ok_or("unknown character")?;
            if p.squad_id.is_some() {
                return Err("character already belongs to a squad; leave first".into());
            }
            w.characters.get_mut(character_id).unwrap().squad_id = Some(squad_id.into());
            w.squads
                .get_mut(squad_id)
                .unwrap()
                .member_ids
                .push(character_id.into());
            w.event("人物加入小隊。".into(), Some(character_id.into()), None)
        })
    }
    pub fn leave_squad(&mut self, character_id: &str) -> Result<()> {
        self.transaction(|w| {
            w.detach_person(character_id)?;
            w.prune_empty()?;
            w.event("人物離開小隊。".into(), Some(character_id.into()), None)
        })
    }
    fn detach_person(&mut self, id: &str) -> Result<()> {
        let old = self
            .characters
            .get_mut(id)
            .ok_or("unknown character")?
            .squad_id
            .take();
        if let Some(s) = old {
            self.squads
                .get_mut(&s)
                .ok_or("invalid membership")?
                .member_ids
                .retain(|v| v != id);
        }
        Ok(())
    }
    fn prune_empty(&mut self) -> Result<()> {
        loop {
            let empty = self
                .squads
                .values()
                .find(|s| s.member_ids.is_empty() && s.child_squad_ids.is_empty())
                .map(|s| s.id.clone());
            let Some(id) = empty else { break };
            let s = self.squads.remove(&id).unwrap();
            if let Some(parent) = s.parent_squad_id {
                self.squads
                    .get_mut(&parent)
                    .ok_or("invalid parent")?
                    .child_squad_ids
                    .retain(|v| v != &id);
            }
        }
        Ok(())
    }

    pub fn assign_commander(&mut self, squad_id: &str, character_id: &str) -> Result<()> {
        self.transaction(|w| {
            if !w.members_recursive(squad_id)?.contains(character_id)
                || !w
                    .characters
                    .get(character_id)
                    .ok_or("unknown character")?
                    .character
                    .can_directly_command()
            {
                return Err("commander must be an eligible member".into());
            }
            w.squads.get_mut(squad_id).unwrap().nominal_commander_id = Some(character_id.into());
            Ok(())
        })
    }
    pub fn effective_commander(&self, squad_id: &str) -> Option<String> {
        let s = self.squads.get(squad_id)?;
        let id = s.nominal_commander_id.as_ref()?;
        (self.members_recursive(squad_id).ok()?.contains(id)
            && self.characters.get(id)?.character.can_directly_command())
        .then(|| id.clone())
    }
    /// A tree reference, never a copied squad. No automatic succession is implied.
    pub fn attach_squad(&mut self, child: &str, parent: &str) -> Result<()> {
        self.transaction(|w| {
            if child == parent {
                return Err("squad cannot contain itself".into());
            }
            if w.squads
                .get(child)
                .ok_or("unknown child squad")?
                .parent_squad_id
                .is_some()
            {
                return Err("squad already has a parent".into());
            }
            let mut cursor = Some(parent.to_string());
            while let Some(id) = cursor {
                if id == child {
                    return Err("cyclic squad containment".into());
                }
                cursor = w
                    .squads
                    .get(&id)
                    .ok_or("unknown parent squad")?
                    .parent_squad_id
                    .clone();
            }
            w.squads.get_mut(child).unwrap().parent_squad_id = Some(parent.into());
            w.squads
                .get_mut(parent)
                .unwrap()
                .child_squad_ids
                .push(child.into());
            Ok(())
        })
    }
    pub fn detach_squad(&mut self, child: &str) -> Result<()> {
        self.transaction(|w| {
            let parent = w
                .squads
                .get_mut(child)
                .ok_or("unknown squad")?
                .parent_squad_id
                .take();
            if let Some(parent) = parent {
                w.squads
                    .get_mut(&parent)
                    .unwrap()
                    .child_squad_ids
                    .retain(|v| v != child);
            }
            w.prune_empty()
        })
    }
    fn members_recursive(&self, id: &str) -> Result<BTreeSet<String>> {
        let mut result = BTreeSet::new();
        let mut visited = BTreeSet::new();
        let mut stack = vec![id.to_string()];
        while let Some(id) = stack.pop() {
            if !visited.insert(id.clone()) {
                return Err("cyclic or duplicate squad containment".into());
            }
            let s = self.squads.get(&id).ok_or("unknown squad")?;
            for member in &s.member_ids {
                if !result.insert(member.clone()) {
                    return Err("duplicate character membership".into());
                }
            }
            stack.extend(s.child_squad_ids.clone());
        }
        Ok(result)
    }
    fn selected(&self, ids: &[String]) -> Result<()> {
        if ids.is_empty() || ids.len() > MAX_CHARACTERS {
            return Err("empty or excessive character selection".into());
        }
        let mut seen = BTreeSet::new();
        for id in ids {
            if !self.characters.contains_key(id) {
                return Err("unknown character".into());
            }
            if !seen.insert(id) {
                return Err("duplicate character selection".into());
            }
        }
        Ok(())
    }
    fn split_inner(&mut self, ids: &[String], name: String) -> Result<String> {
        self.selected(ids)?;
        name_valid(&name)?;
        let id = format!("squad-{}", self.next_squad_id);
        self.next_squad_id = self
            .next_squad_id
            .checked_add(1)
            .ok_or("squad IDs exhausted")?;
        for person in ids {
            self.detach_person(person)?;
        }
        self.prune_empty()?;
        let commander = ids
            .iter()
            .find(|p| self.characters[*p].character.can_directly_command())
            .cloned();
        self.squads.insert(
            id.clone(),
            Squad {
                id: id.clone(),
                name,
                member_ids: ids.to_vec(),
                nominal_commander_id: commander,
                parent_squad_id: None,
                child_squad_ids: vec![],
            },
        );
        for person in ids {
            self.characters.get_mut(person).unwrap().squad_id = Some(id.clone());
        }
        self.event("人物重新編組為小隊。".into(), None, None)?;
        Ok(id)
    }
    fn merge_inner(&mut self, source: &str, target: &str) -> Result<()> {
        if source == target {
            return Err("cannot merge a squad into itself".into());
        }
        // The public prototype command merges flat squads only. Tree edits are explicit core APIs.
        for id in [source, target] {
            let s = self.squads.get(id).ok_or("unknown squad")?;
            if s.parent_squad_id.is_some() || !s.child_squad_ids.is_empty() {
                return Err("detach hierarchy before flat prototype merge".into());
            }
        }
        let s = self.squads.remove(source).unwrap();
        for id in s.member_ids {
            self.characters.get_mut(&id).unwrap().squad_id = Some(target.into());
            self.squads.get_mut(target).unwrap().member_ids.push(id);
        }
        self.event("兩支小隊合流。".into(), None, None)
    }

    pub fn apply(&mut self, action: &Action) -> Result<()> {
        self.transaction(|w| match action {
            Action::Move { routes, pace } => {
                w.selected(
                    &routes
                        .iter()
                        .map(|r| r.character_id.clone())
                        .collect::<Vec<_>>(),
                )?;
                for route in routes {
                    w.validate_route(w.characters[&route.character_id].position, &route.points)?;
                }
                for route in routes {
                    let p = w.characters.get_mut(&route.character_id).unwrap();
                    p.route = route.points.clone().into();
                    p.pace = *pace;
                }
                Ok(())
            }
            Action::Stop { character_ids } => {
                w.selected(character_ids)?;
                for id in character_ids {
                    w.characters.get_mut(id).unwrap().route.clear();
                }
                Ok(())
            }
            Action::Split {
                character_ids,
                name,
            } => w.split_inner(character_ids, name.clone()).map(|_| ()),
            Action::Merge {
                source_squad_id,
                target_squad_id,
            } => w.merge_inner(source_squad_id, target_squad_id),
            Action::SetEquipment {
                character_id,
                loadout,
            } => {
                loadout.validate()?;
                let p = w
                    .characters
                    .get_mut(character_id)
                    .ok_or("unknown character")?;
                if &p.loadout != loadout {
                    p.loadout = loadout.clone();
                    w.event("人物調整了裝備。".into(), Some(character_id.clone()), None)?;
                }
                Ok(())
            }
            Action::Interact {
                character_id,
                event_key,
            } => w.interact(character_id, event_key),
            Action::Save { .. } | Action::Load { .. } => {
                Err("save/load require the persistence service".into())
            }
        })
    }
    fn validate_route(&self, start: [f64; 2], points: &[[f64; 2]]) -> Result<()> {
        if points.is_empty() || points.len() > MAX_ROUTE_POINTS {
            return Err("route requires 1..512 points".into());
        }
        let mut previous = start;
        let mut length = 0.0;
        for p in points {
            self.config.position(*p)?;
            length += distance(previous, *p);
            previous = *p;
        }
        if length > 32768.0 {
            return Err("route exceeds prototype distance limit".into());
        }
        Ok(())
    }
    fn interact(&mut self, id: &str, key: &str) -> Result<()> {
        let (position, text) = match key {
            "scout-north" => (
                self.config.scout_north,
                "觀察北側路口：眼前道路延伸至林邊，遠方情況仍不明。",
            ),
            "scout-east" => (
                self.config.scout_east,
                "觀察東側路口：眼前通道可通行，轉角後的情況尚未確認。",
            ),
            "return-camp" => (self.config.camp, "返回營地，帶回本次親自觀察的道路資訊。"),
            _ => return Err("unknown event_key".into()),
        };
        let p = self.characters.get_mut(id).ok_or("unknown character")?;
        if distance(p.position, position) > self.config.interaction_radius {
            return Err("character must reach the interaction location".into());
        }
        if key == "return-camp" {
            if p.unreported.is_empty() {
                return Ok(());
            }
            p.unreported.clear();
        } else {
            if !p.observed.insert(key.into()) {
                return Ok(());
            }
            p.unreported.insert(key.into());
        }
        self.event(text.into(), Some(id.into()), Some(key.into()))
    }
    fn event(
        &mut self,
        text: String,
        character_id: Option<String>,
        event_key: Option<String>,
    ) -> Result<()> {
        if self.events.len() >= MAX_EVENTS {
            return Err("event capacity reached; history retained".into());
        }
        let id = format!("event-{}", self.next_event_id);
        self.next_event_id = self
            .next_event_id
            .checked_add(1)
            .ok_or("event IDs exhausted")?;
        self.events.push(Event {
            id,
            sim_time_ms: self.sim_time_ms,
            text,
            character_id,
            event_key,
        });
        Ok(())
    }

    /// Elapsed simulation time, independent of HTTP polling or rendering frame rate.
    pub fn advance(&mut self, elapsed_ms: u64) -> Result<()> {
        let next_time = self
            .sim_time_ms
            .checked_add(elapsed_ms)
            .ok_or("simulation time exhausted")?;
        if elapsed_ms == 0 {
            return Ok(());
        }
        let moving = self.is_moving();
        let next_revision = if moving {
            self.revision.checked_add(1).ok_or("revision exhausted")?
        } else {
            self.revision
        };
        for p in self.characters.values_mut() {
            let mut remaining = self.config.speed(p.pace) * elapsed_ms as f64 / 1000.0;
            while let Some(target) = p.route.front().copied() {
                let length = distance(p.position, target);
                if length <= remaining || length <= 1e-8 {
                    p.position = target;
                    p.route.pop_front();
                    remaining = (remaining - length).max(0.0);
                } else {
                    let fraction = remaining / length;
                    p.position[0] += (target[0] - p.position[0]) * fraction;
                    p.position[1] += (target[1] - p.position[1]) * fraction;
                    break;
                }
            }
        }
        self.sim_time_ms = next_time;
        self.revision = next_revision;
        Ok(())
    }

    pub fn validate(&self) -> Result<()> {
        if self.schema_version != 1
            || self.revision == 0
            || self.revision == u64::MAX
            || self.sim_time_ms == u64::MAX
        {
            return Err("unsupported or invalid world version/clock".into());
        }
        self.config.validate()?;
        if self.characters.is_empty()
            || self.characters.len() > MAX_CHARACTERS
            || self.squads.len() > MAX_CHARACTERS
            || self.events.len() > MAX_EVENTS
        {
            return Err("invalid world capacity".into());
        }
        let mut character_max = 0;
        let mut squad_max = 0;
        let mut event_max = 0;
        let mut memberships = BTreeMap::new();
        for (id, p) in &self.characters {
            let number = numbered_id(id, "")?;
            character_max = character_max.max(number);
            if p.character.id().get() != number {
                return Err("character identity mismatch".into());
            }
            p.character.validate()?;
            self.config.position(p.position)?;
            p.loadout.validate()?;
            if !p.route.is_empty() {
                self.validate_route(p.position, &p.route.iter().copied().collect::<Vec<_>>())?;
            }
            if p.observed
                .iter()
                .any(|k| !matches!(k.as_str(), "scout-north" | "scout-east"))
                || !p.unreported.is_subset(&p.observed)
            {
                return Err("invalid observation state".into());
            }
        }
        for (id, s) in &self.squads {
            squad_max = squad_max.max(numbered_id(id, "squad-")?);
            name_valid(&s.name)?;
            if &s.id != id || (s.member_ids.is_empty() && s.child_squad_ids.is_empty()) {
                return Err("invalid or empty squad".into());
            }
            if let Some(commander) = &s.nominal_commander_id
                && !self.characters.contains_key(commander)
            {
                return Err("unknown nominal commander".into());
            }
            for member in &s.member_ids {
                if !self.characters.contains_key(member)
                    || memberships.insert(member.clone(), id.clone()).is_some()
                {
                    return Err("invalid or duplicated squad member".into());
                }
            }
            if let Some(parent) = &s.parent_squad_id
                && !self
                    .squads
                    .get(parent)
                    .ok_or("missing parent")?
                    .child_squad_ids
                    .contains(id)
            {
                return Err("parent linkage mismatch".into());
            }
            for child in &s.child_squad_ids {
                if self
                    .squads
                    .get(child)
                    .ok_or("missing child")?
                    .parent_squad_id
                    .as_ref()
                    != Some(id)
                {
                    return Err("child linkage mismatch".into());
                }
            }
            self.members_recursive(id)?;
        }
        for (id, p) in &self.characters {
            if p.squad_id.as_ref() != memberships.get(id) {
                return Err("character squad linkage mismatch".into());
            }
        }
        let mut event_ids = BTreeSet::new();
        let mut previous_time = 0;
        let mut observed: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
        let mut unreported: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
        for event in &self.events {
            let number = numbered_id(&event.id, "event-")?;
            if !event_ids.insert(&event.id)
                || number <= event_max
                || event.sim_time_ms < previous_time
                || event.sim_time_ms > self.sim_time_ms
            {
                return Err("invalid event chronology".into());
            }
            event_max = number;
            previous_time = event.sim_time_ms;
            name_valid(&event.text)?;
            if let Some(id) = &event.character_id
                && !self.characters.contains_key(id)
            {
                return Err("event references unknown character".into());
            }
            if let Some(key) = &event.event_key {
                let id = event
                    .character_id
                    .as_ref()
                    .ok_or("observation lacks character")?;
                match key.as_str() {
                    "scout-north" | "scout-east" => {
                        if !observed.entry(id.clone()).or_default().insert(key.clone()) {
                            return Err("duplicated observation event".into());
                        }
                        unreported
                            .entry(id.clone())
                            .or_default()
                            .insert(key.clone());
                    }
                    "return-camp" => {
                        let pending = unreported.entry(id.clone()).or_default();
                        if pending.is_empty() {
                            return Err("return without observed information".into());
                        }
                        pending.clear();
                    }
                    _ => return Err("unknown saved event key".into()),
                }
            }
        }
        for (id, p) in &self.characters {
            if p.observed != observed.remove(id).unwrap_or_default()
                || p.unreported != unreported.remove(id).unwrap_or_default()
            {
                return Err("event history does not match observations".into());
            }
        }
        for (next, max) in [
            (self.next_character_id, character_max),
            (self.next_squad_id, squad_max),
            (self.next_event_id, event_max),
        ] {
            if next <= max || next == u64::MAX {
                return Err("unsafe saved ID allocator".into());
            }
        }
        Ok(())
    }
}
