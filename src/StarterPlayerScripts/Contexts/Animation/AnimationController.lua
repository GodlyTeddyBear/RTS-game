--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local AnimationEntityRuntimeService = require(script.Parent.Infrastructure.Services.AnimationEntityRuntimeService)
local AnimationActionPlaybackSystem = require(script.Parent.Infrastructure.Systems.AnimationActionPlaybackSystem)
local AnimationAimSystem = require(script.Parent.Infrastructure.Systems.AnimationAimSystem)
local AnimationCleanupSystem = require(script.Parent.Infrastructure.Systems.AnimationCleanupSystem)
local AnimationClipLoadingSystem = require(script.Parent.Infrastructure.Systems.AnimationClipLoadingSystem)
local AnimationLeanSystem = require(script.Parent.Infrastructure.Systems.AnimationLeanSystem)
local AnimationLocomotionSystem = require(script.Parent.Infrastructure.Systems.AnimationLocomotionSystem)
local AnimationRigSetupSystem = require(script.Parent.Infrastructure.Systems.AnimationRigSetupSystem)
local AnimationRuntimeReconciliationSystem = require(script.Parent.Infrastructure.Systems.AnimationRuntimeReconciliationSystem)

local AnimationController = Knit.CreateController({
	Name = "AnimationController",
})

local DEBUG_PREFIX = "[AnimationPipeline]"

function AnimationController:KnitInit()
	self._runtimeService = nil
	self._markerObservers = {}
end

function AnimationController:KnitStart()
	local entityController = Knit.GetController("EntityController")
	self._runtimeService = AnimationEntityRuntimeService.new(self, entityController)

	entityController:RegisterSystem(
		"AnimationRuntimeReconciliationSystem",
		AnimationRuntimeReconciliationSystem.new(self._runtimeService),
		"Reconcile"
	)
	entityController:RegisterSystem("AnimationRigSetupSystem", AnimationRigSetupSystem.new(self._runtimeService), "Setup")
	entityController:RegisterSystem("AnimationClipLoadingSystem", AnimationClipLoadingSystem.new(self._runtimeService), "Setup")
	entityController:RegisterSystem("AnimationLocomotionSystem", AnimationLocomotionSystem.new(self._runtimeService), "Playback")
	entityController:RegisterSystem(
		"AnimationActionPlaybackSystem",
		AnimationActionPlaybackSystem.new(self._runtimeService),
		"Playback"
	)
	entityController:RegisterSystem("AnimationAimSystem", AnimationAimSystem.new(self._runtimeService), "Procedural")
	entityController:RegisterSystem("AnimationLeanSystem", AnimationLeanSystem.new(self._runtimeService), "Render")
	entityController:RegisterSystem("AnimationCleanupSystem", AnimationCleanupSystem.new(self._runtimeService), "Cleanup")
	warn(DEBUG_PREFIX, "AnimationController registered animation systems")
end

function AnimationController:RequestLocalAction(entity: number, actionId: string, channelId: string?): boolean
	if self._runtimeService == nil then
		return false
	end
	return self._runtimeService:RequestLocalAction(entity, actionId, channelId)
end

function AnimationController:CancelLocalAction(entity: number, channelId: string?): boolean
	if self._runtimeService == nil then
		return false
	end
	return self._runtimeService:CancelLocalAction(entity, channelId)
end

function AnimationController:ObserveMarker(callback: (any) -> ()): () -> ()
	table.insert(self._markerObservers, callback)
	local disconnected = false
	return function()
		if disconnected then
			return
		end
		disconnected = true
		local index = table.find(self._markerObservers, callback)
		if index ~= nil then
			table.remove(self._markerObservers, index)
		end
	end
end

function AnimationController:_EmitMarker(payload: any)
	for _, callback in ipairs(self._markerObservers) do
		callback(payload)
	end
end

function AnimationController:Destroy()
	if self._runtimeService ~= nil then
		self._runtimeService:Destroy()
		self._runtimeService = nil
	end
	table.clear(self._markerObservers)
end

return AnimationController
