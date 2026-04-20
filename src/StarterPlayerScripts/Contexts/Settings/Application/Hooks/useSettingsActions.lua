--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local function _ClampVolume(value: number): number
	return math.clamp(math.round(value * 10) / 10, 0, 1)
end

local function useSettingsActions()
	local settingsController = Knit.GetController("SettingsController")

	return {
		setSoundVolume = function(key: string, value: number)
			return settingsController:UpdateSoundSettings({
				[key] = _ClampVolume(value),
			})
		end,

		setSoundEnabled = function(enabled: boolean)
			return settingsController:UpdateSoundSettings({
				Enabled = enabled,
			})
		end,
	}
end

return useSettingsActions
