--!strict

local BaseStateSyncSystem = {}
BaseStateSyncSystem.__index = BaseStateSyncSystem

function BaseStateSyncSystem.new(entityFactory: any, syncService: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_syncService = syncService,
	}, BaseStateSyncSystem)
end

function BaseStateSyncSystem:Run()
	local result = self._entityFactory:Query({
		Keys = {
			{ Key = "BaseTag", FeatureName = "Base" },
			{ Key = "DirtyTag", FeatureName = "Entity" },
		},
	})
	if not result.success then
		return
	end

	for _, entity in ipairs(result.value) do
		self._syncService:SyncBaseState()
		self._entityFactory:Remove(entity, "DirtyTag", "Entity")
	end
end

return BaseStateSyncSystem
