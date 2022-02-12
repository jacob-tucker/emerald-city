//  ____   ____ _   _ __  __  ___  _____ ____  
// / ___| / ___| | | |  \/  |/ _ \| ____/ ___| 
// \___ \| |   | |_| | |\/| | | | |  _| \___ \ 
//  ___) | |___|  _  | |  | | |_| | |___ ___) |
// |____/ \____|_| |_|_|  |_|\___/|_____|____/ 
// 
// Made by amit @ zay.codes
//

import NonFungibleToken from "../NonFungibleToken.cdc"
import Crypto

pub contract ZayVerifierV2 {

    // Returns timestamp of the last sealed block for when this signature was created
    // If the signature is invalid, returns nil.
    pub fun verifySignature(acctAddress: Address, message: String, keyIds: [Int], signatures: [String], signatureBlock: UInt64, intent: String, identifier: String): UFix64? {
        // Creates an empty KeyList to add to
        let keyList = Crypto.KeyList()

        // An array of straight up public keys
        //
        // WHY DO WE NEED THIS?
        // To append to `keyList`
        let rawPublicKeys: [String] = []
        // An array of weights
        // 
        // WHY DO WE NEED THIS?
        // In order to determine total key weight, and also add the 
        // weight for each KeyListEntry when we add to `keyList`
        let weights: [UFix64] = []
        // An array of signature algorithms
        //
        // WHY DO WE NEED THIS?
        // To append to `keyList`
        let signAlgos: [UInt] = []

        // Dictionary of keyIds that signed the message on the front end.
        let uniqueKeys: {Int: Bool} = {}
        let account = getAccount(acctAddress)
        
        for id in keyIds {
            uniqueKeys[id] = true
        }

        assert(uniqueKeys.keys.length == keyIds.length, message: "Invalid duplicates of the same keyID provided for signature")

        var counter = 0
        while (counter < keyIds.length) {
            /*
            struct AccountKey {
                let keyIndex: Int
                let publicKey: PublicKey
                let hashAlgorithm: HashAlgorithm
                let weight: UFix64
                let isRevoked: Bool
            }
            */
            // Get the key associated `AccountKey` with that keyId
            let accountKey: AccountKey = account.keys.get(keyIndex: keyIds[counter]) ?? panic("Provided key signature does not exist")
            
            /*
            struct PublicKey {
                let publicKey: [UInt8]
                let signatureAlgorithm: SignatureAlgorithm
                let isValid: Bool

                /// Verifies a signature under the given tag, data and public key.
                /// It uses the given hash algorithm to hash the tag and data.
                pub fun verify(
                    signature: [UInt8],
                    signedData: [UInt8],
                    domainSeparationTag: String,
                    hashAlgorithm: HashAlgorithm
                ): Bool
            }
            */
            // This is the actual public key string
            // QUESTION: Why do we encode here just to decode later?
            let rawPublicKey: String = String.encodeHex(accountKey.publicKey.publicKey)
            rawPublicKeys.append(rawPublicKey)
            // Get the weight associated with that accountKey
            weights.append(accountKey.weight)
            // Gets the signatureAlgorithm rawValue since it's an enum.
            signAlgos.append(UInt(accountKey.publicKey.signatureAlgorithm.rawValue))
            counter = counter + 1
        }

        // Since we need this weight for the transaction to go through
        var totalWeight = 0.0
        var weightIndex = 0
        while (weightIndex < weights.length) {
            totalWeight = totalWeight + weights[weightIndex]
            weightIndex = weightIndex + 1
        }
        // Why 999 instead of 1000? Blocto currently signs with a 999 weight key sometimes for non-custodial blocto accounts.
        // We would like to support these non-custodial Blocto wallets - but can be switched to 1000 weight when Blocto updates this.
        assert(totalWeight >= 999.0, message: "Total weight of combined signatures did not satisfy 999 requirement.")

        // This is all for the account
        var i = 0
        for rawPublicKey in rawPublicKeys {
            // We are adding to the empty keyList
            /*
             pub fun add(
                _ publicKey: PublicKey,
                hashAlgorithm: HashAlgorithm,
                weight: UFix64
             )
            */
            keyList.add(
                PublicKey(
                    publicKey: rawPublicKey.decodeHex(),
                    signatureAlgorithm: signAlgos[i] == 2 ? SignatureAlgorithm.ECDSA_secp256k1  : SignatureAlgorithm.ECDSA_P256
                ),
                hashAlgorithm: HashAlgorithm.SHA3_256,
                weight: weights[i]
            )
            i = i + 1
        }

        // In verify we need a [KeyListSignature] so we do that here
        let signatureSet: [Crypto.KeyListSignature] = []
        var j = 0
        for signature in signatures {
            signatureSet.append(
                Crypto.KeyListSignature(
                    keyIndex: j,
                    signature: signature.decodeHex()
                )
            )
            j = j + 1
        }

        var signingBlockHashStr = ""
        counter = 0
        // Takes the height of the latest block and gets the block
        /*
        pub struct Block {
            /// The ID of the block.
            pub let id: [UInt8; 32]

            /// The height of the block.
            pub let height: UInt64

            ...
        }
        */
        let signingBlock = getBlock(at: signatureBlock)!
        let id = signingBlock.id
        // QUESTION: Why don't you just say `let ids = id`
        let ids: [UInt8] = []
        while (counter < id.length) {
            ids.append(id[counter])
            counter = counter + 1
        }
        let intentHex = String.encodeHex(intent.utf8)
        let identifierHex = String.encodeHex(identifier.utf8)
        let hexStr = String.encodeHex(ids)

        // The provided signed message should be made up in the following format:
        // {intentHex}{identifierHex}{hexStr}

        assert(intentHex == message.slice(from: 0, upTo: intentHex.length), message: "Failed to validate intent")
        assert(identifierHex == message.slice(from: intentHex.length, upTo: intentHex.length + identifierHex.length), message: "Failed to validate identifier")
        assert(hexStr == message.slice(from: intentHex.length + identifierHex.length, upTo: message.length), message: "Unable to validate signature provided contained a valid block id.")

        // signedData is supposed to be [UInt8] of the message
        // The data we're supposed to be verifying out signatures against.
        // On the front end, we signed a message and got back signatures. We're verifying
        // that here.
        let signedData = message.decodeHex()
        /*
        pub fun verify(
            signatureSet: [KeyListSignature],
            signedData: [UInt8]
        ): Bool
        */
        let signatureValid = keyList.verify(
            signatureSet: signatureSet,
            signedData: signedData
        )
        if (signatureValid) {
            return signingBlock.timestamp
        } else {
            return nil
        }
    }

    pub fun checkOwnership(
        address: Address,
        collectionPath: PublicPath,
        nftType: Type
    ): Bool {
        let collectionRef = getAccount(address).getCapability<&{NonFungibleToken.CollectionPublic}>(collectionPath).borrow()
        if collectionRef == nil {
            return false
        }
        let ids = collectionRef!.getIDs()
        var index = 0
        while (index < ids.length) {
            // Borrow the NFT, and ensure it is the proper type
            let id = ids[index]
            let nft = collectionRef!.borrowNFT(id: id)
            if (nft.isInstance(nftType)) {
                return true
            }
            index = index + 1
        }
        return false
    }
}