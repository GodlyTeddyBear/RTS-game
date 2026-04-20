--!strict

--[=[
	@class DestroyDungeon
	Application command: orchestrates dungeon cleanup, teleportation, and state removal.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Errors = require(script.Parent.Parent.Parent.Errors)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Err, Try = Result.Ok, Result.Err, Result.Try
local fromNilable = Result.fromNilable
local MentionSuccess = Result.MentionSuccess

local DestroyDungeon = {}
DestroyDungeon.__index = DestroyDungeon

export type TDestroyDungeon = typeof(setmetatable({}, DestroyDungeon))

function DestroyDungeon.new(): TDestroyDungeon
	local self = setmetatable({}, DestroyDungeon)
	return self
end

function DestroyDungeon:Init(registry: any)
	self._registry = registry
	self.DungeonSyncService = registry:Get("DungeonSyncService")
	self.DungeonInstanceService = registry:Get("DungeonInstanceService")
end

function DestroyDungeon:Start()
	self.LotContext = self._registry:Get("LotContext")
end

--[=[
	Execute dungeon destruction: cleanup instances, remove state, teleport player back, emit events.
	@within DestroyDungeon
	@param player Player? -- The player to teleport (may be nil on disconnect)
	@param userId number -- The player's user ID
	@return Result<nil> -- Success indicator, or error
]=]
function DestroyDungeon:Execute(player: Player?, userId: number): Result.Result<nil>
	-- Layer 1: Check if dungeon exists (skip validation on disconnect — just cleanup)
	local hasInstance = self.DungeonInstanceService:HasActiveDungeon(userId)
	local hasState = self.DungeonSyncService:HasActiveDungeon(userId)

	if not hasInstance and not hasState then
		-- Nothing to clean up
		return Ok(nil)
	end

	-- Layer 2: Destroy all dungeon instances
	self.DungeonInstanceService:DestroyDungeon(userId)

	-- Layer 3: Remove sync state
	self.DungeonSyncService:RemoveDungeonState(userId)

	-- Layer 4: Teleport player back to lot (only if player is still connected)
	if player and player.Parent then
		local lotCFrame = Try(fromNilable(
			self.LotContext:GetLotSpawnPosition(userId),
			"LotPositionNotFound",
			Errors.LOT_POSITION_NOT_FOUND,
			{ userId = userId }
		))
		self:_TeleportPlayerToLot(player, lotCFrame)
	end

	-- Layer 5: Fire cleanup event
	GameEvents.Bus:Emit(Events.Dungeon.DungeonCleanedUp, userId)
	MentionSuccess("Dungeon:DestroyDungeon:Execute", "Destroyed dungeon state and emitted cleanup event", {
		userId = userId,
	})

	return Ok(nil)
end

-- Teleport player to their lot spawn position, offset upward to prevent clipping
function DestroyDungeon:_TeleportPlayerToLot(player: Player, lotCFrame: CFrame)
	local character = player.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return
	end

	-- Offset slightly upward to prevent clipping
	humanoidRootPart.CFrame = lotCFrame + Vector3.new(0, 3, 0)
end

return DestroyDungeon
