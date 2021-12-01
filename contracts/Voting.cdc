pub contract Voting {
    pub var totalProposals: UInt64

    // list of proposals
    access(contract) var proposals: {UInt64: Proposal}

    pub struct Proposal {
        pub let title: String 
        pub let description: String
        // starting timestamp of the proposal
        pub let sTimestamp: UFix64
        // when the voting will end
        pub let eTimestamp: UFix64
        // keeps track of the total votes
        // maps true to the amount of people who want to 'Accept',
        // and maps false to the amount of people who want to 'Decline'
        access(contract) var votes: {Bool: UInt64}
        // keeps track of who has voted
        access(contract) var voters: {Address: Bool}

        // 'Accepted' (true) or 'Declined' (false)
        pub var decision: Bool?

        pub fun vote(vote: Bool, voter: Address) {
            pre {
                self.decision == nil: "This Proposal is finished!"
                self.voters[voter] == nil: "This voter has already voted."
            }

            if getCurrentBlock().timestamp >= self.eTimestamp {
                self.finish()
            } else {
                self.votes[vote] = self.votes[vote]! + 1
                self.voters[voter] = true
            }
        }

        pub fun finish() {
            self.decision = self.votes[true]! >= self.votes[false]!
        }

        init(_title: String, _description: String, _length: UFix64) {
            self.title = _title
            self.description = _description
            self.sTimestamp = getCurrentBlock().timestamp
            self.eTimestamp = self.sTimestamp + _length
            self.votes = {}
            self.voters = {}
            self.decision = nil
        }
    }

    pub resource Voter {
        pub fun castVote(proposalID: UInt64, vote: Bool) {
            let proposal = Voting.proposals[proposalID] ?? panic("A proposal with this proposalID does not exist.")
            proposal.vote(vote: vote, voter: self.owner!.address)
        }
    }

    pub fun createVoter(): @Voter {
        return <- create Voter()
    }

    // What should an "Administrator" even do?
    pub resource Administrator {
        // Who should be able to initialize a new proposal? Is it an Administrator? Or should it be someone
        // who owns X amount of Emerald token?
        pub fun initializeProposal(title: String, description: String, length: UFix64) {
            Voting.proposals[Voting.totalProposals] = Proposal(_title: title, _description: description, _length: length)
            Voting.totalProposals = Voting.totalProposals + 1
        }

        pub fun createAdministrator(): @Administrator {
            return <- create Administrator()
        }
    }

    init() {
        self.totalProposals = 0
        self.proposals = {}
        self.account.save<@Administrator>(<-create Administrator(), to: /storage/VotingAdmin)
    }
}