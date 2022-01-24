import Reputation from 0x01

// Get reputation during specific season

pub fun main(account: Address, season: UInt64): Reputation.Skills {

  let identityPublic = getAccount(account).getCapability(Reputation.IdentityPublicPath)
                                    .borrow<&Reputation.Identity{Reputation.IdentityPublic}>()
                                    ?? panic("Could not borrow the public Identity.")
  return identityPublic.getReputationInSeason(season: season)

}
