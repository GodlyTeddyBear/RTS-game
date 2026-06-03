--!strict

local MiningEntitySchema = {
	FeatureName = "Mining",
	Components = {
		Extractor = {
			ECSName = "Mining.Extractor",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				InstanceId = 0,
				OwnerUserId = 0,
				ResourceType = "",
				AmountPerCycle = 0,
			},
		},
		ExtractorTiming = {
			ECSName = "Mining.ExtractorTiming",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				IntervalSeconds = 0,
				ElapsedSeconds = 0,
			},
		},
		ResourceNode = {
			ECSName = "Mining.ResourceNode",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				NodeId = "",
				ResourceType = "",
			},
		},
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
		ExtractorActiveTag = {
			Replication = "ServerOnly",
		},
		ResourceNodeTag = {
			Replication = "ServerOnly",
		},
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
		Extractor = {
			Components = {
				Extractor = true,
				ExtractorTiming = true,
			},
			Tags = {
				ExtractorActiveTag = true,
			},
		},
		ResourceNode = {
			Components = {
				ResourceNode = true,
			},
			Tags = {
				ResourceNodeTag = true,
			},
		},
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
