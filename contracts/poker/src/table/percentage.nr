struct Percentage {
    value: Field
}

impl Percentage {
    fn new(value: Field) -> Percentage {
        Percentage { value }
    }

    fn pct_mul(self, other: Field) -> Field {
        self.value * other / 1e18
    }
}
