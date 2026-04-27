--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local AnimationPoseFilter = require(script.Parent.AnimationPoseFilter)

type TAnimationPreset = Types.TAnimationPreset
type TAnimInfo = Types.TAnimInfo
type TActionEntry = Types.TActionEntry
type TLoadedClips = Types.TLoadedClips

local function _ToActionName(folderName: string): string
	return folderName:sub(1, 1):upper() .. folderName:sub(2)
end

local AnimationClipLoader = {
	ToActionName = _ToActionName,
}

local POSE_TO_FOLDER = table.freeze({
	Run = "run",
	Idle = "idle",
	Walk = "walk",
	GettingUp = "idle",
	FallingDown = "fall",
	Freefall = "fall",
	FellOff = "fall",
	Jumping = "jump",
	Landed = "idle",
	Seated = "sit",
	Swimming = "swim",
	Climbing = "climb",
	SwimIdle = "swimidle",
})

local function _LoadTrack(
	animator: Animator,
	animation: Animation,
	priority: Enum.AnimationPriority,
	looped: boolean
): TAnimInfo
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return { anim = track, weight = 10 } :: TAnimInfo
end

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

local function _FindAnimationInSlot(slot: Instance?): Animation?
	if not slot then
		return nil
	end

	if slot:IsA("Animation") then
		return slot
	end

	return slot:FindFirstChildWhichIsA("Animation", true)
end

local function _FindVariantAnimation(animationsFolder: Folder, variant: string, folderName: string): Animation?
	local variantFolder = animationsFolder:FindFirstChild(variant)
	if not variantFolder then
		return nil
	end

	return _FindAnimationInSlot(_FindChildCaseInsensitive(variantFolder, folderName))
end

local function _GetDefaultClip(registry: any, animationsFolder: Folder, folderName: string): Animation?
	local defaultAnimation = _FindVariantAnimation(animationsFolder, "Default", folderName)
	if defaultAnimation then
		return defaultAnimation
	end

	if registry:Exists("Default", folderName) then
		return registry:Get("Default", folderName)
	end

	return nil
end

local function _ResolveFolderNameForPose(pose: string, preset: TAnimationPreset): string?
	for _, entry in preset.CorePoseFolders do
		if entry.Pose == pose then
			return entry.Folder
		end
	end

	return POSE_TO_FOLDER[pose]
end

function AnimationClipLoader.GetVariantClip(
	model: Model,
	registry: any,
	animationsFolder: Folder,
	variant: string,
	folderName: string,
	preset: TAnimationPreset
): Animation?
	local tag = preset.Tag
	local useVariant = variant ~= "Default"

	if useVariant then
		local variantAnimation = _FindVariantAnimation(animationsFolder, variant, folderName)
		if variantAnimation then
			return variantAnimation
		end
		if registry:Exists(variant, folderName) then
			return registry:Get(variant, folderName)
		end
	end

	local defaultAnimation = _FindVariantAnimation(animationsFolder, "Default", folderName)
	if defaultAnimation then
		return defaultAnimation
	end
	if registry:Exists("Default", folderName) then
		return registry:Get("Default", folderName)
	end

	if preset.WarnOnMissingAnimation == true then
		warn(tag, model.Name, "- no animation found for folder:", folderName, "(variant:", variant .. ")")
	end
	return nil
end

function AnimationClipLoader.ReconcileMissingCoreAnimations(
	model: Model,
	registry: any,
	animator: Animator,
	animationsFolder: Folder,
	coreAnimations: { [string]: { TAnimInfo } },
	preset: TAnimationPreset
)
	for _, pose in preset.AllPoses do
		if coreAnimations[pose] ~= nil or not AnimationPoseFilter.IsPoseAllowed(preset, pose) then
			continue
		end

		local folderName = _ResolveFolderNameForPose(pose, preset)
		if type(folderName) ~= "string" or folderName == "" then
			if preset.WarnOnMissingPose == true then
				warn(preset.Tag, model.Name, "- pose", pose, ": no folder mapping for reconcile")
			end
			continue
		end

		local defaultAnimation = _GetDefaultClip(registry, animationsFolder, folderName)
		if defaultAnimation then
			coreAnimations[pose] = {
				_LoadTrack(animator, defaultAnimation, Enum.AnimationPriority.Core, true),
			}
		elseif preset.WarnOnMissingPose == true then
			warn(preset.Tag, model.Name, "- pose", pose, ": missing in Default/", folderName)
		end
	end
