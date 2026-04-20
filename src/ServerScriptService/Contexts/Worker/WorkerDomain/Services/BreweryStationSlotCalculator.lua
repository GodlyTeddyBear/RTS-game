--!strict

local BreweryStationSlotCalculator = {}
BreweryStationSlotCalculator.__index = BreweryStationSlotCalculator

local SLOT_RADIUS = 6
local SLOT_COUNT = 5
local ANGLE_STEP_DEG = 35
local CENTER_INDEX = 2
local SPAWN_Y_OFFSET = 3

local PRIORITY_ORDER: { number } = { 2, 1, 3, 0, 4 }

export type TSlotCandidate = {
	SlotIndex: number,
	Position: Vector3,
	LookAt: Vector3,
}

export type TBreweryStationSlotCalculator = typeof(setmetatable({}, BreweryStationSlotCalculator))

function BreweryStationSlotCalculator.new(): TBreweryStationSlotCalculator
	return setmetatable({}, BreweryStationSlotCalculator)
end

function BreweryStationSlotCalculator:GetSlotPosition(slotIndex: number, stationCFrame: CFrame): TSlotCandidate
	local angleRad = math.rad((slotIndex - CENTER_INDEX) * ANGLE_STEP_DEG)
	local forward = stationCFrame.LookVector
	local right = stationCFrame.RightVector
	local center = stationCFrame.Position
	local dir = (forward * math.cos(angleRad)) + (right * math.sin(angleRad))
	local position = center + dir * SLOT_RADIUS + Vector3.new(0, SPAWN_Y_OFFSET, 0)

	return {
		SlotIndex = slotIndex,
		Position = position,
		LookAt = center,
	}
end

function BreweryStationSlotCalculator:GetCandidateSlots(stationCFrame: CFrame): { TSlotCandidate }
	local candidates: { TSlotCandidate } = {}
	for _, slotIndex in PRIORITY_ORDER do
		table.insert(candidates, self:GetSlotPosition(slotIndex, stationCFrame))
	end
	return candidates
end

function BreweryStationSlotCalculator:GetCenterSlotIndex(): number
	return CENTER_INDEX
end

function BreweryStationSlotCalculator:GetSlotCount(): number
	return SLOT_COUNT
end

return BreweryStationSlotCalculator
