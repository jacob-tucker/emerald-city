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
        pub let season: UInt64
        pub let start: UFix64
        pub var end: UFix64

        init(_seasonDuration: UFix64, _season: UInt64) {
            self.season = _season
            self.start = getCurrentBlock().timestamp
            self.end = self.start + _seasonDuration
        }
    }

    // The information for the current season.
    pub var seasonInfo: SeasonInfo

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
            self.season = Reputation.seasonInfo.season
            self.skillPoints = {}
            
            for skill in Reputation.skillTotals.keys {
                self.skillPoints[skill] = 0.0
            }
        }
    }

    // For the public to be able to read your reputation
    pub resource interface IdentityPublic {
        pub fun getReputation(): {UInt64: Skills}
        pub fun getReputationInSeason(season: UInt64): Skills
        pub fun getSpecificSkillInSeason(season: UInt64, skill: String): UFix64
    }

    // For the Leader to be able to add skill to your identity
    pub resource interface IdentityLeader {
        access(contract) fun addSkill(skill: String, amount: UFix64)
    }

    pub resource Identity: IdentityPublic, IdentityLeader {
        // Maps a season # to the Skills this identity has for that season
        //
        // 0 --> Skills (educational = 50.0, building = 100.0, etc)
        // 1 --> Skills (educational = 20.0, building = 80.0, etc)
        access(contract) var skills: {UInt64: Skills}

        access(contract) fun addSkill(skill: String, amount: UFix64) {
            if self.skills[Reputation.currentSeason()] == nil {
                self.skills[Reputation.currentSeason()] = Skills()
            }

            let skillsRef = &self.skills[Reputation.currentSeason()] as &Skills
            skillsRef.addSkillPoints(skill: skill, amount: amount)
        }

        pub fun getReputation(): {UInt64: Skills} {
            return self.skills
        }

        pub fun getReputationInSeason(season: UInt64): Skills {
            if self.skills[season] == nil {
                self.skills[season] = Skills()
            }
            return self.skills[season]!
        }

        pub fun getSpecificSkillInSeason(season: UInt64, skill: String): UFix64 {
             if self.skills[season] == nil {
                self.skills[season] = Skills()
            }
            return self.skills[season]!.skillPoints[skill]!
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
                Reputation.currentSeason() == self.season:
                    "This season has already passed."
            }
            identity.addSkill(skill: self.skill, amount: amount)
            Reputation.skillTotals[self.skill] = Reputation.skillTotals[self.skill]! + amount
            emit ReputationAdded(skill: self.skill, by: self.owner!.address, to: identity.owner!.address, amount: amount)
        }

        init(_skill: String) {
            self.season = Reputation.currentSeason()
            self.skill = _skill
        }
    }

    pub resource Administrator {
        pub fun startSeason(seasonDuration: UFix64) {
            pre {   
                Reputation.seasonInfo == nil || Reputation.seasonInfo.end >= getCurrentBlock().timestamp:
                    "This season has not ended yet."
            }   
            Reputation.seasonInfo = SeasonInfo(_seasonDuration: seasonDuration, _season: Reputation.currentSeason() + 1)
        }

        pub fun createSkill(skill: String) {
            pre {
                Reputation.skillTotals[skill] == nil:
                    "This skill type already exists."
            }
            Reputation.skillTotals[skill] = 0.0
        }

        pub fun createLeader(skill: String): @Leader {
            pre {
                Reputation.skillTotals[skill] != nil: 
                    "This is not a valid skill type."
            }
            return <- create Leader(_skill: skill)
        }
    }

    pub fun currentSeason(): UInt64 {
        return Reputation.seasonInfo.season
    }

    init() {
        self.IdentityStoragePath = /storage/ReputationIdentity
        self.IdentityPublicPath = /public/ReputationIdentity
        self.LeaderStoragePath = /storage/ReputationLeader

        self.seasonInfo = SeasonInfo(_seasonDuration: 0.0, _season: 0)
        self.skillTotals = {}

        self.account.save(<- create Administrator(), to: /storage/ReputationAdministrator)
    }

}