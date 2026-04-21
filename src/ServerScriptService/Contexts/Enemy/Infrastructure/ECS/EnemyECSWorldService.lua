--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JECS = require(ReplicatedStorage.Packages.JECS)

--[=[
	@class EnemyECSWorldService
	Owns the isolated JECS world used by EnemyContext.
	@server
]=]
local EnemyECSWorldService = {}
EnemyECSWorldService.__index = EnemyECSWorldService

function EnemyECSWorldService.new()
	local self = setmetatable({}, EnemyECSWorldService)
	self._world = JECS.World.new()
	return self
end

function EnemyECSWorldService:Init(_registry: any, _name: string)
end

function EnemyECSWorldService:GetWorld()
	return self._world
end

return EnemyECSWorldService
