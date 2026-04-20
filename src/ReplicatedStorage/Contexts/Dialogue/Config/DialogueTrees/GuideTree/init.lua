--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueTree = DialogueTypes.TDialogueTree
type TDialogueNode = DialogueTypes.TDialogueNode

local dynamicRequire: any = require

local function _GetModuleOrder(moduleScript: ModuleScript): (number, number, string)
	local name = moduleScript.Name
	if name == "Root" then
		return 0, 0, name
	end

	local chapterNumber = string.match(name, "^Chapter(%d+)$")
	if chapterNumber then
		return 1, tonumber(chapterNumber) or 0, name
	end

	return 2, 0, name
end

local function _LoadDialogueNodeModules(): { { [string]: TDialogueNode } }
	local moduleScripts: { ModuleScript } = {}
	for _, child in ipairs(script:GetChildren()) do
		if child:IsA("ModuleScript") then
			table.insert(moduleScripts, child)
		end
	end

	table.sort(moduleScripts, function(a, b)
		local aGroup, aOrder, aName = _GetModuleOrder(a)
		local bGroup, bOrder, bName = _GetModuleOrder(b)
		if aGroup ~= bGroup then
			return aGroup < bGroup
		end
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		return aName < bName
	end)

	local loadedModules: { { [string]: TDialogueNode } } = {}
	for _, moduleScript in ipairs(moduleScripts) do
		table.insert(loadedModules, dynamicRequire(moduleScript))
	end
	return loadedModules
end

local function mergeNodes(...: { [string]: TDialogueNode }): { [string]: TDialogueNode }
	local merged: { [string]: TDialogueNode } = {}
	for _, chapter in { ... } do
		for id, node in chapter do
			merged[id] = node
		end
	end
	return merged
end

local loadedNodeModules = _LoadDialogueNodeModules()
local mergedNodes = mergeNodes(table.unpack(loadedNodeModules))

local GuideTree: TDialogueTree = {
	NPCId = "Eldric",
	DisplayName = "Eldric the Elder",
	RootNodeId = "root",
	Nodes = mergedNodes,
}

return GuideTree
