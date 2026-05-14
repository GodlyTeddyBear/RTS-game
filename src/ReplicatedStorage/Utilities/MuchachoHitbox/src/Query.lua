--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox

local Query = {}

local function buildQueryOptionsFromOverlapParams(overlapParams: OverlapParams)
	return SpatialQuery.CreateOverlapOptions({
		FilterType = overlapParams.FilterType,
		FilterDescendantsInstances = overlapParams.FilterDescendantsInstances,
		CollisionGroup = overlapParams.CollisionGroup,
		RespectCanCollide = overlapParams.RespectCanCollide,
		MaxParts = overlapParams.MaxParts,
	})
end

function Query.CastSpatialQuery(hitbox: THitbox, hitboxCFrame: CFrame): { BasePart }
	local queryOptions = buildQueryOptionsFromOverlapParams(hitbox.OverlapParams)

	if hitbox.Shape == Enum.PartType.Block then
		return SpatialQuery.OverlapBox(hitboxCFrame, hitbox.Size :: Vector3, queryOptions)
	end

	if hitbox.Shape == Enum.PartType.Ball then
		return SpatialQuery.OverlapRadius(hitboxCFrame.Position, hitbox.Size :: any, queryOptions)
	end

	error("Part type: " .. tostring(hitbox.Shape) .. " isn't compatible with MuchachoHitbox")
end

return Query
