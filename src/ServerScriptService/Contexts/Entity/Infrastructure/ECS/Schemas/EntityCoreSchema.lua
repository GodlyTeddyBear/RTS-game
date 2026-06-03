--!strict

local EntityCoreSchema = {
	FeatureName = "Entity",
	Components = {
		Identity = {
			ECSName = "Entity.Identity",
			Authority = "AUTHORITATIVE",
			Default = {
				EntityId = "",
				EntityKind = "",
				DefinitionId = nil,
			},
		},
		Ownership = {
			ECSName = "Entity.Ownership",
			Authority = "AUTHORITATIVE",
			Default = {
				Faction = nil,
				OwnerKind = nil,
				OwnerId = nil,
			},
		},
		Transform = {
			ECSName = "Entity.Transform",
			Authority = "DERIVED",
			Default = {
				CFrame = CFrame.identity,
			},
		},
		Health = {
			ECSName = "Entity.Health",
			Authority = "AUTHORITATIVE",
			Default = {
				Current = 0,
				Max = 0,
			},
		},
		Lifetime = {
			ECSName = "Entity.Lifetime",
			Authority = "AUTHORITATIVE",
			Default = {
				SpawnedAt = 0,
				ExpiresAt = nil,
			},
		},
		Target = {
			ECSName = "Entity.Target",
			Authority = "AUTHORITATIVE",
			Default = {
				TargetEntity = nil,
				TargetKind = nil,
			},
		},
		ModelRef = {
			ECSName = "Entity.ModelRef",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Model = nil,
			},
		},
		ModelAsset = {
			ECSName = "Entity.ModelAsset",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				AssetDomain = "",
				AssetId = "",
				AssetKind = "Model",
			},
		},
		ModelBinding = {
			ECSName = "Entity.ModelBinding",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				ParentFolder = "",
				SetupProfileId = "",
				RevealTag = "EntityActor",
				NameFormat = nil,
			},
		},
		HumanoidProjection = {
			ECSName = "Entity.HumanoidProjection",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Enabled = false,
				Health = true,
				WalkSpeed = true,
			},
		},
		TransformProjection = {
			ECSName = "Entity.TransformProjection",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Enabled = true,
			},
		},
		TransformPoll = {
			ECSName = "Entity.TransformPoll",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Enabled = false,
			},
		},
		CleanupOutcomes = {
			ECSName = "Entity.CleanupOutcomes",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				OutcomeIds = {},
			},
		},
		CleanupOutcomeRequest = {
			ECSName = "Entity.CleanupOutcomeRequest",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				SourceEntity = nil,
				OutcomeId = "",
				CreatedAt = 0,
				Status = "Requested",
			},
		},
		HealthDepletedOutcome = {
			ECSName = "Entity.HealthDepletedOutcome",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				OutcomeId = nil,
			},
		},
		GoalReachedOutcome = {
			ECSName = "Entity.GoalReachedOutcome",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				OutcomeId = nil,
			},
		},
		ReplicationPolicy = {
			ECSName = "Entity.ReplicationPolicy",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Mode = "Default",
			},
		},
	},
	Tags = {
		ActiveTag = {},
		DirtyTag = {},
		CleanupRequestTag = {
			Replication = "ServerOnly",
		},
		CleanupProcessedTag = {
			Replication = "ServerOnly",
		},
		CleanupFailedTag = {
			Replication = "ServerOnly",
		},
	},
	Archetypes = {
		Core = {
			Components = {
				Identity = true,
				Transform = true,
			},
			Tags = {
				ActiveTag = true,
			},
		},
		Actor = {
			Extends = "Core",
			Components = {
				Health = true,
				ModelRef = true,
				ModelAsset = true,
				ModelBinding = true,
				HumanoidProjection = true,
				TransformProjection = true,
				TransformPoll = true,
				CleanupOutcomes = true,
				HealthDepletedOutcome = true,
				GoalReachedOutcome = true,
				ReplicationPolicy = true,
			},
		},
		OwnedActor = {
			Extends = "Actor",
			Components = {
				Ownership = true,
			},
		},
		Targetable = {
			Extends = "Actor",
			Components = {
				Target = true,
			},
		},
		Timed = {
			Extends = "Core",
			Components = {
				Lifetime = true,
			},
		},
		CleanupRequest = {
			Components = {
				CleanupOutcomeRequest = true,
			},
			Tags = {
				CleanupRequestTag = true,
			},
		},
	},
}

return table.freeze(EntityCoreSchema)
