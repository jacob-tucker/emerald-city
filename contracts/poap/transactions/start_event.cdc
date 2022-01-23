import FLOAT from 0x01

transaction(name: String, description: String, image: String, timePeriod: UFix64) {

  let FLOATEvents: &FLOAT.FLOATEvents

  prepare(acct: AuthAccount) {
    self.FLOATEvents = acct.borrow<&FLOAT.FLOATEvents>(from: FLOAT.FLOATEventsStoragePath)
                        ?? panic("Could not borrow the FLOATEvents from the signer.")
  }

  execute {
    self.FLOATEvents.createEvent(name: name, description: description, image: image, timePeriod: timePeriod)
    log("Started a new event.")
  }
}
