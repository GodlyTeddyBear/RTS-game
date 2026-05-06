--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local SettingsAtom = require(script.Parent.Parent.Parent.Infrastructure.SettingsAtom)

local function useSettingsState()
	return ReactCharm.useAtom(SettingsAtom.GetAtom())
end

return useSettingsState
