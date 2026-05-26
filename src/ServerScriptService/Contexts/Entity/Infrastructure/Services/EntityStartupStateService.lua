--!strict

local EntityStartupStateService = {}
EntityStartupStateService.__index = EntityStartupStateService

function EntityStartupStateService.new()
	local self = setmetatable({}, EntityStartupStateService)
	self._lastStartupFailure = nil
	return self
end

function EntityStartupStateService:Init(_registry: any, _name: string)
	return
end

function EntityStartupStateService:SetLastStartupFailure(failureResult: any?)
	if failureResult == nil then
		self._lastStartupFailure = nil
		return
	end

	self._lastStartupFailure = {
		Type = failureResult.type,
		Message = failureResult.message,
		Data = failureResult.data,
	}
end

function EntityStartupStateService:ClearLastStartupFailure()
	self._lastStartupFailure = nil
end

function EntityStartupStateService:GetLastStartupFailure(): any?
	return self._lastStartupFailure
end

function EntityStartupStateService:GetStatus(): any
	return table.freeze({
		LastStartupFailure = self._lastStartupFailure,
	})
end

return EntityStartupStateService
