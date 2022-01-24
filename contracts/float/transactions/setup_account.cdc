import FLOAT from "../FLOAT.cdc"
import NonFungibleToken from "../../NonFungibleToken.cdc"
import MetadataViews from "../MetadataViews.cdc"

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
