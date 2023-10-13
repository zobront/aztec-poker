// mod x; for other files i wrote

contract Poker {
    // use dep::...

    struct Storage {
    //     // game_id => game data
    //     games: Map<PublicState<Game, GAME_SERIALIZED_LEN>>,
    //     // game_id => private (challenger) throw
    //     privateThrows: Map<ImmutableSingleton<ThrowNote, THROW_NOTE_LEN>>,
    }

    impl Storage {
        fn init(context: Context) -> pub Self {
            Storage {
    //             games: Map::new(context, 1, |context, slot| {
    //                 PublicState::new(context, slot, GameMethods)
    //             }),
    //             privateThrows: Map::new(context, 2, |context, slot| {
    //                 ImmutableSingleton::new(context, slot, ThrowNoteMethods)
    //             })
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
    fn create_table() {
        // set up Table struct
        // can specify other player or not
        // can specify stakes & timeout
        // i think table id should be hash of both players plus a nonce, so add nonce as well
        // put chips on table (into usdp with table id verification and balances tracked here?)
    }

    #[aztec(public)]
    fn join_table() {
        // for tables that don't have a P2, join and set themselves as P2
        // put chips on table (need this because otherwise could double spend in two games)
    }

    ////////////////////////////////
    //////// SHUFFLE & DEAL ////////
    ////////////////////////////////

    #[aztec(private)]
    fn dealer_shuffle() {
        // require(dealer)
        // require(phase check)
        // input cards in any order
        // prove that deck has one of every card
        // encrypt each card with my private key
        // call_public_function(save encrypted deck) => put in public storage
    }

    #[aztec(private)]
    fn player_shuffle() {
        // require(player)
        // require(phase check)
        // start with deck in public storage
        // proof of valid shuffle
        // put two cards into dealer's private state (only dealer's encryption)
        // encrypt all other cards with player's private key
        // call_public_function(save encrypted deck) => put in public storage
        // call_public_function => update next card counter = 2
    }

    #[aztec(public)]
    fn deal_cards() {
        // require(dealer)
        // require(phase check)
        // start with deck in public storage
        // decrypt top two cards from the deck (still leaving player encryption)
        // place in player's private state
        // call_public_function => update next card counter = 4
    }

    ////////////////////////////////
    ///////// TABLE CARDS //////////
    ////////////////////////////////

    #[aztec(public)]
    fn deal_next_table_cards() {
        // require(dealer)
        // require(next phase == flop deal, turn, or river)
        // decrypt next X cards from deck and put encrypted by player in pub storage
        // next card counter += X
    }

    #[aztec(public)]
    fn reveal_table_cards() {
        // require(player)
        // require(next phase == flop reveal, turn, or river)
        // decrypt table cards and put in pub storage
    }

    ////////////////////////////////
    //////// HAND ANALYSIS /////////
    ////////////////////////////////

    #[aztec(private)]
    fn reveal_hand() {
        // require(dealer)
        // require(phase check)
        // decrypt hand and put in pub storage
    }

    #[aztec(private)]
    fn muck() {
        // require(player)
        // forfeit hand
    }

    #[aztec(public)]
    fn determine_winner() {
        // require(phase check)
        // both hands are in public state, as well as all table cards
        // determine who won
        // pay them the pot
    }

    ////////////////////////////////
    /////////// BETTING ////////////
    ////////////////////////////////

    #[aztec(public)]
    fn bet() {
        // player has a chance to bet first
    }

    #[aztec(public)]
    fn call() {
        // player has a chance to call
    }

    #[aztec(public)]
    fn fold() {
        // player has a chance to fold
    }

    #[aztec(public)]
    fn raise() {
        // player has a chance to reveal
    }

    ////////////////////////////////
    /////////// TIMEOUT ////////////
    ////////////////////////////////

    #[aztec(public)]
    fn timeout() {
        // require(phase check should be other player's turn)
        // require(timeout has passed since last move)
        // claim the pot and end the hand
    }

    ////////////////////////////////
    ////// INTERNAL FUNCTIONS //////
    ////////////////////////////////


}
