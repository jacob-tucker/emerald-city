pub contract Time {
    pub let minute: UFix64
    pub let hour: UFix64
    pub let day: UFix64
    pub let month: UFix64 
    pub let year: UFix64

    pub fun blockTime(): UFix64 {
        return getCurrentBlock().timestamp
    }

    init() {
        self.minute = 60.0
        self.hour = self.minute * 60.0
        self.day = self.hour * 24.0
        self.month = self.day * 30.0
        self.year = self.month * 12.0
    }
}