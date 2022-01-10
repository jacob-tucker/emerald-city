// https://play.onflow.org/cc94c193-cdff-4169-9409-184c5aa4c9c7?type=account&id=0

pub contract Reputation {

    // Events
    pub event ReputationAdded(skill: String, by: Address, to: Address, amount: UFix64)
    pub event ReputationRemoved(skill: String, by: Address, to: Address, amount: UFix64)

    // Paths
    pub var IdentityStoragePath: StoragePath
    pub var IdentityPublicPath: PublicPath
    pub var LeaderStoragePath: StoragePath

    // The information about a season
    pub struct SeasonInfo {
        pub let number: UInt64
        pub let start: UFix64
        pub var end: UFix64

        init(_seasonDuration: UFix64) {
            if let currentSeason = Reputation.currentSeason() {
                self.number = currentSeason + 1
            } else {
                self.number = 0
            }
            self.start = getCurrentBlock().timestamp
            self.end = self.start + _seasonDuration
        }
    }

    // The information for the current season.
    // Will only be nil before season 0 starts.
    pub var seasonInfo: SeasonInfo?

    // Maps a skill to the total amount of that skill that exists
    //
    // Education --> 100.0
    // Building --> 60.0
    access(contract) var skillTotals: {String: UFix64}

    // A container for the skill points a user gets during a certain season.
    // Mainly used inside the user's `Identity`.
    pub struct Skills {
        pub let season: UInt64
        pub let skillPoints: {String: UFix64}

        pub fun addSkillPoints(skill: String, amount: UFix64) {
            self.skillPoints[skill] = self.skillPoints[skill]! + amount
        }
        
        init() {
            self.season = Reputation.seasonInfo!.number
            self.skillPoints = {}
            
            for skill in Reputation.skillTotals.keys {
                self.skillPoints[skill] = 0.0
            }
        }
    }

    // For the public to be able to read your reputation
    pub resource interface IdentityPublic {
        pub fun getReputation(): {UInt64: Skills}
    }

    // For the Leader to be able to add skill to your identity
    pub resource interface IdentityLeader {
        access(contract) fun addSkill(skill: String, amount: UFix64)
    }

    pub resource Identity: IdentityPublic, IdentityLeader {
        // Maps a season # to the Skills this identity has for that season
        //
        // 0 --> Skills (educational == 50.0, building == 100.0, etc)
        // 1 --> Skills (educational == 20.0, building == 80.0, etc)
        access(contract) var skills: {UInt64: Skills}

        access(contract) fun addSkill(skill: String, amount: UFix64) {
            if self.skills[Reputation.currentSeason()!] == nil {
                self.skills[Reputation.currentSeason()!] = Skills()
            }

            let skillsRef = &self.skills[Reputation.currentSeason()!] as &Skills
            skillsRef.addSkillPoints(skill: skill, amount: amount)
        }

        pub fun getReputation(): {UInt64: Skills} {
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
                Reputation.seasonInfo == nil || Reputation.seasonInfo!.end >= getCurrentBlock().timestamp:
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

    pub fun currentSeason(): UInt64? {
        return Reputation.seasonInfo?.number
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