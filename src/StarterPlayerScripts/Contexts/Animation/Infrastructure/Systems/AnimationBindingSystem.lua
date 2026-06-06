--!strict

local AnimationBindingSystem = {}
AnimationBindingSystem.__index = AnimationBindingSystem

function AnimationBindingSystem.new(entityController: any, runtimeService: any)
	return setmetatable({
		_entityController = entityController,
		_runtimeService = runtimeService,
	}, AnimationBindingSystem)
end

function AnimationBindingSystem:Run()
	local activeEntities = {}
	for _, record in ipairs(self._entityController:GetByTag("Animation.EnabledTag")) do
		local profile = record.Components["Animation.Profile"]
		if type(profile) ~= "table" then
			continue
		end
		activeEntities[record.Entity] = true
		self._runtimeService:Ensure(record.Entity, profile)
	end
	self._runtimeService:CleanupMissing(activeEntities)
end

return AnimationBindingSystem
