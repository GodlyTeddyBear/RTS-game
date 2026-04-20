--!strict

--[[
	useSoundSettings - Read hook for sound volume levels.

	Returns current volume settings for use in a settings UI.
	Also provides setter functions for adjusting volumes.

	Designed for future persistence integration — currently session-only.

	Usage:
		local settings = useSoundSettings()
		print(settings.masterVolume) -- 1
		settings.setMasterVolume(0.5)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Knit = require(ReplicatedStorage.Packages.Knit)

local useState = React.useState
local useCallback = React.useCallback

local function useSoundSettings()
	local masterVolume, setMasterVolumeState = useState(1)
	local musicVolume, setMusicVolumeState = useState(0.8)
	local sfxVolume, setSfxVolumeState = useState(1)
	local uiVolume, setUiVolumeState = useState(0.8)
	local ambientVolume, setAmbientVolumeState = useState(0.6)

	local setMasterVolume = useCallback(function(volume: number)
		setMasterVolumeState(volume)
		local soundController = Knit.GetController("SoundController")
		soundController:SetVolume("Master", volume, 0.3)
	end, {})

	local setMusicVolume = useCallback(function(volume: number)
		setMusicVolumeState(volume)
		local soundController = Knit.GetController("SoundController")
		soundController:SetVolume("Music", volume, 0.3)
	end, {})

	local setSfxVolume = useCallback(function(volume: number)
		setSfxVolumeState(volume)
		local soundController = Knit.GetController("SoundController")
		soundController:SetVolume("SFX", volume, 0.3)
	end, {})

	local setUiVolume = useCallback(function(volume: number)
		setUiVolumeState(volume)
		local soundController = Knit.GetController("SoundController")
		soundController:SetVolume("UI", volume, 0.3)
	end, {})

	local setAmbientVolume = useCallback(function(volume: number)
		setAmbientVolumeState(volume)
		local soundController = Knit.GetController("SoundController")
		soundController:SetVolume("Ambient", volume, 0.3)
	end, {})

	return {
		MasterVolume = masterVolume,
		MusicVolume = musicVolume,
		SfxVolume = sfxVolume,
		UiVolume = uiVolume,
		AmbientVolume = ambientVolume,
		SetMasterVolume = setMasterVolume,
		SetMusicVolume = setMusicVolume,
		SetSfxVolume = setSfxVolume,
		SetUiVolume = setUiVolume,
		SetAmbientVolume = setAmbientVolume,
	}
end

return useSoundSettings
