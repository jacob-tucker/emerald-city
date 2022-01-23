import MetadataViews from 0x02
import NonFungibleToken from 0x03

pub contract FLOAT: NonFungibleToken {

    // Paths
    //
    pub let FLOATCollectionStoragePath: StoragePath
    pub let FLOATCollectionPublicPath: PublicPath
    pub let FLOATEventsStoragePath: StoragePath
    pub let FLOATEventsPublicPath: PublicPath

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    // Throw away for standard
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event NFTMinted(recipient: Address, name: String, description: String, dateReceived: UFix64, image: String)
    pub event NFTDeposited(to: Address, host: Address, name: String, id: UInt64)
    pub event NFTWithdrawn(from: Address, host: Address, name: String, id: UInt64)

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let info: MetadataViews.FLOATMetadataView

        pub fun getViews(): [Type] {
             return [
                Type<MetadataViews.FLOATMetadataView>(),
                Type<MetadataViews.Identifier>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.FLOATMetadataView>():
                    return self.info
                case Type<MetadataViews.Identifier>():
                    return MetadataViews.Identifier(id: self.id, address: self.owner!.address) 
            }

            return nil
        }

        init(_recipient: Address, _host: Address, _name: String, _description: String, _image: String) {
            self.id = self.uuid
            self.info = MetadataViews.FLOATMetadataView(_recipient: _recipient, _host: _host, _name: _name, _description: _description, _image: _image)

            let dateReceived = 0.0 // getCurrentBlock().timestamp
            emit NFTMinted(recipient: _recipient, name: _name, description: _description, dateReceived: dateReceived, image: _image)

            FLOAT.totalSupply = FLOAT.totalSupply + 1
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let nft <- token as! @NFT
            emit NFTDeposited(to: nft.info.recipient, host: nft.info.host, name: nft.info.name, id: nft.uuid)
            self.ownedNFTs[nft.uuid] <-! nft
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            var token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist in this Collection.")
            var nft <- token as! @NFT
            emit NFTWithdrawn(from: nft.info.recipient, host: nft.info.host, name: nft.info.name, id: nft.uuid)
            return <- nft
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
            let tokenRef = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            let nftRef = tokenRef as! &NFT
            return nftRef as &{MetadataViews.Resolver}
        }

        init() {
            self.ownedNFTs <- {}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub struct FLOATEvent {
        pub let name: String
        pub let description: String 
        pub let image: String 
        pub let dateCreated: UFix64 
        pub let timePeriod: UFix64?
        pub let dateEnding: UFix64?
        pub(set) var active: Bool

        init(_name: String, _description: String, _image: String, _timePeriod: UFix64?) {
            self.name = _name
            self.description = _description
            self.image = _image
            self.dateCreated = 0.0 // getCurrentBlock().timestamp
            
            if let timePeriod = _timePeriod {
                self.timePeriod = timePeriod
                self.dateEnding = self.dateCreated + timePeriod
            } else {
                self.timePeriod = nil
                self.dateEnding = nil
            }
            
            self.active = true
        }
    }

    pub resource interface FLOATEventsPublic {
        pub fun getEvent(name: String): FLOATEvent
    }

    pub resource FLOATEvents: FLOATEventsPublic {
        pub var events: {String: FLOATEvent}

        pub fun createEvent(name: String, description: String, image: String, timePeriod: UFix64?) {
            pre {
                self.events[name] == nil: "An event with this name already exists in your Collection."
            }
            self.events[name] = FLOATEvent(_name: name, _description: description, _image: image, _timePeriod: timePeriod)
        }

        pub fun endEvent(name: String) {
            pre {
                self.events[name] != nil: "This event does not exist in your Collection."
            }
            let eventRef = &self.events[name] as &FLOATEvent
            eventRef.active = false
        }

        pub fun getEvent(name: String): FLOATEvent {
            return self.events[name] ?? panic("This event does not exist in this Collection.")
        }

        init() {
            self.events = {}
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun createEmptyFLOATEventCollection(): @FLOATEvents {
        return <- create FLOATEvents()
    }

    pub fun mint(FLOATEvents: &FLOATEvents{FLOATEventsPublic}, name: String, nftCollection: &Collection) {
        pre {
            FLOATEvents.getEvent(name: name).active: "This FLOAT is not active."
        }
        let FLOATEvent = FLOATEvents.getEvent(name: name)
        let token <- create NFT(
                                _recipient: nftCollection.owner!.address, 
                                _host: FLOATEvents.owner!.address, 
                                _name: FLOATEvent.name, 
                                _description: FLOATEvent.description, 
                                _image: FLOATEvent.image
                               ) 
        nftCollection.deposit(token: <- token)
    }

    init() {
        self.totalSupply = 0
        emit ContractInitialized()

        self.FLOATCollectionStoragePath = /storage/FLOATCollectionStoragePath
        self.FLOATCollectionPublicPath = /public/FLOATCollectionPublicPath
        self.FLOATEventsStoragePath = /storage/FLOATEventsStoragePath
        self.FLOATEventsPublicPath = /public/FLOATEventsPublicPath
    }
}