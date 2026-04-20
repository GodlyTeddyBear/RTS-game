--!strict

--[[
	BaseSlotService — shared slot-claim/release logic for all zone slot services.

	All three zone services (Mining, Forest, Garden) are structurally identical.
	This module contains the shared implementation. Concrete services set
	`self.SlotCalculator` in their `Init` method and inherit all behaviour via
	metatable delegation.

	Slot map structure:
	  self.SlotMap[userId][targetId][slotIndex] = workerId

	Collision box constants (character-sized 2×5×2, used for all zone types):
]]

local workspace = game:GetService("Workspace")

local WORKER_BOX_SIZE = Vector3.new(2, 5, 2)
local WORKER_BOX_HALF_HEIGHT = 2.5

local BaseSlotService = {}
BaseSlotService.__index = BaseSlotService

export type TBaseSlotService = typeof(setmetatable({} :: {
	SlotCalculator: any,
	SlotMap: { [number]: { [string]: { [number]: string } } },
}, BaseSlotService))

function BaseSlotService.new(): TBaseSlotService
	local self = setmetatable({}, BaseSlotService)
	self.SlotMap = {} :: { [number]: { [string]: { [number]: string } } }
	return self
end

--[[
	Claim the best available slot for a worker on a given target.
	- Releases any slot this worker previously held (supports re-assignment)
	- Iterates priority order; skips occupied or geometry-blocked slots
	- Falls back to center slot if all slots are unavailable
	Returns: (slotIndex: number, position: Vector3, lookAt: Vector3)
]]
function BaseSlotService:ClaimSlot(
	userId: number,
	workerId: string,
	targetId: string,
	targetCFrame: CFrame,
	targetModel: Instance
): (number, Vector3, Vector3)
	assert(self.SlotCalculator ~= nil, "SlotCalculator missing; ensure concrete slot service Init ran")
	self:_ReleaseWorkerSlotAny(userId, workerId)

	local candidates = self.SlotCalculator:GetCandidateSlots(targetCFrame)

	local chosenIndex: number? = nil
	local chosenPosition: Vector3? = nil
	local chosenLookAt: Vector3? = nil

	for _, candidate in ipairs(candidates) do
		local idx = candidate.SlotIndex

		if self:_IsSlotOccupied(userId, targetId, idx) then
			continue
		end

		if not self:_IsPositionClear(candidate.Position, targetModel) then
			continue
		end

		chosenIndex = idx
		chosenPosition = candidate.Position
		chosenLookAt = candidate.LookAt
		break
	end

	-- Graceful degradation: fall back to center slot
	if not chosenIndex then
		local centerIndex = self.SlotCalculator:GetCenterSlotIndex()
		local centerCandidate = self.SlotCalculator:GetSlotPosition(centerIndex, targetCFrame)
		chosenIndex = centerIndex
		chosenPosition = centerCandidate.Position
		chosenLookAt = centerCandidate.LookAt
	end

	-- Record the claim
	if not self.SlotMap[userId] then
		self.SlotMap[userId] = {}
	end
	if not self.SlotMap[userId][targetId] then
		self.SlotMap[userId][targetId] = {}
	end
	self.SlotMap[userId][targetId][chosenIndex :: number] = workerId

	return chosenIndex :: number, chosenPosition :: Vector3, chosenLookAt :: Vector3
end

--[[
	Release the slot held by a specific worker on a specific target.
	Safe to call even if the worker holds no slot.
]]
function BaseSlotService:ReleaseSlot(userId: number, workerId: string, targetId: string)
	local userMap = self.SlotMap[userId]
	if not userMap then return end
	local targetMap = userMap[targetId]
	if not targetMap then return end

	for slotIndex, owner in pairs(targetMap) do
		if owner == workerId then
			targetMap[slotIndex] = nil
			return
		end
	end
end

--[[
	Repopulate the slot tracker from persisted data on player rejoin.
	Does NOT run geometry checks — trusts the stored index.
]]
function BaseSlotService:RecoverSlot(userId: number, workerId: string, targetId: string, slotIndex: number)
	if not self.SlotMap[userId] then
		self.SlotMap[userId] = {}
	end
	if not self.SlotMap[userId][targetId] then
		self.SlotMap[userId][targetId] = {}
	end
	self.SlotMap[userId][targetId][slotIndex] = workerId
end

--[[
	Release all slot tracking for a user (called on player leave / lot cleanup).
]]
function BaseSlotService:ReleaseAllSlotsForUser(userId: number)
	self.SlotMap[userId] = nil
end

--[[
	Returns the number of workers currently occupying slots on a given target.
]]
function BaseSlotService:GetOccupiedSlotCount(userId: number, targetId: string): number
	local userMap = self.SlotMap[userId]
	if not userMap then return 0 end
	local targetMap = userMap[targetId]
	if not targetMap then return 0 end
	local count = 0
	for _ in pairs(targetMap) do
		count += 1
	end
	return count
end

--[[
	Returns the number of workers on a target excluding a specific worker id.
	Useful for assignment eligibility checks where "re-assign to same target"
	should not count the worker against max-capacity.
]]
function BaseSlotService:GetOccupiedSlotCountExcludingWorker(userId: number, targetId: string, excludedWorkerId: string): number
	local userMap = self.SlotMap[userId]
	if not userMap then return 0 end
	local targetMap = userMap[targetId]
	if not targetMap then return 0 end

	local count = 0
	for _, owner in pairs(targetMap) do
		if owner ~= excludedWorkerId then
			count += 1
		end
	end
	return count
end

-- Internal: release any slot this worker holds across all targets for this user
function BaseSlotService:_ReleaseWorkerSlotAny(userId: number, workerId: string)
	local userMap = self.SlotMap[userId]
	if not userMap then return end
	for _, targetMap in pairs(userMap) do
		for slotIndex, owner in pairs(targetMap) do
			if owner == workerId then
				targetMap[slotIndex] = nil
				return -- a worker can only hold one slot at a time
			end
		end
	end
end

-- Internal: check if a slot index is currently occupied by another worker
function BaseSlotService:_IsSlotOccupied(userId: number, targetId: string, slotIndex: number): boolean
	local userMap = self.SlotMap[userId]
	if not userMap then return false end
	local targetMap = userMap[targetId]
	if not targetMap then return false end
	return targetMap[slotIndex] ~= nil
end

--[[
	Internal: check if a candidate position is free of solid collidable geometry.
	Places a character-sized box (2×5×2) at the slot position raised by half-height,
	then filters out:
	  - Parts that are part of the target model itself
	  - Parts with CanCollide = false (decorations, sensors)
	Any remaining solid part means the slot is blocked.
]]
function BaseSlotService:_IsPositionClear(position: Vector3, targetModel: Instance): boolean
	local checkCFrame = CFrame.new(position + Vector3.new(0, WORKER_BOX_HALF_HEIGHT, 0))
	local parts = workspace:GetPartBoundsInBox(checkCFrame, WORKER_BOX_SIZE)

	for _, part in ipairs(parts) do
		if part:IsDescendantOf(targetModel) then
			continue
		end
		if not part.CanCollide then
			continue
		end
		return false
	end

	return true
end

return BaseSlotService
