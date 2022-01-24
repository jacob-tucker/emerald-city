import Reputation from 0x01

// Get your total reputation ever

pub fun main(account: Address): {UInt64: Reputation.Skills} {

  let identityPublic = getAccount(account).getCapability(Reputation.IdentityPublicPath)
                                    .borrow<&Reputation.Identity{Reputation.IdentityPublic}>()
                                    ?? panic("Could not borrow the public Identity.")
  return identityPublic.getReputation()

}
