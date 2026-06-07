--!strict

local AnimationRuntimeReconciliationSystem = {}
AnimationRuntimeReconciliationSystem.__index = AnimationRuntimeReconciliationSystem

function AnimationRuntimeReconciliationSystem.new(runtimeService: any)
	return setmetatable({
		_runtimeService = runtimeService,
	}, AnimationRuntimeReconciliationSystem)
end

function AnimationRuntimeReconciliationSystem:Run()
	self._runtimeService:Reconcile()
end

return AnimationRuntimeReconciliationSystem
