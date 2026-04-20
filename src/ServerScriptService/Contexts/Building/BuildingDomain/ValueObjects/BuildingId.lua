--!strict

--[=[
	@class BuildingId
	Generates immutable building identifiers scoped to player and incrementing counter.
	@server
]=]

--[=[
	@type TBuildingIdCounter { Value: number }
	@within BuildingId
]=]
type TBuildingIdCounter = { Value: number }

--[=[
	@interface TBuildingId
	@within BuildingId
	.GetId (self: TBuildingId) -> string -- Returns full unique building identifier.
	.GetUserId (self: TBuildingId) -> number -- Returns owning user ID.
	.GetCounter (self: TBuildingId) -> number -- Returns monotonic per-user counter value.
]=]
type TBuildingId = {
	GetId: (self: TBuildingId) -> string,
	GetUserId: (self: TBuildingId) -> number,
	GetCounter: (self: TBuildingId) -> number,
}

local BuildingId = {}
BuildingId.__index = BuildingId

-- Validate constructor invariants to prevent invalid IDs from entering persistence.
local function validate(userId: number, counter: number)
	assert(userId > 0, "BuildingId: userId must be positive")
	assert(counter > 0, "BuildingId: counter must be positive")
end

--[=[
	Create a new immutable building identifier from user and shared counter state.
	@within BuildingId
	@param userId number -- Owning player user ID.
	@param counter TBuildingIdCounter -- Mutable shared counter object.
	@return TBuildingId -- Frozen identifier value object.
]=]
function BuildingId.new(userId: number, counter: TBuildingIdCounter): TBuildingId
	counter.Value += 1
	validate(userId, counter.Value)

	local self = setmetatable({
		_id = string.format("Building_%d_%d", userId, counter.Value),
		_userId = userId,
		_counter = counter.Value,
	}, BuildingId)

	return table.freeze(self) :: TBuildingId
end

--[=[
	Get the full persisted building ID string.
	@within BuildingId
	@return string -- Composite identifier value.
]=]
function BuildingId:GetId(): string
	return self._id
end

--[=[
	Get the owner user ID component.
	@within BuildingId
	@return number -- Owning user ID.
]=]
function BuildingId:GetUserId(): number
	return self._userId
end

--[=[
	Get the monotonic counter component.
	@within BuildingId
	@return number -- Per-user building sequence value.
]=]
function BuildingId:GetCounter(): number
	return self._counter
end

return BuildingId
