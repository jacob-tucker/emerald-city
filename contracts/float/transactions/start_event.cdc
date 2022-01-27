import FLOAT from "../FLOAT.cdc"

transaction(type: UInt8, name: String, description: String, image: String, timePeriod: UFix64?, capacity: UInt64?, transferrable: Bool) {

  let FLOATEvents: &FLOAT.FLOATEvents

  prepare(acct: AuthAccount) {
    self.FLOATEvents = acct.borrow<&FLOAT.FLOATEvents>(from: FLOAT.FLOATEventsStoragePath)
                        ?? panic("Could not borrow the FLOATEvents from the signer.")
  }

  execute {
    self.FLOATEvents.createEvent(type: FLOAT.ClaimOptions(rawValue: type)!, name: name, description: description, image: image, timePeriod: timePeriod, capacity: capacity, transferrable: transferrable)
    log("Started a new event.")
  }
}
