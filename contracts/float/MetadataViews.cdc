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

    pub struct FLOATMetadataView {
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

    // Display is a basic view that includes the name, description and
    // thumbnail for an object. Most objects should implement this view.
    //
    pub struct Display {

        // The name of the object. 
        //
        // This field will be displayed in lists and therefore should
        // be short an concise.
        //
        pub let name: String

        // A written description of the object. 
        //
        // This field will be displayed in a detailed view of the object,
        // so can be more verbose (e.g. a paragraph instead of a single line).
        //
        pub let description: String

        // A small thumbnail representation of the object.
        //
        // This field should be a web-friendly file (i.e JPEG, PNG)
        // that can be displayed in lists, link previews, etc.
        //
        pub let thumbnail: AnyStruct{File}

        init(
            name: String,
            description: String,
            thumbnail: AnyStruct{File}
        ) {
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
        }
    }

    // File is a generic interface that represents a file stored on or off chain.
    //
    // Files can be used to references images, videos and other media.
    //
    pub struct interface File {
        pub fun uri(): String
    }
}