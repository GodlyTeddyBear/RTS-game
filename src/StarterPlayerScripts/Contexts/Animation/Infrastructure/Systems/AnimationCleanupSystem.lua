--!strict

local AnimationCleanupSystem = {}
AnimationCleanupSystem.__index = AnimationCleanupSystem

function AnimationCleanupSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationCleanupSystem)
end

function AnimationCleanupSystem:Run()
	self._runtimeService:Cleanup()
end

return AnimationCleanupSystem
