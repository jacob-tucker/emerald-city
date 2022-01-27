import MetadataViews from "./MetadataViews.cdc"
import NonFungibleToken from "../NonFungibleToken.cdc"

pub contract FLOAT: NonFungibleToken {

    pub enum ClaimType: UInt8 {
        pub case Public
        pub case Admin
    }

    pub enum ClaimPropType: UInt8 {
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

    pub event FLOATMinted(recipient: Address, host: Address, name: String, serial: UInt64, id: UInt64)
    pub event FLOATDeposited(to: Address, host: Address, name: String, serial: UInt64, id: UInt64)
    pub event FLOATWithdrawn(from: Address, host: Address, name: String, serial: UInt64, id: UInt64)

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

        init(_recipient: Address, _serial: UInt64, _info: FLOATEventInfo) {
            self.id = self.uuid
            self.info = MetadataViews.FLOATMetadataView(
                                                        _recipient: _recipient, 
                                                        _serial: _serial,
                                                        _host: _info.host, 
                                                        _name: _info.name, 
                                                        _description: _info.description, 
                                                        _image: _info.image,
                                                        _transferrable: _info.transferrable
                                                       )

            let dateReceived = getCurrentBlock().timestamp
            emit FLOATMinted(recipient: _recipient, host: _info.host, name: _info.name, serial: _serial, id: self.id)

            FLOAT.totalSupply = FLOAT.totalSupply + 1
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let nft <- token as! @NFT
            emit FLOATDeposited(to: self.owner!.address, host: nft.info.host, name: nft.info.name, serial: nft.info.serial, id: nft.uuid)
            self.ownedNFTs[nft.uuid] <-! nft
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("You do not own this FLOAT in your collection")
            let nft <- token as! @NFT
            
            assert(nft.info.transferrable, message: "This FLOAT is not transferrable.")
            emit FLOATWithdrawn(from: self.owner!.address, host: nft.info.host, name: nft.info.name, serial: nft.info.serial, id: nft.uuid)
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
        pub let host: Address
        pub let name: String
        pub let description: String 
        pub let image: String 
        pub let transferrable: Bool

        // When the FLOAT Event was created
        pub let dateCreated: UFix64
        // Effectively the current serial number
        pub var totalSupply: UInt64
        // Maps a user's address to its serial number
        access(contract) var claimed: {Address: UInt64}
        // A manual switch for the host to be able to turn off
        pub(set) var active: Bool

        access(contract) let claimType: ClaimType
        access(contract) let claimPropTypes: {ClaimPropType: {ClaimProp}}

        pub fun getClaimPropRef(claimPropType: ClaimPropType): auth &{ClaimProp} {
            return &self.claimPropTypes[claimPropType] as auth &{ClaimProp}
        }

        access(contract) fun mintedFLOAT(to: Address, serial: UInt64) {
            self.claimed[to] = serial
            self.totalSupply = serial + 1
        }

        init (
            _claimType: ClaimType, 
            _claimPropTypes: {ClaimPropType: {ClaimProp}}, 
            _host: Address, _name: String,
            _description: String, 
            _image: String, 
            _transferrable: Bool
        ) {
            self.claimType = _claimType
            self.claimPropTypes = _claimPropTypes

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
        pub(set) var dateEnding: UFix64

        pub fun verify(): Bool {
            assert(
                    getCurrentBlock().timestamp < self.dateEnding,
                    message: "Sorry! The time has run out to mint this Timelock FLOAT."
            )
            return true
        }

        init(_timePeriod: UFix64) {
            self.type = ClaimPropType.Timelock

            self.dateStart = getCurrentBlock().timestamp
            self.dateEnding = getCurrentBlock().timestamp + _timePeriod
        }
    }

    // If the secretPhrase == "", this is set to active.
    // Otherwise, the secretPhrase has been inputted and this is
    // no longer active.
    pub struct Secret: ClaimProp {
        pub let type: ClaimPropType
        
        // A list of accounts to see who has put in a code.
        // Maps their address to the code they put in.
        access(contract) var accounts: {Address: String}
        // The secret code, set by the owner of this event.
        pub(set) var secretPhrase: String

        pub fun verify(accountAddr: Address, secret: String?): Bool {
            // The secretPhrase == "" if the Host hasn't input the code yet
            assert(
                self.secretPhrase != "" || secret != nil,
                message: "You must provide a secret phrase code to claim your FLOAT ahead of time."
            )

            // Return here because this means the Admin hasn't set the secret phrase yet
            // and the user is still guessing, so they shouldn't be getting any FLOATs.
            if self.secretPhrase == "" {
                self.accounts[accountAddr] = secret
                return false
            }
            assert(
                self.accounts[accountAddr] == self.secretPhrase, 
                message: "You did not guess the correct secret before the Host typed it in."
            )
            return true
        }

        init() {
            self.type = ClaimPropType.Secret

            self.accounts = {}
            self.secretPhrase = ""
        }
    }

    // If the maximum capacity is reached, this is no longer active.
    pub struct Limited: ClaimProp {
        pub let type: ClaimPropType
        
        // A list of accounts to get track on who is here first
        // Maps the position of who come first to their address.
        access(contract) var accounts: {UInt64: Address}
        pub(set) var capacity: UInt64

        pub fun verify(accountAddr: Address): Bool {
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
        pub fun createEvent(claimType: ClaimType, claimPropTypes: {ClaimPropType: Bool}, name: String, description: String, image: String, timePeriod: UFix64?, capacity: UInt64?, transferrable: Bool) {
            pre {
                self.events[name] == nil: 
                    "An event with this name already exists in your Collection."
            }

            let claimProps: {ClaimPropType: {ClaimProp}} = {}
            if claimPropTypes[ClaimPropType.Timelock] != nil && claimPropTypes[ClaimPropType.Timelock]! {
                assert(
                    timePeriod != nil, 
                    message: "You must provide a non-nil timePeriod if you wish to include the Timelock Prop."
                )
                claimProps[ClaimPropType.Timelock] = Timelock(_timePeriod: timePeriod!)
            } 
            
            if claimPropTypes[ClaimPropType.Secret] != nil && claimPropTypes[ClaimPropType.Secret]! {
                claimProps[ClaimPropType.Secret] = Secret()
            } 
            
            if claimPropTypes[ClaimPropType.Limited] != nil && claimPropTypes[ClaimPropType.Limited]! {
                assert(
                    capacity != nil, 
                    message: "You must provide a non-nil capacity if you wish to include the Limited Prop."
                )
                claimProps[ClaimPropType.Limited] = Limited(_capacity: capacity!)
            }

            let FLOATEvent = FLOATEventInfo(
                _claimType: claimType, 
                _claimPropTypes: claimProps, 
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
        // You can use this to change some properties of the 
        // ClaimPropTypes present in the event.
        //
        // Here's an example of the host of the `floatEvents: FLOATEvents` resource
        // changing the secretPhrase of one of their events 
        // let secret: &Secret = floatEvents
        //                            .getEventRef(name: "Town Hall #1")
        //                            .getClaimPropRef(claimPropType: ClaimPropType) as! &Secret
        // secret.secretPhrase = "My Secret Phrase"
        pub fun getEventRef(name: String): &FLOATEventInfo {
            return &self.events[name] as &FLOATEventInfo
        }

        // Return all the FLOATEvents you have ever created.
        pub fun getAllEvents(): {String: FLOATEventInfo} {
            return self.events
        }

        /*************************************** CLAIMING ***************************************/

        // This is for claiming `Admin` FLOAT Events.
        //
        // For giving out FLOATs when the FLOAT Event is `Admin` type.
        pub fun distributeDirectly(name: String, recipient: &Collection{NonFungibleToken.CollectionPublic} ) {
            pre {
                self.events[name] != nil:
                    "This event does not exist."
                self.events[name]!.claimType == ClaimType.Admin:
                    "This event is not an Admin type."
            }
            let FLOATEvent = self.getEventRef(name: name)
            FLOAT.mint(recipient: recipient, FLOATEvent: FLOATEvent)
        }

        // This is for claiming `Open`, `Timelock`, `Secret`, or `Limited` FLOAT Events.
        //
        // The `secret` parameter is only necessary if you're claiming a `Secret` FLOAT.
        pub fun claim(name: String, recipient: &Collection, secret: String?) {
            pre {
                self.getEvent(name: name).active: 
                    "This FLOATEvent is not active."
                self.events[name]!.claimType == ClaimType.Public:
                    "This event is not a Public type."
            }
            let FLOATEvent: &FLOATEventInfo = self.getEventRef(name: name)
            
            // If the FLOATEvent has the `Timelock` Prop
            if FLOATEvent.claimPropTypes.containsKey(ClaimPropType.Timelock) {
                let Timelock: &Timelock = FLOATEvent.getClaimPropRef(claimPropType: ClaimPropType.Timelock) as! &Timelock
                Timelock.verify()
            } 
            
            // If the FLOATEvent has the `Secret` Prop
            if FLOATEvent.claimPropTypes.containsKey(ClaimPropType.Secret) {
                let Secret: &Secret = FLOATEvent.getClaimPropRef(claimPropType: ClaimPropType.Secret) as! &Secret
                var keepGoing: Bool = true
                keepGoing = Secret.verify(accountAddr: recipient.owner!.address, secret: secret)
                if !keepGoing { return }
            }

            // If the FLOATEvent has the `Limited` Prop
            if FLOATEvent.claimPropTypes.containsKey(ClaimPropType.Limited){
                let Limited: &Limited = FLOATEvent.getClaimPropRef(claimPropType: ClaimPropType.Limited) as! &Limited
               Limited.verify(accountAddr: recipient.owner!.address)
            }

            // You have passed all the props (which act as restrictions).
            FLOAT.mint(recipient: recipient, FLOATEvent: FLOATEvent)
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

    // Helper function to mint FLOATs.
    access(account) fun mint(recipient: &Collection{NonFungibleToken.CollectionPublic}, FLOATEvent: &FLOATEventInfo) {
        pre {
            FLOATEvent.claimed[recipient.owner!.address] == nil:
                "This person already claimed their FLOAT!"
        }
        let serial: UInt64 = FLOATEvent.totalSupply

        let copiedStruct = FLOATEventInfo(
            _claimType: FLOATEvent.claimType, 
            _claimPropTypes: FLOATEvent.claimPropTypes, 
            _host: FLOATEvent.host, 
            _name: FLOATEvent.name, 
            _description: FLOATEvent.description, 
            _image: FLOATEvent.image, 
            _transferrable: FLOATEvent.transferrable
        )
        let token <- create NFT(_recipient: recipient.owner!.address, _serial: serial, _info: copiedStruct) 
        recipient.deposit(token: <- token)

        FLOATEvent.mintedFLOAT(to: recipient.owner!.address, serial: serial)
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