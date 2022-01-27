import MetadataViews from "./MetadataViews.cdc"
import NonFungibleToken from "../NonFungibleToken.cdc"

pub contract FLOAT: NonFungibleToken {

    pub enum ClaimType: UInt8 {
        pub case Claimable
        pub case NotClaimable
    }

    pub enum ClaimPropType: UInt8 {
        pub case Timelock
        pub case Secret
        pub case Limited
    }
b
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

    pub struct interface ClaimProp {
        pub let type: ClaimPropType
    }

    pub struct FLOATEventInfo {
        // Info that will be present in the NFT
        pub let host: Address
        pub let name: String
        pub let description: String 
        pub let image: String 
        pub let transferrable: Bool

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
            _claimProps: {ClaimPropType: {ClaimProp}}, 
            _host: Address, _name: String,
            _description: String, 
            _image: String, 
            _transferrable: Bool
        ) {
            self.claimType = _claimType
            self.Timelock = _claimProps[ClaimPropType.Timelock] as? Timelock
            self.Secret = _claimProps[ClaimPropType.Secret] as? Secret
            self.Limited = _claimProps[ClaimPropType.Limited] as? Limited

            self.host = _host
            self.name = _name
            self.description = _description
            self.image = _image
            self.transferrable = _transferrable

            self.dateCreated = getCurrentBlock().timestamp
            self.totalSupply = 0
            self.claimed = {}
            self.active = true
        }
    }

    pub struct Timelock: ClaimProp {
        pub let type: ClaimPropType
        
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
            self.type = ClaimPropType.Timelock

            self.dateStart = getCurrentBlock().timestamp
            self.dateEnding = getCurrentBlock().timestamp + _timePeriod
        }
    }

    pub struct Secret: ClaimProp {
        pub let type: ClaimPropType
        
        // A list of accounts to see who has put in a code.
        // Maps their address to the code they put in.
        access(account) var accounts: {Address: String}
        // The secret code, set by the owner of this event.
        pub var secretPhrase: String
        pub var claiamble: Bool

        access(account) fun verify(accountAddr: Address) {
            assert(
                self.accounts[accountAddr] == self.secretPhrase, 
                message: "You did not guess the correct secret before the Host typed it in."
            )
        }

        pub fun addSecretPhrase(secret: String) {
            self.secretPhrase = secret
            self.claiamble = true
        }

        init() {
            self.type = ClaimPropType.Secret

            self.accounts = {}
            self.secretPhrase = ""
            self.claiamble = false
        }
    }

    // If the maximum capacity is reached, this is no longer active.
    pub struct Limited: ClaimProp {
        pub let type: ClaimPropType
        
        // A list of accounts to get track on who is here first
        // Maps the position of who come first to their address.
        access(account) var accounts: {UInt64: Address}
        pub var capacity: UInt64

        access(account) fun verify(accountAddr: Address): Bool {
            let currentCapacity = UInt64(self.accounts.length)
            assert(
                currentCapacity < self.capacity,
                message: "This FLOAT Event is at capacity."
            )
            
            self.accounts[currentCapacity + 1] = accountAddr
            return true
        }

        init(_capacity: UInt64) {
            self.type = ClaimPropType.Limited

            self.accounts = {}
            self.capacity = _capacity
        }
    }

    pub resource interface FLOATEventsPublic {
        pub fun getEvent(name: String): FLOATEventInfo
        pub fun getAllEvents(): {String: FLOATEventInfo}
        pub fun addCreationCapability(minter: Capability<&FLOATEvents>) 
        pub fun claim(name: String, recipient: &Collection, secret: String?)
    }

    pub resource FLOATEvents: FLOATEventsPublic {
        access(self) var events: {String: FLOATEventInfo}
        access(self) var otherHosts: {Address: Capability<&FLOATEvents>}

        // Create a new FLOAT Event.
        pub fun createEvent(claimType: ClaimType, claimProps: {ClaimPropType: {ClaimProp}}, name: String, description: String, image: String, transferrable: Bool) {
            pre {
                self.events[name] == nil: 
                    "An event with this name already exists in your Collection."
            }

            let FLOATEvent = FLOATEventInfo(
                _claimType: claimType, 
                _claimProps: claimProps, 
                _host: self.owner!.address, 
                _name: name, 
                _description: description, 
                _image: image, 
                _transferrable: transferrable
            )
            self.events[name] = FLOATEvent
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

        // Get the Capability to do stuff with this FLOATEvents resource.
        pub fun getCreationCapability(host: Address): Capability<&FLOATEvents> {
            return self.otherHosts[host]!
        }

        // Get a public view of the FLOATEventInfo.
        pub fun getEvent(name: String): FLOATEventInfo {
            return self.events[name] ?? panic("This event does not exist in this Collection.")
        }

        // Get a Host view (reference) of the FLOATEventInfo.
        // 
        // You can use this ref right now to toggleActive
        pub fun getEventRef(name: String): &FLOATEventInfo {
            return &self.events[name] as &FLOATEventInfo
        }

        // Return all the FLOATEvents you have ever created.
        pub fun getAllEvents(): {String: FLOATEventInfo} {
            return self.events
        }

        /*************************************** CLAIMING ***************************************/

        // This is for distributing NotClaimable FLOAT Events.
        pub fun distributeDirectly(name: String, recipient: &Collection{NonFungibleToken.CollectionPublic} ) {
            pre {
                self.events[name] != nil:
                    "This event does not exist."
                self.events[name]!.claimType == ClaimType.NotClaimable:
                    "This event is Claimable."
            }
            let FLOATEvent = self.getEventRef(name: name)
            FLOATEvent.mint(recipient: recipient)
        }

        // This is for claiming Claimable FLOAT Events.
        //
        // The `secret` parameter is only necessary if you're claiming a `Secret` FLOAT.
        pub fun claim(name: String, recipient: &Collection, secret: String?) {
            pre {
                self.getEvent(name: name).active: 
                    "This FLOATEvent is not active."
                self.events[name]!.claimType == ClaimType.Claimable:
                    "This event is NotClaimable."
            }
            let FLOATEvent: &FLOATEventInfo = self.getEventRef(name: name)
            
            // If the FLOATEvent has the `Timelock` Prop
            if FLOATEvent.Timelock != nil {
                let Timelock: &Timelock = FLOATEvent.Timelock as! &Timelock
                Timelock.verify()
            } 
            
            // If the FLOATEvent has the `Secret` Prop
            if FLOATEvent.Secret != nil {
                let Secret: &Secret = FLOATEvent.Secret as! &Secret

                if !Secret.claiamble {
                    assert(
                        secret != nil, 
                        message: "You must provide a secret phrase code to mark your FLOAT ahead of time."
                    )
                    Secret.accounts[recipient.owner!.address] = secret
                } else {
                    Secret.verify(accountAddr: recipient.owner!.address)
                }
            }

            // If the FLOATEvent has the `Limited` Prop
            if FLOATEvent.Limited != nil {
            let Limited: &Limited = FLOATEvent.Limited as! &Limited
               Limited.verify(accountAddr: recipient.owner!.address)
            }

            // You have passed all the props (which act as restrictions).
            FLOATEvent.mint(recipient: recipient)
        }

        /******************************************************************************/

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