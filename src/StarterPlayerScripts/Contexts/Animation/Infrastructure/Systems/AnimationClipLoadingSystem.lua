--!strict

local AnimationClipLoadingSystem = {}
AnimationClipLoadingSystem.__index = AnimationClipLoadingSystem

function AnimationClipLoadingSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationClipLoadingSystem)
end

function AnimationClipLoadingSystem:Run()
	self._runtimeService:LoadClips()
end

return AnimationClipLoadingSystem
