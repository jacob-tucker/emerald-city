import MetadataViews from "./MetadataViews.cdc"
import NonFungibleToken from "../NonFungibleToken.cdc"

pub contract FLOAT: NonFungibleToken {

    pub enum ClaimType: UInt8 {
        pub case Claimable
        pub case NotClaimable
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

    pub event FLOATMinted(id: UInt64, metadata: MetadataViews.FLOATMetadataView)
    pub event FLOATDeposited(to: Address, id: UInt64, metadata: MetadataViews.FLOATMetadataView)
    pub event FLOATWithdrawn(from: Address, id: UInt64, metadata: MetadataViews.FLOATMetadataView)

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let metadata: MetadataViews.FLOATMetadataView

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
                    return self.metadata
                case Type<MetadataViews.Identifier>():
                    return MetadataViews.Identifier(id: self.id, address: self.owner!.address) 
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                                                 name: self.metadata.name, 
                                                 description: self.metadata.description, 
                                                 file: MetadataViews.IPFSFile(cid: self.metadata.image, path: nil)
                                                )
            }

            return nil
        }

        init(_metadata: MetadataViews.FLOATMetadataView) {
            self.id = self.uuid
            self.metadata = _metadata

            let dateReceived = getCurrentBlock().timestamp
            emit FLOATMinted(id: self.id, metadata: self.metadata)

            FLOAT.totalSupply = FLOAT.totalSupply + 1
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let nft <- token as! @NFT
            emit FLOATDeposited(to: self.owner!.address, id: nft.uuid, metadata: nft.metadata)
            self.ownedNFTs[nft.uuid] <-! nft
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("You do not own this FLOAT in your collection")
            let nft <- token as! @NFT
            
            assert(nft.metadata.transferrable, message: "This FLOAT is not transferrable.")
            emit FLOATWithdrawn(from: self.owner!.address, id: nft.uuid, metadata: nft.metadata)
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

    pub resource FLOATEvent {
        // Info that will be present in the NFT
        pub let host: Address
        pub let name: String
        pub let description: String 
        pub let image: String 
        pub let transferrable: Bool
        pub let metadata: {String: String}

        pub let dateCreated: UFix64
        // Effectively the current serial number
        pub var totalSupply: UInt64
        // Maps a user's address to its serial number
        access(account) var claimed: {Address: UInt64}
        // A manual switch for the host to be able to turn off
        pub var active: Bool

        pub let claimType: ClaimType
        pub let Timelock: Timelock?
        pub let Secret: Secret?
        pub let Limited: Limited?

        pub fun toggleActive(): Bool {
            self.active = !self.active
            return self.active
        }
  
        pub fun getClaimed(): {Address: UInt64} {
            return self.claimed
        }

        // Helper function to mint FLOATs.
        access(account) fun mint(recipient: &Collection{NonFungibleToken.CollectionPublic}) {
            pre {
                self.claimed[recipient.owner!.address] == nil:
                    "This person already claimed their FLOAT!"
            }
            let serial: UInt64 = self.totalSupply
            let recipientAddr: Address = recipient.owner!.address

            let metadata = MetadataViews.FLOATMetadataView(
                                            _recipient: recipientAddr, 
                                            _serial: serial,
                                            _host: self.host, 
                                            _name: self.name, 
                                            _description: self.description, 
                                            _image: self.image,
                                            _transferrable: self.transferrable
                                        )
            let token <- create NFT(_metadata: metadata) 
            recipient.deposit(token: <- token)

            self.claimed[recipientAddr] = serial
            self.totalSupply = serial + 1
        }

        init (
            _claimType: ClaimType, 
            _timelock: Timelock?,
            _secret: Secret?,
            _limited: Limited?,
            _host: Address, _name: String,
            _description: String, 
            _image: String, 
            _transferrable: Bool,
            _metadata: {String: String}
        ) {
            self.host = _host
            self.name = _name
            self.description = _description
            self.image = _image
            self.transferrable = _transferrable
            self.metadata = _metadata

            self.dateCreated = getCurrentBlock().timestamp
            self.totalSupply = 0
            self.claimed = {}
            self.active = true

            self.claimType = _claimType
            self.Timelock = _timelock
            self.Secret = _secret
            self.Limited = _limited
        }
    }

    pub struct Timelock {
        // An automatic switch handled by the contract
        // to stop people from claiming after a certain time.
        pub let dateStart: UFix64
        pub let dateEnding: UFix64

        access(account) fun verify() {
            assert(
                    getCurrentBlock().timestamp < self.dateEnding,
                    message: "Sorry! The time has run out to mint this Timelock FLOAT."
            )
        }

        init(_timePeriod: UFix64) {
            self.dateStart = getCurrentBlock().timestamp
            self.dateEnding = getCurrentBlock().timestamp + _timePeriod
        }
    }

    pub struct Secret {
        // The secret code, set by the owner of this event.
        access(account) var secretPhrase: String

        access(account) fun verify(secretPhrase: String?) {
            assert(
                secretPhrase != nil,
                message: "You must input a secret phrase."
            )
            assert(
                self.secretPhrase == secretPhrase, 
                message: "You did not input the correct secret phrase."
            )
        }

        init(_secretPhrase: String) {
            self.secretPhrase = _secretPhrase
        }
    }

    // If the maximum capacity is reached, this is no longer active.
    pub struct Limited {
        // A list of accounts to get track on who is here first
        // Maps the position of who come first to their address.
        access(account) var accounts: {UInt64: Address}
        pub var capacity: UInt64

        access(account) fun verify(accountAddr: Address) {
            let currentCapacity = UInt64(self.accounts.length)
            assert(
                currentCapacity < self.capacity,
                message: "This FLOAT Event is at capacity."
            )
            
            self.accounts[currentCapacity + 1] = accountAddr
        }

        init(_capacity: UInt64) {
            self.accounts = {}
            self.capacity = _capacity
        }
    }
 
    pub resource interface FLOATEventsPublic {
        pub fun getAllEvents(): [String]
        pub fun addCreationCapability(minter: Capability<&FLOATEvents>) 
        pub fun claim(name: String, recipient: &Collection, secret: String?)
    }

    pub resource FLOATEvents: FLOATEventsPublic {
        access(self) var events: @{String: FLOATEvent}
        access(self) var otherHosts: {Address: Capability<&FLOATEvents>}

        // Create a new FLOAT Event.
        pub fun createEvent(
            claimType: ClaimType, 
            timelock: Timelock?, 
            secret: Secret?, 
            limited: Limited?, 
            name: String, 
            description: String, 
            image: String, 
            transferrable: Bool,
            _ metadata: {String: String}
        ) {
            pre {
                self.events[name] == nil: 
                    "An event with this name already exists in your Collection."
            }

            let FLOATEvent <- create FLOATEvent(
                _claimType: claimType, 
                _timelock: timelock,
                _secret: secret,
                _limited: limited,
                _host: self.owner!.address, 
                _name: name, 
                _description: description, 
                _image: image, 
                _transferrable: transferrable,
                _metadata: metadata
            )
            self.events[name] <-! FLOATEvent
        }

        // Delete an event if you made a mistake.
        pub fun deleteEvent(name: String) {
            let event <- self.events.remove(key: name)
            destroy event
        }

        // A method for receiving a &FLOATEvent Capability. This is if 
        // a different account wants you to be able to handle their FLOAT Events
        // for them, so imagine if you're on a team of people and you all handle
        // one account.
        pub fun addCreationCapability(minter: Capability<&FLOATEvents>) {
            self.otherHosts[minter.borrow()!.owner!.address] = minter
        }

        // Get the Capability to do stuff with this FLOATEvents resource.
        pub fun getCreationCapability(host: Address): Capability<&FLOATEvents> {
            return self.otherHosts[host]!
        }

        // Get a view of the FLOATEvent.
        pub fun getEvent(name: String): &FLOATEvent {
            return &self.events[name] as &FLOATEvent
        }

        // Return all the FLOATEvents.
        pub fun getAllEvents(): [String] {
            return self.events.keys
        }

        /*************************************** CLAIMING ***************************************/

        // This is for distributing NotClaimable FLOAT Events.
        // NOT available to the public.
        pub fun distributeDirectly(name: String, recipient: &Collection{NonFungibleToken.CollectionPublic} ) {
            pre {
                self.events[name] != nil:
                    "This event does not exist."
                self.getEvent(name: name).claimType == ClaimType.NotClaimable:
                    "This event is Claimable."
            }
            let FLOATEvent = self.getEvent(name: name)
            FLOATEvent.mint(recipient: recipient)
        }

        // This is for claiming Claimable FLOAT Events.
        //
        // The `secret` parameter is only necessary if you're claiming a `Secret` FLOAT.
        // Available to the public.
        pub fun claim(name: String, recipient: &Collection, secret: String?) {
            pre {
                self.getEvent(name: name).active: 
                    "This FLOATEvent is not active."
                self.getEvent(name: name).claimType == ClaimType.Claimable:
                    "This event is NotClaimable."
            }
            let FLOATEvent: &FLOATEvent = self.getEvent(name: name)
            
            // If the FLOATEvent has the `Timelock` Prop
            if FLOATEvent.Timelock != nil {
                let Timelock: &Timelock = &FLOATEvent.Timelock! as &Timelock
                Timelock.verify()
            } 

            // If the FLOATEvent has the `Secret` Prop
            if FLOATEvent.Secret != nil {
                let Secret: &Secret = &FLOATEvent.Secret! as &Secret
                Secret.verify(secretPhrase: secret)
            }

            // If the FLOATEvent has the `Limited` Prop
            if FLOATEvent.Limited != nil {
                let Limited: &Limited = &FLOATEvent.Limited! as &Limited
                Limited.verify(accountAddr: recipient.owner!.address)
            }

            // You have passed all the props (which act as restrictions).
            FLOATEvent.mint(recipient: recipient)
        }

        /******************************************************************************/

        init() {
            self.events <- {}
            self.otherHosts = {}
        }

        destroy() {
            destroy self.events
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun createEmptyFLOATEventCollection(): @FLOATEvents {
        return <- create FLOATEvents()
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