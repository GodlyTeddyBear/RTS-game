--!strict

local AnimationPresetHelpers = {}

function AnimationPresetHelpers.ToActionName(folderName: string): string
	return folderName:sub(1, 1):upper() .. folderName:sub(2)
end

function AnimationPresetHelpers.BuildSet(values: { string }): { [string]: boolean }
	local map: { [string]: boolean } = {}
	for _, value in values do
		map[value] = true
	end
	return table.freeze(map)
end

return table.freeze(AnimationPresetHelpers)
