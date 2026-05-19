--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActorRegistryBase = require(ReplicatedStorage.Utilities.ActorRegistryBase)

local TestRegistry = {}
TestRegistry.__index = TestRegistry
setmetatable(TestRegistry, ActorRegistryBase)

function TestRegistry.new()
	local self = ActorRegistryBase.new()
	return setmetatable(self, TestRegistry)
end

function TestRegistry:_ValidateActorTypePayload(_payload: any): any
	return nil
end

function TestRegistry:_ValidateActorPayload(_payload: any): any
	return nil
end

function TestRegistry:_BuildStoredActorTypePayload(payload: any): any
	return payload
end

function TestRegistry:_BuildRecordFromPayload(payload: any, runtimeId: number, _buildContext: any?): any
	return {
		RuntimeId = runtimeId,
		ActorType = payload.ActorType,
		ActorHandle = payload.ActorHandle,
		Active = payload.Active ~= false,
	}
end

function TestRegistry:_IsRecordActive(record: any): boolean
	return record.Active == true
end

function TestRegistry:GetCompiledBehaviorTree(_runtimeId: number): any?
	return nil
end

function TestRegistry:GetActionState(_runtimeId: number): any?
	return nil
end

function TestRegistry:SetActionState(_runtimeId: number, _actionState: any) end

function TestRegistry:ClearActionState(_runtimeId: number) end

function TestRegistry:SetPendingAction(_runtimeId: number, _actionId: string, _actionData: any?) end

function TestRegistry:UpdateLastTickTime(_runtimeId: number, _currentTime: number) end

function TestRegistry:ShouldEvaluate(_runtimeId: number, _currentTime: number): boolean
	return true
end

function TestRegistry:CancelActor(_runtimeId: number) end

local function registerActorType(registry: any, actorType: string)
	local result = registry:RegisterActorType({
		ActorType = actorType,
		Conditions = {},
		Commands = {},
		Executors = {},
	})

	expect(result.success).toBe(true)
end

local function registerActor(registry: any, actorType: string, actorHandle: string, active: boolean?): number
	local result = registry:RegisterActor({
		ActorType = actorType,
		ActorHandle = actorHandle,
		Active = active,
	}, nil)

	expect(result.success).toBe(true)

	local record = registry:GetRecordByHandle(actorHandle)
	expect(record).never.toBeNil()

	return record.RuntimeId
end

