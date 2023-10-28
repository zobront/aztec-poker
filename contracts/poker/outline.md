[x] private dealer_shuffle()
- @todo how to handle caller validation?
- validate proper deck
- encrypt deck
- put deck in player's private state

[x] private player_shuffle()
- validate player and phase
- require deck is in player's private state
- validate new deck is permutation of old deck
- encrypt new deck
- public player_shuffle_backend()
    - validate caller == player & phase == 2
    - put top 2 cards in player's hand (public state)
    - put next 7 cards in player's hand, table cards (public state)

[x] private deal()
- input: player's encrypted cards
- decrypt them
- public deal_backend()
    - validate caller == dealer && phase == 3
    - validate inputted cards match player's current hand
    - replace player's hand with decrypted version

private flop/turn/river_deal()
- input: encrypted flop
- decrypt them
- public flop/turn/river_deal_backend()
    - validate caller == dealer && phase == 6
    - vlaidate inputted cards match current flop
    - replace with decrypted

private flop/turn/river_reveal()
- input: semi-encrypted flop
- decrypt them
- public flop/turn/river_reveal_backend()
    - validate caller == player && phase == 7
    - vlaidate inputted cards match current flop
    - replace with decrypted

private dealer_showdown()
- input encrypted dealer hand & resulting hand score
- decrypt dealer hand
- public dealer_showdown_backend()
    - validate caller == dealer && phase == x
    - validate inputted cards match dealer's current hand
    - validate decrypted hand can make resulting hand score

private player_showdown()
- same as dealer showdown, but with logic for settling up pot

[x] public bet:
- validate player and possible phases
- pots must be equal
- move bet amount from stack to pot
- if player: phase += 1; if dealer: phase -= 1

[x] public check:
- validate player and possible phases
- pots must be equal
- phase += 1

[x] public fold:
- validate player and possible phases
- pots go to other player's stack
- reset hand

[x] public call:
- validate player and possible phases
- other player pot must be higher
- move difference from stack to pot
- phase += 1

[x] public raise:
- validate player and possible phases
- other player pot must be higher
- bet size > difference
- move bet size from stack to pot
- if player: phase += 1; if dealer: phase -= 1
