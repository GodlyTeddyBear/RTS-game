--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local UnitSelectionTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitSelectionTypes)

type TSelectableUnitRecord = UnitSelectionTypes.TSelectableUnitRecord

local SELECTION_CLICK_MAX_DISTANCE = 100

local ResolveOwnedUnitSelectionFromCharacterClickQuery = {}
ResolveOwnedUnitSelectionFromCharacterClickQuery.__index = ResolveOwnedUnitSelectionFromCharacterClickQuery

local function _ResolveCharacterRoot(character: Model): BasePart?
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart ~= nil and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	local primaryPart = character.PrimaryPart
	if primaryPart ~= nil then
		return primaryPart
	end

	return nil
end

function ResolveOwnedUnitSelectionFromCharacterClickQuery.new(resolveOwnedUnitSelectionQuery: any)
	local self = setmetatable({}, ResolveOwnedUnitSelectionFromCharacterClickQuery)
	self._resolveOwnedUnitSelectionQuery = resolveOwnedUnitSelectionQuery
	return self
end

function ResolveOwnedUnitSelectionFromCharacterClickQuery:Execute(mouseSnapshot: any): TSelectableUnitRecord?
	if mouseSnapshot == nil or mouseSnapshot.WorldPoint == nil then
		return nil
	end

	local localPlayer = Players.LocalPlayer
	if localPlayer == nil then
		return nil
	end

	local character = localPlayer.Character
	if character == nil then
		return nil
	end

	local characterRoot = _ResolveCharacterRoot(character)
	if characterRoot == nil then
		return nil
	end

	local clickDelta = mouseSnapshot.WorldPoint - characterRoot.Position
	local clickDistance = math.min(clickDelta.Magnitude, SELECTION_CLICK_MAX_DISTANCE)
	if clickDistance <= 0 then
		return nil
	end

	local hit = SpatialQuery.Raycast(
		characterRoot.Position,
		clickDelta.Unit * clickDistance,
		SpatialQuery.CreateRaycastOptions({
			FilterType = Enum.RaycastFilterType.Exclude,
			FilterDescendantsInstances = { character },
		})
	)
	if hit == nil then
		return nil
	end

	local resolvedTarget = SelectionPlus.ResolveTargetFromHit(hit)
	if resolvedTarget == nil then
		return nil
	end

	return self._resolveOwnedUnitSelectionQuery:Execute(resolvedTarget)
end

return ResolveOwnedUnitSelectionFromCharacterClickQuery
