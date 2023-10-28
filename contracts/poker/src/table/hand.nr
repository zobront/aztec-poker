mod phase;

use dep::aztec::types::{
    address::{AztecAddress},
    type_serialization::TypeSerializationInterface
};
use phase::Phase;

global HAND_SERIALIZED_LEN: Field = 66;

struct Hand {
    p0_pot: Field,
    p1_pot: Field,
    // @todo what's most inexpensive way that we need
    // 52 cards for shuffle but only 9 for gameplay
    // should i move shuffle out and keep this separate, or is that more wasteful?
    deck: [Field; 52],
    next_card_idx: Field,
    table_cards: [Field; 5],
    dealer_hand: [Field; 2],
    player_hand: [Field; 2],
    next_phase: Phase,
    last_move_time: Field
}

impl Hand {
    pub fn new() -> Self {
        Hand {
            p0_pot: 0,
            p1_pot: 0,
            deck: [0; 52],
            next_card_idx: 0,
            table_cards: [0; 5],
            dealer_hand: [0; 2],
            player_hand: [0; 2],
            next_phase: Phase::new(),
            last_move_time: 0 // @todo is zero fine?
        }
    }

    pub fn get_next_card(&mut self) -> Field {
        let next_card = self.deck[self.next_card_idx];
        self.next_card_idx += 1;
        next_card
    }

    pub fn get_next_two_cards(&mut self) -> [Field; 2] {
        let next_card = self.deck[self.next_card_idx];
        let next_card2 = self.deck[self.next_card_idx + 1];
        self.next_card_idx += 2;
        [next_card, next_card2]
    }

    pub fn get_next_three_cards(&mut self) -> [Field; 3] {
        let next_card = self.deck[self.next_card_idx];
        let next_card2 = self.deck[self.next_card_idx + 1];
        let next_card3 = self.deck[self.next_card_idx + 2];
        self.next_card_idx += 3;
        [next_card, next_card2, next_card3]
    }

    pub fn reset(&mut self) {
        self.p0_pot = 0;
        self.p1_pot = 0;
        self.deck = [0; 52];
        self.next_card_idx = 0;
        self.table_cards = [0; 5];
        self.dealer_hand = [0; 2];
        self.player_hand = [0; 2];
        self.next_phase = Phase::new();
        self.last_move_time = 0;
    }
}
