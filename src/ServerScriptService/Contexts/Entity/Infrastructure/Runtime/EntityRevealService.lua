--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.Utilities.ECS)

local EntityRevealService = {}
EntityRevealService.__index = EntityRevealService

function EntityRevealService.new()
	return setmetatable({}, EntityRevealService)
end

function EntityRevealService:Init(_registry: any, _name: string)
	return
end

function EntityRevealService:Apply(instance: Instance?, revealState: any?)
	if instance == nil or revealState == nil then
		return
	end

	ECS.RevealApplier.Apply(instance, revealState)
end

return EntityRevealService
