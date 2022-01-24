import Reputation from 0x01

// Signed by a Leader

transaction(recipient: Address, skill: String, amount: UFix64) {
  let Leader: &Reputation.Leader
  let IdentityLeader: &Reputation.Identity{Reputation.IdentityLeader}
  
  prepare(signer: AuthAccount) {
    let identity = signer.borrow<&Reputation.Identity>(from: Reputation.IdentityStoragePath)
                            ?? panic("Could not borrow the Identity.")
    self.Leader = identity.getLeader()
    self.IdentityLeader = getAccount(recipient).getCapability(Reputation.IdentityPublicPath)
                                    .borrow<&Reputation.Identity{Reputation.IdentityLeader}>()
                                    ?? panic("Could not borrow the public Identity.")
  }

  execute {
    self.Leader.giveSkill(identity: self.IdentityLeader, amount: amount, skill: "Education")
    log("Gave Skill Points")
  }
}