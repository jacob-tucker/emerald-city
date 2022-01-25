import MetadataViews from "./MetadataViews.cdc"
import NonFungibleToken from "../NonFungibleToken.cdc"

pub contract FLOAT: NonFungibleToken {

    pub enum ClaimOptions: UInt8 {
        pub case Open
        pub case Timelock
        pub case Secret
        pub case Limited
        pub case Admin
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
        // The secret code, set by the owner of this event.
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

    // For an Admin to distribute directly to whomever.
    pub struct Admin: FLOATEvent {
        pub let type: ClaimOptions
        pub let info: FLOATEventInfo

        init(_host: Address, _name: String, _description: String, _image: String) {
            self.type = ClaimOptions.Admin
            self.info = FLOATEventInfo(_host: _host, _name: _name, _description: _description, _image: _image)
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

        // Create a new FLOAT Event.
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
            } else if type == ClaimOptions.Admin {
                self.events[name] = Admin(_host: self.owner!.address, _name: name, _description: description, _image: image)
            }
        }

        // Toggles the event true/false and returns
        // the new state of it.
        // 
        // If an event is not active, you can never claim from it.
        pub fun toggleEventActive(name: String): Bool {
            pre {
                self.events[name] != nil: "This event does not exist in your Collection."
            }
            let eventRef = &self.events[name] as &{FLOATEvent}
            eventRef.info.active = !eventRef.info.active
            return eventRef.info.active
        }

        // Delete an event if you made a mistake.
        pub fun deleteEvent(name: String) {
            self.events.remove(key: name)
        }

        // A method for receiving a &FLOATEvent Capability. This is if 
        // a different account wants you to be able to handle their FLOAT Events
        // for them, so imagine if you're on a team of people and you all handle
        // one account.
        pub fun addCreationCapability(minter: Capability<&FLOATEvents>) {
            self.otherHosts[minter.borrow()!.owner!.address] = minter
        }

        // For giving out FLOATs when the FLOAT Event is `Admin` type.
        pub fun distributeDirectly(name: String, recipient: &Collection{NonFungibleToken.CollectionPublic}) {
            pre {
                self.events[name] != nil:
                    "This event does not exist."
                self.events[name]!.type == ClaimOptions.Admin:
                    "This event is not an Admin type."
            }
            let FLOATEvent = self.getEventRef(name: name)
            FLOAT.mint(recipient: recipient, FLOATEvent: FLOATEvent)
        }

        // Get the Capability to do stuff with this FLOATEvents resource.
        pub fun getCreationCapability(host: Address): Capability<&FLOATEvents> {
            return self.otherHosts[host]!
        }

        // Get a {FLOATEvent} struct. The returned value is a copy.
        pub fun getEvent(name: String): {FLOATEvent} {
            return self.events[name] ?? panic("This event does not exist in this Collection.")
        }

        // Only used in this contract, so you can update things on the {FLOATEvent} struct.
        access(contract) fun getEventRef(name: String): auth &{FLOATEvent} {
            return &self.events[name] as auth &{FLOATEvent}
        }

        // If you have a `Secret` FLOATEvent and want to add the secretPhrase to it.
        // Once you do this, users will be able to claim their FLOAT if they had
        // previously typed in the same phrase you provided here.
        pub fun addSecretToEvent(name: String, secretPhrase: String) {
            let ref = &self.events[name] as auth &{FLOATEvent}
            let secret = ref as! &Secret
            secret.secretPhrase = secretPhrase
        }

        // Return all the FLOATEvents you have ever created.
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
    // This is for claiming `Open`, `Timelock`, `Secret`, or `Limited` FLOAT Events.
    //
    // The `secret` parameter is only necessary if you're claiming a `Secret` FLOAT.
    pub fun claim(FLOATEvents: &FLOATEvents{FLOATEventsPublic}, name: String, recipient: &Collection, secret: String?) {
        pre {
            FLOATEvents.getEvent(name: name).info.active: 
                "This FLOATEvent is not active."
        }
        let FLOATEvent: auth &{FLOATEvent} = FLOATEvents.getEventRef(name: name)
        
        // For `Open` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Open {
            self.mint(recipient: recipient, FLOATEvent: FLOATEvent)
            return
        }
        
        // For `Timelock` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Timelock {
            let Timelock: &Timelock = FLOATEvent as! &Timelock
            if Timelock.dateEnding <= getCurrentBlock().timestamp {
                panic("Sorry! The time has run out to mint this Timelock FLOAT.")
            }
            self.mint(recipient: recipient, FLOATEvent: FLOATEvent)
            return
        } 
        
        // For `Secret` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Secret {
            let Secret: &Secret = FLOATEvent as! &Secret
            if Secret.secretPhrase == "" && secret == nil {
                panic("You must provide a secret phrase code to claim your FLOAT ahead of time.")
            }

            if Secret.secretPhrase == "" {
                Secret.accounts[recipient.owner!.address] = secret
            } else if Secret.accounts[recipient.owner!.address] == Secret.secretPhrase {
                self.mint(recipient: recipient, FLOATEvent: FLOATEvent)
            }
            return
        }

        // For `Limited` FLOATEvents
        if FLOATEvent.type == ClaimOptions.Limited {
            let Limited: &Limited = FLOATEvent as! &Limited
            let currentCapacity = UInt64(Limited.accounts.length)
            if currentCapacity < Limited.capacity {
                Limited.accounts[currentCapacity + 1] = recipient.owner!.address
                self.mint(recipient: recipient, FLOATEvent: FLOATEvent)
            }
            return
        }
    }

    // Helper function to mint FLOATs.
    access(contract) fun mint(recipient: &Collection{NonFungibleToken.CollectionPublic}, FLOATEvent: &{FLOATEvent}) {
        pre {
            !FLOATEvent.info.claimed[recipient.owner!.address]!:
                "This person already claimed their FLOAT!"
        }
        let token <- create NFT(_recipient: recipient.owner!.address, _info: FLOATEvent.info) 
        recipient.deposit(token: <- token)
        FLOATEvent.info.claimed[recipient.owner!.address] = true
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