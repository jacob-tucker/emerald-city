import MetadataViews from "./MetadataViews.cdc"
import NonFungibleToken from "../NonFungibleToken.cdc"

pub contract FLOAT: NonFungibleToken {

    pub enum ClaimOptions: UInt8 {
        pub case Open
        pub case Timelock
        pub case Secret
        pub case Limited
    }

    // Paths
    //
    pub let FLOATCollectionStoragePath: StoragePath
    pub let FLOATCollectionPublicPath: PublicPath
    pub let FLOATEventsStoragePath: StoragePath
    pub let FLOATEventsPublicPath: PublicPath
    pub let FLOATEventsPrivatePath: PrivatePath

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    // Throw away for standard
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event FLOATMinted(recipient: Address, info: FLOATEventInfo)
    pub event FLOATDeposited(to: Address, host: Address, name: String, id: UInt64)
    pub event FLOATWithdrawn(from: Address, host: Address, name: String, id: UInt64)

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let info: MetadataViews.FLOATMetadataView

        pub fun getViews(): [Type] {
             return [
                Type<MetadataViews.FLOATMetadataView>(),
                Type<MetadataViews.Identifier>(),
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.FLOATMetadataView>():
                    return self.info
                case Type<MetadataViews.Identifier>():
                    return MetadataViews.Identifier(id: self.id, address: self.owner!.address) 
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                                                 name: self.info.name, 
                                                 description: self.info.description, 
                                                 file: MetadataViews.IPFSFile(cid: self.info.image, path: nil)
                                                )
            }

            return nil
        }

        init(_recipient: Address, _info: FLOATEventInfo) {
            self.id = self.uuid
            self.info = MetadataViews.FLOATMetadataView(
                                                        _recipient: _recipient, 
                                                        _host: _info.host, 
                                                        _name: _info.name, 
                                                        _description: _info.description, 
                                                        _image: _info.image
                                                       )

            let dateReceived = 0.0 // getCurrentBlock().timestamp
            emit FLOATMinted(recipient: _recipient, info: _info)

            FLOAT.totalSupply = FLOAT.totalSupply + 1
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let nft <- token as! @NFT
            emit FLOATDeposited(to: nft.info.recipient, host: nft.info.host, name: nft.info.name, id: nft.uuid)
            self.ownedNFTs[nft.uuid] <-! nft
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            var token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist in this Collection.")
            var nft <- token as! @NFT
            emit FLOATWithdrawn(from: nft.info.recipient, host: nft.info.host, name: nft.info.name, id: nft.uuid)
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

    pub struct interface FLOATEvent {
        pub let type: ClaimOptions
        pub let info: FLOATEventInfo
    }

    pub struct FLOATEventInfo {
        pub let host: Address
        pub let name: String
        pub let description: String 
        pub let image: String 
        pub let dateCreated: UFix64
        pub(set) var claimed: {Address: Bool}
        // A manual switch for the host to be able to turn off
        pub(set) var active: Bool
        init(_host: Address, _name: String, _description: String, _image: String) {
            self.host = _host
            self.name = _name
            self.description = _description
            self.image = _image
            self.dateCreated = 0.0 // getCurrentBlock().timestamp
            self.claimed = {}
            self.active = true
        }
    }

    pub struct Open: FLOATEvent {
        pub let type: ClaimOptions
        pub let info: FLOATEventInfo

        init(_host: Address, _name: String, _description: String, _image: String) {
            self.type = ClaimOptions.Open
            self.info = FLOATEventInfo(_host: _host, _name: _name, _description: _description, _image: _image)
        }
    }

    pub struct Timelock: FLOATEvent {
        pub let type: ClaimOptions
        pub let info: FLOATEventInfo
        
        // An automatic switch handled by the contract
        // to stop people from claiming after a certain time.
        pub let timePeriod: UFix64
        pub let dateEnding: UFix64

        init(_host: Address, _name: String, _description: String, _image: String, _timePeriod: UFix64) {
            self.type = ClaimOptions.Timelock
            self.info = FLOATEventInfo(_host: _host, _name: _name, _description: _description, _image: _image)
            
            self.timePeriod = _timePeriod
            self.dateEnding = self.info.dateCreated + _timePeriod
        }
    }

    // If the secretPhrase == "", this is set to active.
    // Otherwise, the secretPhrase has been inputted and this is
    // no longer active.
    pub struct Secret: FLOATEvent {
        pub let type: ClaimOptions
        pub let info: FLOATEventInfo
        
        // A list of accounts to see who has put in a code.
        // Maps their address to the code they put in.
        pub(set) var accounts: {Address: String}
        pub(set) var secretPhrase: String

        init(_host: Address, _name: String, _description: String, _image: String) {
            self.type = ClaimOptions.Secret
            self.info = FLOATEventInfo(_host: _host, _name: _name, _description: _description, _image: _image)

            self.accounts = {}
            self.secretPhrase = ""
        }
    }

    // If the maximum capacity is reached, this is no longer active.
    pub struct Limited: FLOATEvent {
        pub let type: ClaimOptions
        pub let info: FLOATEventInfo
        
        // A list of accounts to get track on who is here first
        // Maps the position of who come first to their address.
        pub(set) var accounts: {UInt64: Address}
        pub let capacity: UInt64

        init(_host: Address, _name: String, _description: String, _image: String, _capacity: UInt64) {
            self.type = ClaimOptions.Secret
            self.info = FLOATEventInfo(_host: _host, _name: _name, _description: _description, _image: _image)

            self.accounts = {}
            self.capacity = _capacity
        }
    }

    pub resource interface FLOATEventsPublic {
        pub fun getEvent(name: String): {FLOATEvent}
        access(contract) fun getEventRef(name: String): auth &{FLOATEvent}
        pub fun getAllEvents(): {String: {FLOATEvent}}
        pub fun addCreationCapability(minter: Capability<&FLOATEvents>) 
    }

    pub resource FLOATEvents: FLOATEventsPublic {
        access(contract) var events: {String: {FLOATEvent}}
        access(contract) var otherHosts: {Address: Capability<&FLOATEvents>}

        pub fun createEvent(type: ClaimOptions, name: String, description: String, image: String, timePeriod: UFix64?, capacity: UInt64?) {
            pre {
                self.events[name] == nil: 
                    "An event with this name already exists in your Collection."
                type != ClaimOptions.Timelock || timePeriod != nil: 
                    "If you use Timelock as the event type, you must provide a timePeriod."
                type != ClaimOptions.Limited || capacity != nil:
                    "If you use Limited as the event type, you must provide a capacity."
            }

            if type == ClaimOptions.Open {
                self.events[name] = Open(_host: self.owner!.address, _name: name, _description: description, _image: image)
            } else if type == ClaimOptions.Timelock {
                self.events[name] = Timelock(_host: self.owner!.address, _name: name, _description: description, _image: image, _timePeriod: timePeriod!)
            } else if type == ClaimOptions.Secret {
                self.events[name] = Secret(_host: self.owner!.address, _name: name, _description: description, _image: image)
            } else if type == ClaimOptions.Limited {
                self.events[name] = Limited(_host: self.owner!.address, _name: name, _description: description, _image: image, _capacity: capacity!)
            }
        }

        // Toggles the event true/false and returns
        // the new state of it.
        pub fun toggleEventActive(name: String): Bool {
            pre {
                self.events[name] != nil: "This event does not exist in your Collection."
            }
            let eventRef = &self.events[name] as &{FLOATEvent}
            eventRef.info.active = !eventRef.info.active
            return eventRef.info.active
        }

        pub fun deleteEvent(name: String) {
            self.events.remove(key: name)
        }

        pub fun addCreationCapability(minter: Capability<&FLOATEvents>) {
            self.otherHosts[minter.borrow()!.owner!.address] = minter
        }

        pub fun getCreationCapability(host: Address): Capability<&FLOATEvents> {
            return self.otherHosts[host]!
        }

        pub fun getEvent(name: String): {FLOATEvent} {
            return self.events[name] ?? panic("This event does not exist in this Collection.")
        }

        access(contract) fun getEventRef(name: String): auth &{FLOATEvent} {
            return &self.events[name] as auth &{FLOATEvent}
        }

        pub fun addSecretToEvent(name: String, secretPhrase: String) {
            let ref = &self.events[name] as auth &{FLOATEvent}
            let secret = ref as! &Secret
            secret.secretPhrase = secretPhrase
        }

        pub fun getAllEvents(): {String: {FLOATEvent}} {
            return self.events
        }

        init() {
            self.events = {}
            self.otherHosts = {}
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun createEmptyFLOATEventCollection(): @FLOATEvents {
        return <- create FLOATEvents()
    }

    // Claim a FLOAT.
    //
    // The `secret` parameter is only necessary if you're claiming a `Secret` FLOAT.
    pub fun claim(FLOATEvents: &FLOATEvents{FLOATEventsPublic}, name: String, nftCollection: &Collection, secret: String?) {
        pre {
            FLOATEvents.getEvent(name: name).info.active: 
                "This FLOATEvent is not active."
        }
        let FLOATEvent: auth &{FLOATEvent} = FLOATEvents.getEventRef(name: name)
        
        // For `Open` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Open {
            self.mint(nftCollection: nftCollection, FLOATEvent: FLOATEvent)
            return
        }
        
        // For `Timelock` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Timelock {
            let Timelock: &Timelock = FLOATEvent as! &Timelock
            if Timelock.dateEnding <= getCurrentBlock().timestamp {
                panic("Sorry! The time has run out to mint this Timelock FLOAT.")
            }
            self.mint(nftCollection: nftCollection, FLOATEvent: FLOATEvent)
            return
        } 
        
        // For `Secret` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Secret {
            let Secret: &Secret = FLOATEvent as! &Secret
            if Secret.secretPhrase == "" && secret == nil {
                panic("You must provide a secret phrase code to claim your FLOAT ahead of time.")
            }

            if Secret.secretPhrase == "" {
                Secret.accounts[nftCollection.owner!.address] = secret
            } else if Secret.accounts[nftCollection.owner!.address] == Secret.secretPhrase {
                self.mint(nftCollection: nftCollection, FLOATEvent: FLOATEvent)
            }
            return
        }

        // For `Limited` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Limited {
            let Limited: &Limited = FLOATEvent as! &Limited
            let currentCapacity = UInt64(Limited.accounts.length)
            if Limited.capacity > currentCapacity {
                Limited.accounts[currentCapacity + 1] = nftCollection.owner!.address
                self.mint(nftCollection: nftCollection, FLOATEvent: FLOATEvent)
            }
            return
        }
    }

    access(contract) fun mint(nftCollection: &Collection, FLOATEvent: &{FLOATEvent}) {
        pre {
            !FLOATEvent.info.claimed[nftCollection.owner!.address]!:
                "This person already claimed their FLOAT!"
        }
        let token <- create NFT(_recipient: nftCollection.owner!.address, _info: FLOATEvent.info) 
        nftCollection.deposit(token: <- token)
        FLOATEvent.info.claimed[nftCollection.owner!.address] = true
    }

    init() {
        self.totalSupply = 0
        emit ContractInitialized()

        self.FLOATCollectionStoragePath = /storage/FLOATCollectionStoragePath
        self.FLOATCollectionPublicPath = /public/FLOATCollectionPublicPath
        self.FLOATEventsStoragePath = /storage/FLOATEventsStoragePath
        self.FLOATEventsPublicPath = /public/FLOATEventsPublicPath
        self.FLOATEventsPrivatePath = /private/FLOATEventsPrivatePath
    }
}