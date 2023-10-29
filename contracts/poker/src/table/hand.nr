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

    pub fn validate_and_shift_betting_phase(&mut self, is_dealer: bool, bet_size: Field, timestamp: Field) {
        // check or bet
        if (self.p0_pot == self.p1_pot) {
            // player goes first, so will always pass to dealer
            if !is_dealer {
                self.validate_and_shift_phase([3, 7, 11, 15], 1, timestamp);
            } else {
                // if dealer checks, it progresses forward; bets passes backwards
                if bet_size == 0 {
                    self.validate_and_shift_phase([4, 8, 12, 16], 1, timestamp);
                } else {
                    self.validate_and_shift_phase([4, 8, 12, 16], 18, timestamp);
                }
            }
        } else { // @audit this assumes taht if not equal, the other player's is higher - is that always true?
            if !is_dealer {
                if bet_size == 0 {
                    // if player is calling, it's been passed back to them, so jump 2 to skip
                    self.validate_and_shift_phase([3, 7, 11, 15], 2, timestamp);
                } else {
                    // if player is raising, they will pass turn back to dealer
                    self.validate_and_shift_phase([3, 7, 11, 15], 1, timestamp);
                }
            } else {
                if bet_size == 0 {
                    // if dealer is calling, we move forward by 1 out of betting round
                    self.validate_and_shift_phase([4, 8, 12, 16], 1, timestamp);
                } else {
                    // if dealer raises, we push backwards to the player's turn
                    self.validate_and_shift_phase([4, 8, 12, 16], 18, timestamp);
                }
            }
        }
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
