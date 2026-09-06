use serde_json::json;
use world_core::prototype::{Command, Gender};
use world_prototype::Engine;

fn cmd(value: serde_json::Value) -> Command {
    serde_json::from_value(value).unwrap()
}

#[test]
fn save_load_restart_new_id_and_receipt_replay() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = Engine::open(dir.path()).unwrap();
    let split =
        cmd(json!({"request_id":"split","type":"split","character_ids":["3","4"],"name":"側翼"}));
    let first = engine.command(split.clone()).unwrap();
    assert_eq!(engine.command(split.clone()).unwrap(), first);
    engine
        .command(cmd(
            json!({"request_id":"save","type":"save","slot":"slot-1"}),
        ))
        .unwrap();
    assert_eq!(
        engine
            .update_world(|w| w.add_character("新人".into(), Gender::Female, [400.0, 900.0]))
            .unwrap(),
        "5"
    );
    engine
        .command(cmd(
            json!({"request_id":"load","type":"load","slot":"slot-1"}),
        ))
        .unwrap();
    drop(engine);
    let mut engine = Engine::open(dir.path()).unwrap();
    let before = engine.snapshot();
    assert_eq!(before.characters.len(), 4);
    assert_eq!(before.squads.len(), 2);
    assert_eq!(engine.command(split).unwrap(), before);
    assert_eq!(
        engine
            .update_world(|w| w.add_character("再加入".into(), Gender::Male, [432.0, 900.0]))
            .unwrap(),
        "6"
    );
    let conflict = engine
        .command(cmd(
            json!({"request_id":"split","type":"stop","character_ids":["1"]}),
        ))
        .unwrap_err();
    assert_eq!(conflict.status, 409);
}

#[test]
fn corrupted_slots_and_failed_atomic_replace_do_not_damage_current_world() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = Engine::open(dir.path()).unwrap();
    let before = engine.snapshot();
    let current = std::fs::read(dir.path().join("current.json")).unwrap();
    std::fs::write(dir.path().join("slot-1.json"), b"{broken").unwrap();
    assert_eq!(
        engine
            .command(cmd(
                json!({"request_id":"bad-load","type":"load","slot":"slot-1"})
            ))
            .unwrap_err()
            .status,
        422
    );
    std::fs::create_dir(dir.path().join("slot-2.json")).unwrap();
    assert_eq!(
        engine
            .command(cmd(
                json!({"request_id":"failed-save","type":"save","slot":"slot-2"})
            ))
            .unwrap_err()
            .status,
        500
    );
    for slot in ["../current", "C:/elsewhere", "slot-0", "slot-1.json", ""] {
        assert_eq!(
            engine
                .command(cmd(
                    json!({"request_id":"bad-slot","type":"save","slot":slot})
                ))
                .unwrap_err()
                .status,
            400
        );
    }
    assert_eq!(engine.snapshot(), before);
    assert_eq!(
        std::fs::read(dir.path().join("current.json")).unwrap(),
        current
    );
    drop(engine);
    assert_eq!(Engine::open(dir.path()).unwrap().snapshot(), before);
}

#[test]
fn corrupt_current_is_reported_without_silent_reset_and_directory_is_locked() {
    let dir = tempfile::tempdir().unwrap();
    let engine = Engine::open(dir.path()).unwrap();
    assert!(Engine::open(dir.path()).is_err());
    drop(engine);
    std::fs::write(dir.path().join("current.json"), b"bad").unwrap();
    assert!(Engine::open(dir.path()).is_err());
    assert_eq!(
        std::fs::read(dir.path().join("current.json")).unwrap(),
        b"bad"
    );
}

#[test]
fn slot_load_rejects_valid_json_with_unsafe_identity_allocator() {
    let dir = tempfile::tempdir().unwrap();
    let mut engine = Engine::open(dir.path()).unwrap();
    let mut state: serde_json::Value =
        serde_json::from_slice(&std::fs::read(dir.path().join("current.json")).unwrap()).unwrap();
    state["world"]["next_character_id"] = json!(1);
    std::fs::write(
        dir.path().join("slot-1.json"),
        serde_json::to_vec(&state).unwrap(),
    )
    .unwrap();
    let before = engine.snapshot();
    assert_eq!(
        engine
            .command(cmd(
                json!({"request_id":"load-bad-id","type":"load","slot":"slot-1"})
            ))
            .unwrap_err()
            .status,
        422
    );
    assert_eq!(engine.snapshot(), before);
}

#[test]
fn versioned_save_keeps_routes_equipment_and_observation_return_history() {
    let dir = tempfile::tempdir().unwrap();
    let mut e = Engine::open(dir.path()).unwrap();
    for value in [
        json!({"request_id":"equip","type":"set_equipment","character_id":"1","loadout":{"clothing":"cloth","armor":"chest","weapon":"sword"}}),
        json!({"request_id":"north","type":"move","routes":[{"character_id":"1","points":[[1040,304]]}],"pace":"run"}),
    ] {
        e.command(cmd(value)).unwrap();
    }
    e.advance(30000).unwrap();
    e.command(cmd(json!({"request_id":"scout","type":"interact","character_id":"1","event_key":"scout-north"}))).unwrap();
    e.command(cmd(json!({"request_id":"camp","type":"move","routes":[{"character_id":"1","points":[[336,848]]}],"pace":"run"}))).unwrap();
    e.advance(30000).unwrap();
    e.command(cmd(json!({"request_id":"return","type":"interact","character_id":"1","event_key":"return-camp"}))).unwrap();
    let before = e.snapshot();
    drop(e);
    let mut e = Engine::open(dir.path()).unwrap();
    assert_eq!(e.snapshot(), before);
    e.command(cmd(json!({"request_id":"return-again","type":"interact","character_id":"1","event_key":"return-camp"}))).unwrap();
    assert_eq!(e.snapshot().events, before.events);
    e.command(cmd(json!({"request_id":"moving","type":"move","routes":[{"character_id":"1","points":[[400,848],[400,900]]}],"pace":"walk"}))).unwrap();
    e.advance(1000).unwrap();
    drop(e);
    let mut e = Engine::open(dir.path()).unwrap();
    e.advance(1000).unwrap();
    assert_eq!(e.snapshot().characters[0].position, [400.0, 848.0]);
}
