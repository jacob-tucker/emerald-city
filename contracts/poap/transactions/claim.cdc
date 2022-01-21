import POAP from 0x01

transaction(name: String, host: Address) {
 
  let POAPEvents: &POAP.POAPEvents{POAP.POAPEventsPublic}
  let Collection: &POAP.Collection

  prepare(acct: AuthAccount) {
    self.POAPEvents = getAccount(host).getCapability(POAP.POAPEventsPublicPath)
                        .borrow<&POAP.POAPEvents{POAP.POAPEventsPublic}>()
                        ?? panic("Could not borrow the public POAPEvents from the host.")
    self.Collection = acct.borrow<&POAP.Collection>(from: POAP.POAPCollectionStoragePath)
                        ?? panic("Could not get the Collection from the signer.")
  }

  execute {
    POAP.mint(poapEvents: self.POAPEvents, name: name, nftCollection: self.Collection)
    log("Claimed the POAP.")
  }
}
