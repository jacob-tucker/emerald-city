import Time from "../contracts/Time.cdc"

pub contract DAOReputation {

    pub resource interface IdentityPublic {
        pub fun receiveApplause(amount: UInt64)
    }
    
    pub resource Identity: IdentityPublic {
        // Your total reputation
        pub var reputation: UFix64
        // The amount of applause you currently have (refreshes to 5 every month)
        pub var applause: UInt64
        // The timestamp since your applause was last refreshed
        pub var lastRefresh: UFix64
        // If you can use your Identity yet
        pub var locked: Bool
        // The amount of applause you receive during the current month
        pub var amountReceivedInMonth: UInt64

        pub fun receiveApplause(amount: UInt64) {
            pre {
                !self.locked: "This Identity is not unlocked yet."
            }
            self.reputation = self.reputation + UFix64(amount)
            self.amountReceivedInMonth = self.amountReceivedInMonth + 1
        }

        pub fun applaud(identity: &Identity) {
            pre {
                !self.locked: "This Identity is not unlocked yet."
            }
            if (self.applause <= 1) {
                self.refreshApplause()
            }
            identity.receiveApplause(amount: 1)
            self.applause = self.applause - 1
        }

        access(contract) fun refreshApplause() {
            pre {
                !self.locked: "This Identity is not unlocked yet."
                Time.blockTime() >= self.lastRefresh + (Time.month):
                    "You cannot refresh yet."
            }
            // Calculation for the new applause:
            // 1) 5 by default
            // 2) 10% of the applause you received the previous month
            self.applause = 5 + UInt64(0.1 * UFix64(self.amountReceivedInMonth))
            self.amountReceivedInMonth = 0
        }

        pub fun unlock() {
            pre {
                Time.blockTime() >= self.lastRefresh + (Time.month): 
                    "It has not been a month since you created this Identity."
                self.locked: "You have already unlocked your Identity."
            }
            self.locked = false
            self.lastRefresh = Time.blockTime()
        }

        init() {
            self.reputation = 0.0
            self.applause = 0
            self.lastRefresh = Time.blockTime()
            self.locked = true
            self.amountReceivedInMonth = 0
        }
    }

    pub fun createIdentity(): @Identity {
        return <- create Identity()
    }

    init() {
    }

}