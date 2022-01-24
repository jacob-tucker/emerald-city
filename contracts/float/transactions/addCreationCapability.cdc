import FLOAT from "../FLOAT.cdc"
import NonFungibleToken from "../../NonFungibleToken.cdc"
import MetadataViews from "../MetadataViews.cdc"

transaction (receiveraddr : Address) {
let FLOATEventsCapability : Capability<&FLOAT.FLOATEvents>

  prepare(acct: AuthAccount) {

    pre{ 
      acct.borrow<&FLOAT.FLOATEvents>(from: FLOAT.FLOATEventsStoragePath) != nil : "FLOATEvent Collection is not created."
    }
    // set up the FLOAT Collection (where users will store their FLOATs) if they havent get one
    if acct.borrow<&FLOAT.Collection>(from: FLOAT.FLOATCollectionStoragePath) == nil {
      acct.save(<- FLOAT.createEmptyCollection(), to: FLOAT.FLOATCollectionStoragePath)
      acct.link<&FLOAT.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>
              (FLOAT.FLOATCollectionPublicPath, target: FLOAT.FLOATCollectionStoragePath)
    }


    // link the FLOATEvents as private capability to enable passing
    acct.link<&FLOAT.FLOATEvents>(FLOAT.FLOATEventsPrivatePath, target: FLOAT.FLOATEventsStoragePath)
    self.FLOATEventsCapability = acct.getCapability<&FLOAT.FLOATEvents>(FLOAT.FLOATEventsPrivatePath)

  }

  execute {
    let receiverRef = getAccount(receiveraddr).getCapability(FLOAT.FLOATEventsPublicPath).borrow<&FLOAT.FLOATEvents{FLOAT.FLOATEventsPublic}>() ?? panic("This capability does not exist")
    receiverRef.addCreationCability(minter: self.FLOATEventsCapability)
    log("Finished setting up the account for FLOATs.")

  }
}
