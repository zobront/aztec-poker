struct Deck {
    deck: [Field; 52]
}

impl Deck {
    pub fn validate_deck(self) {
        let mut used = [false; 52];
        for card in self.deck {
            assert(card as u32 < 52);
            assert(!used[card]);
            used[card] = true;
        }
    }
}
