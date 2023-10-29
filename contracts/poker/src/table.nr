mod hand;
mod percentage;

use dep::aztec::{
    hash,
    types::{
        address::{AztecAddress},
        type_serialization::TypeSerializationInterface
    }
};
use dep::std::hash::pedersen;
use hand::Hand;
use percentage::Percentage;

global TABLE_SERIALIZED_LEN: Field = 22;

struct TableOptions {
    small_blind: Field, // big calculated as 2 * small
    rake: Percentage, // in 1e18
    timeout: Field // in seconds
}

struct Table {
    p0: AztecAddress, // 0
    p1: AztecAddress, // 1
    nonce: Field, // 2
    p0_stack: Field, // 3
    p1_stack: Field, // 4
    p0_is_dealer: bool, // 5 @todo replace this with dealer as address on the hand itself?
    options: TableOptions, // 6-8
    hand: Hand // 9-21
}

impl Table {
    pub fn new(p0: AztecAddress, p1: AztecAddress, rake: Field, small_blind: Field, timeout: Field, nonce: Field) -> Self {
        let options = TableOptions {
            Percentage::from(small_blind),
            rake,
            timeout
        };
        let hand = Hand::new();

        Table {
            p0,
            p1,
            nonce,
            p0_stack: 0,
            p1_stack: 0,
            p0_is_dealer: true,
            options,
            hand
        }
    }

    pub fn serialize(self) -> [Field; TABLE_SERIALIZED_LEN] {
        // insert
    }

    pub fn id(self) -> Field {
        let hashable = [
            self.p0 as Field,
            self.options.rake,
            self.options.small_blind,
            self.options.timeout,
            self.nonce
        ];
        pedersen(hashable)[0]
    }

    pub fn place_blinds(&mut self) {
        let small_blind = self.options.small_blind;
        if self.p0_is_dealer {
            self.p0_stack -= small_blind * 2;
            self.hand.p0_pot += small_blind * 2;
            self.p1_stack -= small_blind;
            self.hand.p1_pot += small_blind;
        } else {
            self.p0_stack -= small_blind;
            self.hand.p0_pot += small_blind;
            self.p1_stack -= small_blind * 2;
            self.hand.p1_pot += small_blind * 2;
        }
    }

    pub fn send_winnings_and_return_fees(&mut self, winner: Field) -> Field {
        let mut pot = self.hand.p0_pot + self.hand.p1_pot;
        let fees = pot * self.options.rake.pct_mul(pot);
        pot -= fees;

        if winner == 0 {
            self.p0_stack += pot;
        } else if winner == 1 {
            self.p1_stack += pot;
        } else {
            self.p0_stack += pot / 2;
            self.p1_stack += (pot - pot / 2);
        }

        fees
    }

    pub fn next_hand(&mut self) {
        self.hand = Hand::new();
        self.p0_is_dealer = !self.p0_is_dealer;
    }

    pub fn validate_caller(self, caller: AztecAddress, should_be_dealer: bool) {
        let caller_should_be_p0 = (should_be_dealer == self.p0_is_dealer);
        if caller_should_be_p0 {
            assert(caller.eq(self.p0));
        } else {
            assert(caller.eq(self.p1));
        }
    }

    pub fn validate_and_define_caller(self, caller: AztecAddress) -> (bool, bool) {
        let mut is_p0 = false;
        let mut is_dealer = false;

        if (caller.eq(self.p0)) {
            is_p0 = true;
            if self.p0_is_dealer {
                is_dealer = true;
            }
        } else if (caller.eq(self.p1)) {
            if !self.p0_is_dealer {
                is_dealer = true;
            }
        } else {
            assert(false);
        }

        (is_p0, is_dealer)
    }
}

fn deserialize(preimage: [Field; TABLE_SERIALIZED_LEN]) -> Table {
    // insert
}

fn serialize(table: Table) -> [Field; TABLE_SERIALIZED_LEN] {
    table.serialize()
}

global TableMethods = TypeSerializationInterface {
    deserialize,
    serialize
};
