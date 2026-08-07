use std::fmt;
use std::sync::atomic::{AtomicU64, Ordering};

static NEXT_CHARACTER_ID: AtomicU64 = AtomicU64::new(1);

/// 世界內人物的穩定唯一識別。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct CharacterId(u64);

impl CharacterId {
    pub fn new() -> Self {
        Self(NEXT_CHARACTER_ID.fetch_add(1, Ordering::Relaxed))
    }

    pub fn get(self) -> u64 {
        self.0
    }
}

impl Default for CharacterId {
    fn default() -> Self {
        Self::new()
    }
}

/// 人物目前由真人玩家或 NPC 控制。
///
/// 這只是控制來源，不代表玩家與 NPC 使用不同的人物模型。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ControllerKind {
    Player,
    Npc,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Presence {
    Online,
    Offline,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Consciousness {
    Conscious,
    Unconscious,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LifeState {
    Alive,
    Dead,
}

/// MP0 的人物核心。
///
/// `martial`（武力）與 `intellect`（智力）目前只是能力尺度；
/// 不在此處提前寫死戰鬥、傷害或成長公式。
#[derive(Debug, Clone, PartialEq)]
pub struct Character {
    id: CharacterId,
    name: String,
    controller: ControllerKind,
    martial: f32,
    intellect: f32,
    presence: Presence,
    consciousness: Consciousness,
    life_state: LifeState,
}

impl Character {
    pub fn new(
        name: impl Into<String>,
        controller: ControllerKind,
        martial: f32,
        intellect: f32,
    ) -> Result<Self, CharacterError> {
        let name = name.into();
        if name.trim().is_empty() {
            return Err(CharacterError::EmptyName);
        }
        if !martial.is_finite() || martial < 0.0 {
            return Err(CharacterError::InvalidAbilityValue("martial"));
        }
        if !intellect.is_finite() || intellect < 0.0 {
            return Err(CharacterError::InvalidAbilityValue("intellect"));
        }

        Ok(Self {
            id: CharacterId::new(),
            name,
            controller,
            martial,
            intellect,
            presence: Presence::Online,
            consciousness: Consciousness::Conscious,
            life_state: LifeState::Alive,
        })
    }

    pub fn id(&self) -> CharacterId {
        self.id
    }

    pub fn name(&self) -> &str {
        &self.name
    }

    pub fn controller(&self) -> ControllerKind {
        self.controller
    }

    pub fn martial(&self) -> f32 {
        self.martial
    }

    pub fn intellect(&self) -> f32 {
        self.intellect
    }

    pub fn presence(&self) -> Presence {
        self.presence
    }

    pub fn consciousness(&self) -> Consciousness {
        self.consciousness
    }

    pub fn life_state(&self) -> LifeState {
        self.life_state
    }

    pub fn set_presence(&mut self, presence: Presence) {
        self.presence = presence;
    }

    pub fn set_consciousness(&mut self, consciousness: Consciousness) {
        if self.life_state == LifeState::Alive {
            self.consciousness = consciousness;
        }
    }

    /// MP0 中死亡是不可逆狀態；復活若未來存在，必須另立正式規則。
    pub fn die(&mut self) {
        self.life_state = LifeState::Dead;
        self.consciousness = Consciousness::Unconscious;
    }

    /// 是否具備「直接下達指揮」的最低資格。
    ///
    /// 在線／離線目前只代表真人控制可用性；NPC 即使沒有真人在線概念，
    /// 仍使用同一欄位。更完整的通訊、失聯與代理指揮留待後續模組。
    pub fn can_directly_command(&self) -> bool {
        self.life_state == LifeState::Alive
            && self.consciousness == Consciousness::Conscious
            && self.presence == Presence::Online
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CharacterError {
    EmptyName,
    InvalidAbilityValue(&'static str),
}

impl fmt::Display for CharacterError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::EmptyName => write!(f, "character name cannot be empty"),
            Self::InvalidAbilityValue(field) => write!(f, "invalid ability value: {field}"),
        }
    }
}

impl std::error::Error for CharacterError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn characters_receive_unique_ids() {
        let a = Character::new("A", ControllerKind::Player, 5.0, 5.0).unwrap();
        let b = Character::new("B", ControllerKind::Npc, 5.0, 5.0).unwrap();
        assert_ne!(a.id(), b.id());
    }

    #[test]
    fn player_and_npc_share_the_same_character_model() {
        let player = Character::new("Player", ControllerKind::Player, 6.0, 4.0).unwrap();
        let npc = Character::new("NPC", ControllerKind::Npc, 4.0, 6.0).unwrap();
        assert_eq!(player.controller(), ControllerKind::Player);
        assert_eq!(npc.controller(), ControllerKind::Npc);
    }

    #[test]
    fn unconscious_character_cannot_directly_command() {
        let mut character = Character::new("A", ControllerKind::Player, 5.0, 5.0).unwrap();
        character.set_consciousness(Consciousness::Unconscious);
        assert!(!character.can_directly_command());
    }

    #[test]
    fn dead_character_cannot_directly_command() {
        let mut character = Character::new("A", ControllerKind::Player, 5.0, 5.0).unwrap();
        character.die();
        assert_eq!(character.life_state(), LifeState::Dead);
        assert_eq!(character.consciousness(), Consciousness::Unconscious);
        assert!(!character.can_directly_command());
    }

    #[test]
    fn offline_character_cannot_directly_command() {
        let mut character = Character::new("A", ControllerKind::Player, 5.0, 5.0).unwrap();
        character.set_presence(Presence::Offline);
        assert!(!character.can_directly_command());
    }

    #[test]
    fn conscious_alive_online_character_can_directly_command() {
        let character = Character::new("A", ControllerKind::Player, 5.0, 5.0).unwrap();
        assert!(character.can_directly_command());
    }

    #[test]
    fn invalid_character_data_is_rejected() {
        assert_eq!(
            Character::new(" ", ControllerKind::Npc, 1.0, 1.0),
            Err(CharacterError::EmptyName)
        );
        assert_eq!(
            Character::new("A", ControllerKind::Npc, -1.0, 1.0),
            Err(CharacterError::InvalidAbilityValue("martial"))
        );
    }
}
