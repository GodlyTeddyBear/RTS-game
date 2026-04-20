--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err

local VOLUME_KEYS = table.freeze({
	MasterVolume = true,
	MusicVolume = true,
	SfxVolume = true,
	UiVolume = true,
	AmbientVolume = true,
})

local SoundSettingsValidator = {}
SoundSettingsValidator.__index = SoundSettingsValidator

function SoundSettingsValidator.new()
	return setmetatable({}, SoundSettingsValidator)
end

function SoundSettingsValidator:ValidatePatch(patch: { [string]: any }): Result.Result<{ [string]: any }>
	if type(patch) ~= "table" then
		return Err("InvalidArgument", "Sound settings patch must be a table.")
	end

	local normalized = {}

	for key, value in patch do
		if VOLUME_KEYS[key] then
			if type(value) ~= "number" or value < 0 or value > 1 then
				return Err("InvalidSoundSetting", "Volume must be a number between 0 and 1.", {
					key = key,
					value = value,
				})
			end
			normalized[key] = value
		elseif key == "Enabled" then
			if type(value) ~= "boolean" then
				return Err("InvalidSoundSetting", "Enabled must be a boolean.", {
					key = key,
					value = value,
				})
			end
			normalized.Enabled = value
		else
			return Err("UnknownSoundSetting", "Unknown sound setting key.", {
				key = key,
			})
		end
	end

	return Ok(normalized)
end

return SoundSettingsValidator