describe("ActorRegistryBase FIFO selection", function()
	it("only advances FIFO order after selected actors are explicitly marked serviced", function()
		local registry = TestRegistry.new()
		registerActorType(registry, "Enemy")

		for index = 1, 100 do
			registerActor(registry, "Enemy", ("Enemy-%d"):format(index))
		end

		local first = registry:ResolveSelectedBatchForTick(25, 1)
		for _, runtimeId in ipairs(first) do
			registry:MarkRuntimeIdServiced(runtimeId, 1)
		end
		local second = registry:ResolveSelectedBatchForTick(25, 2)
		for _, runtimeId in ipairs(second) do
			registry:MarkRuntimeIdServiced(runtimeId, 2)
		end
		local third = registry:ResolveSelectedBatchForTick(25, 3)
		for _, runtimeId in ipairs(third) do
			registry:MarkRuntimeIdServiced(runtimeId, 3)
		end
		local fourth = registry:ResolveSelectedBatchForTick(25, 4)
		for _, runtimeId in ipairs(fourth) do
			registry:MarkRuntimeIdServiced(runtimeId, 4)
		end
		local fifth = registry:ResolveSelectedBatchForTick(25, 5)

		expect(#first).toBe(25)
		expect(first[1]).toBe(1)
		expect(first[25]).toBe(25)
		expect(second[1]).toBe(26)
		expect(second[25]).toBe(50)
		expect(third[1]).toBe(51)
		expect(third[25]).toBe(75)
		expect(fourth[1]).toBe(76)
		expect(fourth[25]).toBe(100)
		expect(fifth[1]).toBe(1)
		expect(fifth[25]).toBe(25)
	end)

	it("reuses the cached batch for the same tick and appends new actors to the tail", function()
		local registry = TestRegistry.new()
		registerActorType(registry, "Enemy")

		for index = 1, 100 do
			registerActor(registry, "Enemy", ("Enemy-%d"):format(index))
		end

		local firstTickBatch = registry:ResolveSelectedBatchForTick(25, 1)
		local firstTickBatchAgain = registry:ResolveSelectedBatchForTick(25, 1)
		local newRuntimeId = registerActor(registry, "Enemy", "Enemy-101")

		expect(firstTickBatchAgain).toBe(firstTickBatch)
		expect(table.find(firstTickBatchAgain, newRuntimeId)).toBeNil()

		for _, runtimeId in ipairs(firstTickBatch) do
			registry:MarkRuntimeIdServiced(runtimeId, 1)
		end
		local secondTickBatch = registry:ResolveSelectedBatchForTick(25, 2)
		for _, runtimeId in ipairs(secondTickBatch) do
			registry:MarkRuntimeIdServiced(runtimeId, 2)
		end
		local thirdTickBatch = registry:ResolveSelectedBatchForTick(25, 3)
		for _, runtimeId in ipairs(thirdTickBatch) do
			registry:MarkRuntimeIdServiced(runtimeId, 3)
		end
		local fourthTickBatch = registry:ResolveSelectedBatchForTick(25, 4)
		for _, runtimeId in ipairs(fourthTickBatch) do
			registry:MarkRuntimeIdServiced(runtimeId, 4)
		end
		local fifthTickBatch = registry:ResolveSelectedBatchForTick(25, 5)

		expect(fifthTickBatch[1]).toBe(newRuntimeId)
	end)

	it("lazily prunes stale queue entries and keeps cursor progress stable", function()
		local registry = TestRegistry.new()
		registerActorType(registry, "Enemy")

		registerActor(registry, "Enemy", "Enemy-1")
		local removedRuntimeId = registerActor(registry, "Enemy", "Enemy-2")
		registerActor(registry, "Enemy", "Enemy-3")

		local unregisterResult = registry:UnregisterActor("Enemy-2")
		expect(unregisterResult.success).toBe(true)
		expect(registry._runtimeQueueMembership[removedRuntimeId]).toBe(true)

		local batch = registry:ResolveSelectedBatchForTick(3, 1)

		expect(#batch).toBe(2)
		expect(batch[1]).toBe(1)
		expect(batch[2]).toBe(3)
		expect(registry._runtimeQueueMembership[removedRuntimeId]).toBeNil()
		expect(registry._runtimeQueueCursor).toBe(1)
	end)

	it("skips inactive actors without removing them and can select them later", function()
		local registry = TestRegistry.new()
		registerActorType(registry, "Enemy")

		registerActor(registry, "Enemy", "Enemy-1", true)
		local inactiveRuntimeId = registerActor(registry, "Enemy", "Enemy-2", false)
		registerActor(registry, "Enemy", "Enemy-3", true)

		local firstBatch = registry:ResolveSelectedBatchForTick(2, 1)
		expect(firstBatch).toEqual({ 1, 3 })
		for _, runtimeId in ipairs(firstBatch) do
			registry:MarkRuntimeIdServiced(runtimeId, 1)
		end

		local inactiveRecord = registry:GetRecord(inactiveRuntimeId)
		expect(inactiveRecord).never.toBeNil()
		inactiveRecord.Active = true

		local secondBatch = registry:ResolveSelectedBatchForTick(2, 2)
		expect(secondBatch).toEqual({ 1, 2 })
	end)

	it("partitions one global batch by actor type without duplicate wrap selection", function()
		local registry = TestRegistry.new()
		registerActorType(registry, "Enemy")
		registerActorType(registry, "Structure")

		registerActor(registry, "Enemy", "Enemy-1")
		registerActor(registry, "Structure", "Structure-1")
		registerActor(registry, "Enemy", "Enemy-2")

		local globalBatch = registry:ResolveSelectedBatchForTick(25, 1)
		local enemyBatch = registry:GetSelectedRuntimeIdsForActorType("Enemy", 25, 1)
		local structureBatch = registry:GetSelectedRuntimeIdsForActorType("Structure", 25, 1)

		expect(globalBatch).toEqual({ 1, 2, 3 })
		expect(enemyBatch).toEqual({ 1, 3 })
		expect(structureBatch).toEqual({ 2 })
	end)

	it("clears queue state and selection cache on reset", function()
		local registry = TestRegistry.new()
		registerActorType(registry, "Enemy")
		registerActor(registry, "Enemy", "Enemy-1")

		registry:ResolveSelectedBatchForTick(25, 1)
		registry:ClearAll()

		expect(#registry._runtimeQueue).toBe(0)
		expect(next(registry._runtimeQueueMembership)).toBeNil()
		expect(registry._runtimeQueueCursor).toBe(1)
		expect(registry._selectedTickId).toBeNil()
		expect(#registry._selectedGlobalBatch).toBe(0)
		expect(next(registry._selectedByActorType)).toBeNil()
	end)

	it("keeps unserviced selected actors at the front for spillback on the next tick", function()
		local registry = TestRegistry.new()
		registerActorType(registry, "Enemy")

		for index = 1, 5 do
			registerActor(registry, "Enemy", ("Enemy-%d"):format(index))
		end

		local firstTickBatch = registry:ResolveSelectedBatchForTick(5, 1)
		expect(firstTickBatch).toEqual({ 1, 2, 3, 4, 5 })

		expect(registry:MarkRuntimeIdServiced(1, 1)).toBe(true)
		expect(registry:MarkRuntimeIdServiced(2, 1)).toBe(true)

		local secondTickBatch = registry:ResolveSelectedBatchForTick(5, 2)
		expect(secondTickBatch).toEqual({ 3, 4, 5, 1, 2 })
	end)
end)
