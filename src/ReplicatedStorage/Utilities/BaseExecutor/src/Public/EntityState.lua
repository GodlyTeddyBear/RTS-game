--!strict

return function(BaseExecutor)
	--[=[
		@within BaseExecutor
		Returns the mutable runtime state bag associated with one entity.
		@param entity number -- Entity id being processed.
		@return { [string]: any } -- Entity-scoped state table.
	]=]
	function BaseExecutor:GetEntityState(entity: number)
		local state = self._entityState[entity]
		if state ~= nil then
			return state
		end

		state = {}
		self._entityState[entity] = state
		return state
	end

	--[=[
		@within BaseExecutor
		Stores one entity-scoped runtime value.
		@param entity number -- Entity id being processed.
		@param key string -- State key to update.
		@param value any -- Value to store for the entity.
	]=]
	function BaseExecutor:SetEntityValue(entity: number, key: string, value: any)
		local state = self:GetEntityState(entity)
		state[key] = value
	end

	--[=[
		@within BaseExecutor
		Returns one entity-scoped runtime value.
		@param entity number -- Entity id being processed.
		@param key string -- State key to inspect.
		@return any -- Stored value for the entity and key.
	]=]
	function BaseExecutor:GetEntityValue(entity: number, key: string): any
		local state = self._entityState[entity]
		if state == nil then
			return nil
		end

		return state[key]
	end

	--[=[
		@within BaseExecutor
		Returns whether one entity-scoped state key currently exists.
		@param entity number -- Entity id being processed.
		@param key string -- State key to inspect.
		@return boolean -- Whether the entity currently stores a value for the key.
	]=]
	function BaseExecutor:HasEntityValue(entity: number, key: string): boolean
		local state = self._entityState[entity]
		if state == nil then
			return false
		end

		return state[key] ~= nil
	end

	--[=[
		@within BaseExecutor
		Returns an entity-scoped value or creates and stores it when absent.
		@param entity number -- Entity id being processed.
		@param key string -- State key to inspect.
		@param createValue () -> any -- Factory invoked only when the key is absent.
		@return any -- Existing or newly-created state value.
	]=]
	function BaseExecutor:GetOrCreateEntityValue(entity: number, key: string, createValue: () -> any): any
		local state = self:GetEntityState(entity)
		local value = state[key]
		if value ~= nil then
			return value
		end

		value = createValue()
		state[key] = value
		return value
	end

	--[=[
		@within BaseExecutor
		Clears one entity-scoped state key.
		@param entity number -- Entity id being processed.
		@param key string -- State key to clear.
	]=]
	function BaseExecutor:ClearEntityValue(entity: number, key: string)
		local state = self._entityState[entity]
		if state == nil then
			return
		end

		state[key] = nil
		if next(state) == nil then
			self._entityState[entity] = nil
		end
	end

	--[=[
		@within BaseExecutor
		Clears all entity-scoped runtime state and failure metadata for one entity.
		@param entity number -- Entity id being processed.
	]=]
	function BaseExecutor:ClearEntityState(entity: number)
		self._entityState[entity] = nil
		self._lastFailureReason[entity] = nil
	end
end
