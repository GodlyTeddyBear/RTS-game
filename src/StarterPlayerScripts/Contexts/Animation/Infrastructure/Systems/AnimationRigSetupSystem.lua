--!strict

local AnimationRigSetupSystem = {}
AnimationRigSetupSystem.__index = AnimationRigSetupSystem

function AnimationRigSetupSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationRigSetupSystem)
end

function AnimationRigSetupSystem:Run()
	self._runtimeService:Setup()
end

return AnimationRigSetupSystem
