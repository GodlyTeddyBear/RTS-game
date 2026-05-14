--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local getBaseProductionAtom = require(script.Parent.Parent.Parent.Infrastructure.BaseProductionAtom)

type TBaseProductionState = getBaseProductionAtom.TBaseProductionState

export type TBaseProductionActions = {
	open: () -> (),
	close: () -> (),
	selectUnit: (string) -> (),
	produceUnavailable: (string) -> (),
}

local function _SetState(nextState: TBaseProductionState)
	getBaseProductionAtom()(table.freeze(nextState))
end

local function useBaseProductionActions(): TBaseProductionActions
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
			produceUnavailable = function(unitId: string)
				warn(("[BaseProduction] Unit production is not implemented yet: %s"):format(unitId))
			end,
		} :: TBaseProductionActions)
	end, {})
end

return useBaseProductionActions
