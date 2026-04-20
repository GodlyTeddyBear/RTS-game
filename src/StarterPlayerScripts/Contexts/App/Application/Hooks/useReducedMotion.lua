--!strict
--[=[
	@class useReducedMotion
	React hook that returns whether animations should be reduced or disabled for accessibility.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local useState = React.useState

--[[
    useReducedMotion - Detects if user prefers reduced motion

    Returns true if animations should be disabled or reduced.
    Currently returns false by default, but can be expanded to read from:
    - Player settings/preferences in DataStore
    - Accessibility settings
    - Game options menu

    Usage:
        local prefersReducedMotion = useReducedMotion()

        if prefersReducedMotion then
            -- Instant change, no animation
            ref.current.Size = targetSize
        else
            -- Animated change
            spring(ref, { Size = targetSize }, "Responsive")
        end
]]
--[=[
	Return whether the player prefers reduced motion; all animation hooks use this to skip transitions.
	@within useReducedMotion
	@return boolean -- `true` if animations should be skipped.
]=]
local function useReducedMotion()
	-- For now, always return false (animations enabled)
	-- Future: Read from player preferences in DataStore or settings
	local reducedMotion, _setReducedMotion = useState(false)
	return reducedMotion
end

return useReducedMotion
