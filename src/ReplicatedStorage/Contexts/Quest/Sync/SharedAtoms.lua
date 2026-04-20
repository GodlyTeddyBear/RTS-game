--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)
local QuestTypes = require(ReplicatedStorage.Contexts.Quest.Types.QuestTypes)

type TQuestState = QuestTypes.TQuestState

--- Server stores all players' quest states, indexed by UserId
export type TPlayerQuestStates = {
	[number]: TQuestState,
}

--- Creates server-side atom for all players' quest states
local function CreateServerAtom()
	return Charm.atom({} :: TPlayerQuestStates)
end

--- Creates client-side atom for the current player's quest state only
local function CreateClientAtom()
	return Charm.atom(nil :: TQuestState?)
end

return {
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
}
