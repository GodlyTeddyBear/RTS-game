--!strict

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderVisualReplacementConfig =
	require(ReplicatedStorage.Contexts.Render.Config.RenderVisualReplacementConfig)

local RenderCharacterExclusion = {}

local function _IsCurrentPlayerCharacter(model: Model): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == model then
			return true
		end
	end

	return false
end

local function _IsHiddenInstance(instance: Instance): boolean
	local hiddenFolder = ServerStorage:FindFirstChild(RenderVisualReplacementConfig.HiddenFolderName)
	if hiddenFolder == nil then
		return false
	end

	return instance:IsDescendantOf(hiddenFolder)
end

local function _IsVisualReplacementManagedInstance(instance: Instance): boolean
	if RenderVisualReplacementConfig.IsInAccessoryTree(instance) then
		return true
	end

	local current = instance

	while current ~= nil do
		if RenderVisualReplacementConfig.GetVisualReplacementId(current) ~= nil then
			return true
		end

		current = current.Parent
	end

	return false
end

function RenderCharacterExclusion.IsExcludedInstance(instance: Instance): boolean
	if _IsHiddenInstance(instance) then
		return true
	end
	if _IsVisualReplacementManagedInstance(instance) then
		return true
	end

	local current = instance

	while current ~= nil do
		if current:IsA("Model") and _IsCurrentPlayerCharacter(current) then
			return true
		end

		current = current.Parent
	end

	return false
end

return table.freeze(RenderCharacterExclusion)
