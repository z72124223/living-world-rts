use serde_json::{Value, json};
use std::{
    io::{BufRead, BufReader, Read, Write},
    net::TcpStream,
    path::Path,
    process::{Child, Command, Stdio},
    sync::mpsc,
    thread,
    time::{Duration, Instant},
};
use world_core::prototype::Gender;
use world_prototype::Engine;

struct Server {
    child: Child,
    port: u16,
}
impl Server {
    fn start(directory: &Path) -> Self {
        let mut child = Command::new(env!("CARGO_BIN_EXE_world-prototype"))
            .args(["--port", "0", "--save-dir"])
            .arg(directory)
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .unwrap();
        let stdout = child.stdout.take().unwrap();
        let (sender, receiver) = mpsc::channel();
        thread::spawn(move || {
            let mut line = String::new();
            BufReader::new(stdout).read_line(&mut line).unwrap();
            let _ = sender.send(line);
        });
        let line = match receiver.recv_timeout(Duration::from_secs(10)) {
            Ok(line) => line,
            Err(e) => {
                let _ = child.kill();
                let _ = child.wait();
                panic!("server readiness: {e}");
            }
        };
        let port = line
            .trim()
            .strip_prefix("WORLD_READY http://127.0.0.1:")
            .expect("real process readiness")
            .parse()
            .unwrap();
        Self { child, port }
    }
    fn raw(&self, request: String) -> (u16, Value) {
        let mut stream = TcpStream::connect(("127.0.0.1", self.port)).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(12)))
            .unwrap();
        stream.write_all(request.as_bytes()).unwrap();
        let mut bytes = vec![];
        stream.read_to_end(&mut bytes).unwrap();
        let index = bytes.windows(4).position(|v| v == b"\r\n\r\n").unwrap();
        let head = std::str::from_utf8(&bytes[..index]).unwrap();
        let status = head.split_whitespace().nth(1).unwrap().parse().unwrap();
        (status, serde_json::from_slice(&bytes[index + 4..]).unwrap())
    }
    fn get(&self) -> Value {
        let (status, body) = self.raw(format!(
            "GET /snapshot HTTP/1.1\r\nHost: 127.0.0.1:{}\r\nConnection: close\r\n\r\n",
            self.port
        ));
        assert_eq!(status, 200);
        body
    }
    fn post(&self, body: Value) -> (u16, Value) {
        let body = serde_json::to_string(&body).unwrap();
        self.raw(format!("POST /command HTTP/1.1\r\nHost: 127.0.0.1:{}\r\nContent-Type: application/json\r\nContent-Length: {}\r\n\r\n{}",self.port,body.len(),body))
    }
    fn ok(&self, body: Value) -> Value {
        let (status, response) = self.post(body);
        assert_eq!(status, 200, "{response}");
        assert_eq!(response["ok"], true);
        response["snapshot"].clone()
    }
    fn wait_position(&self, id: &str, target: [f64; 2], timeout: Duration) -> Value {
        let start = Instant::now();
        loop {
            let snapshot = self.get();
            let person = snapshot["characters"]
                .as_array()
                .unwrap()
                .iter()
                .find(|p| p["id"] == id)
                .unwrap();
            let x = person["position"][0].as_f64().unwrap();
            let y = person["position"][1].as_f64().unwrap();
            if (x - target[0]).hypot(y - target[1]) < 0.001 {
                return snapshot;
            }
            assert!(start.elapsed() < timeout, "route did not arrive: {person}");
            thread::sleep(Duration::from_millis(150));
        }
    }
}
impl Drop for Server {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[test]
fn actual_http_split_merge_move_stop_save_restart_and_new_character() {
    let directory = tempfile::tempdir().unwrap();
    let server = Server::start(directory.path());
    let initial = server.get();
    assert_eq!(initial["characters"].as_array().unwrap().len(), 4);
    assert_eq!(initial["characters"][0]["position"], json!([304.0, 816.0]));
    let split =
        json!({"request_id":"split-1","type":"split","character_ids":["3","4"],"name":"側翼"});
    let split_snapshot = server.ok(split.clone());
    assert_eq!(split_snapshot["squads"].as_array().unwrap().len(), 2);
    assert_eq!(server.ok(split.clone())["events"], split_snapshot["events"]);
    assert_eq!(
        server
            .post(json!({"request_id":"split-1","type":"stop","character_ids":["1"]}))
            .0,
        409
    );
    let merged=server.ok(json!({"request_id":"merge-1","type":"merge","source_squad_id":"squad-2","target_squad_id":"squad-1"}));
    assert_eq!(merged["characters"], initial["characters"]);
    server.ok(json!({"request_id":"move-1","type":"move","routes":[{"character_id":"1","points":[[360,816],[360,900]]}],"pace":"run"}));
    thread::sleep(Duration::from_millis(450));
    let moving = server.get();
    assert!(moving["characters"][0]["position"][0].as_f64().unwrap() > 304.0);
    let stopped = server.ok(json!({"request_id":"stop-1","type":"stop","character_ids":["1"]}));
    thread::sleep(Duration::from_millis(300));
    assert_eq!(server.get()["characters"], stopped["characters"]);
    let equipped=server.ok(json!({"request_id":"equip-1","type":"set_equipment","character_id":"2","loadout":{"clothing":"cloth","armor":"chest","weapon":"sword"}}));
    server.ok(json!({"request_id":"save-1","type":"save","slot":"slot-1"}));
    let current = std::fs::read(directory.path().join("current.json")).unwrap();
    for invalid in [
        json!({"request_id":"bad-1","type":"move","routes":[{"character_id":"1","points":[[-1,0]]}],"pace":"walk"}),
        json!({"request_id":"bad-2","type":"split","character_ids":["1","1"],"name":"bad"}),
        json!({"request_id":"bad-3","type":"stop","character_ids":["missing"]}),
        json!({"request_id":"bad-4","type":"merge","source_squad_id":"squad-1","target_squad_id":"squad-1"}),
        json!({"request_id":"bad-5","type":"save","slot":"../current"}),
        json!({"request_id":"bad-6","type":"stop","character_ids":["1"],"unexpected":true}),
        json!({"request_id":"bad-7","type":"not-a-command"}),
    ] {
        assert_eq!(server.post(invalid).0, 400);
    }
    std::fs::write(directory.path().join("slot-2.json"), b"{corrupt").unwrap();
    assert_eq!(
        server
            .post(json!({"request_id":"bad-load","type":"load","slot":"slot-2"}))
            .0,
        422
    );
    assert_eq!(server.get()["characters"], equipped["characters"]);
    assert_eq!(
        std::fs::read(directory.path().join("current.json")).unwrap(),
        current
    );
    drop(server);
    // A real executable restart, then creation through the documented Rust-only API.
    let server = Server::start(directory.path());
    let restarted = server.get();
    assert_eq!(restarted["characters"], equipped["characters"]);
    assert_eq!(restarted["events"], equipped["events"]);
    assert_eq!(server.ok(split)["squads"].as_array().unwrap().len(), 1);
    drop(server);
    {
        let mut engine = Engine::open(directory.path()).unwrap();
        assert_eq!(
            engine
                .update_world(|w| w.add_character(
                    "重啟後加入".into(),
                    Gender::Female,
                    [400.0, 900.0]
                ))
                .unwrap(),
            "5"
        );
    }
    let server = Server::start(directory.path());
    assert_eq!(server.get()["characters"].as_array().unwrap().len(), 5);
    let loaded = server.ok(json!({"request_id":"load-1","type":"load","slot":"slot-1"}));
    assert_eq!(loaded["characters"], equipped["characters"]);
    drop(server);
    {
        let mut engine = Engine::open(directory.path()).unwrap();
        assert_eq!(
            engine
                .update_world(|w| w.add_character("再次加入".into(), Gender::Male, [432.0, 900.0]))
                .unwrap(),
            "6"
        );
    }
    println!(
        "HTTP_RESTART_PASS four-person IDs, split/merge, timed move, stop, equipment, slots, request replay, corrupt load, new IDs 5 then 6"
    );
}

#[test]
fn actual_http_observation_requires_arrival_and_return_survives_restart() {
    let directory = tempfile::tempdir().unwrap();
    let server = Server::start(directory.path());
    assert_eq!(server.post(json!({"request_id":"remote-scout","type":"interact","character_id":"1","event_key":"scout-north"})).0,400);
    server.ok(json!({"request_id":"north-route","type":"move","routes":[{"character_id":"1","points":[[1040,304]]}],"pace":"run"}));
    server.wait_position("1", [1040.0, 304.0], Duration::from_secs(25));
    let observed=server.ok(json!({"request_id":"observe","type":"interact","character_id":"1","event_key":"scout-north"}));
    assert_eq!(server.ok(json!({"request_id":"observe-again","type":"interact","character_id":"1","event_key":"scout-north"}))["events"],observed["events"]);
    server.ok(json!({"request_id":"return-route","type":"move","routes":[{"character_id":"1","points":[[336,848]]}],"pace":"run"}));
    server.wait_position("1", [336.0, 848.0], Duration::from_secs(25));
    let returned=server.ok(json!({"request_id":"return-event","type":"interact","character_id":"1","event_key":"return-camp"}));
    assert!(
        returned["events"]
            .as_array()
            .unwrap()
            .iter()
            .any(|e| e["event_key"] == "return-camp")
    );
    drop(server);
    let server = Server::start(directory.path());
    assert_eq!(server.get()["events"], returned["events"]);
    assert_eq!(server.ok(json!({"request_id":"return-again","type":"interact","character_id":"1","event_key":"return-camp"}))["events"],returned["events"]);
    println!(
        "HTTP_SCOUT_RETURN_PASS actual timed travel north and back, proximity gate, event deduplication, restart history"
    );
}

#[test]
fn actual_http_rejects_cross_origin_host_streams_and_oversized_requests() {
    let directory = tempfile::tempdir().unwrap();
    let server = Server::start(directory.path());
    let port = server.port;
    for (request, expected) in [
        (
            format!("GET /snapshot HTTP/1.1\r\nHost: evil.example:{port}\r\n\r\n"),
            403,
        ),
        (
            format!(
                "GET /snapshot HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nOrigin: https://evil.example\r\n\r\n"
            ),
            403,
        ),
        (
            format!(
                "GET /snapshot HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nSec-Fetch-Site: cross-site\r\n\r\n"
            ),
            403,
        ),
        (
            format!(
                "POST /command HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Length: 65537\r\n\r\n"
            ),
            413,
        ),
        (
            format!(
                "POST /command HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nTransfer-Encoding: chunked\r\n\r\n"
            ),
            400,
        ),
        (
            format!(
                "POST /command HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n"
            ),
            400,
        ),
        (
            format!(
                "POST /command HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Type: text/plain\r\nContent-Length: 0\r\n\r\n"
            ),
            415,
        ),
        (
            format!("GET /unknown HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n\r\n"),
            404,
        ),
        (
            format!("GET /command HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n\r\n"),
            405,
        ),
        (
            format!(
                "POST /command HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Type: application/json\r\nContent-Length: 1\r\n\r\n{{"
            ),
            400,
        ),
    ] {
        assert_eq!(server.raw(request).0, expected);
    }
    assert_eq!(server.get()["characters"].as_array().unwrap().len(), 4);
    let output = Command::new(env!("CARGO_BIN_EXE_world-prototype"))
        .args(["--host", "0.0.0.0"])
        .output()
        .unwrap();
    assert!(!output.status.success());
    println!(
        "HTTP_BOUNDARY_PASS loopback-only options, Host/Origin, framing, bounded body, errors preserve world"
    );
}

#[test]
fn delayed_client_bytes_work_with_nonblocking_windows_listener() {
    let directory = tempfile::tempdir().unwrap();
    let server = Server::start(directory.path());
    let mut stream = TcpStream::connect(("127.0.0.1", server.port)).unwrap();
    stream
        .set_read_timeout(Some(Duration::from_secs(5)))
        .unwrap();
    thread::sleep(Duration::from_millis(100));
    stream
        .write_all(
            format!(
                "GET /snapshot HTTP/1.1\r\nHost: 127.0.0.1:{}\r\n",
                server.port
            )
            .as_bytes(),
        )
        .unwrap();
    thread::sleep(Duration::from_millis(100));
    stream.write_all(b"\r\n").unwrap();
    let mut response = String::new();
    stream.read_to_string(&mut response).unwrap();
    assert!(response.starts_with("HTTP/1.1 200 "));
}
