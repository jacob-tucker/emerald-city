import Reputation from 0x01

// Signed by anyone to set up their I

transaction {
  prepare(signer: AuthAccount) {
    signer.save(<- Reputation.createIdentity(), to: Reputation.IdentityStoragePath)
    signer.link<&Reputation.Identity{Reputation.IdentityPublic, 
                                     Reputation.IdentityLeader, 
                                    Reputation.IdentityAdministrator
                                    }>(Reputation.IdentityPublicPath, target:  Reputation.IdentityStoragePath)
    log("Setup Account")
  }
}