import Crypto
import FungibleToken from "./contracts/core/FungibleToken.cdc"

pub contract MyMultiSig {

    //
    // ------- Resource Interfaces ------- 
    //

    pub resource interface MultiSign {
        pub let multiSignManager: @Manager
    }

    //
    // ------- Action Wrapper ------- 
    //

    pub struct interface Action {
        pub fun execute(_ params: {String: AnyStruct})
    }

    //
    // ------- Resources ------- 
    //

    pub resource MultiSignAction {

        pub var totalVerified: Int
        pub var accountsVerified: {Address: Bool}
        pub let intent: String
        pub let action: {Action}

        // ZayVerifierv2 - verifySignature
        //
        // Explanation: 
        // Verifies that `acctAddress` is the one that signed the `message` (producing `signatures`) 
        // with the `keyIds` (that are hopefully in its account, or its false) during `signatureBlock`
        //
        // Parameters:
        // acctAddress: the address of the account we're verifying
        // message: {blockId}{uuid of this resource}
        // keyIds: the keyIds that the acctAddress theoretically signed with
        // signatures: the signature that was theoretically produced from the `acctAddress` signing `message` with `keyIds`.
        // can be multiple because you can sign with multiple keys, thus creating multiple signatures.
        // signatureBlock: when the signature was produced
        //
        // Returns:
        // Whether or not this signature is valid
        pub fun verifySignature(acctAddress: Address, message: String, keyIds: [Int], signatures: [String], signatureBlock: UInt64): Bool {
            pre {
                self.accountsVerified[acctAddress] != nil:
                    "This address is not allowed to sign for this."
                !self.accountsVerified[acctAddress]!:
                    "This address has already signed."
            }
            // Creates an empty KeyList to add to
            let keyList = Crypto.KeyList()
            let account = getAccount(acctAddress)

            // Really important that we keep these all in order
            let publicKeys: [[UInt8]] = []
            let weights: [UFix64] = []
            let signAlgos: [UInt] = []
            
            // --- Makes sure the keyIds are unique --- //
            let uniqueKeys: {Int: Bool} = {}
            for id in keyIds {
                uniqueKeys[id] = true
            }
            assert(uniqueKeys.keys.length == keyIds.length, message: "Invalid duplicates of the same keyID provided for signature")
            // ---------------------------------------- //

            var counter = 0
            var totalWeight = 0.0
            while (counter < keyIds.length) {
                // Get the key associated `AccountKey`/`KeyListEntry` with that keyId
                let accountKey: AccountKey = account.keys.get(keyIndex: keyIds[counter]) ?? panic("Provided key signature does not exist")
                
                publicKeys.append(accountKey.publicKey.publicKey)
                let keyWeight = accountKey.weight
                weights.append(keyWeight)
                totalWeight = totalWeight + keyWeight

                // Note on rawValue:
                // 1 == ECDSA_P256
                // 2 == ECDSA_secp256k1
                signAlgos.append(UInt(accountKey.publicKey.signatureAlgorithm.rawValue))

                counter = counter + 1
            }

            // Why 999 instead of 1000? Blocto currently signs with a 999 weight key sometimes for non-custodial blocto accounts.
            // We would like to support these non-custodial Blocto wallets - but can be switched to 1000 weight when Blocto updates this.
            assert(totalWeight >= 999.0, message: "Total weight of combined signatures did not satisfy 999 requirement.")

            var i = 0
            for publicKey in publicKeys {
                keyList.add(
                    PublicKey(
                        publicKey: publicKey,
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

            counter = 0
            let signingBlock = getBlock(at: signatureBlock)!
            let blockId = signingBlock.id
            // The format of `blockId` is a fixed-sized array
            // so have to adapt here by populating blockIds
            // with the same info
            let blockIds: [UInt8] = []
            while (counter < blockId.length) {
                blockIds.append(blockId[counter])
                counter = counter + 1
            }
            let blockIdHexStr: String = String.encodeHex(blockIds)
          
            // message: {uuid of this resource}{intent}{blockId}
            let uuidString = self.uuid.toString()

            // Matches the `uuid` of this resource
            assert(uuidString == message.slice(from: 0, upTo: uuidString.length), message: "This signature is not for the current block id")
            // Matches the `intent` of this resource
            assert(self.intent == message.slice(from: uuidString.length, upTo: uuidString.length + self.intent.length))
            // Ensure that the message passed in is of the current block id...
            assert(blockIdHexStr == message.slice(from: uuidString.length + self.intent.length, upTo: message.length), message: "You did not sign for this MultiSign")

            let signatureValid = keyList.verify(
                signatureSet: signatureSet,
                signedData: message.decodeHex()
            )
            if (signatureValid) {
                self.accountsVerified[acctAddress] = true
                self.totalVerified = self.totalVerified + 1
                return true
            } else {
                return false
            }
        }

        pub fun readyToExecute(): Bool {
            return self.totalVerified == self.accountsVerified.keys.length
        }

        init(_signers: [Address], _intent: String, _action: {Action}) {
            self.totalVerified = 0
            self.accountsVerified = {}
            self.intent = _intent
            self.action = _action
            
            for signer in _signers {
                self.accountsVerified[signer] = false
            }
        }
    }

    pub resource interface ManagerPublic {
        pub fun borrowAction(actionUUID: UInt64): &MultiSignAction
        pub fun getIDs(): [UInt64]
        pub fun getIntent(actionUUID: UInt64): String
    }
    
    pub resource Manager: ManagerPublic {
        pub let signers: {Address: Bool}

        // Maps the `uuid` of the MultiSignAction
        // to the resource itself
        access(self) var actions: @{UInt64: MultiSignAction}

        pub fun createMultiSign(intent: String, action: {Action}) {
            let newAction <- create MultiSignAction(_signers: self.signers.keys, _intent: intent, _action: action)
            self.actions[newAction.uuid] <-! newAction
        }

        pub fun addSigner(signer: Address) {
            self.signers.insert(key: signer, true)
        }

        pub fun removeSigner(signer: Address) {
            self.signers.remove(key: signer)
        }

        pub fun removeAction(actionUUID: UInt64) {
            let removedAction <- self.actions.remove(key: actionUUID) ?? panic("This action does not exist.")
            destroy removedAction
        }

        pub fun readyToExecute(actionUUID: UInt64): Bool {
            let actionRef: &MultiSignAction = &self.actions[actionUUID] as &MultiSignAction
            return actionRef.readyToExecute()
        }

        pub fun executeAction(actionUUID: UInt64): @MultiSignAction {
            pre {
                self.readyToExecute(actionUUID: actionUUID):
                    "This action has not received a signature from every signer yet."
            }
            
            let action <- self.actions.remove(key: actionUUID) ?? panic("This action does not exist.")
            return <- action
        }

        pub fun borrowAction(actionUUID: UInt64): &MultiSignAction {
            return &self.actions[actionUUID] as &MultiSignAction
        }

        pub fun getIDs(): [UInt64] {
            return self.actions.keys
        }

        pub fun getIntent(actionUUID: UInt64): String {
            let actionRef: &MultiSignAction = &self.actions[actionUUID] as &MultiSignAction
            return actionRef.intent
        }

        init(_initialSigners: [Address]) {
            self.signers = {}
            self.actions <- {}

            for signer in _initialSigners {
                self.signers.insert(key: signer, true)
            }
        }

        destroy() {
            destroy self.actions
        }
    }

    // 
    // ------- Functions --------
    //
        
    pub fun createMultiSigManager(signers: [Address]): @Manager {
        return <- create Manager(_initialSigners: signers)
    }
}