pub contract Reputation {

    // Events
    pub event ReputationAdded(skill: String, by: Address, to: Address, amount: UFix64)
    pub event ReputationRemoved(skill: String, by: Address, to: Address, amount: UFix64)

    // Paths
    pub var IdentityStoragePath: StoragePath
    pub var IdentityPublicPath: PublicPath
    pub var AdministratorStoragePath: StoragePath

    // The information about a season
    pub struct SeasonInfo {
        pub let season: UInt64
        pub let description: String
        pub let start: UFix64
        pub var end: UFix64

        init(_seasonDuration: UFix64, _season: UInt64, _description: String) {
            self.season = _season
            self.description = _description
            self.start = 0.0 // getCurrentBlock().timestamp
            self.end = self.start + _seasonDuration
        }
    }

    // The information for the current season.
    access(account) var seasons: {UInt64: SeasonInfo}
    pub var currentSeason: UInt64

    // Maps a skill to the total amount of that skill that exists
    //
    // Education --> 100.0
    // Building --> 60.0
    access(account) var skillTotals: {String: UFix64}

    // A container for the skill points a user gets during a certain season.
    // Mainly used inside the user's `Identity`.
    pub struct Skills {
        pub let season: UInt64
        pub let skillPoints: {String: UFix64}

        pub fun addSkillPoints(skill: String, amount: UFix64) {
            self.skillPoints[skill] = self.skillPoints[skill]! + amount
        }
        
        init() {
            self.season = Reputation.currentSeason
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

    pub resource interface IdentityAdministrator {
        access(contract) fun addLeader(leader: @Leader)
    }

    pub resource Identity: IdentityPublic, IdentityLeader, IdentityAdministrator {
        // Maps a season # to the Skills this identity has for that season
        //
        // 0 --> Skills (educational = 50.0, building = 100.0, etc)
        // 1 --> Skills (educational = 20.0, building = 80.0, etc)
        access(contract) var skills: {UInt64: Skills}

        // The Identity may have leaders for a certain season
        access(self) var leaders: @{UInt64: Leader}

        access(contract) fun addSkill(skill: String, amount: UFix64) {
            if self.skills[Reputation.currentSeason] == nil {
                self.skills[Reputation.currentSeason] = Skills()
            }

            let skillsRef = &self.skills[Reputation.currentSeason] as &Skills
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

        access(contract) fun addLeader(leader: @Leader) {
            self.leaders[leader.season] <-! leader
        }

        pub fun getLeader(): &Leader {
            return &self.leaders[Reputation.currentSeason] as &Leader
        }

        init() {
            self.skills = {}
            self.leaders <- {}
        }

        destroy() {
            destroy self.leaders
        }
    }

    pub fun createIdentity(): @Identity {
        return <- create Identity()
    }

    pub resource Leader {
        // The season this leader is active for
        pub let season: UInt64
        // The amount this leader can give per skill
        pub let allowedAmounts: {String: UFix64}

        pub fun giveSkill(identity: &Identity{IdentityLeader}, amount: UFix64, skill: String) {
            pre {
                self.allowedAmounts.containsKey(skill):
                    "This skill does not exist."
                self.allowedAmounts[skill]! >= amount:
                    "You do not have enough skill to give away."
                Reputation.currentSeason == self.season:
                    "This season has already passed."
                self.owner!.address != identity.owner!.address:
                    "Cannot give reputation to yourself."
            }
            identity.addSkill(skill: skill, amount: amount)
            Reputation.skillTotals[skill] = Reputation.skillTotals[skill]! + amount
            self.allowedAmounts[skill] = self.allowedAmounts[skill]! - amount
            emit ReputationAdded(skill: skill, by: self.owner!.address, to: identity.owner!.address, amount: amount)
        }

        init(_allowedAmounts: {String: UFix64}) {
            self.season = Reputation.currentSeason
            self.allowedAmounts = _allowedAmounts
        }
    }

    pub resource Administrator {
        pub fun startSeason(seasonDuration: UFix64, description: String) {
            pre {   
                Reputation.getCurrentSeasonInfo().end >= 0.0: // getCurrentBlock().timestamp
                    "This season has not ended yet."
            }   
            Reputation.currentSeason = Reputation.currentSeason + 1
            Reputation.seasons[Reputation.currentSeason] = SeasonInfo(_seasonDuration: seasonDuration, _season: Reputation.currentSeason, _description: description)
        }

        pub fun createSkill(skill: String) {
            pre {
                Reputation.skillTotals[skill] == nil:
                    "This skill type already exists."
            }
            Reputation.skillTotals[skill] = 0.0
        }

        pub fun createLeader(identity: &Identity{IdentityAdministrator}, allowedAmounts: {String: UFix64}) {
            pre {
                allowedAmounts.keys.length == Reputation.skillTotals.keys.length:
                    "Must pass in amounts for all the skill points."
            }
            for skill in allowedAmounts.keys {
                if !Reputation.skillTotals.containsKey(skill) {
                    panic("This skill does not exist!")
                }
            }
            identity.addLeader(leader: <- create Leader(_allowedAmounts: allowedAmounts))
        }
    }

    pub fun getCurrentSeasonInfo(): SeasonInfo {
        return self.seasons[Reputation.currentSeason]!
    }

    pub fun getSkillTotals(): {String: UFix64} {
        return self.skillTotals
    }

    init() {
        self.IdentityStoragePath = /storage/ReputationIdentity
        self.IdentityPublicPath = /public/ReputationIdentity
        self.AdministratorStoragePath = /storage/ReputationAdministrator

        self.seasons = {0: SeasonInfo(_seasonDuration: 0.0, 
                                      _season: 0, 
                                      _description: "The first ever season for Emerald City. Covers everything from November 2021 to end of January 2022. Main topics include the Emerald bot, reputation system, and the beginning of FLOAT."
                                     )
                       }
        self.currentSeason = 0
        self.skillTotals = {"Education": 0.0, "Building": 0.0, "Governance": 0.0}

        self.account.save(<- create Administrator(), to: self.AdministratorStoragePath)
    }

}