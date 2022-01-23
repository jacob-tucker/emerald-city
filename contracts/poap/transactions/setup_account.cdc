import FLOAT from 0x01
import NonFungibleToken from 0x03
import MetadataViews from 0x02

transaction {

  prepare(acct: AuthAccount) {
    // set up the FLOAT Collection where users will store their FLOATs
    acct.save(<- FLOAT.createEmptyCollection(), to: FLOAT.FLOATCollectionStoragePath)
    acct.link<&FLOAT.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>
            (FLOAT.FLOATCollectionPublicPath, target: FLOAT.FLOATCollectionStoragePath)

    // set up the FLOAT Events where users will store all their created events
    acct.save(<- FLOAT.createEmptyFLOATEventCollection(), to: FLOAT.FLOATEventsStoragePath)
    acct.link<&FLOAT.FLOATEvents{FLOAT.FLOATEventsPublic}>(FLOAT.FLOATEventsPublicPath, target: FLOAT.FLOATEventsStoragePath)
  }

  execute {
    log("Finished setting up the account for FLOATs.")
  }
}
