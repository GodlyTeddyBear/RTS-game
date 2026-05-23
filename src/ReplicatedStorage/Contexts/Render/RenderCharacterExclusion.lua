--!strict

local Players = game:GetService("Players")

local RenderCharacterExclusion = {}

local function _IsCurrentPlayerCharacter(model: Model): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == model then
			return true
		end
	end

	return false
end

function RenderCharacterExclusion.IsExcludedInstance(instance: Instance): boolean
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
