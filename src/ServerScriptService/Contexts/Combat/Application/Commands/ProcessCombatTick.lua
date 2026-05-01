--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

local ProcessCombatTick = {}
ProcessCombatTick.__index = ProcessCombatTick
setmetatable(ProcessCombatTick, BaseCommand)

function ProcessCombatTick.new()
	local self = BaseCommand.new("Combat", "ProcessCombatTick")
	return setmetatable(self, ProcessCombatTick)
end

function ProcessCombatTick:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_loopService = "CombatLoopService",
		_behaviorRuntimeService = "CombatBehaviorRuntimeService",
		_actorRegistryService = "CombatActorRegistryService",
	})
end

function ProcessCombatTick:Execute(userId: number, dt: number): Result.Result<boolean>
	return Result.Catch(function()
		if not self._loopService:IsRunnable(userId) then
			return Ok(false)
		end

		local currentTime = os.clock()
		local frameResult = self._behaviorRuntimeService:RunFrame({
			CurrentTime = currentTime,
			DeltaTime = dt,
			Services = {
				CombatActorRegistryService = self._actorRegistryService,
			},
		})
		self:_NotifyActorResults(frameResult)

		return Ok(true)
	end, self:_Label())
end

function ProcessCombatTick:_NotifyActorResults(frameResult: any)
	for _, entityResult in ipairs(frameResult.EntityResults) do
		self._actorRegistryService:NotifyActionResult(entityResult.Entity, entityResult)
	end
end

return ProcessCombatTick
