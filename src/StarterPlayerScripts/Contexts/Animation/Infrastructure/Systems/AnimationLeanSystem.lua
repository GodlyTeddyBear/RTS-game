--!strict

local AnimationLeanSystem = {}
AnimationLeanSystem.__index = AnimationLeanSystem

function AnimationLeanSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationLeanSystem)
end

function AnimationLeanSystem:Run()
	self._runtimeService:UpdateRender()
end

return AnimationLeanSystem
