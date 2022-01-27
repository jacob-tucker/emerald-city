import FLOAT from "../FLOAT.cdc"

transaction(type: UInt8, name: String, description: String, image: String, transferrable: Bool, timePeriod: UFix64?, secret: Bool, capacity: UInt64?,) {

  let FLOATEvents: &FLOAT.FLOATEvents

  prepare(acct: AuthAccount) {
    self.FLOATEvents = acct.borrow<&FLOAT.FLOATEvents>(from: FLOAT.FLOATEventsStoragePath)
                        ?? panic("Could not borrow the FLOATEvents from the signer.")
  }

  execute {
    var Timelock: FLOAT.Timelock? = nil
    var Secret: FLOAT.Secret? = nil
    var Limited: FLOAT.Limited? = nil
    
    if let timePeriod = timePeriod {
      Timelock = FLOAT.Timelock(_timePeriod: timePeriod)
    }
    
    if secret {
      Secret = FLOAT.Secret()
    }

    if let capacity = capacity {
      Limited = FLOAT.Limited(_capacity: capacity)
    }
    
    self.FLOATEvents.createEvent(claimType: FLOAT.ClaimType(rawValue: type)!, timelock: Timelock, secret: Secret, limited: Limited, name: name, description: description, image: image, transferrable: transferrable)
    log("Started a new event.")
  }
}
