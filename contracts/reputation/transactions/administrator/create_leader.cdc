import Reputation from 0x01

// Signed by Contract Account

transaction(leaderRecipient: Address) {
  let Administrator: &Reputation.Administrator
  let IdentityAdministrator: &Reputation.Identity{Reputation.IdentityAdministrator}
  
  prepare(signer: AuthAccount) {
    self.Administrator = signer.borrow<&Reputation.Administrator>(from: Reputation.AdministratorStoragePath)
                            ?? panic("Could not borrow the Reputation Administrator.")
    self.IdentityAdministrator = getAccount(leaderRecipient).getCapability(Reputation.IdentityPublicPath)
                                    .borrow<&Reputation.Identity{Reputation.IdentityAdministrator}>()
                                    ?? panic("Could not borrow the public Identity.")
  }

  execute {
    self.Administrator.createLeader(identity: self.IdentityAdministrator, allowedAmounts: {"Education": 40.0, "Building": 0.0, "Governance": 0.0})
    log("Created Leader")
  }
}