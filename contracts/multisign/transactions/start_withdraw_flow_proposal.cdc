import MyMultiSig from "../MyMultiSig.cdc"
import DAOTreasury from "../DAOTreasury.cdc"
import FlowToken from "../contracts/core/FlowToken.cdc"
import FungibleToken from "../contracts/core/FungibleToken.cdc"

transaction(treasuryAccount: Address, recipient: Address, amount: UFix64) {
  let Treasury: &DAOTreasury.Treasury{DAOTreasury.TreasuryPublic}
  let RecipientVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
  prepare(signer: AuthAccount) {
    self.Treasury = getAccount(treasuryAccount).getCapability(/public/DAOTreasury)
                      .borrow<&DAOTreasury.Treasury{DAOTreasury.TreasuryPublic}>()
                      ?? panic("Could no find this DAOTreasury")
    self.RecipientVault = getAccount(recipient).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
  }
  execute {
    self.Treasury.proposeAction(
      intent: "Transfer `amount` FlowTokens out of the DAOTreasury owned by `treasuryAccount` to the `recipient`.", 
      action: Action(_recipientVault: self.RecipientVault, _amount: amount)
    )
  }
}

pub struct Action: MyMultiSig.Action {
  pub let recipientVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>
  pub let amount: UFix64

  pub fun execute(_ params: {String: AnyStruct}) {
    let treasuryRef: &DAOTreasury.Treasury = params["treasuryRef"] as! &DAOTreasury.Treasury
    let vaultType: String = FlowToken.Vault.getType().identifier

    let vaultRef: &FungibleToken.Vault = treasuryRef.borrowVault(identifier: vaultType)
    let withdrawnTokens <- vaultRef.withdraw(amount: self.amount)
    self.recipientVault.borrow()!.deposit(from: <- withdrawnTokens)
  }

  init(_recipientVault: Capability<&FlowToken.Vault{FungibleToken.Receiver}>, _amount: UFix64) {
    self.recipientVault = _recipientVault
    self.amount = _amount
  }
}