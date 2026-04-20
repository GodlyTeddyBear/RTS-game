--!strict

local DialogueTypes = require(script.Parent.Parent.Parent.Parent.Types.DialogueTypes)

type TDialogueNode = DialogueTypes.TDialogueNode

--[[
	Chapter 1 — Eldric the Elder: Getting Started.

	Milestone flags (set externally by DialogueMilestoneService):
		Ch1_ShopOpen          — player has opened the shop for the first time
		Ch1_MinerHired        — player has hired a miner
		Ch1_LumberjackHired   — player has hired a lumberjack
		Ch1_CharcoalCrafted   — player has crafted charcoal at least once
		Ch1_SmelterAffordable — player has enough gold to place the smelter

	Flags set by dialogue itself:
		HasMet_Eldric         — set automatically by StartDialogueSession on first talk
		Ch1_SmelterTalkDone   — set when the player finishes the smelter briefing
]]

-- ----------------------------------------------------------------
-- INTRO — before the shop is open
-- ----------------------------------------------------------------
local IntroNodes: { [string]: TDialogueNode } = {
	intro = {
		Id = "intro",
		Text = "I am Eldric — elder of this village and keeper of the guild records. You have taken on the old shop at the edge of the lot. It has been empty too long. Open it up, start selling, and this village will breathe again.",
		Options = {
			{
				Id = "intro_continue",
				Text = "I will get it running.",
				NextNodeId = "intro_2",
			},
		},
	},
	intro_2 = {
		Id = "intro_2",
		Text = "Good. Start simple — craft what you can and sell it in the village. The market and the villagers will both buy. Once you have gold coming in, hire a worker or two. Come back when the shop is open.",
		Options = {
			{
				Id = "intro_leave",
				Text = "Understood.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- MILESTONES — one node (or chain) per progression step
-- ----------------------------------------------------------------
local MilestoneNodes: { [string]: TDialogueNode } = {
	shop_open = {
		Id = "shop_open",
		Text = "The shop is open — that is the first step. Now you need workers on the lot. Two tracks keep gold flowing: a miner to dig ore, and a lumberjack to fell trees. Hire the miner first — ore sells well and the gold will come faster.",
		Options = {
			{
				Id = "shop_open_leave",
				Text = "Got it — miner first.",
				EndDialogue = true,
			},
		},
	},

	miner_done = {
		Id = "miner_done",
		Text = "A miner on the lot — good. Ore will start coming in. But do not neglect the wood line. Hire a lumberjack next. Wood feeds the charcoal machine, and charcoal... you will need it soon enough.",
		Options = {
			{
				Id = "miner_done_leave",
				Text = "A lumberjack next. I understand.",
				EndDialogue = true,
			},
		},
	},

	lumberjack_done = {
		Id = "lumberjack_done",
		Text = "Both workers on the lot. Now, run wood through the machine on the lot — it produces charcoal. You must craft charcoal. It is not optional. When the time comes, nothing will smelt without it.",
		Options = {
			{
				Id = "lumberjack_done_leave",
				Text = "Charcoal. I will make it.",
				EndDialogue = true,
			},
		},
	},

	charcoal_done = {
		Id = "charcoal_done",
		Text = "You have charcoal in stock. Then you are ready to hear this: there is a forge hearth — a smelter — that can be placed on your lot. It turns ore into ingots and plates, worth far more than raw ore. It is expensive. Save your gold.",
		Options = {
			{
				Id = "charcoal_done_ask_cost",
				Text = "How much?",
				NextNodeId = "charcoal_done_cost",
			},
		},
	},
	charcoal_done_cost = {
		Id = "charcoal_done_cost",
		Text = "Enough that you will feel it. Keep both workers running, sell steadily, and take guild commissions if they come up — they pay well. Come back when you can afford it. I will know.",
		Options = {
			{
				Id = "charcoal_done_cost_leave",
				Text = "I will save up.",
				EndDialogue = true,
			},
		},
	},

	smelter_ready = {
		Id = "smelter_ready",
		Text = "You have the gold. The forge hearth is within reach. Place it on your lot and light it — but remember: it will not run without charcoal. Keep the wood line going or the smelter goes cold.",
		Options = {
			{
				Id = "smelter_ready_confirm",
				Text = "I will keep charcoal stocked.",
				NextNodeId = "smelter_ready_2",
			},
		},
	},
	smelter_ready_2 = {
		Id = "smelter_ready_2",
		Text = "Then go. Place it. This village has not seen a working smelter in a long time. What it produces... well. There are things beyond this lot worth thinking about. One step at a time.",
		Options = {
			{
				Id = "smelter_ready_leave",
				Text = "Time to place it.",
				EndDialogue = true,
				SetFlags = { Ch1_SmelterTalkDone = true },
			},
		},
	},
}

-- ----------------------------------------------------------------
-- UTILITY — repeatable, milestone-aware nodes
-- ----------------------------------------------------------------
local UtilityNodes: { [string]: TDialogueNode } = {
	reminder = {
		Id = "reminder",
		Text = "We need charcoal before the hearth will light. Keep the wood line running.",
		Options = {
			{
				Id = "reminder_charcoal_context",
				Text = "What else?",
				RequiredFlags = { Ch1_CharcoalCrafted = true },
				NextNodeId = "reminder_post_charcoal",
			},
			{
				Id = "reminder_pre_charcoal",
				Text = "Got it.",
				RequiredFlags = { Ch1_CharcoalCrafted = false },
				EndDialogue = true,
			},
		},
	},
	reminder_post_charcoal = {
		Id = "reminder_post_charcoal",
		Text = "Save gold for the forge hearth. Both workers running, sell steadily. Take commissions when they appear.",
		Options = {
			{
				Id = "reminder_post_charcoal_leave",
				Text = "Understood.",
				EndDialogue = true,
			},
		},
	},
}

-- ----------------------------------------------------------------
-- Merge all sections into the final node map
-- ----------------------------------------------------------------
local Chapter1Nodes: { [string]: TDialogueNode } = {}

for id, node in IntroNodes do
	Chapter1Nodes[id] = node
end

for id, node in MilestoneNodes do
	Chapter1Nodes[id] = node
end

for id, node in UtilityNodes do
	Chapter1Nodes[id] = node
end

return Chapter1Nodes