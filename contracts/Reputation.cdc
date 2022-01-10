pub contract Reputation {

    pub event ReputationAdded(by: Address, to: Address, amount: UFix64)
    pub event ReputationRemoved(by: Address, to: Address, amount: UFix64)

    access(contract) var reputationTypes: {String: Bool}

    pub resource interface IdentityPublic {
        pub fun getReputations(): {String: UFix64}
    }

    pub resource interface IdentityGovernor {
        access(contract) fun addReputation(reputationType: String, amount: UFix64)
        access(contract) fun removeReputation(reputationType: String, amount: UFix64)
    }

    pub resource Identity: IdentityPublic, IdentityGovernor {
        access(contract) var reputations: {String: UFix64}

        access(contract) fun addReputation(reputationType: String, amount: UFix64) {
            if let reputation = self.reputations[reputationType] {
                self.reputations[reputationType] = reputation + amount
            } else {
                self.reputations[reputationType] = amount
            }
        }

        access(contract) fun removeReputation(reputationType: String, amount: UFix64) {
            if let reputation = self.reputations[reputationType] {
                self.reputations[reputationType] = reputation - amount
            } else {
                self.reputations[reputationType] = 0.0
            }
        }

        pub fun getReputations(): {String: UFix64} {
            return self.reputations
        }

        init() {
            self.reputations = {}
        }
    }

    pub fun createIdentity(): @Identity {
        return <- create Identity()
    }

    pub resource Governor {
        pub fun toggleReputationType(reputationType: String) {
            if Reputation.reputationTypes[reputationType] != nil {
                Reputation.reputationTypes[reputationType] = nil
            } else {
                Reputation.reputationTypes[reputationType] = true
            }
        }

        pub fun giveReputation(reputationType: String, amount: UFix64, identity: &Identity{IdentityGovernor}) {
            pre {
                Reputation.reputationTypes[reputationType] != nil: 
                    "This is not a valid reputation type."
            }
            identity.addReputation(reputationType: reputationType, amount: amount)
            emit ReputationAdded(by: self.owner!.address, to: identity.owner!.address, amount: amount)
        }

         pub fun takeReputation(reputationType: String, amount: UFix64, identity: &Identity{IdentityGovernor}) {
            pre {
                Reputation.reputationTypes[reputationType] != nil: 
                    "This is not a valid reputation type."
            }
            identity.removeReputation(reputationType: reputationType, amount: amount)
            emit ReputationRemoved(by: self.owner!.address, to: identity.owner!.address, amount: amount)
        }
    }

    init() {
        self.reputationTypes = {}
        self.account.save(<- create Governor(), to: /storage/Governor)
    }

}