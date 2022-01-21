import POAP from 0x01
import MetadataViews from 0x02

pub fun main(account: Address, id: UInt64): MetadataViews.POAPMetadataView? {
  let nftCollection = getAccount(account).getCapability(POAP.POAPCollectionPublicPath)
                        .borrow<&POAP.Collection{MetadataViews.ResolverCollection}>()
                        ?? panic("Could not borrow the Collection from the account.")
  let nft = nftCollection.borrowViewResolver(id: id)
  if let metadata = nft.resolveView(Type<MetadataViews.POAPMetadataView>()) {
    return metadata as! MetadataViews.POAPMetadataView
  }

  return nil
}
