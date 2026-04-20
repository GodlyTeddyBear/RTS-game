--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local SharedAtoms = require(ReplicatedStorage.Contexts.Settings.Sync.SharedAtoms)

local function useSettingsState(): SharedAtoms.TSettingsData
	local settingsController = Knit.GetController("SettingsController")
	local settingsAtom = settingsController:GetSettingsAtom()

	return ReactCharm.useAtom(settingsAtom) or SharedAtoms.CloneSettings(nil)
end

return useSettingsState
