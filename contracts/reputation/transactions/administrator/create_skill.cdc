import Reputation from 0x01

// Signed by Contract Account

transaction(skill: String) {
  let Administrator: &Reputation.Administrator
  
  prepare(signer: AuthAccount) {
    self.Administrator = signer.borrow<&Reputation.Administrator>(from: Reputation.AdministratorStoragePath)
                            ?? panic("Could not borrow the Reputation Administrator.")
  }

  execute {
    self.Administrator.createSkill(skill: skill)
    log("Created Skill")
  }
}