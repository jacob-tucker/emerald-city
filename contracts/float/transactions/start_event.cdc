import FLOAT from "../FLOAT.cdc"

transaction(type: UInt8, name: String, description: String, image: String, timePeriod: UFix64?) {

  let FLOATEvents: &FLOAT.FLOATEvents

  prepare(acct: AuthAccount) {
    self.FLOATEvents = acct.borrow<&FLOAT.FLOATEvents>(from: FLOAT.FLOATEventsStoragePath)
                        ?? panic("Could not borrow the FLOATEvents from the signer.")
  }

  pre {
      type != 1 || timePeriod != nil:
        "If you are creating a Timelock event, you must pass in a timePeriod."
  }

  execute {
    self.FLOATEvents.createEvent(type: FLOAT.ClaimOptions(rawValue: type)!, name: name, description: description, image: image, timePeriod: timePeriod)
    log("Started a new event.")
  }
}
