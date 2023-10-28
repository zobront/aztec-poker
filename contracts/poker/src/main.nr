mod table;
mod hand;

contract Poker {
    use dep::std::option::Option;
    use dep::aztec::{
        note::{
            note_header::NoteHeader
        },
        context::{PrivateContext, PublicContext, Context},
        state_vars::{
            map::Map,
            public_state::PublicState,
            singleton::Singleton
        },
        types::{
            type_serialization::{
                field_serialization::{FieldSerializationMethods, FIELD_SERIALIZED_LEN},
                bool_serialization::{BoolSerializationMethods, BOOL_SERIALIZED_LEN}
            }
            address::{AztecAddress}
        },
        selector::compute_selector
    };
    use crate::{
        table::{Table, TableOptions, TableMethods, TABLE_SERIALIZED_LEN}
    };



    struct Storage {
        // tableid = hash(creator, options, nonce) => table
        tables: Map<PublicState<Table, TABLE_SERIALIZED_LEN>>
        // tableid = hash(creator, options, nonce) => private shuffled deck
        deck: Map<Singleton<Deck, DECK_SERIALIZED_LEN>>
    }

    impl Storage {
        fn init(context: Context) -> pub Self {
            Storage {
                tables: Map::new(context, 1, |context, slot| {
                    PublicState::new(context, slot, TableMethods)
                }),
                deck: Map::new(context, 2, |context, slot| {
                    Singleton::new(context, slot, DeckMethods)
                })
            }
        }
    }

    ////////////////////////////////
    ////// EXTERNAL FUNCTIONS //////
    ////////////////////////////////

    #[aztec(private)]
    fn constructor() {}

    ////////////////////////////////
    ///////// CREATE TABLE /////////
    ////////////////////////////////

    #[aztec(public)]
    fn create_table(opponent: AztecAddress, rake: Field, small_blind: Field, timeout: Field, nonce: Field) {
        let table = Table::new(
            AztecAddress::new(context.msg_sender()),
            opponent,
            rake,
            small_blind,
            timeout,
            nonce
        );
        storage.tables.at(table.id()).write(table);
        // @todo put chips on table (into usdp with table id verification and balances tracked here?)
    }

    #[aztec(public)]
    fn join_table(table_id: Field) {
        let mut table = storage.tables.at(table_id).read();
        if table.p1.eq(AztecAddress::new(0)) {
            // no opponent specified, anyone can join
            table.p1 = AztecAddress::new(context.msg_sender());
        } else {
            // opponent specified, confirm they are msg.sender
            assert(table.p1.eq(AztecAddress::new(context.msg_sender())));
        }
        // @todo put chips on table (need this because otherwise could double spend in two games)
    }

    ////////////////////////////////
    //////// SHUFFLE & DEAL ////////
    ////////////////////////////////

    #[aztec(private)]
    fn dealer_shuffle(table_id: Field, deck: [Field; 52]) {
        // prove that deck has one of every card (inputted as plaintext)
        let mut used = [0; false];
        for card in deck {
            assert(card as u32 < 52);
            asssert(!used[card]);
            used[card] = true;
        }

        // @todo encrypt each card with dealer's private key
        // - this can use their aztec secret key if el gamel has grumpking
        // - otherwise, will need them to register a separate secret key for el gamel
        let encrypted_deck = deck;

        // @todo save the encrypted deck into player's private storage

        // @todo is there a way to skip public check on this one since it doesn't change public state?
        // - i think that can be made safe because this private state will be nullified when read
        // - so there's no private state for them to use for player shuffle until this happens
        // - but can't figure out how to make it work
        context.call_public_function(
            compute_selector("dealer_shuffle_backend(Field)"),
            [table_id]
        )
    }

    #[aztec(public)]
    internal fn dealer_shuffle_backend(table_id: Field) {
        let mut table = storage.tables.at(table_id).read();
        table.validate_caller(caller, true);
        table.validate_and_increment_phase(0); // from 0 to 1
        storage.tables.at(table_id).write(table);
    }

    #[aztec(private)]
    fn player_shuffle(table_id: Field, shuffle_array: [Field; 52]) {
        // @todo pull old_deck directly from private state
        let old_deck = storage.deck.at(table_id).read();

        // confirm that the shuffle array contains one of each number 0-51
        let mut used = [false; 52];
        for i in shuffle_array {
            assert(i as u32 < 52);
            asssert(!used[i]);
            used[i] = true;
        }

        // set new_deck[i] to the card at position shuffle_array[i] in the old deck
        let mut new_deck = [0; 52];
        for i in 0..52 {
            new_deck[i] = old_deck[shuffle_array[i]];
        }

        // // OLD IMPLEMENTATION:
        // // if the sorted version of each deck is identical
        // // then we know new_deck is a valid shuffle of old_deck
        // let old_sorted = old_deck.sort();
        // let new_sorted = new_deck.sort();
        // for i in 0..52 {
        //     assert(old_sorted[i] == new_sorted[i]);
        // }

        // @todo encrypt each with player's private key
        let encrypted_deck = new_deck

        // initiate public state checks and updated
        context.call_public_function(
            compute_selector("player_shuffle_backend(Field,Field,[Field;2],[Field;2],[Field;5])"),
            [table_id, AztecAddress::new(context.msg_sender()), new_deck[:2], encrypted_deck[2:4], encrypted_deck[4:9]]
        )
    }

    #[aztec(public)]
    internal fn player_shuffle_backend(
        table_id: Field,
        caller: AztecAddress,
        dealer_cards: [Field; 2],
        player_cards: [Field; 2],
        table_cards: [Field; 5]
    ) {
        let mut table = storage.tables.at(table_id).read();
        table.validate_caller(caller, false);
        table.validate_and_increment_phase(1); // from 1 to 2

        table.hand.dealer_cards = dealer_cards; // already unencrypted for dealer
        table.hand.player_cards = player_cards; // double encrypted
        table.hand.table_cards = table_cards; // double encrypted

        storage.tables.at(table_id).write(table);
    }



    #[aztec(private)]
    fn deal_cards(table_id: Field, player_cards: [Field; 2]) {
        // @todo decrypt cards
        let decrypted cards = player_cards;

        // initiate public state checks and updated
        context.call_public_function(
            compute_selector("deal_cards_backend(Field,[Field;2])"),
            [table_id, AztecAddress::new(context.msg_sender()), decrypted_cards]
        )
    }

    #[aztec(public)]
    fn deal_cards_backend(table_id: Field, caller: AztecAddress, players_cards: [Field; 2]) {
        let table = storage.tables.at(table_id).read();
        table.validate_caller(caller, true);
        table.validate_and_increment_phase(2); // from 2 to 3

        table.hand.player_cards = players_cards; // unencrypt for player
        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    ///////// TABLE CARDS //////////
    ////////////////////////////////

    // @todo can i merge these into one function with generics? or at least merge backends?
    // same with deal_cards above, and maybe even player showdown? all same pattern

    #[aztec(private)]
    fn deal_flop(table_id: Field, encrypted_cards: [Field; 3]) {
        // @todo decrypt cards
        let decrypted_cards = encrypted_cards;

        // initiate public state checks and updated
        context.call_public_function(
            compute_selector("deal_flop_backend(Field,[Field;3])"),
            [table_id, AztecAddress::new(context.msg_sender()), encrypted_cards, decrypted_cards]
        )
    }

    #[aztec(public)]
    internal fn deal_flop_backend(table_id: Field, caller: AztecAddress, encrypted_flop: [Field; 3], decrypted_flop: [Field; 3]) {
        let mut table = storage.tables.at(table_id).read();
        assert(table.hand.table_cards[:3] == encrypted_flop);

        if table.hand.next_phase.phase == 5 {
            table.validate_caller(caller, true);

        } else if table.hand.next_phase.phase == 6 {
            table.validate_caller(caller, false);
        } else {
            assert(false);
        }
        table.hand.next_phase.phase += 1; // from 5 to 6 or 6 to 7

        table.hand.table_cards[:3] = decrypted_flop; // unencrypt for player

        storage.tables.at(table_id).write(table);
    }

    #[aztec(private)]
    fn deal_turn_or_river(table_id: Field, encrypted_card: Field) {
        // @todo decrypt card
        let decrypted_card = encrypted_card;

        // initiate public state checks and updated
        context.call_public_function(
            compute_selector("deal_turn_or_river_backend(Field,Field,Field,Field)"),
            [table_id, AztecAddress::new(context.msg_sender()), encrypted_card, decrypted_card]
        )
    }

    #[aztec(public)]
    internal fn deal_turn_or_river_backend(table_id: Field, caller: AztecAddress, encrypted_card: Field, decrypted_card: Field) {
        let mut table = storage.tables.at(table_id).read();
        let phase = table.hand.next_phase.phase;

        if phase == 9 || phase == 10 {
            assert(table.hand.table_cards[4] == encrypted_card);
            table.hand.table_cards[4] = decrypted_card;
        } else if phase == 13 || phase == 14 {
            assert(table.hand.table_cards[5] == encrypted_card);
            table.hand.table_cards[5] = decrypted_card;
        } else {
            assert(false);
        }

        if phase == 9 || phase == 13 {
            table.validate_caller(caller, true);
        } else if phase == 10 || phase == 14 {
            table.validate_caller(caller, false);
        }

        table.hand.next_phase.phase += 1; // from 5 to 6 or 6 to 7
        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    //////// HAND ANALYSIS /////////
    ////////////////////////////////

    #[aztec(private)]
    fn showdown(table_id: Field, hand: [Field; 2]) {
        // @todo decrypt hand
        let decrypted_hand = hand;

        // initiate public state checks and updated
        context.call_public_function(
            compute_selector("player_showdown_backend(Field,[Field;2],[Field;2])"),
            [table_id, AztecAddress::new(context.msg_sender()), decrypted_hand, encrypted_hand]
        )
    }

    #[aztec(public)]
    internal fn showdown_backend(table_id: Field, caller: AztecAddress, decrypted_hand: [Field; 2], encrypted_hand: [Field; 2]) {
        let mut table = storage.tables.at(table_id).read();
        assert(table.hand.player_cards == encrypted_hand);

        if table.hand.next_phase.phase == 17 {
            table.validate_caller(caller, false);
            table.hand.player_cards = decrypted_hand; // unencrypt for player
        } else if table.hand.next_phase.phase == 18 {
            table.validate_caller(caller, true);
            table.hand.dealer_cards = decrypted_hand; // unencrypt for player

            // @todo determine who won, settle up the pot, reset the hand
            // maybe game holds hand storage so we can call game.end_hand() and it can call hand.reset()
        } else {
            assert(false);
        }

        table.hand.next_phase.phase += 1; // from 18 to 19
        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    /////////// BETTING ////////////
    ////////////////////////////////

    // @todo TONS of repeated code here, can consolidate later

    #[aztec(public)]
    fn bet(table_id: Field, bet_size: Field) {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // pots should always be the same size when betting
        assert(table.hand.p0_pot == table.hand.p1_pot);

        // create two variables to track if caller is p0 or p1 and dealer or not
        // @todo is there a more elegant way to do this?
        let caller_is_p0 = false;
        let caller_is_dealer = false;

        if (caller == table.p0) {
            caller_is_p0 = true;
            if table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else if (caller == table.p1) {
            if !table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else {
            assert(false);
        }

        // if caller is dealer, it must be dealer's turn to bet
        // after the dealer bets, it moves backwards to the player bet
        // note, this can only happen after a check from the player
        if caller_is_dealer {
            // @todo implement that this can take arrays of options
            table.validate_phase([4, 8, 12, 16]);
            table.hand.next_phase.phase -= 1;

        // if caller is player, it must be player's turn to bet
        // after the player bets, it moves forward to the dealer's bet
        } else {
            table.validate_phase([3, 7, 11, 15]);
            table.hand.next_phase.phase += 1;
        }

        // move tokens from the correct player's stack to their pot
        if caller_is_p0 {
            table.p0_stack -= bet_size;
            table.hand.p0_pot += bet_size;
        } else {
            table.p1_stack -= bet_size;
            table.hand.p1_pot += bet_size;
        }

        // update table storage
        storage.tables.at(table_id).write(table);
    }

    // @todo might be some duplicate logic to conslidate between this and bet
    #[aztec(public)]
    fn check() {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // pots should always be the same size when betting
        assert(table.hand.p0_pot == table.hand.p1_pot);

        // create two variables to track if caller is p0 or p1 and dealer or not
        // @todo is there a more elegant way to do this?
        let caller_is_p0 = false;
        let caller_is_dealer = false;

        if (caller == table.p0) {
            caller_is_p0 = true;
            if table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else if (caller == table.p1) {
            if !table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else {
            assert(false);
        }

        // if caller is dealer, it must be dealer's turn to bet
        // after the dealer checks, it moves forward to next phase
        if caller_is_dealer {
            table.validate_phase([4, 8, 12, 16]);

        // if caller is player, it must be player's turn to bet
        // after the player checks, it moves forward to the dealer's turn
        } else {
            table.validate_phase([3, 7, 11, 15]);
        }

        // progress to next phase and update storage
        table.hand.next_phase.phase += 1;
        storage.tables.at(table_id).write(table);
    }

    #[aztec(public)]
    fn call(table_id: Field) {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // create two variables to track if caller is p0 or p1 and dealer or not
        // @todo is there a more elegant way to do this?
        let caller_is_p0 = false;
        let caller_is_dealer = false;

        if (caller == table.p0) {
            caller_is_p0 = true;
            if table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else if (caller == table.p1) {
            if !table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else {
            assert(false);
        }

        // if caller is dealer, it means the player bet
        // if the dealer calls, we move forward to the next phase
        if caller_is_dealer {
            // @todo implement that this can take arrays of options
            table.validate_phase([4, 8, 12, 16]);
            table.hand.next_phase.phase += 1;

        // if caller is player, it means the dealer bet and sent it back
        // after the player calls, we skip the dealer to go to the next phase
        } else {
            table.validate_phase([3, 7, 11, 15]);
            table.hand.next_phase.phase += 2;
        }

        // move tokens from the correct player's stack to their pot
        if caller_is_p0 {
            // other player should always have a bigger pot, underflow check
            let call_size = table.hand.p1_pot - table.hand.p0_pot;

            // @todo implement all in logic here
            table.p0_stack -= call_size;
            table.hand.p0_pot += call_size;
        } else {
            let call_size = table.hand.p0_pot - table.hand.p1_pot;
            table.p1_stack -= call_size;
            table.hand.p1_pot += call_size;
        }

        // update table storage
        storage.tables.at(table_id).write(table);
    }

    // @todo any risk of this being called at wrong time if no phase check?
    // i think it's fine, you can fold any time, right?
    // unless could be frontrun to make you fold next hand?
    #[aztec(public)]
    fn fold(table_id: Field) {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // move the pot to the opposite player
        if (caller == table.p0) {
            table.p1_stack += (table.hand.p0_pot + table.hand.p1_pot);
        } else if (caller == table.p1) {
            table.p0_stack += (table.hand.p0_pot + table.hand.p1_pot);
        } else {
            assert(false);
        }

        // @todo should reset phase, pots, etc.
        table.hand.reset();
        storage.tables.at(table_id).write(table);
    }

    // bet_size is the total bet, including the call, not just the raise money
    #[aztec(public)]
    fn raise(table_id: Field, bet_size: Field) {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // create two variables to track if caller is p0 or p1 and dealer or not
        // @todo is there a more elegant way to do this?
        let caller_is_p0 = false;
        let caller_is_dealer = false;

        if (caller == table.p0) {
            caller_is_p0 = true;
            if table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else if (caller == table.p1) {
            if !table.dealer_is_p0 {
                caller_is_dealer = true;
            }
        } else {
            assert(false);
        }

        // if caller is dealer, it must be dealer's turn to bet
        // after the dealer bets, it moves backwards to the player bet
        // note, this can only happen after a check from the player
        if caller_is_dealer {
            // @todo implement that this can take arrays of options
            table.validate_phase([4, 8, 12, 16]);
            table.hand.next_phase.phase -= 1;

        // if caller is player, it must be player's turn to bet
        // after the player bets, it moves forward to the dealer's bet
        } else {
            table.validate_phase([3, 7, 11, 15]);
            table.hand.next_phase.phase += 1;
        }

        // move tokens from the correct player's stack to their pot
        if caller_is_p0 {
            // other player should always have a bigger pot, underflow check
            let call_size = table.hand.p1_pot - table.hand.p0_pot;
            assert(bet_size > call_size);

            table.p0_stack -= bet_size;
            table.hand.p0_pot += bet_size;
        } else {
            let call_size = table.hand.p0_pot - table.hand.p1_pot;
            assert(bet_size > call_size);

            table.p1_stack -= bet_size;
            table.hand.p1_pot += bet_size;
        }
        // update table storage
        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    /////////// TIMEOUT ////////////
    ////////////////////////////////

    #[aztec(public)]
    fn timeout(table_id: Field) {
        // require(phase check should be other player's turn)
        // require(timeout has passed since last move)
        // claim the pot and end the hand
    }
