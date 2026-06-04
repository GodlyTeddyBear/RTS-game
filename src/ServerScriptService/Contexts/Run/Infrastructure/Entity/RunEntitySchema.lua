--!strict

local RunEntitySchema = {
	FeatureName = "Run",
	Components = {
		FailureRequest = {
			ECSName = "Run.FailureRequest",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				SourceEntity = nil,
				OutcomeId = "",
				Reason = "",
				EmitEvent = nil,
				CreatedAt = 0,
				ExpiresAt = nil,
				Status = "Requested",
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
		FailureRequest = {
			Components = {
				FailureRequest = true,
			},
			Tags = {
				RequestTag = true,
			},
		},
	},
}

return table.freeze(RunEntitySchema)
