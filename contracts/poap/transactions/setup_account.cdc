import POAP from 0x01
import NonFungibleToken from 0x03
import MetadataViews from 0x02

// Set up the user's account

transaction {

  prepare(acct: AuthAccount) {
    // set up the POAP Collection where users will store their POAPs
    acct.save(<- POAP.createEmptyCollection(), to: POAP.POAPCollectionStoragePath)
    acct.link<&POAP.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>
            (POAP.POAPCollectionPublicPath, target: POAP.POAPCollectionStoragePath)

    // set up the POAP Events where users will store all their created events
    acct.save(<- POAP.createEmptyPOAPEventCollection(), to: POAP.POAPEventsStoragePath)
    acct.link<&POAP.POAPEvents{POAP.POAPEventsPublic}>(POAP.POAPEventsPublicPath, target: POAP.POAPEventsStoragePath)
  }

  execute {
    log("Finished setting up the account for POAPs.")
  }
}
