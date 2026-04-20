--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

--[=[
	@class OverlayContext
	React context for the dropdown overlay container frame. Allows dropdowns to render portals above other UI.
	@client
]=]

local OverlayContext = React.createContext(nil :: Frame?)

--[=[
	Hook to get the overlay container frame for portal rendering.
	@within OverlayContext
	@return Frame? -- Overlay frame if available, nil otherwise
]=]
local function useOverlayContainer(): Frame?
	return React.useContext(OverlayContext)
end

return {
	Provider = OverlayContext.Provider,
	useOverlayContainer = useOverlayContainer,
}
