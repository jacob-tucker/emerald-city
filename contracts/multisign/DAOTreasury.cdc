import MyMultiSig from "./MyMultiSig.cdc"
import FungibleToken from "./contracts/core/FungibleToken.cdc"

pub contract DAOTreasury {

  pub resource interface TreasuryPublic {
    pub fun proposeAction(intent: String, action: {MyMultiSig.Action})
    pub fun executeAction(actionUUID: UInt64)
    pub fun borrowManagerPublic(): &MyMultiSig.Manager{MyMultiSig.ManagerPublic}
  }

  pub resource Treasury: MyMultiSig.MultiSign, TreasuryPublic {
    pub let multiSignManager: @MyMultiSig.Manager
    access(account) var vaults: @{String: FungibleToken.Vault}

    // ------- Manager -------   
    pub fun proposeAction(intent: String, action: {MyMultiSig.Action}) {
      self.multiSignManager.createMultiSign(intent: intent, action: action)
    }

    pub fun executeAction(actionUUID: UInt64) {
      let action <- self.multiSignManager.executeAction(actionUUID: actionUUID)
      action.action.execute({"treasuryRef": &self as &Treasury})
      destroy action
    }

    pub fun borrowManager(): &MyMultiSig.Manager {
      return &self.multiSignManager as &MyMultiSig.Manager
    }

    pub fun borrowManagerPublic(): &MyMultiSig.Manager{MyMultiSig.ManagerPublic} {
      return &self.multiSignManager as &MyMultiSig.Manager{MyMultiSig.ManagerPublic}
    }

    // ------- Vaults ------- 
    pub fun depositVault(vault: @FungibleToken.Vault) {
      self.vaults[vault.getType().identifier] <-! vault
    }

    pub fun borrowVault(identifier: String): &FungibleToken.Vault {
      return &self.vaults[identifier] as &FungibleToken.Vault
    }

    init(_initialSigners: [Address]) {
      self.multiSignManager <- MyMultiSig.createMultiSigManager(signers: _initialSigners)
      self.vaults <- {}
    }

    destroy() {
      destroy self.multiSignManager
      destroy self.vaults
    }
  }

}