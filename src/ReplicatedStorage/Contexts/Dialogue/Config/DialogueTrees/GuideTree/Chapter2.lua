--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueNode = DialogueTypes.TDialogueNode

-- ----------------------------------------------------------------
-- INTRO + PREP — chapter framing and readiness reminders
-- ----------------------------------------------------------------
local IntroAndPrepNodes: { [string]: TDialogueNode } = {
	ch2_intro = {
		Id = "ch2_intro",
		Text = "Expeditions are open now. If an adventurer dies, they are gone, and their equipped gear is lost. Prepare one adventurer before you launch.",
		Options = {
			{
				Id = "ch2_intro_continue",
				Text = "Understood. What is my first step?",
				NextNodeId = "ch2_prep",
			},
		},
	},
	ch2_prep = {
		Id = "ch2_prep",
		Text = "Pick one adventurer and give them a basic loadout. Then start the first route and watch the outcome.",
		Options = {
			{
				Id = "ch2_prep_gear_question",
				Text = "What loadout should I bring?",
				NextNodeId = "ch2_prep_gear",
			},
			{
				Id = "ch2_prep_leave",
				Text = "I will prepare now.",
				EndDialogue = true,
			},
		},
	},
	ch2_prep_gear = {
		Id = "ch2_prep_gear",
		Text = "Do not go in empty-handed. Equip a minimum combat loadout, then launch when you are ready.",
		Options = {
			{
				Id = "ch2_prep_gear_leave",
				Text = "I will gear up first.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- LAUNCH — pre-run confirmation beat
-- ----------------------------------------------------------------
local LaunchNodes: { [string]: TDialogueNode } = {
	ch2_launch = {
		Id = "ch2_launch",
		Text = "Launch the route once your adventurer is selected and equipped. We only need one clean Victory to secure this chapter.",
		Options = {
			{
				Id = "ch2_launch_leave",
				Text = "I am heading out.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- OUTCOMES — per-result follow-up beats
-- ----------------------------------------------------------------
local OutcomeNodes: { [string]: TDialogueNode } = {
	ch2_outcome_victory = {
		Id = "ch2_outcome_victory",
		Text = "Well fought. That Victory proves your expedition loop is stable. Keep rebuilding and push into the next systems.",
		Options = {
			{
				Id = "ch2_outcome_victory_leave",
				Text = "I will keep the momentum.",
				EndDialogue = true,
			},
		},
	},
	ch2_outcome_defeat = {
		Id = "ch2_outcome_defeat",
		Text = "A hard loss. Rebuild through production and sales, re-equip a new adventurer, and try again.",
		Options = {
			{
				Id = "ch2_outcome_defeat_leave",
				Text = "I will rebuild and reattempt.",
				EndDialogue = true,
			},
		},
	},
	ch2_outcome_fled = {
		Id = "ch2_outcome_fled",
		Text = "Retreat was the right call. Re-prep your adventurer, tighten your loadout, and launch another attempt.",
		Options = {
			{
				Id = "ch2_outcome_fled_leave",
				Text = "I will regroup first.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- Merge all sections into the final node map
-- ----------------------------------------------------------------
local Chapter2Nodes: { [string]: TDialogueNode } = {}

for id, node in IntroAndPrepNodes do
	Chapter2Nodes[id] = node
end

for id, node in LaunchNodes do
	Chapter2Nodes[id] = node
end

for id, node in OutcomeNodes do
	Chapter2Nodes[id] = node
end

return Chapter2Nodes
