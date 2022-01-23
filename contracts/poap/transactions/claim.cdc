import FLOAT from 0x01

transaction(name: String, host: Address) {
 
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
    FLOAT.mint(FLOATEvents: self.FLOATEvents, name: name, nftCollection: self.Collection)
    log("Claimed the FLOAT.")
  }
}
