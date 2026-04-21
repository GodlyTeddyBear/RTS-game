--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BehaviorConfig = require(ReplicatedStorage.Contexts.Combat.Config.BehaviorConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure

--[=[
	@class StartCombat
	Begins combat and assigns behavior trees to alive enemies.
	@server
]=]
local StartCombat = {}
StartCombat.__index = StartCombat

-- Creates a new combat-start command.
function StartCombat.new()
	return setmetatable({}, StartCombat)
end

-- Resolves the combat loop and enemy infrastructure dependencies.
function StartCombat:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._behaviorTreeFactory = registry:Get("BehaviorTreeFactory")
end

function StartCombat:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
end

-- Builds and stores the role-specific behavior tree for one enemy entity.
function StartCombat:_AssignBehaviorTree(entity: number)
	local role = self._enemyEntityFactory:GetRole(entity)
	local roleName = if role and role.role then role.role else "swarm"
	local tree = self._behaviorTreeFactory:CreateTree(roleName)

	local roleDefaults = BehaviorConfig.DEFAULTS_BY_ROLE[roleName] or BehaviorConfig.DEFAULT
	local tickInterval = roleDefaults.TickInterval

	self._enemyEntityFactory:SetBehaviorTree(entity, tree, tickInterval)
	self._enemyEntityFactory:SetBehaviorConfig(entity, {
		TickInterval = tickInterval,
	})
	self._enemyEntityFactory:ClearAction(entity)
end

-- Validates the wave start, activates combat for the primary player, and assigns trees to existing enemies.
function StartCombat:Execute(waveNumber: number, isEndless: boolean): Result.Result<boolean>
	return Result.Catch(function()
		-- Guard the wave number before any combat state changes happen.
		Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)

		-- Resolve the primary player so the loop service can key the combat session.
		local players = Players:GetPlayers()
		local primaryPlayer = players[1]
		Ensure(primaryPlayer ~= nil, "MissingPrimaryPlayer", Errors.MISSING_PRIMARY_PLAYER)

		-- Start the active session before existing enemies begin ticking.
		self._loopService:StartCombat(primaryPlayer.UserId, waveNumber, isEndless)

		-- Backfill behavior trees for enemies that already exist when the wave starts.
		local aliveEntities = self._enemyEntityFactory:QueryAliveEntities()
		for _, entity in ipairs(aliveEntities) do
			self:_AssignBehaviorTree(entity)
		end

		return Ok(true)
	end, "Combat:StartCombat")
end

return StartCombat
