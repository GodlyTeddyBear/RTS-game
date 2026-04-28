--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
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

--[=[
	@within StartCombat
	Creates a new combat-start command.
	@return StartCombat -- Command instance used to begin combat sessions.
]=]
function StartCombat.new()
	return setmetatable({}, StartCombat)
end

--[=[
	@within StartCombat
	Resolves the combat loop and enemy infrastructure dependencies.
	@param registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function StartCombat:Init(registry: any, _name: string)
	self._loopService = registry:Get("CombatLoopService")
	self._behaviorRuntimeService = registry:Get("CombatBehaviorRuntimeService")
	self._lockOnService = registry:Get("LockOnService")
end

--[=[
	@within StartCombat
	Stores the enemy entity factory needed to backfill existing enemies.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the command.
]=]
function StartCombat:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
end

-- Builds and stores the role-specific behavior tree for one enemy entity.
function StartCombat:_AssignBehaviorTree(entity: number)
	-- Resolve the enemy's role so the runtime can pick the correct behavior tree.
	local role = self._enemyEntityFactory:GetRole(entity)
	local roleName = if role and role.Role then role.Role else "Swarm"
	local tree, tickInterval = self._behaviorRuntimeService:BuildEnemyBehaviorTree(roleName)

	-- Replace any stale combat state before the entity re-enters the tick loop.
	self._enemyEntityFactory:SetBehaviorTree(entity, tree, tickInterval)
	self._enemyEntityFactory:SetBehaviorConfig(entity, {
		TickInterval = tickInterval,
	})
	self._enemyEntityFactory:ClearAction(entity)
	self._enemyEntityFactory:ClearTarget(entity)

	-- Reattach lock-on so newly started combat faces the current target immediately.
	self._lockOnService:AttachConstraint(entity)
end

function StartCombat:_AssignStructureBehaviorTree(entity: number)
	-- Build the shared structure behavior tree once per active structure.
	local tree, tickInterval = self._behaviorRuntimeService:BuildStructureBehaviorTree()

	-- Clear stale action state before the structure resumes combat ticks.
	self._structureEntityFactory:SetBehaviorTree(entity, tree, tickInterval)
	self._structureEntityFactory:ClearAction(entity)
end

--[=[
	@within StartCombat
	Validates the wave start, activates combat for the primary player, and assigns trees to existing enemies.
	@param waveNumber number -- Wave number being started.
	@param isEndless boolean -- Whether the run is in endless mode.
	@return Result.Result<boolean> -- Success confirmation or a typed combat error.
]=]
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

		-- Apply the same combat tree setup to structures so both actor types enter the wave together.
		local activeStructures = self._structureEntityFactory:QueryActiveEntities()
		for _, entity in ipairs(activeStructures) do
			self:_AssignStructureBehaviorTree(entity)
		end

		return Ok(true)
	end, "Combat:StartCombat")
end

return StartCombat
