--!strict

local MapEntitySchema = {
	FeatureName = "Map",
	Components = {
		Root = {
			ECSName = "Map.Root",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				MapId = "",
				Template = "",
				CreatedAt = 0,
			},
		},
		Instance = {
			ECSName = "Map.Instance",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Model = nil,
			},
		},
		Zone = {
			ECSName = "Map.Zone",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				MapEntity = nil,
				ZoneName = "",
				Instance = nil,
			},
		},
		Spawn = {
			ECSName = "Map.Spawn",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Instance = nil,
			},
		},
		Base = {
			ECSName = "Map.Base",
			Authority = "AUTHORITATIVE",
			Replication = "ServerOnly",
			Default = {
				Instance = nil,
				Anchor = nil,
			},
		},
	},
	Tags = {
		ActiveMapTag = {
			Replication = "ServerOnly",
		},
		SpawnZoneTag = {
			Replication = "ServerOnly",
		},
		BaseZoneTag = {
			Replication = "ServerOnly",
		},
	},
	Archetypes = {
		Root = {
			Components = {
				Root = true,
				Instance = true,
			},
			Tags = {
				ActiveMapTag = true,
			},
		},
		Zone = {
			Components = {
				Zone = true,
			},
		},
		SpawnZone = {
			Extends = "Zone",
			Components = {
				Spawn = true,
			},
			Tags = {
				SpawnZoneTag = true,
			},
		},
		BaseZone = {
			Extends = "Root",
			Components = {
				Base = true,
			},
			Tags = {
				BaseZoneTag = true,
			},
		},
	},
}

return table.freeze(MapEntitySchema)
