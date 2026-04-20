--!strict
--[=[
	@class useHudVisibility
	React hook that subscribes to global App HUD visibility state.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local hudVisibilityAtom = require(script.Parent.Parent.Parent.Infrastructure.HudVisibilityAtom)

export type THudVisibilityState = typeof(hudVisibilityAtom())

local function useHudVisibility(): THudVisibilityState
	return ReactCharm.useAtom(hudVisibilityAtom)
end

return useHudVisibility
