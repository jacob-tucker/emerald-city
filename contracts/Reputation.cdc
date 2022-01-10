// https://play.onflow.org/cc94c193-cdff-4169-9409-184c5aa4c9c7?type=account&id=0

pub contract Reputation {

    // Events
    pub event ReputationAdded(skill: String, by: Address, to: Address, amount: UFix64)
    pub event ReputationRemoved(skill: String, by: Address, to: Address, amount: UFix64)

    // Paths
    pub var IdentityStoragePath: StoragePath
    pub var IdentityPublicPath: PublicPath
    pub var LeaderStoragePath: StoragePath

    pub struct SeasonInfo {
        pub let seasonNumber: UInt64
        pub let seasonStart: UFix64
        pub var seasonEnd: UFix64

        init(_seasonDuration: UFix64) {
            self.seasonNumber = Reputation.seasonInfo!.seasonNumber + 1
            self.seasonStart = getCurrentBlock().timestamp
            self.seasonEnd = self.seasonStart + _seasonDuration
        }
    }

    // The information for the current season
    pub var seasonInfo: SeasonInfo?

    // Maps a skill to the total amount of that skill that exists
    //
    // Education --> 100.0
    // Building --> 60.0
    access(contract) var skillTotals: {String: UFix64}

    // For the public to be able to read your reputation
    pub resource interface IdentityPublic {
        pub fun getReputation(): {String: UFix64}
    }

    // For the Leader to be able to add skill to your identity
    pub resource interface IdentityLeader {
        access(contract) fun addSkill(skill: String, amount: UFix64)
    }

    pub resource Identity: IdentityPublic, IdentityLeader {
        // Maps a skill to the individuals skill points
        //
        // Education --> 10.0
        // Building --> 5.0
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

    pub resource Leader {
        // The season this leader is active for
        pub let season: UInt64
        // The skill this leader is allowed to give out
        pub let skill: String

        pub fun giveSkill(amount: UFix64, identity: &Identity{IdentityLeader}) {
            pre {
                Reputation.skillTotals[self.skill] != nil: 
                    "This is not a valid skill type."
            }
            identity.addSkill(skill: self.skill, amount: amount)
            Reputation.skillTotals[self.skill] = Reputation.skillTotals[self.skill]! + amount
            emit ReputationAdded(skill: self.skill, by: self.owner!.address, to: identity.owner!.address, amount: amount)
        }

        init(_season: UInt64, _skill: String) {
            self.season = _season
            self.skill = _skill
        }
    }

    pub resource Administrator {
        pub fun startSeason(seasonDuration: UFix64) {
            pre {   
                Reputation.seasonInfo == nil || Reputation.seasonInfo!.seasonEnd >= getCurrentBlock().timestamp:
                    "This season has not ended yet."
            }   
            Reputation.seasonInfo = SeasonInfo(_seasonDuration: seasonDuration)
        }

        pub fun createSkill(skill: String) {
            pre {
                Reputation.skillTotals[skill] == nil:
                    "This skill type already exists."
            }
            Reputation.skillTotals[skill] = 0.0
        }
    }

    init() {
        self.IdentityStoragePath = /storage/ReputationIdentity
        self.IdentityPublicPath = /public/ReputationIdentity
        self.LeaderStoragePath = /storage/ReputationLeader

        self.seasonInfo = nil
        self.skillTotals = {}

        self.account.save(<- create Administrator(), to: /storage/ReputationAdministrator)
    }

}