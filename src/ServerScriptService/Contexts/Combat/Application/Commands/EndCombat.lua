--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess
local Errors = require(script.Parent.Parent.Parent.Errors)
local BoidsHelper = require(script.Parent.Parent.Parent.Executors.Helpers.BoidsHelper)

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
	@class EndCombat
	Application command that ends a combat session.

	Orchestration order: stop loop → cleanup hitboxes → cleanup boids sessions →
	collect dead adventurer IDs → emit CombatEnded event.
	@server
]=]

export type TEndCombatResult = {
	DeadAdventurerIds: { string },
	Status: string,
}

local EndCombat = {}
EndCombat.__index = EndCombat

export type TEndCombat = typeof(setmetatable({}, EndCombat))

function EndCombat.new(): TEndCombat
	return setmetatable({}, EndCombat)
end

function EndCombat:Init(registry: any, _name: string)
	self.Registry = registry
	self.CombatLoopService = registry:Get("CombatLoopService")
	self.HitboxService = registry:Get("HitboxService")
end

function EndCombat:Start()
	self.NPCEntityFactory = self.Registry:Get("NPCEntityFactory")
end

--[=[
	End combat for a user and clean up all active resources.
	@within EndCombat
	@param userId number
	@param status string -- `"Victory"`, `"Defeat"`, or `"Fled"`
	@return Result.Result<TEndCombatResult>
]=]
function EndCombat:Execute(userId: number, status: string): Result.Result<TEndCombatResult>
	Ensure(userId ~= nil and userId > 0, "InvalidUserId", Errors.INVALID_USER_ID)

	-- Step 1: Stop the combat loop for this user
	self.CombatLoopService:StopCombat(userId)

	-- Step 2: Clean up active hitboxes
	if self.HitboxService then
		self.HitboxService:CleanupAll()
	end

	-- Step 3: Clean up active boids sessions
	BoidsHelper.CleanupAllSessions()

	-- Step 4: Collect dead adventurer IDs and emit completion event
	local deadAdventurerIds = self:_CollectDeadAdventurerIds(userId)
	GameEvents.Bus:Emit(Events.Combat.CombatEnded, userId, status, deadAdventurerIds)

	MentionSuccess(
		"Combat:EndCombat:StateChange",
		"userId: "
			.. userId
			.. " - Combat ended with status: "
			.. status
			.. ", dead adventurers: "
			.. #deadAdventurerIds
	)

	return Ok({
		DeadAdventurerIds = deadAdventurerIds,
		Status = status,
	})
end

-- Collects IDs of all dead adventurers at combat end. Used to notify dungeon context which members to mark as defeated.
function EndCombat:_CollectDeadAdventurerIds(userId: number): { string }
	local deadIds: { string } = {}
	local allEntities = self.NPCEntityFactory:QueryAllEntities(userId)

	for _, entity in ipairs(allEntities) do
		local identity = self.NPCEntityFactory:GetIdentity(entity)
		if identity and identity.IsAdventurer and not self.NPCEntityFactory:IsAlive(entity) then
			table.insert(deadIds, identity.NPCId)
		end
	end

	return deadIds
end

return EndCombat
