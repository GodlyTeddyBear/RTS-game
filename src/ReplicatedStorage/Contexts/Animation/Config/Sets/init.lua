--!strict

local Types = require(script.Parent.Parent.Types.AnimationTypes)

type TAnimationSet = Types.TAnimationSet

local Sets: { [string]: TAnimationSet } = {
	HumanoidCommon = table.freeze({
		Id = "HumanoidCommon",
		Slots = table.freeze({
			Idle = "shared/humanoid/common/idle",
			Walk = "shared/humanoid/common/walk",
			Run = "shared/humanoid/common/run",
			Jump = "shared/humanoid/common/jump",
			Fall = "shared/humanoid/common/fall",
			Climb = "shared/humanoid/common/climb",
			Sit = "shared/humanoid/common/sit",
			Emote = "shared/humanoid/common/dance",
		}),
	}),
	Player = table.freeze({
		Id = "Player",
		Extends = table.freeze({ "HumanoidCommon" }),
		Slots = table.freeze({
			Action = "shared/humanoid/combat/attack",
			FullBodyAction = "shared/humanoid/combat/attack",
		}),
	}),
	CombatNPC = table.freeze({
		Id = "CombatNPC",
		Extends = table.freeze({ "HumanoidCommon" }),
		Slots = table.freeze({
			Action = "shared/humanoid/combat/attack",
			Attack = "shared/humanoid/combat/attack",
			FullBodyAction = "shared/humanoid/combat/attack",
			Build = "shared/humanoid/combat/build",
		}),
	}),
	EnemyLocomotion = table.freeze({
		Id = "EnemyLocomotion",
		Extends = table.freeze({ "CombatNPC" }),
		Slots = table.freeze({
			Attack = "shared/humanoid/combat/attackstructure",
			Action = "shared/humanoid/combat/attackstructure",
			FullBodyAction = "shared/humanoid/combat/attackstructure",
		}),
	}),
	Structure = table.freeze({
		Id = "Structure",
		Slots = table.freeze({
			Idle = "shared/structure/idle",
			Action = "shared/structure/attack",
			FullBodyAction = "shared/structure/attack",
			Attack = "shared/structure/attack",
			Extract = "shared/structure/extract",
			Stasis = "shared/structure/stasis",
		}),
		Variants = table.freeze({
			SentryTurret = table.freeze({
				Idle = "structures/sentryturret/idle",
				Action = "structures/sentryturret/attack",
				FullBodyAction = "structures/sentryturret/attack",
				Attack = "structures/sentryturret/attack",
			}),
			Extractor = table.freeze({
				Idle = "structures/extractor/idle",
				Extract = "structures/extractor/extract",
			}),
			StasisField = table.freeze({
				Idle = "structures/stasisfield/idle",
				Stasis = "structures/stasisfield/stasis",
			}),
			ArcPylon = table.freeze({
				Idle = "structures/arcpylon/idle",
			}),
			BulwarkProjector = table.freeze({
				Idle = "structures/bulwarkprojector/idle",
			}),
			RelayBeacon = table.freeze({
				Idle = "structures/relaybeacon/idle",
			}),
		}),
	}),
}

return table.freeze(Sets)
