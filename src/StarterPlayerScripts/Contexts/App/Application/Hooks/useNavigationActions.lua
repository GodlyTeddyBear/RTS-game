--!strict
--[=[
	@class useNavigationActions
	React hook that returns imperative navigation actions for pushing, replacing, going back, and resetting the screen stack.
	@client
]=]
local navigationAtom = require(script.Parent.Parent.Parent.Infrastructure.NavigationAtom)

--[=[
	Return a table of navigation action functions for modifying the screen stack.
	@within useNavigationActions
	@return { navigate: (screenName: string, params: { [string]: any }?) -> (), goBack: () -> (), replace: (screenName: string, params: { [string]: any }?) -> (), reset: (screenName: string, params: { [string]: any }?) -> () } -- Navigation action table.
]=]
local function useNavigationActions()
	return {
		-- Navigate forward: push screen onto history stack
		navigate = function(screenName: string, params: { [string]: any }?)
			local current = _GetCurrentState()
			local newHistory = table.clone(current.History)
			table.insert(newHistory, screenName)

			_UpdateNavigationState({
				CurrentScreen = screenName,
				History = newHistory,
				Params = params,
			})
		end,

		-- Go back: pop the current screen from history
		goBack = function()
			if not _CanGoBack() then
				return
			end

			local current = _GetCurrentState()
			local newHistory = table.clone(current.History)
			table.remove(newHistory)

			_UpdateNavigationState({
				CurrentScreen = newHistory[#newHistory],
				History = newHistory,
				Params = nil,
			})
		end,

		-- Replace current screen with a new one (same history depth)
		replace = function(screenName: string, params: { [string]: any }?)
			local current = _GetCurrentState()
			local newHistory = table.clone(current.History)
			newHistory[#newHistory] = screenName

			_UpdateNavigationState({
				CurrentScreen = screenName,
				History = newHistory,
				Params = params,
			})
		end,

		-- Reset history: clear stack and navigate to a single screen
		reset = function(screenName: string, params: { [string]: any }?)
			_UpdateNavigationState({
				CurrentScreen = screenName,
				History = { screenName },
				Params = params,
			})
		end,
	}
end

-- Get the current navigation state from the atom
function _GetCurrentState()
	return navigationAtom()
end

-- Update the navigation atom with partial state
function _UpdateNavigationState(update: { [string]: any })
	navigationAtom(update)
end

-- Check if there's a previous screen to go back to
function _CanGoBack(): boolean
	return #_GetCurrentState().History > 1
end

return useNavigationActions
