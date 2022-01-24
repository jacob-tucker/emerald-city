import Reputation from 0x01

// Get reputation during specific season for a specific skill

pub fun main(account: Address, season: UInt64, skill: String): UFix64 {

  let identityPublic = getAccount(account).getCapability(Reputation.IdentityPublicPath)
                                    .borrow<&Reputation.Identity{Reputation.IdentityPublic}>()
                                    ?? panic("Could not borrow the public Identity.")
  return identityPublic.getSpecificSkillInSeason(season: season, skill: skill)

}