end

function AnimationClipLoader.BuildCoreAnimations(
	model: Model,
	registry: any,
	variant: string,
	animator: Animator,
	animationsFolder: Folder,
	preset: TAnimationPreset
): { [string]: { TAnimInfo } }
	local coreAnimations: { [string]: { TAnimInfo } } = {}

	for _, entry in preset.CorePoseFolders do
		local animation = AnimationClipLoader.GetVariantClip(model, registry, animationsFolder, variant, entry.Folder, preset)
		if animation then
			coreAnimations[entry.Pose] = {
				_LoadTrack(animator, animation, Enum.AnimationPriority.Core, true),
			}
		end
	end

	return coreAnimations
end

function AnimationClipLoader.EnsurePoseFallbacks(
	model: Model,
	coreAnimations: { [string]: any },
	preset: TAnimationPreset
)
	for _, pose in preset.AllPoses do
		if not AnimationPoseFilter.IsPoseAllowed(preset, pose) then
			continue
		end

		if coreAnimations[pose] then
			continue
		end

		local fallbackPose = preset.PoseFallbacks[pose]
		if fallbackPose and AnimationPoseFilter.IsPoseAllowed(preset, fallbackPose) and coreAnimations[fallbackPose] then
			coreAnimations[pose] = coreAnimations[fallbackPose]
		elseif preset.WarnOnMissingPose == true then
			if fallbackPose then
				warn(preset.Tag, model.Name, "- pose", pose, ": NO FALLBACK (", fallbackPose, "also missing)")
			else
				warn(preset.Tag, model.Name, "- pose", pose, ": MISSING (no fallback defined)")
			end
		end
	end
end

function AnimationClipLoader.BuildActionsAndEmotes(
	model: Model,
	registry: any,
	variant: string,
	animator: Animator,
	animationsFolder: Folder,
	preset: TAnimationPreset
): ({ TActionEntry }, { TActionEntry })
	local actions: { TActionEntry } = {}
	local emotes: { TActionEntry } = {}
	local coreFolders: { [string]: boolean } = {}

	for _, entry in preset.CorePoseFolders do
		coreFolders[entry.Folder:lower()] = true
	end

	local sourceFolder = animationsFolder:FindFirstChild(variant) or animationsFolder:FindFirstChild("Default")
	if not sourceFolder then
		return actions, emotes
	end

	for _, child in sourceFolder:GetChildren() do
		local slotAnimation = _FindAnimationInSlot(child)
		if not slotAnimation then
			continue
		end

		local lookupName = child.Name
		if preset.ActionNameTransform then
			lookupName = child.Name:lower()
		end

		if coreFolders[lookupName:lower()] then
			continue
		end

		local animation = AnimationClipLoader.GetVariantClip(model, registry, animationsFolder, variant, lookupName, preset)
		if not animation then
			continue
		end

		local actionName = if preset.ActionNameTransform then preset.ActionNameTransform(lookupName) else lookupName
		local entry: TActionEntry = {
			Action = actionName,
			AnimInfos = {
				_LoadTrack(animator, animation, Enum.AnimationPriority.Action, false),
			},
		}

		if preset.EnableEmotes == true and preset.EmoteFolders and preset.EmoteFolders[lookupName:lower()] then
			table.insert(emotes, entry)
		else
			table.insert(actions, entry)
		end
	end

	return actions, emotes
end

function AnimationClipLoader.Load(
	model: Model,
	registry: any,
	variant: string,
	animator: Animator,
	animationsFolder: Folder,
	preset: TAnimationPreset
): TLoadedClips
	local coreAnimations = AnimationClipLoader.BuildCoreAnimations(model, registry, variant, animator, animationsFolder, preset)
	AnimationClipLoader.ReconcileMissingCoreAnimations(model, registry, animator, animationsFolder, coreAnimations, preset)
	AnimationClipLoader.EnsurePoseFallbacks(model, coreAnimations, preset)

	local actions, emotes = AnimationClipLoader.BuildActionsAndEmotes(
		model,
		registry,
		variant,
		animator,
		animationsFolder,
		preset
	)

	return {
		CoreAnimations = coreAnimations,
		Actions = actions,
		Emotes = emotes,
	}
end

return AnimationClipLoader
