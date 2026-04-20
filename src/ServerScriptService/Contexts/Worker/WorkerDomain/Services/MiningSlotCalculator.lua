--!strict

--[[
	Mining Slot Calculator - Domain Service

	Pure math service that generates radial mining slot positions around an ore.
	No Roblox service dependencies — only takes CFrame input and returns Vector3 values.

	Slot layout (7 positions, 30° apart, semicircle in front of ore):
	  Physical index:  0     1     2     3(center)  4     5     6
	  Angle offset:  -90°  -60°  -30°    0°        +30°  +60°  +90°

	Priority order (center-first, fanning outward):
	  3 → 2 → 4 → 1 → 5 → 0 → 6
]]

local MiningSlotCalculator = {}
MiningSlotCalculator.__index = MiningSlotCalculator

local SLOT_RADIUS = 7 -- studs from ore center to slot
local SLOT_COUNT = 7 -- total candidate slots
local ANGLE_STEP_DEG = 30 -- degrees between slots
local CENTER_INDEX = 3 -- physical index of the center (0°) slot
local SPAWN_Y_OFFSET = 3 -- studs above ore pivot to spawn worker

-- Priority order: center first, then alternating left/right outward
local PRIORITY_ORDER: { number } = { 3, 2, 4, 1, 5, 0, 6 }

export type TSlotCandidate = {
	SlotIndex: number,
	Position: Vector3,
	LookAt: Vector3,
}

export type TMiningSlotCalculator = typeof(setmetatable({}, MiningSlotCalculator))

function MiningSlotCalculator.new(): TMiningSlotCalculator
	local self = setmetatable({}, MiningSlotCalculator)
	return self
end

--[[
	Compute the world position and look-at point for a single slot index.
	SlotIndex 0-6, where 3 is directly in front of the ore.
]]
function MiningSlotCalculator:GetSlotPosition(slotIndex: number, oreCFrame: CFrame): TSlotCandidate
	local angleRad = math.rad((slotIndex - CENTER_INDEX) * ANGLE_STEP_DEG)
	local forward = oreCFrame.LookVector
	local right = oreCFrame.RightVector
	local oreCenter = oreCFrame.Position

	local dir = (forward * math.cos(angleRad)) + (right * math.sin(angleRad))
	local position = oreCenter + dir * SLOT_RADIUS + Vector3.new(0, SPAWN_Y_OFFSET, 0)

	return {
		SlotIndex = slotIndex,
		Position = position,
		LookAt = oreCenter,
	}
end

--[[
	Returns all 7 candidate slots in priority order (center first, fanning outward).
	Each entry: { SlotIndex: number, Position: Vector3, LookAt: Vector3 }
]]
function MiningSlotCalculator:GetCandidateSlots(oreCFrame: CFrame): { TSlotCandidate }
	local candidates: { TSlotCandidate } = {}
	for _, slotIndex in ipairs(PRIORITY_ORDER) do
		table.insert(candidates, self:GetSlotPosition(slotIndex, oreCFrame))
	end
	return candidates
end

--[[
	Returns the center slot index constant (index 3).
	Used by MiningSlotService for graceful fallback.
]]
function MiningSlotCalculator:GetCenterSlotIndex(): number
	return CENTER_INDEX
end

--[[
	Returns the total number of slots.
]]
function MiningSlotCalculator:GetSlotCount(): number
	return SLOT_COUNT
end

return MiningSlotCalculator
