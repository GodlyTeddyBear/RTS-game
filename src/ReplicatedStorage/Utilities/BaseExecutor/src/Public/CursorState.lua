--!strict

local function _DeepClone(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" then
		return value
	end

	local tracked = seen
	if tracked == nil then
		tracked = {}
	end

	local existing = tracked[value]
	if existing ~= nil then
		return existing
	end

	local cloned = {}
	tracked[value] = cloned

	for key, nestedValue in pairs(value) do
		cloned[_DeepClone(key, tracked)] = _DeepClone(nestedValue, tracked)
	end

	return cloned
end

local function _DeepFreeze(value: any, seen: { [any]: boolean }?): any
	if type(value) ~= "table" then
		return value
	end

	local tracked = seen
	if tracked == nil then
		tracked = {}
	end

	if tracked[value] == true then
		return value
	end

	tracked[value] = true
	for _, nestedValue in pairs(value) do
		_DeepFreeze(nestedValue, tracked)
	end

	return table.freeze(value)
end

local function _CloneCursorTable(cursorLike: any): { [string]: any }
	local clonedCursor = if type(cursorLike) == "table" then _DeepClone(cursorLike) else {}
	local data = clonedCursor.Data
	local meta = clonedCursor.Meta

	clonedCursor.Data = if type(data) == "table" then table.clone(data) else {}
	clonedCursor.Meta = if type(meta) == "table" then table.clone(meta) else {}
	clonedCursor.Phase = if type(clonedCursor.Phase) == "string" and clonedCursor.Phase ~= "" then clonedCursor.Phase else "Default"
	clonedCursor.Index = if type(clonedCursor.Index) == "number" then clonedCursor.Index else 1
	clonedCursor.BatchSize = if type(clonedCursor.BatchSize) == "number" then clonedCursor.BatchSize else 1
	clonedCursor.IsDone = clonedCursor.IsDone == true

	return clonedCursor
end

local function _GetEntityCursorSlots(self: any, entity: number): { [string]: any }?
	return self._cursorState[entity]
end

local function _GetOrCreateEntityCursorSlots(self: any, entity: number): { [string]: any }
	local cursorSlots = self._cursorState[entity]
	if cursorSlots ~= nil then
		return cursorSlots
	end

	cursorSlots = {}
	self._cursorState[entity] = cursorSlots
	return cursorSlots
end

local function _CanMutateCursor(self: any, entity: number, key: string): boolean
	local cursorAdvanceGate = self._cursorAdvanceGate[entity]
	if cursorAdvanceGate == nil then
		return true
	end

	return cursorAdvanceGate[key] == true
end

return function(BaseExecutor)
	function BaseExecutor:BeginCursor(entity: number, key: string, initialCursor: any): any
		assert(type(key) == "string" and key ~= "", "BaseExecutor:BeginCursor requires a non-empty key")

		local cursorSlots = _GetOrCreateEntityCursorSlots(self, entity)
		local cursor = _CloneCursorTable(initialCursor)
		cursorSlots[key] = cursor
		return cursor
	end

	function BaseExecutor:GetCursor(entity: number, key: string): any
		local cursorSlots = _GetEntityCursorSlots(self, entity)
		if cursorSlots == nil then
			return nil
		end

		return cursorSlots[key]
	end

	function BaseExecutor:GetCursorSnapshot(entity: number, key: string): any
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return nil
		end

		return _DeepFreeze(_CloneCursorTable(cursor))
	end

	function BaseExecutor:GetCursorPhase(entity: number, key: string): string?
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return nil
		end

		return cursor.Phase
	end

	function BaseExecutor:SetCursorPhase(entity: number, key: string, phase: string)
		local cursor = self:GetCursor(entity, key)
		if cursor == nil or not _CanMutateCursor(self, entity, key) then
			return
		end

		cursor.Phase = phase
	end

	function BaseExecutor:GetCursorIndex(entity: number, key: string): number?
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return nil
		end

		return cursor.Index
	end

	function BaseExecutor:SetCursorIndex(entity: number, key: string, index: number)
		local cursor = self:GetCursor(entity, key)
		if cursor == nil or not _CanMutateCursor(self, entity, key) then
			return
		end

		cursor.Index = index
	end

	function BaseExecutor:AdvanceCursorIndex(entity: number, key: string, amount: number)
		local cursor = self:GetCursor(entity, key)
		if cursor == nil or not _CanMutateCursor(self, entity, key) then
			return
		end

		cursor.Index += amount
	end

	function BaseExecutor:MarkCursorDone(entity: number, key: string, result: any?)
		local cursor = self:GetCursor(entity, key)
		if cursor == nil or not _CanMutateCursor(self, entity, key) then
			return
		end

		cursor.IsDone = true
		cursor.Result = result
	end

	function BaseExecutor:IsCursorDone(entity: number, key: string): boolean
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return false
		end

		return cursor.IsDone == true
	end

	function BaseExecutor:GetCursorData(entity: number, key: string): { [string]: any }?
		local cursor = self:GetCursor(entity, key)
		if cursor == nil then
			return nil
		end

		return cursor.Data
	end

	function BaseExecutor:SetCursorData(entity: number, key: string, data: { [string]: any })
		local cursor = self:GetCursor(entity, key)
		if cursor == nil or not _CanMutateCursor(self, entity, key) then
			return
		end

		cursor.Data = data
	end

	function BaseExecutor:ClearCursor(entity: number, key: string)
		local cursorSlots = _GetEntityCursorSlots(self, entity)
		if cursorSlots == nil then
			return
		end

		cursorSlots[key] = nil
		if next(cursorSlots) == nil then
			self._cursorState[entity] = nil
		end
	end

	function BaseExecutor:ClearAllCursors(entity: number)
		self._cursorState[entity] = nil
	end
end
