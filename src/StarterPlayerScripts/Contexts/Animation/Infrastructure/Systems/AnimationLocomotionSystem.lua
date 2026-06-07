--!strict

local AnimationLocomotionSystem = {}
AnimationLocomotionSystem.__index = AnimationLocomotionSystem

function AnimationLocomotionSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationLocomotionSystem)
end

function AnimationLocomotionSystem:Run()
	self._runtimeService:UpdateLocomotion()
end

return AnimationLocomotionSystem
