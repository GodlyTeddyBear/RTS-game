--!strict

local Types = require(script.Parent.Types)

type TQueryOptions = Types.TQueryOptions

--[=[
    @class SpatialQueryShared
    Internal shared helpers for `SpatialQuery` option normalization and distance math.
    @server
    @client
]=]

-- ── Constants ─────────────────────────────────────────────────────────────────

local Shared = {}

--[=[
    @prop EPSILON number
    @within SpatialQueryShared
    Small tolerance used to reject degenerate directions and zero-sized query inputs.
]=]
Shared.EPSILON = 1e-5

function Shared.CloneInstances(instances: { Instance }?): { Instance }?
	if instances == nil then
		return nil
	end

	local clone = table.create(#instances)
	for index, instance in ipairs(instances) do
		clone[index] = instance
	end

	return clone
end

function Shared.FreezeOptions(options: TQueryOptions?): TQueryOptions
	local frozenOptions: TQueryOptions = {}
	if options ~= nil then
		frozenOptions.FilterType = options.FilterType
		frozenOptions.FilterDescendantsInstances = Shared.CloneInstances(options.FilterDescendantsInstances)
		frozenOptions.CollisionGroup = options.CollisionGroup
		frozenOptions.IgnoreWater = options.IgnoreWater
		frozenOptions.RespectCanCollide = options.RespectCanCollide
		frozenOptions.MaxParts = options.MaxParts
	end

	return table.freeze(frozenOptions)
end

function Shared.IsPositiveNumber(value: number): boolean
	return value > 0 and value == value and value < math.huge
end

function Shared.IsPositiveVector(size: Vector3): boolean
	return Shared.IsPositiveNumber(size.X) and Shared.IsPositiveNumber(size.Y) and Shared.IsPositiveNumber(size.Z)
end

function Shared.GetDistanceSquared(a: Vector3, b: Vector3): number
	local delta = b - a
	return delta:Dot(delta)
end

function Shared.ResolveModelPosition(model: Model): Vector3
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart.Position
	end

	return model:GetPivot().Position
end

function Shared.ResolveAttachmentPosition(attachment: Attachment): Vector3
	return attachment.WorldPosition
end

function Shared.ResolvePositionIndices(positions: { Vector3 }): { number }
	local indices = table.create(#positions)
	for index = 1, #positions do
		indices[index] = index
	end
	return indices
end

return table.freeze(Shared)
