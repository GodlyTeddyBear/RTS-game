--!strict
--[=[
	@class HudVisibilityAtom
	Singleton Charm atom holding global App HUD visibility state.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type THudVisibilityState = {
	IsGameHudEnabled: boolean,
	Reason: string?,
}

local hudVisibilityAtom = Charm.atom({
	IsGameHudEnabled = true,
	Reason = nil,
} :: THudVisibilityState)

return hudVisibilityAtom
