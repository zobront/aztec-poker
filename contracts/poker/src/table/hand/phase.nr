use dep::aztec::types::{
    address::{AztecAddress},
    type_serialization::{
        TypeSerializationInterface,
        bool_serialization::{BoolSerializationMethods, BOOL_SERIALIZED_LEN}
    }
};

global PHASE_SERIALIZED_LEN: Field = 1;

// global PHASES = [
//     "DEALER_SHUFFLE", // 0,
//     "PLAYER_SHUFFLE", // 1,
//     "DEAL", // 2,
//     "PREFLOP_PLAYER_BET", // 3,
//     "PREFLOP_DEALER_BET", // 4,
//     "DEAL_FLOP", // 5,
//     "REVEAL_FLOP", // 6,
//     "FLOP_PLAYER_BET", // 7,
//     "FLOP_DEALER_BET", // 8,
//     "DEAL_TURN", // 9,
//     "REVEAL_TURN", // 10,
//     "TURN_PLAYER_BET", // 11,
//     "TURN_DEALER_BET", // 12,
//     "DEAL_RIVER", // 13,
//     "REVEAL_RIVER", // 14,
//     "RIVER_PLAYER_BET", // 15,
//     "RIVER_DEALER_BET", // 16,
//     "PLAYER_SHOWDOWN", // 17,
//     "DEALER_SHOWDOWN" // 18
// ]

struct Phase {
    phase: Field
}

impl Phase {
    pub fn new() -> Self {
        Phase {
            phase: 0
        }
    }

    pub fn serialize(self) -> [Field; PHASE_SERIALIZED_LEN] {
        [self.phase]
    }

    // needs to be able to increment by more than one
    // ex. bet, raise, call, then we jump to next phase
    pub fn increment_by(&mut self, amount: Field) {
        assert (self.phase as u32 + amount as u32 <= 18);
        self.phase += amount;
    }

    pub fn last(&mut self) {
        assert (self.phase as u32 >= 0);
        self.phase -= 1;
    }

    pub fn reset(&mut self) {
        self.phase = 0;
    }

    pub fn validate_betting_phase(dealer: bool) {
        if dealer {
            assert (self.phase == 4 || self.phase == 8 || self.phase == 12 || self.phase == 16);
        } else {
            assert (self.phase == 3 || self.phase == 7 || self.phase == 11 || self.phase == 15);
        }
    }

}

fn deserialize(preimage: [Field; PHASE_SERIALIZED_LEN]) -> Phase {
    Phase {
            preimage[0]
    }
}

fn serialize(Phase: Phase) -> [Field; Phase_SERIALIZED_LEN] {
    Phase.serialize()
}

global PhaseMethods = TypeSerializationInterface {
    deserialize,
    serialize
};
