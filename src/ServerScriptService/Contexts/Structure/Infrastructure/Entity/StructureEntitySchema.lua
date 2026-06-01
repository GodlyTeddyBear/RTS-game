--!strict

local StructureEntitySchema = {
	FeatureName = "Structure",
	Components = {
		Stats = {
			ECSName = "Structure.Stats",
			Authority = "AUTHORITATIVE",
			Default = {
				StructureType = "",
				RuntimeProfileId = "Passive",
				AttackRange = 0,
				AttackDamage = 0,
				AttackCooldown = 0,
				LastAttackAt = 0,
				StasisRadius = 0,
				MoveSpeedMultiplier = 1,
			},
		},
		Construction = {
			ECSName = "Structure.Construction",
			Authority = "AUTHORITATIVE",
			Default = {
				CurrentWork = 0,
				RequiredWork = 0,
			},
		},
		SourcePlacement = {
			ECSName = "Structure.SourcePlacement",
			Authority = "AUTHORITATIVE",
			Default = {
				InstanceId = 0,
				OwnerUserId = 0,
				WorldPos = Vector3.zero,
				RotationQuarterTurns = 0,
				ResourceType = nil,
			},
		},
		AnimationState = {
			ECSName = "Structure.AnimationState",
			Authority = "DERIVED",
			Default = "Idle",
		},
		AnimationLooping = {
			ECSName = "Structure.AnimationLooping",
			Authority = "DERIVED",
			Default = true,
		},
		TargetEnemyId = {
			ECSName = "Structure.TargetEnemyId",
			Authority = "DERIVED",
			Default = nil,
		},
		BuildContributionState = {
			ECSName = "Structure.BuildContributionState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "BuildStructure",
				SourceEntity = 0,
				TargetStructureEntity = nil,
				RequestedAt = 0,
				StartedAt = 0,
				UpdatedAt = nil,
				Status = "Started",
			},
		},
		ExtractState = {
			ECSName = "Structure.ExtractState",
			Authority = "AUTHORITATIVE",
			Default = {
				ActionId = "Extract",
				SourceEntity = 0,
				InstanceId = nil,
				RequestedAt = 0,
				StartedAt = 0,
				UpdatedAt = nil,
				Status = "Started",
			},
		},
	},
	Tags = {
		PlacedTag = {},
		UnderConstructionTag = {},
		OperationalTag = {},
		TargetableTag = {},
	},
	Archetypes = {
		Actor = {
			Extends = "Entity.Targetable",
			Components = {
				Stats = true,
				Construction = true,
				SourcePlacement = true,
				AnimationState = true,
				AnimationLooping = true,
				TargetEnemyId = true,
				ExtractState = true,
			},
			Tags = {
				PlacedTag = true,
				UnderConstructionTag = true,
				TargetableTag = true,
			},
		},
	},
}

return table.freeze(StructureEntitySchema)
