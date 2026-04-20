--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)

local AnimationRigResolver = {}

local function _FindChildCaseInsensitive(parent: Instance, childName: string): Instance?
	local direct = parent:FindFirstChild(childName)
	if direct then
		return direct
	end

	local lowerName = childName:lower()
	for _, child in parent:GetChildren() do
		if child.Name:lower() == lowerName then
			return child
		end
	end

	return nil
end

local function _FindAnimationSlot(parent: Instance, childName: string): Animation?
	local slot = _FindChildCaseInsensitive(parent, childName)
	if not slot then
		return nil
	end

	if slot:IsA("Animation") then
		return slot
	end

	return slot:FindFirstChildWhichIsA("Animation", true)
end

local function _GetOrCreateAnimator(model: Model, humanoid: Humanoid, tag: string): Animator
	local existing = humanoid:FindFirstChildOfClass("Animator")
	if existing then
		return existing
	end

	warn(tag, model.Name, "- Animator not found on Humanoid, creating one")
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

function AnimationRigResolver.ResolveRig(model: Model, tag: string)
	return Promise.new(function(resolve, reject)
		local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
		if not humanoid then
			humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
		end
		if not humanoid or not humanoid:IsA("Humanoid") then
			reject(tag .. " " .. model.Name .. " - No Humanoid found")
			return
		end

		local animator = _GetOrCreateAnimator(model, humanoid, tag)
		resolve({
			Humanoid = humanoid,
			Animator = animator,
		})
	end)
end

function AnimationRigResolver.ResolveDirectAnimationsFolder(model: Model, animationsFolder: Folder, tag: string)
	return Promise.new(function(resolve, reject)
		if not animationsFolder or not animationsFolder:IsA("Folder") then
			reject(tag .. " " .. model.Name .. " - Animations folder is invalid")
			return
		end
		resolve(animationsFolder)
	end)
end

function AnimationRigResolver.ResolveObjectValueAnimationsFolder(model: Model, tag: string)
	return Promise.new(function(resolve, reject)
		local folderRef = model:FindFirstChild("AnimationsFolder") or model:WaitForChild("AnimationsFolder", 10)
		if not folderRef or not folderRef:IsA("ObjectValue") then
			reject(tag .. " " .. model.Name .. " - AnimationsFolder ObjectValue not found")
			return
		end

		local objectValue = folderRef :: ObjectValue
		if not objectValue.Value then
			local startTime = os.clock()
			while not objectValue.Value and os.clock() - startTime < 10 do
				objectValue.Changed:Wait()
			end
		end

		if not objectValue.Value or not objectValue.Value:IsA("Folder") then
			reject(tag .. " " .. model.Name .. " - AnimationsFolder.Value not set")
			return
		end

		resolve(objectValue.Value)
	end)
end

function AnimationRigResolver.WaitForHierarchyReplication(model: Model, animationsFolder: Folder, tag: string)
	return Promise.new(function(resolve, reject)
		local defaultFolder = animationsFolder:FindFirstChild("Default") or animationsFolder:WaitForChild("Default", 10)
		if not defaultFolder or not defaultFolder:IsA("Folder") then
			reject(tag .. " " .. model.Name .. " - Default animations folder not found")
			return
		end

		local idleSlot = _FindChildCaseInsensitive(defaultFolder, "idle") or defaultFolder:WaitForChild("idle", 10)
		if not idleSlot then
			reject(tag .. " " .. model.Name .. " - Default/idle animation slot not found")
			return
		end

		local animation = _FindAnimationSlot(defaultFolder, "idle")
		if not animation and not idleSlot:IsA("Animation") then
			idleSlot:WaitForChild("Animation", 10)
			animation = _FindAnimationSlot(defaultFolder, "idle")
		end

		if not animation then
			reject(tag .. " " .. model.Name .. " - Default/idle Animation not found")
			return
		end

		resolve(animationsFolder)
	end)
end

return AnimationRigResolver
