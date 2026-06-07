--!strict

local AnimationActionPlaybackSystem = {}
AnimationActionPlaybackSystem.__index = AnimationActionPlaybackSystem

function AnimationActionPlaybackSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationActionPlaybackSystem)
end

function AnimationActionPlaybackSystem:Run()
	self._runtimeService:UpdateActions()
end

return AnimationActionPlaybackSystem
