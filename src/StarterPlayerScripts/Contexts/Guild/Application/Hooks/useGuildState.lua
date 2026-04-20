--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local useAtom = ReactCharm.useAtom

--[[
	Read hook that subscribes to the guild adventurer state atom.

	@return Current adventurer state { [string]: TAdventurer } or {} if not yet hydrated
]]
local function useGuildState()
	local guildController = Knit.GetController("GuildController")
	if not guildController then
		warn("useGuildState: GuildController not available")
		return {}
	end
	local adventurersAtom = guildController:GetAdventurersAtom()
	return useAtom(adventurersAtom) or {}
end

return useGuildState
