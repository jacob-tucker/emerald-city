pub contract EmeraldIdentity {

    // Paths
    //
    pub let EmeraldIDAdministrator: StoragePath
    pub let EmeraldIDEmerald: StoragePath

    // Events
    //
    pub event EmeraldIDCreated(account: Address, discordID: String, admin: Address)
    pub event EmeraldIDRemoved(account: Address, discordID: String, admin: Address)

    pub resource Emerald {
        // 1-to-1
        access(contract) var accountToDiscord: {Address: String}
        // 1-to-1
        access(contract) var discordToAccount: {String: Address}

        access(contract) fun addMapping(account: Address, discordID: String) {
            self.accountToDiscord[account] = discordID
            self.discordToAccount[discordID] = account
        }

        access(contract) fun removeMapping(account: Address, discordID: String) {
            self.discordToAccount.remove(key: discordID)
            self.accountToDiscord.remove(key: account)
        }

        init() {
            self.accountToDiscord = {}
            self.discordToAccount = {}
        }
    }
    
    // Owned by the Emerald Bot
    pub resource Administrator {

        pub fun createEmeraldID(account: Address, discordID: String) {
            pre {
                EmeraldIdentity.getAccountFromDiscord(discordID: discordID) == nil &&
                EmeraldIdentity.getDiscordFromAccount(account: account) == nil: 
                "The old account must remove their EmeraldID first."
            }

            let emerald = EmeraldIdentity.account.borrow<&Emerald>(from: EmeraldIdentity.EmeraldIDEmerald)!
            emerald.addMapping(account: account, discordID: discordID)

            emit EmeraldIDCreated(account: account, discordID: discordID, admin: self.owner!.address)
        }

        pub fun removeByAccount(account: Address) {
            let discordID = EmeraldIdentity.getDiscordFromAccount(account: account) ?? panic("This EmeraldID does not exist!")
            self.remove(account: account, discordID: discordID)
        }

        pub fun removeByDiscord(discordID: String) {
            let account = EmeraldIdentity.getAccountFromDiscord(discordID: discordID) ?? panic("This EmeraldID does not exist!")
            self.remove(account: account, discordID: discordID)
        }

        access(self) fun remove(account: Address, discordID: String) {
            let emerald = EmeraldIdentity.account.borrow<&Emerald>(from: EmeraldIdentity.EmeraldIDEmerald)!
            emerald.removeMapping(account: account, discordID: discordID)

            emit EmeraldIDRemoved(account: account, discordID: discordID, admin: self.owner!.address)
        }

        pub fun createAdministrator(): @Administrator {
            return <- create Administrator()
        }
    }

    /*** USE THE BELOW FUNCTIONS FOR SECURE VERIFICATION OF ID ***/ 

    pub fun getDiscordFromAccount(account: Address): String?  {
        let emerald = EmeraldIdentity.account.borrow<&Emerald>(from: EmeraldIdentity.EmeraldIDEmerald)!
        return emerald.accountToDiscord[account]
    }

    pub fun getAccountFromDiscord(discordID: String): Address? {
        let emerald = EmeraldIdentity.account.borrow<&Emerald>(from: EmeraldIdentity.EmeraldIDEmerald)!
        return emerald.discordToAccount[discordID]
    }

    init() {
        self.EmeraldIDAdministrator = /storage/EmeraldIDAdministrator
        self.EmeraldIDEmerald = /storage/EmeraldIDEmerald

        self.account.save(<- create Emerald(), to: EmeraldIdentity.EmeraldIDEmerald)
        self.account.save(<- create Administrator(), to: EmeraldIdentity.EmeraldIDAdministrator)
    }
}