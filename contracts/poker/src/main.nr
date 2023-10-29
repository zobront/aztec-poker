mod table;
mod deck;

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
        table::{Table, TableOptions, TableMethods, TABLE_SERIALIZED_LEN},
        deck::Deck
    };



    struct Storage {
        // tableid = hash(creator, options, nonce) => table
        tables: Map<PublicState<Table, TABLE_SERIALIZED_LEN>>
        // tableid = hash(creator, options, nonce) => private shuffled deck
        deck: Map<Singleton<Deck, DECK_SERIALIZED_LEN>>,
        // total rake available for withdrawal
        fees: Field
    }

    impl Storage {
        fn init(context: Context) -> pub Self {
            Storage {
                tables: Map::new(context, 1, |context, slot| {
                    PublicState::new(context, slot, TableMethods)
                }),
                deck: Map::new(context, 2, |context, slot| {
                    Singleton::new(context, slot, DeckMethods)
                }),
                fees: PublicState::new(context, 3, FieldSerializationMethods)
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
    fn dealer_shuffle(table_id: Field, deck: Deck) {
        // prove that deck has one of every card (inputted as plaintext)
        deck.validate_deck();

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
        table.hand.validate_and_shift_phase([0], 1, context.block_timestamp());
        storage.tables.at(table_id).write(table);
    }

    #[aztec(private)]
    fn player_shuffle(table_id: Field, shuffle_array: Deck) {
        // @todo pull old_deck directly from private state
        let old_deck = storage.deck.at(table_id).read();

        // confirm that the shuffle array contains one of each number 0-51
        shuffle_array.validate_deck();

        // set new_deck[i] to the card at position shuffle_array[i] in the old deck
        let mut new_deck = [0; 52];
        for i in 0..52 {
            new_deck[i] = old_deck[shuffle_array[i]];
        }

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
        table.hand.validate_and_shift_phase([1], 1, context.block_timestamp());

        table.hand.dealer_cards = dealer_cards; // already unencrypted for dealer
        table.hand.player_cards = player_cards; // double encrypted
        table.hand.table_cards = table_cards; // double encrypted

        table.place_blinds();

        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    ///////// TABLE CARDS //////////
    ////////////////////////////////

    #[aztec(private)]
    fn deal_cards(table_id: Field, encrypted_cards: [Field; 3]) {
        // @todo decrypt cards
        // - skip any that are zero and just pass zero
        let decrypted_cards = encrypted_cards;

        // initiate public state checks and updated
        context.call_public_function(
            compute_selector("deal_cards_backend(Field,Field,[Field;3],[Field;3])"),
            [table_id, AztecAddress::new(context.msg_sender()), encrypted_cards, decrypted_cards]
        )
    }

    #[aztec(public)]
    internal fn deal_cards_backend(table_id: Field, caller: AztecAddress, encrypted_cards: [Field; 3], decrypted_cards: [Field; 3]) {
        let table = storage.tables.at(table_id).read();
        let phase = table.hand.phase;

        if phase == 2 {
            // dealer is passing hand cards to player
            table.validate_caller(caller, true);
            assert(table.hand.player_cards == encrypted_cards[:2]);
            table.hand.player_cards = decrypted_cards[:2];
        } else if phase == 5 {
            // dealer is dealing flop cards
            table.validate_caller(caller, true);
            assert(table.hand.table_cards[:3] == encrypted_cards);
            table.hand.table_cards[:3] = decrypted_cards;
        } else if phase == 6 {
            // player is revealing flop cards
            table.validate_caller(caller, false);
            assert(table.hand.table_cards[:3] == encrypted_cards);
            table.hand.table_cards[:3] = decrypted_cards;
        } else if phase == 9 {
            // dealer is dealing turn card
            table.validate_caller(caller, true);
            assert(table.hand.table_cards[3] == encrypted_cards[0]);
            table.hand.table_cards[3] = decrypted_cards[0];
        } else if phase == 10 {
            // player is revealing turn card
            table.validate_caller(caller, false);
            assert(table.hand.table_cards[3] == encrypted_cards[0]);
            table.hand.table_cards[3] = decrypted_cards[0];
        } else if phase == 13 {
            // dealer is dealing river card
            table.validate_caller(caller, true);
            assert(table.hand.table_cards[4] == encrypted_cards[0]);
            table.hand.table_cards[4] = decrypted_cards[0];
        } else if phase == 14 {
            // player is revealing river card
            table.validate_caller(caller, false);
            assert(table.hand.table_cards[4] == encrypted_cards[0]);
            table.hand.table_cards[4] = decrypted_cards[0];
        } else if phase == 17 {
            // player is showing hand
            table.validate_caller(caller, false);
            assert(table.hand.player_cards == encrypted_cards[:2]);
            table.hand.player_cards = decrypted_cards[:2];
        } else {
            assert(false);
        }

        table.hand.shift_phase(1, context.block_timestamp());
        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    //////// HAND ANALYSIS /////////
    ////////////////////////////////

    #[aztec(private)]
    fn showdown(table_id: Field, encrypted_hand: [Field; 2]) {
        // @todo decrypt hand
        let decrypted_hand = encrypted_hand;

        // initiate public state checks and updated
        context.call_public_function(
            compute_selector("showdown_backend(Field,[Field;2],[Field;2])"),
            [table_id, AztecAddress::new(context.msg_sender()), encrypted_hand, decrypted_hand]
        )
    }

    #[aztec(public)]
    internal fn showdown_backend(table_id: Field, caller: AztecAddress, encrypted_hand: [Field; 2], decrypted_hand: [Field; 2]) {
        let mut table = storage.tables.at(table_id).read();

        table.validate_caller(caller, true);
        table.hand.validate_phase(18);
        assert(table.hand.dealer_cards == encrypted_hand);

        // @todo determine who won
        // 0 = p0, 1 = p1, 2 = tie

        // send pot back into player's stacks
        let fees = table.send_winnings_and_return_fees(winner);
        storage.fees.write(storage.fees.read() + fees);

        // reset to prepare for fresh hand
        table.next_hand();
        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    /////////// BETTING ////////////
    ////////////////////////////////

    // check: bet_size = 0 when pots are equal
    // call: bet_size = 0 when we are behind
    // bet: bet_size > 0 when pots are equal
    // raise: bet_size > 0 when we are behind (bet_size is the raise amount on top of call amount)
    #[aztec(public)]
    fn bet(table_id: Field, bet_size: Field) {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // create two variables to track if caller is p0 or p1 and dealer or not
        (is_po, is_dealer) = table.validate_and_define_caller(caller);

        // depending on dealer role and whether bet size > 0, validate we are in the correct phase
        // shift us to the next phase for the action we're taking and set last_move_time to now
        table.hand.validate_and_shift_betting_phase(is_dealer, bet_size, context.block_timestamp());

        // move tokens from stack to pot based on the action
        if is_p0 {
            let call_size = table.hand.p1_pot - table.hand.p0_pot; // positive (call, raise); zero (check, bet)
            table.p0_stack -= (call_size + bet_size);
            table.hand.p0_pot += (call_size + bet_size);
        } else {
            let call_size = table.hand.p0_pot - table.hand.p1_pot;
            table.p1_stack -= (call_size + bet_size);;
            table.hand.p1_pot += (call_size + bet_size);;
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
            let fees = table.send_winnings_and_return_fees(1);
            storage.fees.write(storage.fees.read() + fees);
        } else if (caller == table.p1) {
            let fees = table.send_winnings_and_return_fees(0);
            storage.fees.write(storage.fees.read() + fees);
        } else {
            assert(false);
        }

        // reset to prepare for fresh hand
        table.next_hand();
        storage.tables.at(table_id).write(table);
    }

    ////////////////////////////////
    /////////// TIMEOUT ////////////
    ////////////////////////////////

    #[aztec(public)]
    fn timeout(table_id: Field) {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // caller is one of the two players (makes rest of logic easier)
        assert(context.block_timestamp() > table.hand.last_move_timestamp + table.timeout);

        // assuming caller is p0 or p1 (checked later), check that hand is in other player's phase
        if (table.p0_is_dealer) == (caller == table.p0) {
            table.hand.validate_phase([1, 3, 5, 7, 9, 11, 13, 15, 17]])
        } else {
            table.hand.validate_phase([0, 2, 4, 6, 8, 10, 12, 14, 16, 18]);
        }

        // move the pot to self
        if (caller == table.p0) {
            let fees = table.send_winnings_and_return_fees(0);
            storage.fees.write(storage.fees.read() + fees);
        } else if (caller == table.p1) {
            let fees = table.send_winnings_and_return_fees(1);
            storage.fees.write(storage.fees.read() + fees);
        } else {
            assert(false);
        }

        table.next_hand();
        storage.tables.at(table_id).write(table);
    }


    ////////////////////////////////
    //////////// VIEW //////////////
    ////////////////////////////////

    #[aztec(public)]
    unconstrained fn view_hand(table_id: Field) -> [Field; 2] {
        let table = storage.tables.at(table_id).read();
        let caller = AztecAddress::new(context.msg_sender());

        // @todo grab my secret key and use it to decrypt my hand
    }
