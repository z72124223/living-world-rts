use serde_json::{Value, json};
use std::{
    io::Write,
    net::{Ipv4Addr, SocketAddrV4, TcpListener},
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
        mpsc,
    },
    thread,
    time::{Duration, Instant},
};
use world_core::prototype::Command;
use world_prototype::{Engine, http};

fn run() -> Result<(), String> {
    let mut port = 8793u16;
    let mut save_dir = std::env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
        .join("FourPersonPrototype")
        .join("saves");
    let mut run_for_ms = None;
    let mut shutdown_file: Option<PathBuf> = None;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--port" => {
                port = args
                    .next()
                    .ok_or("missing port")?
                    .parse()
                    .map_err(|_| "invalid port")?
            }
            "--save-dir" => save_dir = args.next().ok_or("missing save directory")?.into(),
            "--shutdown-file" => {
                shutdown_file = Some(args.next().ok_or("missing shutdown file")?.into())
            }
            "--run-for-ms" => {
                run_for_ms = Some(
                    args.next()
                        .ok_or("missing duration")?
                        .parse::<u64>()
                        .map_err(|_| "invalid duration")?,
                )
            }
            "--help" => {
                println!(
                    "world-prototype [--port 8793] [--save-dir DIRECTORY] [--run-for-ms N] [--shutdown-file PATH]\nAlways binds 127.0.0.1. Automatically restores current.json; save/load slots are slot-1..slot-9. A local launcher may create the shutdown file to flush and exit."
                );
                return Ok(());
            }
            _ => return Err(format!("unknown option: {arg}")),
        }
    }
    // Bind before touching saves. A busy port must not create or replace a world.
    let listener = TcpListener::bind(SocketAddrV4::new(Ipv4Addr::LOCALHOST, port))
        .map_err(|e| format!("cannot bind loopback: {e}"))?;
    let port = listener.local_addr().map_err(|e| e.to_string())?.port();
    listener.set_nonblocking(true).map_err(|e| e.to_string())?;
    let mut engine = Engine::open(&save_dir)?;
    println!("WORLD_READY http://127.0.0.1:{port}");
    std::io::stdout().flush().map_err(|e| e.to_string())?;
    let active = Arc::new(AtomicUsize::new(0));
    let (sender, receiver) =
        mpsc::sync_channel::<(http::Request, mpsc::SyncSender<(u16, Value)>)>(8);
    let start = Instant::now();
    let mut last_step = Instant::now();
    loop {
        // Movement advances even when no client is connected. Disk failures stop the service,
        // retaining the last committed world rather than acknowledging non-durable changes.
        let step_time = Instant::now();
        let elapsed = step_time.duration_since(last_step);
        if elapsed >= Duration::from_millis(100) {
            engine.advance(elapsed.as_millis().min(u64::MAX as u128) as u64)?;
            last_step = step_time;
        }
        for _ in 0..8 {
            let Ok((request, response)) = receiver.try_recv() else {
                break;
            };
            let result = match (request.method.as_str(), request.path.as_str()) {
                ("GET", "/snapshot") => (
                    200,
                    serde_json::to_value(engine.snapshot()).map_err(|e| e.to_string())?,
                ),
                ("POST", "/command") => match serde_json::from_slice::<Command>(&request.body) {
                    Ok(command) => match engine.command(command) {
                        Ok(snapshot) => (200, json!({"ok":true,"snapshot":snapshot})),
                        Err(e) => (e.status, json!({"ok":false,"error":e.message})),
                    },
                    Err(e) => (
                        400,
                        json!({"ok":false,"error":format!("invalid command JSON: {e}")}),
                    ),
                },
                (_, "/snapshot" | "/command") => {
                    (405, json!({"ok":false,"error":"method not allowed"}))
                }
                _ => (404, json!({"ok":false,"error":"unknown endpoint"})),
            };
            let _ = response.send(result);
        }
        match listener.accept() {
            Ok((mut stream, peer)) => {
                if !peer.ip().is_loopback() {
                    continue;
                }
                if active.load(Ordering::Relaxed) >= 8 {
                    http::respond(
                        &mut stream,
                        503,
                        &json!({"ok":false,"error":"local server is busy"}),
                    );
                    continue;
                }
                active.fetch_add(1, Ordering::Relaxed);
                let active = active.clone();
                let sender = sender.clone();
                thread::spawn(move || {
                    let reply = match http::read_request(&mut stream, port) {
                        Ok(request) => {
                            let (tx, rx) = mpsc::sync_channel(1);
                            if sender.try_send((request, tx)).is_err() {
                                (503, json!({"ok":false,"error":"command queue is full"}))
                            } else {
                                rx.recv_timeout(Duration::from_secs(10)).unwrap_or((503,json!({"ok":false,"error":"world unavailable; retry the same request_id"})))
                            }
                        }
                        Err((status, error)) => (status, json!({"ok":false,"error":error})),
                    };
                    if std::env::var_os("WORLD_HTTP_TRACE").is_some() {
                        eprintln!(
                            "HTTP_REPLY status={} bytes={}",
                            reply.0,
                            reply.1.to_string().len()
                        );
                    }
                    http::respond(&mut stream, reply.0, &reply.1);
                    active.fetch_sub(1, Ordering::Relaxed);
                });
            }
            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                thread::sleep(Duration::from_millis(5))
            }
            Err(e) => return Err(e.to_string()),
        }
        if run_for_ms.is_some_and(|limit| start.elapsed().as_millis() >= limit as u128)
            || shutdown_file.as_ref().is_some_and(|path| path.exists())
        {
            engine.flush()?;
            break;
        }
    }
    Ok(())
}
fn main() {
    if let Err(error) = run() {
        eprintln!("WORLD_ERROR {error}");
        std::process::exit(1);
    }
}
