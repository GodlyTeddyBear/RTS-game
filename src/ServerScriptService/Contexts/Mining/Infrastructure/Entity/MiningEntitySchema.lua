--!strict

local MiningEntitySchema = {
	FeatureName = "Mining",
	Components = {
		ExtractWorkRequest = {
			ECSName = "Mining.ExtractWorkRequest",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				SourceEntity = 0,
				InstanceId = 0,
				DeltaTime = 0,
				CreatedAt = 0,
				Status = "Requested",
				FailureReason = nil,
			},
		},
	},
	Tags = {
		RequestTag = {
			Replication = "ServerOnly",
		},
		ProcessedTag = {
			Replication = "ServerOnly",
		},
		FailedTag = {
			Replication = "ServerOnly",
		},
	},
	Archetypes = {
		ExtractWorkRequest = {
			Components = {
				ExtractWorkRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
	},
}

return table.freeze(MiningEntitySchema)
