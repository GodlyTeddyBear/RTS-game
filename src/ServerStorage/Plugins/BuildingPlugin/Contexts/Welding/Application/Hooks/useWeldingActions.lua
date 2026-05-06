--!strict

local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)

local function useWeldingActions()
	local services = usePluginServices()

	local function applyResult(result)
		AppAtom.SetStatus(result.Message, if result.Success then "Success" else "Error")
	end

	return {
		CreateSingleWeld = function()
			applyResult(services.SelectionActions:CreateSingleWeld())
		end,
		CreateMassWeld = function()
			applyResult(services.SelectionActions:CreateMassWeld())
		end,
	}
end

return useWeldingActions
