import POAP from 0x01

transaction(name: String, description: String, image: String, timePeriod: UFix64) {

  let POAPEvents: &POAP.POAPEvents

  prepare(acct: AuthAccount) {
    self.POAPEvents = acct.borrow<&POAP.POAPEvents>(from: POAP.POAPEventsStoragePath)
                        ?? panic("Could not borrow the POAPEvents from the signer.")
  }

  execute {
    self.POAPEvents.createEvent(name: name, description: description, image: image, timePeriod: timePeriod)
    log("Started a new event.")
  }
}
