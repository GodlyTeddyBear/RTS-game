--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useState = React.useState

--[=[
	Polls the server for machine state updates at regular intervals.
	Automatically starts/stops polling based on overlay open state.
	@within useMachineOverlayPolling
	@param ui any -- UI state containing open status, zoneName, and slotIndex
	@param buildingContext any -- Building context service for state requests
	@return any -- Current machine state, or nil if overlay is closed
	@yields
]=]
local function useMachineOverlayPolling(ui: any, buildingContext: any): any
	local machineView, setMachineView = useState(nil :: any)

	useEffect(function()
		if not ui.open or ui.zoneName == nil or ui.slotIndex == nil then
			setMachineView(nil)
			return
		end

		local cancelled = false
		local zoneName = ui.zoneName :: string
		local slotIndex = ui.slotIndex :: number

		-- Fetch fresh machine state from server
		local function refresh()
			buildingContext:GetMachineState(zoneName, slotIndex)
				:andThen(function(data: any)
					if not cancelled then
						setMachineView(data)
					end
				end)
				:catch(function() end)
		end

		-- Poll every 0.35s to keep UI responsive without overwhelming server
		refresh()
		local thread = task.spawn(function()
			while not cancelled do
				task.wait(0.35)
				if cancelled then
					break
				end
				refresh()
			end
		end)

		return function()
			cancelled = true
			task.cancel(thread)
		end
	end, { ui.open, ui.zoneName, ui.slotIndex, buildingContext } :: { any })

	return machineView
end

return useMachineOverlayPolling
