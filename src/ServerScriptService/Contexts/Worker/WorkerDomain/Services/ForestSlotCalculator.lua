--!strict

--[[
	Forest Slot Calculator - Domain Service

	Pure math service that generates radial slot positions around a tree.
	No Roblox service dependencies — only takes CFrame input and returns Vector3 values.

	Mirrors MiningSlotCalculator exactly; only constants differ.

	Slot layout (7 positions, 30° apart, semicircle in front of tree):
	  Physical index:  0     1     2     3(center)  4     5     6
	  Angle offset:  -90°  -60°  -30°    0°        +30°  +60°  +90°

	Priority order (center-first, fanning outward):
	  3 → 2 → 4 → 1 → 5 → 0 → 6
]]

local ForestSlotCalculator = {}
ForestSlotCalculator.__index = ForestSlotCalculator

local SLOT_RADIUS = 7 -- studs from tree center to slot
local SLOT_COUNT = 7 -- total candidate slots
local ANGLE_STEP_DEG = 30 -- degrees between slots
local CENTER_INDEX = 3 -- physical index of the center (0°) slot
local SPAWN_Y_OFFSET = 3 -- studs above tree pivot to spawn worker

-- Priority order: center first, then alternating left/right outward
local PRIORITY_ORDER: { number } = { 3, 2, 4, 1, 5, 0, 6 }

export type TSlotCandidate = {
	SlotIndex: number,
	Position: Vector3,
	LookAt: Vector3,
}

export type TForestSlotCalculator = typeof(setmetatable({}, ForestSlotCalculator))

function ForestSlotCalculator.new(): TForestSlotCalculator
	return setmetatable({}, ForestSlotCalculator)
end

--[[
	Compute the world position and look-at point for a single slot index.
	SlotIndex 0-6, where 3 is directly in front of the tree.
]]
function ForestSlotCalculator:GetSlotPosition(slotIndex: number, treeCFrame: CFrame): TSlotCandidate
	local angleRad = math.rad((slotIndex - CENTER_INDEX) * ANGLE_STEP_DEG)
	local forward = treeCFrame.LookVector
	local right = treeCFrame.RightVector
	local treeCenter = treeCFrame.Position

	local dir = (forward * math.cos(angleRad)) + (right * math.sin(angleRad))
	local position = treeCenter + dir * SLOT_RADIUS + Vector3.new(0, SPAWN_Y_OFFSET, 0)

	return {
		SlotIndex = slotIndex,
		Position = position,
		LookAt = treeCenter,
	}
end

--[[
	Returns all 7 candidate slots in priority order (center first, fanning outward).
	Each entry: { SlotIndex: number, Position: Vector3, LookAt: Vector3 }
]]
function ForestSlotCalculator:GetCandidateSlots(treeCFrame: CFrame): { TSlotCandidate }
	local candidates: { TSlotCandidate } = {}
	for _, slotIndex in ipairs(PRIORITY_ORDER) do
		table.insert(candidates, self:GetSlotPosition(slotIndex, treeCFrame))
	end
	return candidates
end

--[[
	Returns the center slot index constant (index 3).
	Used by ForestSlotService for graceful fallback.
]]
function ForestSlotCalculator:GetCenterSlotIndex(): number
	return CENTER_INDEX
end

--[[
	Returns the total number of slots.
]]
function ForestSlotCalculator:GetSlotCount(): number
	return SLOT_COUNT
end

return ForestSlotCalculator
