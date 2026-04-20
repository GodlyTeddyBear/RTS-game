--!strict

--[[
	SoundRegistry - Load Sound Effects for Combat and UI

	Provides a registry for loading sound effects for combat actions and UI interactions.

	Folder Structure:
		Sounds/
		├── Combat/
		│   ├── BasicAttack/
		│   │   └── Sound instance
		│   ├── Skills/
		│   │   ├── Slash/
		│   │   │   └── Sound instance
		│   │   ├── Fireball/
		│   │   │   └── Sound instance
		│   │   └── HealingLight/
		│   │       └── Sound instance
		│   └── Defend/
		│       └── Sound instance
		└── UI/
		    ├── ButtonClick/
		    │   └── Sound instance
		    └── MenuOpen/
		        └── Sound instance

	Usage:
		local soundRegistry = SoundRegistry.new(Assets.Sounds)
		local slashSound = soundRegistry:GetCombatSound("Skills/Slash")
		local clickSound = soundRegistry:GetUISound("ButtonClick")
]]

local SoundRegistry = {}
SoundRegistry.__index = SoundRegistry

--[=[
	Creates a new SoundRegistry.

	@param soundsFolder Folder - The root Sounds folder
	@return SoundRegistry - New registry instance
]=]
function SoundRegistry.new(soundsFolder: Folder)
	assert(soundsFolder, "SoundRegistry requires a valid Sounds folder")
	assert(soundsFolder:IsA("Folder"), "SoundRegistry requires a Folder instance")

	local self = setmetatable({}, SoundRegistry)
	self._combatFolder = soundsFolder:FindFirstChild("Combat")
	self._uiFolder = soundsFolder:FindFirstChild("UI")

	return self
end

--[=[
	Gets a combat sound effect.

	Supports both direct sounds (e.g., "BasicAttack") and nested sounds (e.g., "Skills/Slash").

	@param soundName string - The sound path (e.g., "BasicAttack", "Skills/Slash")
	@return Sound - Cloned sound instance

	Example:
		local slashSound = registry:GetCombatSound("Skills/Slash")
		slashSound.Parent = character.HumanoidRootPart
		slashSound:Play()
]=]
function SoundRegistry:GetCombatSound(soundName: string): Sound
	assert(self._combatFolder, "Combat folder not found in Sounds")
	return self:_GetSound(self._combatFolder, soundName, "Combat sound")
end

--[=[
	Gets a UI sound effect.

	@param soundName string - The sound name (e.g., "ButtonClick", "MenuOpen")
	@return Sound - Cloned sound instance

	Example:
		local clickSound = registry:GetUISound("ButtonClick")
		clickSound.Parent = SoundService
		clickSound:Play()
]=]
function SoundRegistry:GetUISound(soundName: string): Sound
	assert(self._uiFolder, "UI folder not found in Sounds")
	return self:_GetSound(self._uiFolder, soundName, "UI sound")
end

--[=[
	Checks if a combat sound exists.

	@param soundName string - The sound path
	@return boolean - True if sound exists

	Example:
		if registry:CombatSoundExists("Skills/Slash") then
			local sound = registry:GetCombatSound("Skills/Slash")
		end
]=]
function SoundRegistry:CombatSoundExists(soundName: string): boolean
	if not self._combatFolder then
		return false
	end
	return self:_SoundExists(self._combatFolder, soundName)
end

--[=[
	Checks if a UI sound exists.

	@param soundName string - The sound name
	@return boolean - True if sound exists

	Example:
		if registry:UISoundExists("ButtonClick") then
			local sound = registry:GetUISound("ButtonClick")
		end
]=]
function SoundRegistry:UISoundExists(soundName: string): boolean
	if not self._uiFolder then
		return false
	end
	return self:_SoundExists(self._uiFolder, soundName)
end

--[=[
	Gets a sound from a folder with validation.

	@private
	@param rootFolder Folder - The root folder to search
	@param soundPath string - Path to the sound (e.g., "Skills/Slash" or "ButtonClick")
	@param soundType string - Type for error message (e.g., "Combat sound")
	@return Sound - Cloned sound instance
]=]
function SoundRegistry:_GetSound(rootFolder: Folder, soundPath: string, soundType: string): Sound
	local soundContainer = self:_NavigateToFolder(rootFolder, soundPath)
	assert(soundContainer, soundType .. " not found: " .. soundPath)

	local sound = self:_ExtractSound(soundContainer)
	assert(sound, "No Sound instance found in: " .. soundPath)

	return sound:Clone()
end

--[=[
	Checks if a sound exists in a folder.

	@private
	@param rootFolder Folder - The root folder to search
	@param soundPath string - Path to the sound
	@return boolean - True if sound exists
]=]
function SoundRegistry:_SoundExists(rootFolder: Folder, soundPath: string): boolean
	local soundContainer = self:_NavigateToFolder(rootFolder, soundPath)
	if not soundContainer then
		return false
	end
	return self:_ExtractSound(soundContainer) ~= nil
end

--[=[
	Navigates to a folder using a path string.

	@private
	@param rootFolder Folder - The root folder to start from
	@param path string - The folder path (e.g., "Skills/Slash")
	@return Folder? - The folder if found, nil otherwise
]=]
function SoundRegistry:_NavigateToFolder(rootFolder: Folder, path: string): Folder?
	local parts = string.split(path, "/")
	local current: Instance = rootFolder

	for _, part in ipairs(parts) do
		local next = current:FindFirstChild(part)
		if not next or not next:IsA("Folder") then
			return nil
		end
		current = next
	end

	return current :: Folder
end

--[=[
	Extracts a Sound instance from a folder.

	@private
	@param folder Folder - The folder containing the sound
	@return Sound? - The sound if found, nil otherwise
]=]
function SoundRegistry:_ExtractSound(folder: Folder): Sound?
	return folder:FindFirstChildWhichIsA("Sound")
end

return SoundRegistry
