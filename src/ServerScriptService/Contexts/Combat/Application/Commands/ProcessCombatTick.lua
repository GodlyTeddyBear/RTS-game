--!strict

--[=[
	@class ProcessCombatTick
	Advances the combat runtime by one frame and refreshes derived status effects.
	@server
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick
setmetatable(ProcessCombatTick, BaseCommand)

--[=[
	Creates a combat tick command instance.
	@within ProcessCombatTick
	@return ProcessCombatTick -- New command instance.
]=]
function ProcessCombatTick.new()
	local self = BaseCommand.new("Combat", "ProcessCombatTick")
	return setmetatable(self, ProcessCombatTick)
end

--[=[
	Resolves the combat command dependencies used during each tick.
	@within ProcessCombatTick
	@param registry any -- Registry supplied by the context bootstrap.
	@param _name string -- Registry key used to register the command.
]=]
function ProcessCombatTick:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_actorRegistryService = "CombatActorRegistryService",
		_statusService = "StatusService",
	})
end

--[=[
	Processes one combat tick for a running session.
	@within ProcessCombatTick
	@param userId number -- Combat session owner to tick.
	@param dt number -- Delta time in seconds for the frame.
	@return Result.Result<boolean> -- Whether the tick ran successfully.
]=]
function ProcessCombatTick:Execute(userId: number, dt: number): Result.Result<boolean>
	return Result.Catch(function()
		if not self._loopService:IsRunnable(userId) then
			return Ok(false)
		end

		local currentTime = os.clock()
		local ok, frameResult = pcall(function()
			return self._behaviorRuntimeService:RunFrame({
				CurrentTime = currentTime,
				DeltaTime = dt,
				Services = {
					CombatActorRegistryService = self._actorRegistryService,
				},
			})
		end)
		if not ok then
			error(frameResult)
		end
		self:_NotifyActorResults(frameResult)
		-- Recompute enemy move speed after all actor actions so status effects stay in sync with the frame.
		self._statusService:EvaluateEnemyMoveSpeedEffects()

		return Ok(true)
	end, self:_Label())
end

function ProcessCombatTick:_NotifyActorResults(frameResult: any)
	for _, entityResult in ipairs(frameResult.EntityResults) do
		self._actorRegistryService:NotifyActionResult(entityResult.Entity, entityResult)
	end
end

return ProcessCombatTick
