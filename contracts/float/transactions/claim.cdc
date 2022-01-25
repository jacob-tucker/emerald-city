import FLOAT from "../FLOAT.cdc"

transaction(name: String, host: Address, secret: String?) {
 
  let FLOATEvents: &FLOAT.FLOATEvents{FLOAT.FLOATEventsPublic}
  let Collection: &FLOAT.Collection

  prepare(acct: AuthAccount) {
    self.FLOATEvents = getAccount(host).getCapability(FLOAT.FLOATEventsPublicPath)
                        .borrow<&FLOAT.FLOATEvents{FLOAT.FLOATEventsPublic}>()
                        ?? panic("Could not borrow the public FLOATEvents from the host.")
    self.Collection = acct.borrow<&FLOAT.Collection>(from: FLOAT.FLOATCollectionStoragePath)
                        ?? panic("Could not get the Collection from the signer.")
  }

  execute {
    self.FLOATEvents.claim(name: name, recipient: self.Collection, secret: secret)
    log("Claimed the FLOAT.")
  }
}
 