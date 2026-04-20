--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueNode = DialogueTypes.TDialogueNode

-- ----------------------------------------------------------------
-- INTRO + PREP — brewery framing and first-brew prompt
-- ----------------------------------------------------------------
local IntroAndPrepNodes: { [string]: TDialogueNode } = {
	ch3_intro = {
		Id = "ch3_intro",
		Text = "The Brewery is open. Place a Brew Kettle and craft your first potion. Potions go into shared inventory alongside your gear.",
		Options = {
			{
				Id = "ch3_intro_continue",
				Text = "What should I brew first?",
				NextNodeId = "ch3_brew_prompt",
			},
			{
				Id = "ch3_intro_leave",
				Text = "I will set it up now.",
				EndDialogue = true,
			},
		},
	},
	ch3_brew_prompt = {
		Id = "ch3_brew_prompt",
		Text = "Start with a Healing Brew or Defense Potion. Both are craftable from what you already produce. Stock a small supply before your next expedition.",
		Options = {
			{
				Id = "ch3_brew_prompt_brewer",
				Text = "Can I automate this?",
				NextNodeId = "ch3_brewer_intro",
			},
			{
				Id = "ch3_brew_prompt_leave",
				Text = "I will brew manually for now.",
				EndDialogue = true,
			},
		},
	},
	ch3_brewer_intro = {
		Id = "ch3_brewer_intro",
		Text = "Hire a Brewer and assign them a recipe. They run the same recipes you can craft manually, so your stock grows without your attention.",
		Options = {
			{
				Id = "ch3_brewer_intro_leave",
				Text = "I will hire one.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- LAUNCH — pre-run potion loadout reminder
-- ----------------------------------------------------------------
local LaunchNodes: { [string]: TDialogueNode } = {
	ch3_launch = {
		Id = "ch3_launch",
		Text = "Bring potions on this run. Slots are limited, so pick for the threat you expect. Use them at the right moment — not all at once.",
		Options = {
			{
				Id = "ch3_launch_leave",
				Text = "I am ready.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- OUTCOMES — per-result follow-up beats
-- ----------------------------------------------------------------
local OutcomeNodes: { [string]: TDialogueNode } = {
	ch3_outcome_victory = {
		Id = "ch3_outcome_victory",
		Text = "Good run. If your potions landed at the right moment, that is the loop working. Restock and keep refining your loadout.",
		Options = {
			{
				Id = "ch3_outcome_victory_leave",
				Text = "I will restock and go again.",
				EndDialogue = true,
			},
		},
	},
	ch3_outcome_defeat = {
		Id = "ch3_outcome_defeat",
		Text = "A setback. Rebuild your stock, adjust your potion selection, and re-equip before the next attempt.",
		Options = {
			{
				Id = "ch3_outcome_defeat_leave",
				Text = "I will restock and retry.",
				EndDialogue = true,
			},
		},
	},
	ch3_outcome_fled = {
		Id = "ch3_outcome_fled",
		Text = "Retreat was the right call. Consumed potions are spent. Restock, review your loadout, and launch again when ready.",
		Options = {
			{
				Id = "ch3_outcome_fled_leave",
				Text = "I will regroup first.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- Merge all sections into the final node map
-- ----------------------------------------------------------------
local Chapter3Nodes: { [string]: TDialogueNode } = {}

for id, node in IntroAndPrepNodes do
	Chapter3Nodes[id] = node
end

for id, node in LaunchNodes do
	Chapter3Nodes[id] = node
end

for id, node in OutcomeNodes do
	Chapter3Nodes[id] = node
end

return Chapter3Nodes
