contract Main {
    internal fn double(x: Field) -> pub Field { x * 2 }
    fn triple(x: Field) -> pub Field { x * 3 }
    fn quadruple(x: Field) -> pub Field { double(double(x)) }

    // to "buy in" to a game, users transfer usdp to the poker contract
    // then poker contract gives them a local balance they can play with
    // when they "cash out" it sends it back
}
