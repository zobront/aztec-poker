use dep::aztec::types::{
    address::{AztecAddress},
    type_serialization::TypeSerializationInterface
};

// 13 fields
struct Hand {
    p0_pot: Field,
    p1_pot: Field,
    dealer_hand: [Field; 2],
    player_hand: [Field; 2],
    table_cards: [Field; 5],
    phase: Field,
    last_move_time: Field
}

impl Hand {
    pub fn new() -> Self {
        Hand {
            p0_pot: 0,
            p1_pot: 0,
            dealer_hand: [0; 2],
            player_hand: [0; 2],
            table_cards: [0; 5],
            phase: 0,
            last_move_time: 0 // @todo is zero fine?
        }
    }

    pub fn validate_and_shift_phase<N>(&mut self, phases: [Field; N], shift: Field, time: Field) {
        self.validate_phase(phases);
        self.shift_phase(shift, time);
    }

    pub fn validate_phase<N>(self, phases: [Field; N]) {
        let mut found = false;
        for phase in phases {
            if phase == self.phase {
                found = true;
                // @todo break?
            }
        }
        assert(found);
    }

    pub fn shift_phase(&mut self, shift: Field, time: Field) {
        self.phase = (self.phase + shift) % 19;
        self.last_move_time = time;
    }
}
