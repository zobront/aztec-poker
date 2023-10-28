mod hand;

use dep::aztec::{
    hash,
    types::{
        address::{AztecAddress},
        type_serialization::TypeSerializationInterface
    }
};
use dep::std::hash::pedersen;
use hand::Hand;

global TABLE_SERIALIZED_LEN: Field = 9;

struct TableOptions {
    small_blind: Field, // big calculated as 2 * small
    // @todo maybe abstract out "percentage" into its own type
    rake: Field, // in 1e18
    timeout: Field // in seconds
}

struct Table {
    p0: AztecAddress,
    p1: AztecAddress,
    nonce: Field,
    p0_stack: Field,
    p1_stack: Field,
    p0_is_dealer: bool,
    options: TableOptions,
    hand: Hand
}

impl Table {
    pub fn new(p0: AztecAddress, p1: AztecAddress, rake: Field, small_blind: Field, timeout: Field, nonce: Field) -> Self {
        let options = TableOptions {
            small_blind,
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

    pub fn validate_caller(self, caller: AztecAddress, should_be_dealer: bool) {
        if (should_be_dealer && self.p0_is_dealer) || (!should_be_dealer && !self.p0_is_dealer) {
            assert(caller.eq(self.p0));
        } else {
            assert(caller.eq(self.p1));
        }
    }

    pub fn validate_and_increment_phase(&mut self, phase: Field) {
        assert(phase == self.hand.next_phase.phase);
        self.hand.next_phase.phase += 1;
    }

    pub fn validate_phase(self, phase: Field) {
        assert(phase == self.hand.next_phase.phase);
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
