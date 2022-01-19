/**

This contract implements the metadata standard proposed
in FLIP-0636.

Ref: https://github.com/onflow/flow/blob/master/flips/20210916-nft-metadata.md

Structs and resources can implement one or more
metadata types, called views. Each view type represents
a different kind of metadata, such as a creator biography
or a JPEG image file.
*/

pub contract MetadataViews {

    // A Resolver provides access to a set of metadata views.
    //
    // A struct or resource (e.g. an NFT) can implement this interface
    // to provide access to the views that it supports.
    //
    pub resource interface Resolver {
        pub fun getViews(): [Type]
        pub fun resolveView(_ view: Type): AnyStruct?
    }

    // A ResolverCollection is a group of view resolvers index by ID.
    //
    pub resource interface ResolverCollection {
        pub fun borrowViewResolver(id: UInt64): &{Resolver}
        pub fun getIDs(): [UInt64]
    }

    pub struct POAPMetadataView {
        pub let recipient: Address
        pub let host: Address
        pub let name: String 
        pub let description: String
        pub let dateReceived: UFix64
        pub let image: String

        init(_recipient: Address, _host: Address, _name: String, _description: String, _image: String) {
            self.recipient = _recipient
            self.host = _host
            self.name = _name
            self.description = _description
            self.dateReceived = 0.0 // getCurrentBlock().timestamp
            self.image = _image
        }
    }

    pub struct Identifier {
        pub let id: UInt64
        pub let address: Address

        init(_id: UInt64, _address: Address) {
            self.id = _id
            self.address = _address
        }
    }
}