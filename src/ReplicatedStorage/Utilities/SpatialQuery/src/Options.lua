--!strict

local Shared = require(script.Parent.Shared)
local Types = require(script.Parent.Types)

type TQueryOptions = Types.TQueryOptions

--[=[
    @class SpatialQueryOptions
    Normalizes spatial query configuration into Roblox `RaycastParams` and `OverlapParams`.
    @server
    @client
]=]

-- ── Public ────────────────────────────────────────────────────────────────────

local Options = {}

--[=[
    Creates a frozen copy of a query options table.
    @within SpatialQueryOptions
    @param spec TQueryOptions? -- Query configuration to normalize.
    @return TQueryOptions -- Frozen normalized options.
]=]
function Options.Create(spec: TQueryOptions?): TQueryOptions
	return Shared.FreezeOptions(spec)
end

--[=[
    Merges two query options tables into one frozen copy.
    @within SpatialQueryOptions
    @param baseOptions TQueryOptions? -- Base options applied first.
    @param overrideOptions TQueryOptions? -- Override options applied last.
    @return TQueryOptions -- Frozen merged options.
]=]
function Options.Merge(baseOptions: TQueryOptions?, overrideOptions: TQueryOptions?): TQueryOptions
	local mergedOptions: TQueryOptions = {}
	if baseOptions ~= nil then
		mergedOptions.FilterType = baseOptions.FilterType
		mergedOptions.FilterDescendantsInstances = Shared.CloneInstances(baseOptions.FilterDescendantsInstances)
		mergedOptions.CollisionGroup = baseOptions.CollisionGroup
		mergedOptions.IgnoreWater = baseOptions.IgnoreWater
		mergedOptions.RespectCanCollide = baseOptions.RespectCanCollide
		mergedOptions.MaxParts = baseOptions.MaxParts
	end

	if overrideOptions ~= nil then
		if overrideOptions.FilterType ~= nil then
			mergedOptions.FilterType = overrideOptions.FilterType
		end
		if overrideOptions.FilterDescendantsInstances ~= nil then
			mergedOptions.FilterDescendantsInstances = Shared.CloneInstances(overrideOptions.FilterDescendantsInstances)
		end
		if overrideOptions.CollisionGroup ~= nil then
			mergedOptions.CollisionGroup = overrideOptions.CollisionGroup
		end
		if overrideOptions.IgnoreWater ~= nil then
			mergedOptions.IgnoreWater = overrideOptions.IgnoreWater
		end
		if overrideOptions.RespectCanCollide ~= nil then
			mergedOptions.RespectCanCollide = overrideOptions.RespectCanCollide
		end
		if overrideOptions.MaxParts ~= nil then
			mergedOptions.MaxParts = overrideOptions.MaxParts
		end
	end

	return table.freeze(mergedOptions)
end

--[=[
    Creates an options table that excludes the given instances from raycast queries.
    @within SpatialQueryOptions
    @param instances { Instance } -- Instances to exclude from the query.
    @return TQueryOptions -- Frozen exclude options.
]=]
function Options.WithExcludedInstances(instances: { Instance }): TQueryOptions
	return Options.Create({
		FilterType = Enum.RaycastFilterType.Exclude,
		FilterDescendantsInstances = instances,
	})
end

--[=[
    Creates an options table that includes only the given instances in raycast queries.
    @within SpatialQueryOptions
    @param instances { Instance } -- Instances to include in the query.
    @return TQueryOptions -- Frozen include options.
]=]
function Options.WithIncludedInstances(instances: { Instance }): TQueryOptions
	return Options.Create({
		FilterType = Enum.RaycastFilterType.Include,
		FilterDescendantsInstances = instances,
	})
end

--[=[
    Creates an options table that targets the specified collision group.
    @within SpatialQueryOptions
    @param name string -- Collision group name.
    @return TQueryOptions -- Frozen collision-group options.
]=]
function Options.WithCollisionGroup(name: string): TQueryOptions
	return Options.Create({
		CollisionGroup = name,
	})
end

--[=[
    Builds a `RaycastParams` instance from normalized query options.
    @within SpatialQueryOptions
    @param options TQueryOptions? -- Query configuration to apply.
    @return RaycastParams -- Configured raycast parameters.
]=]
function Options.BuildRaycastParams(options: TQueryOptions?): RaycastParams
	local raycastParams = RaycastParams.new()
	if options == nil then
		return raycastParams
	end

	if options.FilterType ~= nil then
		raycastParams.FilterType = options.FilterType
	end
	if options.FilterDescendantsInstances ~= nil then
		raycastParams.FilterDescendantsInstances = Shared.CloneInstances(options.FilterDescendantsInstances)
	end
	if options.CollisionGroup ~= nil then
		raycastParams.CollisionGroup = options.CollisionGroup
	end
	if options.IgnoreWater ~= nil then
		raycastParams.IgnoreWater = options.IgnoreWater
	end
	if options.RespectCanCollide ~= nil then
		raycastParams.RespectCanCollide = options.RespectCanCollide
	end

	return raycastParams
end

--[=[
    Builds an `OverlapParams` instance from normalized query options.
    @within SpatialQueryOptions
    @param options TQueryOptions? -- Query configuration to apply.
    @return OverlapParams -- Configured overlap parameters.
]=]
function Options.BuildOverlapParams(options: TQueryOptions?): OverlapParams
	local overlapParams = OverlapParams.new()
	if options == nil then
		return overlapParams
	end

	if options.FilterType ~= nil then
		overlapParams.FilterType = options.FilterType
	end
	if options.FilterDescendantsInstances ~= nil then
		overlapParams.FilterDescendantsInstances = Shared.CloneInstances(options.FilterDescendantsInstances)
	end
	if options.CollisionGroup ~= nil then
		overlapParams.CollisionGroup = options.CollisionGroup
	end
	if options.RespectCanCollide ~= nil then
		overlapParams.RespectCanCollide = options.RespectCanCollide
	end
	if options.MaxParts ~= nil and options.MaxParts >= 0 then
		overlapParams.MaxParts = options.MaxParts
	end

	return overlapParams
end

return table.freeze(Options)
