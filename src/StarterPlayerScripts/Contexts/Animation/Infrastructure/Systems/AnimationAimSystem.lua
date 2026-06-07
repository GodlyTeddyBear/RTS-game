--!strict

local AnimationAimSystem = {}
AnimationAimSystem.__index = AnimationAimSystem

function AnimationAimSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationAimSystem)
end

function AnimationAimSystem:Run()
	self._runtimeService:UpdateProcedural()
end

return AnimationAimSystem
