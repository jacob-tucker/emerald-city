// https://play.onflow.org/3957948d-3179-46ad-b081-7a077963b698?type=account&id=0

pub contract Reputation {

    pub event ReputationAdded(skill: String, by: Address, to: Address, amount: UFix64)
    pub event ReputationRemoved(skill: String, by: Address, to: Address, amount: UFix64)

    // Maps a skill to the total amount of that skill that exists
    access(contract) var skillTotals: {String: UFix64}

    // For the public to be able to read your reputation
    pub resource interface IdentityPublic {
        pub fun getReputation(): {String: UFix64}
    }

    // For the governor to be able to add skill to your identity
    pub resource interface IdentityGovernor {
        access(contract) fun addSkill(skill: String, amount: UFix64)
    }

    pub resource Identity: IdentityPublic, IdentityGovernor {
        access(contract) var skills: {String: UFix64}

        access(contract) fun addSkill(skill: String, amount: UFix64) {
            if let reputation = self.skills[skill] {
                self.skills[skill] = reputation + amount
            } else {
                self.skills[skill] = amount
            }
        }

        pub fun getReputation(): {String: UFix64} {
            return self.skills
        }

        init() {
            self.skills = {}
        }
    }

    pub fun createIdentity(): @Identity {
        return <- create Identity()
    }

    pub resource Governor {
        pub fun createSkill(skill: String) {
            pre {
                Reputation.skillTotals[skill] == nil:
                    "This reputation type already exists."
            }
            Reputation.skillTotals[skill] = 0.0
        }

        pub fun giveSkill(skill: String, amount: UFix64, identity: &Identity{IdentityGovernor}) {
            pre {
                Reputation.skillTotals[skill] != nil: 
                    "This is not a valid reputation type."
            }
            identity.addSkill(skill: skill, amount: amount)
            Reputation.skillTotals[skill] = Reputation.skillTotals[skill]! + amount
            emit ReputationAdded(skill: skill, by: self.owner!.address, to: identity.owner!.address, amount: amount)
        }
    }

    init() {
        self.skillTotals = {}
        self.account.save(<- create Governor(), to: /storage/Governor)
    }

}