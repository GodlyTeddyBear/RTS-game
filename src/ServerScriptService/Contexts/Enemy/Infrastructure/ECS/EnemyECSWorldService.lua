--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseECSWorldService = require(ReplicatedStorage.Utilities.BaseECSWorldService)

--[=[
	@class EnemyECSWorldService
	Owns the isolated JECS world used by EnemyContext.
	@server
]=]
local EnemyECSWorldService = {}
EnemyECSWorldService.__index = EnemyECSWorldService
setmetatable(EnemyECSWorldService, { __index = BaseECSWorldService })

function EnemyECSWorldService.new()
	return setmetatable(BaseECSWorldService.new("Enemy"), EnemyECSWorldService)
end

function EnemyECSWorldService:Init(_registry: any, _name: string)
	BaseECSWorldService.Init(self, _registry, _name)
end

function EnemyECSWorldService:GetWorld()
	return BaseECSWorldService.GetWorld(self)
end

return EnemyECSWorldService
