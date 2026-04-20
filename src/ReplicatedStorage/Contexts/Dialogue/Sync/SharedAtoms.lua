--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local DialogueTypes = require(ReplicatedStorage.Contexts.Dialogue.Types.DialogueTypes)

type TDialogueSnapshot = DialogueTypes.TDialogueSnapshot

local DEFAULT_SNAPSHOT: TDialogueSnapshot = table.freeze({
	Active = false,
	NPCId = nil,
	NPCName = nil,
	NodeId = nil,
	Text = nil,
	Options = {},
})

local function CreateDialogueStateAtom()
	return Charm.atom(DEFAULT_SNAPSHOT)
end

return {
	CreateDialogueStateAtom = CreateDialogueStateAtom,
	DEFAULT_SNAPSHOT = DEFAULT_SNAPSHOT,
}
