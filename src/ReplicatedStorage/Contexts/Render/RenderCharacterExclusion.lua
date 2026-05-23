--!strict

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local EXPORTED_FOLDER_NAME = "Exported"

local RenderCharacterExclusion = {}

local function _IsCurrentPlayerCharacter(model: Model): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == model then
			return true
		end
	end

	return false
end

local function _IsExportedInstance(instance: Instance): boolean
	local exportedFolder = ServerStorage:FindFirstChild(EXPORTED_FOLDER_NAME)
	if exportedFolder == nil then
		return false
	end

	return instance:IsDescendantOf(exportedFolder)
end

function RenderCharacterExclusion.IsExcludedInstance(instance: Instance): boolean
	if _IsExportedInstance(instance) then
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
