--!strict

--[[
	Garden Slot Calculator - Domain Service

	Pure math service that generates radial slot positions around a plant.
	No Roblox service dependencies — only takes CFrame input and returns Vector3 values.

	Mirrors ForestSlotCalculator exactly; only constants differ.

	Slot layout (7 positions, 30° apart, semicircle in front of plant):
	  Physical index:  0     1     2     3(center)  4     5     6
	  Angle offset:  -90°  -60°  -30°    0°        +30°  +60°  +90°

	Priority order (center-first, fanning outward):
	  3 → 2 → 4 → 1 → 5 → 0 → 6
]]

local GardenSlotCalculator = {}
GardenSlotCalculator.__index = GardenSlotCalculator

local SLOT_RADIUS = 5 -- studs from plant center to slot (plants are smaller than trees)
local SLOT_COUNT = 7 -- total candidate slots
local ANGLE_STEP_DEG = 30 -- degrees between slots
local CENTER_INDEX = 3 -- physical index of the center (0°) slot
local SPAWN_Y_OFFSET = 2 -- studs above plant pivot to spawn worker

-- Priority order: center first, then alternating left/right outward
local PRIORITY_ORDER: { number } = { 3, 2, 4, 1, 5, 0, 6 }

export type TSlotCandidate = {
	SlotIndex: number,
	Position: Vector3,
	LookAt: Vector3,
}

export type TGardenSlotCalculator = typeof(setmetatable({}, GardenSlotCalculator))

function GardenSlotCalculator.new(): TGardenSlotCalculator
	return setmetatable({}, GardenSlotCalculator)
end

--[[
	Compute the world position and look-at point for a single slot index.
	SlotIndex 0-6, where 3 is directly in front of the plant.
]]
function GardenSlotCalculator:GetSlotPosition(slotIndex: number, plantCFrame: CFrame): TSlotCandidate
	local angleRad = math.rad((slotIndex - CENTER_INDEX) * ANGLE_STEP_DEG)
	local forward = plantCFrame.LookVector
	local right = plantCFrame.RightVector
	local plantCenter = plantCFrame.Position

	local dir = (forward * math.cos(angleRad)) + (right * math.sin(angleRad))
	local position = plantCenter + dir * SLOT_RADIUS + Vector3.new(0, SPAWN_Y_OFFSET, 0)

	return {
		SlotIndex = slotIndex,
		Position = position,
		LookAt = plantCenter,
	}
end

--[[
	Returns all 7 candidate slots in priority order (center first, fanning outward).
	Each entry: { SlotIndex: number, Position: Vector3, LookAt: Vector3 }
]]
function GardenSlotCalculator:GetCandidateSlots(plantCFrame: CFrame): { TSlotCandidate }
	local candidates: { TSlotCandidate } = {}
	for _, slotIndex in ipairs(PRIORITY_ORDER) do
		table.insert(candidates, self:GetSlotPosition(slotIndex, plantCFrame))
	end
	return candidates
end

--[[
	Returns the center slot index constant (index 3).
	Used by GardenSlotService for graceful fallback.
]]
function GardenSlotCalculator:GetCenterSlotIndex(): number
	return CENTER_INDEX
end

--[[
	Returns the total number of slots.
]]
function GardenSlotCalculator:GetSlotCount(): number
	return SLOT_COUNT
end

return GardenSlotCalculator
