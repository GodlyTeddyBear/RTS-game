--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local getBaseProductionAtom = require(script.Parent.Parent.Parent.Infrastructure.BaseProductionAtom)
local BaseProductionService = require(script.Parent.Parent.Parent.Infrastructure.Services.BaseProductionService)

type TBaseProductionState = getBaseProductionAtom.TBaseProductionState

export type TBaseProductionActions = {
	open: () -> (),
	close: () -> (),
	selectUnit: (string) -> (),
	produceUnit: (string) -> (),
}

local function _SetState(nextState: TBaseProductionState)
	getBaseProductionAtom()(table.freeze(nextState))
end

local function useBaseProductionActions(): TBaseProductionActions
	local productionService = React.useMemo(function()
		return BaseProductionService.new()
	end, {})

	return React.useMemo(function()
		return table.freeze({
			open = function()
				local current = getBaseProductionAtom()()
				_SetState({
					isOpen = true,
					selectedUnitId = current.selectedUnitId,
				})
			end,
			close = function()
				_SetState({
					isOpen = false,
					selectedUnitId = nil,
				})
			end,
			selectUnit = function(unitId: string)
				_SetState({
					isOpen = true,
					selectedUnitId = unitId,
				})
			end,
			produceUnit = function(unitId: string)
				productionService:ProduceUnit(unitId):catch(function(err: any)
					local errType = if err and err.type then tostring(err.type) else "UnknownErrorType"
					local message = if err and err.message then tostring(err.message) else "No message"
					local data = if err and err.data then err.data else nil
					warn(string.format(
						"[BaseProduction] ProduceUnit rejected unitId=%s type=%s message=%s data=%s",
						unitId,
						errType,
						message,
						if data then HttpService:JSONEncode(data) else "nil"
					))
				end)
			end,
		} :: TBaseProductionActions)
	end, { productionService })
end

return useBaseProductionActions
