--!strict

--[[
	AnimationRegistry - Load Animations with Class-Specific Fallback

	Provides a registry for loading combat animations with automatic fallback
	from class-specific animations to Default animations.

	Folder Structure:
		Animations/
		├── BasicAttack/
		│   ├── Default/Animation
		│   ├── Warrior/Animation
		│   └── Mage/Animation
		├── Skills/
		│   ├── Slash/
		│   │   ├── Default/Animation
		│   │   └── Warrior/Animation
		│   └── Fireball/
		│       ├── Default/Animation
		│       └── Mage/Animation
		└── Defend/
		    ├── Default/Animation
		    └── [Class]/Animation

	Usage:
		local animationRegistry = AnimationRegistry.new(Assets.Animations)
		local warriorSlash = animationRegistry:Get("Skills/Slash", "Warrior")
		local defaultDefend = animationRegistry:Get("Defend")  -- Uses Default
]]

local AnimationRegistry = {}
AnimationRegistry.__index = AnimationRegistry

--[=[
	Creates a new AnimationRegistry.

	@param animationsFolder Folder - The root Animations folder
	@return AnimationRegistry - New registry instance
]=]
function AnimationRegistry.new(animationsFolder: Folder)
	assert(animationsFolder, "AnimationRegistry requires a valid Animations folder")
	assert(animationsFolder:IsA("Folder"), "AnimationRegistry requires a Folder instance")

	local self = setmetatable({}, AnimationRegistry)
	self._folder = animationsFolder
	self._cache = {}

	return self
end

--[=[
	Gets an animation with class-specific fallback to Default.

	Lookup order:
	1. Try {actionType}/{class}/Animation
	2. If missing, try {actionType}/Default/Animation
	3. If still missing, throw error

	@param actionType string - The action path (e.g., "Skills/Slash", "BasicAttack")
	@param class string? - Optional class name (defaults to "Default")
	@return Animation - The animation instance

	Example:
		local warriorSlash = registry:Get("Skills/Slash", "Warrior")
		local defaultDefend = registry:Get("Defend")  -- Uses Default
]=]
function AnimationRegistry:Get(actionType: string, class: string?): Animation
	local className = class or "Default"
	local cacheKey = actionType .. "/" .. className

	-- Check cache first for performance
	if self._cache[cacheKey] then
		return self._cache[cacheKey]
	end

	-- Try class-specific animation
	local animation = self:_TryGetAnimation(actionType, className)
	if animation then
		self._cache[cacheKey] = animation
		return animation
	end

	-- Fallback to Default if class-specific not found
	if className ~= "Default" then
		animation = self:_TryGetAnimation(actionType, "Default")
		if animation then
			self._cache[cacheKey] = animation
			return animation
		end
	end

	error("Animation not found: " .. actionType .. "/" .. className)
end

--[=[
	Checks if an animation exists with class-specific fallback.

	@param actionType string - The action path
	@param class string? - Optional class name (defaults to "Default")
	@return boolean - True if animation exists

	Example:
		if registry:Exists("Skills/Slash", "Warrior") then
			local animation = registry:Get("Skills/Slash", "Warrior")
		end
]=]
function AnimationRegistry:Exists(actionType: string, class: string?): boolean
	local success = pcall(function()
		self:Get(actionType, class)
	end)
	return success
end

--[=[
	Gets all class-specific animations for a given action type.

	@param actionType string - The action path (e.g., "Skills/Slash")
	@return {[string]: Animation} - Map of class names to animations

	Example:
		local slashAnimations = registry:GetAll("Skills/Slash")
		-- Returns: { Default = Animation, Warrior = Animation, Rogue = Animation }
]=]
function AnimationRegistry:GetAll(actionType: string): { [string]: Animation }
	local results = {}
	local actionFolder = self:_NavigateToFolder(actionType)
	if not actionFolder then
		return results
	end

	-- Iterate through class folders
	for _, classFolder in ipairs(actionFolder:GetChildren()) do
		if not classFolder:IsA("Folder") then
			continue
		end

		local animation = self:_ExtractAnimation(classFolder)
		if animation then
			results[classFolder.Name] = animation
		end
	end

	return results
end

--[=[
	Navigates to a folder using a path string.

	@private
	@param path string - The folder path (e.g., "Skills/Slash")
	@return Folder? - The folder if found, nil otherwise
]=]
function AnimationRegistry:_NavigateToFolder(path: string): Folder?
	local parts = string.split(path, "/")
	local current: Instance = self._folder

	for _, part in ipairs(parts) do
		local next = current:FindFirstChild(part)
		if not next then
			return nil
		end
		current = next
	end

	return current :: Folder
end

--[=[
	Gets the animation folder for a specific action and class.

	@private
	@param actionType string - The action path (e.g., "Skills/Slash")
	@param class string - The class name (e.g., "Warrior", "Default")
	@return Folder? - The class folder if found, nil otherwise
]=]
function AnimationRegistry:_GetAnimationFolder(actionType: string, class: string): Folder?
	local actionFolder = self:_NavigateToFolder(actionType)
	if not actionFolder then
		return nil
	end

	local classFolder = actionFolder:FindFirstChild(class)
	if classFolder then
		return classFolder :: Folder
	end
	return nil
end

--[=[
	Extracts an Animation instance from a folder.

	@private
	@param folder Folder - The folder containing the animation
	@return Animation? - The animation if found, nil otherwise
]=]
function AnimationRegistry:_ExtractAnimation(folder: Folder): Animation?
	return folder:FindFirstChildWhichIsA("Animation")
end

--[=[
	Attempts to get an animation from a specific action and class.
	Combines folder navigation and animation extraction.

	@private
	@param actionType string - The action path
	@param class string - The class name
	@return Animation? - The animation if found, nil otherwise
]=]
function AnimationRegistry:_TryGetAnimation(actionType: string, class: string): Animation?
	local animationFolder = self:_GetAnimationFolder(actionType, class)
	if not animationFolder then
		return nil
	end
	return self:_ExtractAnimation(animationFolder)
end

return AnimationRegistry
