--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueNode = DialogueTypes.TDialogueNode
type TDialogueNodeOption = DialogueTypes.TDialogueNodeOption

local function mergeOptionGroups(...: { TDialogueNodeOption }): { TDialogueNodeOption }
	local merged: { TDialogueNodeOption } = {}
	for _, group in { ... } do
		for _, option in group do
			table.insert(merged, option)
		end
	end
	return merged
end

local Chapter3RootOptions: { TDialogueNodeOption } = {
	{
		Id = "root_to_ch3_victory",
		Text = "We won an expedition with potions.",
		RequiredFlags = { Ch3_OutcomeVictory = true },
		NextNodeId = "ch3_outcome_victory",
	},
	{
		Id = "root_to_ch3_defeat",
		Text = "We lost an expedition.",
		RequiredFlags = { Ch3_OutcomeDefeat = true, Ch3_OutcomeVictory = false },
		NextNodeId = "ch3_outcome_defeat",
	},
	{
		Id = "root_to_ch3_fled",
		Text = "We had to retreat.",
		RequiredFlags = { Ch3_OutcomeFled = true, Ch3_OutcomeDefeat = false, Ch3_OutcomeVictory = false },
		NextNodeId = "ch3_outcome_fled",
	},
	{
		Id = "root_to_ch3_launch",
		Text = "We are ready to launch with potions.",
		RequiredFlags = {
			Ch3_IntroSeen = true,
			Ch3_ExpeditionLaunched = false,
			Ch3_OutcomeVictory = false,
		},
		NextNodeId = "ch3_launch",
	},
	{
		Id = "root_to_ch3_intro",
		Text = "Tell me about the Brewery.",
		RequiredFlags = { Ch3_IntroSeen = true, Ch3_ExpeditionLaunched = false },
		NextNodeId = "ch3_intro",
	},
	{
		Id = "root_to_ch3_prep",
		Text = "Remind me about potions.",
		RequiredFlags = { Ch3_IntroSeen = true, Ch3_OutcomeVictory = false },
		NextNodeId = "ch3_brew_prompt",
	},
}

local Chapter2RootOptions: { TDialogueNodeOption } = {
	{
		Id = "root_to_ch2_victory",
		Text = "We won an expedition.",
		RequiredFlags = { Ch2_FirstVictory = true },
		NextNodeId = "ch2_outcome_victory",
	},
	{
		Id = "root_to_ch2_defeat",
		Text = "We lost an expedition.",
		RequiredFlags = { Ch2_OutcomeDefeat = true, Ch2_FirstVictory = false },
		NextNodeId = "ch2_outcome_defeat",
	},
	{
		Id = "root_to_ch2_fled",
		Text = "We had to retreat.",
		RequiredFlags = { Ch2_OutcomeFled = true, Ch2_OutcomeDefeat = false, Ch2_FirstVictory = false },
		NextNodeId = "ch2_outcome_fled",
	},
	{
		Id = "root_to_ch2_launch",
		Text = "We are ready to launch.",
		RequiredFlags = {
			Ch2_ExpeditionLaunched = false,
			Ch2_IntroSeen = true,
			Ch2_FirstVictory = false,
		},
		NextNodeId = "ch2_launch",
	},
	{
		Id = "root_to_ch2_intro",
		Text = "Brief me on expeditions.",
		RequiredFlags = { Ch2_IntroSeen = true, Ch2_ExpeditionLaunched = false },
		NextNodeId = "ch2_intro",
	},
	{
		Id = "root_to_ch2_prep",
		Text = "Remind me how to prepare.",
		RequiredFlags = { Ch2_IntroSeen = true, Ch2_FirstVictory = false },
		NextNodeId = "ch2_prep",
	},
}

local Chapter1RootOptions: { TDialogueNodeOption } = {
	{
		Id = "root_to_smelter_ready",
		Text = "Tell me about the smelter.",
		RequiredFlags = { Ch1_SmelterAffordable = true },
		NextNodeId = "smelter_ready",
	},
	{
		Id = "root_to_charcoal",
		Text = "I have charcoal now.",
		RequiredFlags = { Ch1_CharcoalCrafted = true, Ch1_SmelterAffordable = false },
		NextNodeId = "charcoal_done",
	},
	{
		Id = "root_to_lumberjack",
		Text = "I hired a lumberjack.",
		RequiredFlags = { Ch1_LumberjackHired = true, Ch1_CharcoalCrafted = false },
		NextNodeId = "lumberjack_done",
	},
	{
		Id = "root_to_miner",
		Text = "I hired a miner.",
		RequiredFlags = { Ch1_MinerHired = true, Ch1_LumberjackHired = false },
		NextNodeId = "miner_done",
	},
	{
		Id = "root_to_shop",
		Text = "What should I do first?",
		RequiredFlags = { Ch1_ShopOpen = true, Ch1_MinerHired = false },
		NextNodeId = "shop_open",
	},
	{
		Id = "root_intro",
		Text = "Who are you?",
		RequiredFlags = { Ch1_ShopOpen = false },
		NextNodeId = "intro",
	},
}

local SharedRootOptions: { TDialogueNodeOption } = {
	{
		Id = "root_reminder",
		Text = "Remind me what I should be doing.",
		NextNodeId = "reminder",
	},
	{
		Id = "root_leave",
		Text = "Nothing right now.",
		EndDialogue = true,
	},
}

local RootNodes: { [string]: TDialogueNode } = {
	root = {
		Id = "root",
		Text = "Ah, there you are. What can I help you with?",
		Options = mergeOptionGroups(Chapter3RootOptions, Chapter2RootOptions, Chapter1RootOptions, SharedRootOptions),
	},
}

return RootNodes
