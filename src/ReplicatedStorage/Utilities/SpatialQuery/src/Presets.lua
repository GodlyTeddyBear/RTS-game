--!strict

local Options = require(script.Parent.Options)

--[=[
    @class SpatialQueryPresets
    Reusable frozen option presets for common `SpatialQuery` filter configurations.
    @server
    @client
]=]

-- ── Public ────────────────────────────────────────────────────────────────────

local Presets = {
	--[=[
        @prop WorldOnly table
        @within SpatialQueryPresets
        Raycast options that leave world collision behavior intact.
    ]=]
	WorldOnly = Options.Create({
		IgnoreWater = false,
		RespectCanCollide = true,
	}),
	--[=[
        @prop CharactersOnly table
        @within SpatialQueryPresets
        Raycast options that include only selected character instances.
    ]=]
	CharactersOnly = Options.Create({
		FilterType = Enum.RaycastFilterType.Include,
		RespectCanCollide = false,
		IgnoreWater = true,
	}),
	--[=[
        @prop ExcludeInstance function
        @within SpatialQueryPresets
        Builds exclude options for a single instance.
    ]=]
	ExcludeInstance = function(instance: Instance)
		return Options.WithExcludedInstances({ instance })
	end,
	--[=[
        @prop ExcludeModel function
        @within SpatialQueryPresets
        Builds exclude options for a single model.
    ]=]
	ExcludeModel = function(model: Model)
		return Options.WithExcludedInstances({ model })
	end,
	--[=[
        @prop IncludeInstances function
        @within SpatialQueryPresets
        Builds include options for the supplied instance list.
    ]=]
	IncludeInstances = function(instances: { Instance })
		return Options.WithIncludedInstances(instances)
	end,
}

return table.freeze(Presets)
