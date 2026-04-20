--!strict

--[[
	DialogueHelpers - Pure data structure creation for dialogue trees

	Provides the same API as SimpleDialogue's CreateTree/CreateNode/CreateOption/CreateCondition
	but without any UI dependency. These functions create plain Lua tables that describe
	dialogue structure. The actual UI rendering is handled by React components.

	Usage:
		local DH = require(ReplicatedStorage.Contexts.NPC.DialogueHelpers)
		return function(flagReader, flagSetter, npcId)
			return DH.CreateTree({
				DH.CreateNode("Hello!", {
					DH.CreateOption("Hi!", nil, -1),
				}),
			})
		end
]]

export type DialogueOption = {
	Text: string,
	Next: number,
	Callback: (() -> ())?,
	DisplayText: string?,
	AutoAdvance: boolean?,
	ShouldEndDialogue: boolean?,
	Condition: (() -> boolean)?,
	FailCallback: (() -> ())?,
}

export type DialogueNode = {
	Text: string,
	Options: { DialogueOption },
	DialogueTree: { DialogueNode }?,
	Condition: (() -> boolean)?,
	FailCallback: (() -> ())?,
}

export type DialogueTree = { DialogueNode }

local DialogueHelpers = {}

--- Creates a dialogue option (player choice)
--- @param text string Display text for the option
--- @param callback function? Called when option is selected
--- @param next number? Next node index (-1 = end dialogue, 0 = stay, N = go to node N)
--- @param displayText string? NPC response text shown after selecting this option
--- @return table DialogueOption
function DialogueHelpers.CreateOption(
	text: string,
	callback: (() -> ())?,
	next: number?,
	displayText: string?
): DialogueOption
	return {
		Text = text,
		Next = next or -1,
		Callback = callback,
		DisplayText = displayText,
	}
end

--- Creates a dialogue node (NPC speech with player options)
--- @param text string NPC dialogue text
--- @param options table Available player responses
--- @return table DialogueNode
function DialogueHelpers.CreateNode(text: string, options: { DialogueOption }): DialogueNode
	return {
		Text = text,
		Options = options,
		DialogueTree = nil,
	}
end

--- Creates an auto-advancing node (no player input needed)
--- @param text string NPC dialogue text
--- @param callback function? Called when node auto-advances
--- @param shouldEndDialogue boolean? Whether to end dialogue after (default true)
--- @return table DialogueNode
function DialogueHelpers.CreateAutoNode(text: string, callback: (() -> ())?, shouldEndDialogue: boolean?): DialogueNode
	return {
		Text = text,
		Options = {
			{
				Text = "",
				Next = shouldEndDialogue ~= false and -1 or 0,
				Callback = callback,
				AutoAdvance = true,
				ShouldEndDialogue = shouldEndDialogue ~= false,
			},
		},
		DialogueTree = nil,
	}
end

--- Wraps a node or option with a condition function
--- @param condition boolean|function Condition to evaluate
--- @param item any The node or option to conditionally include
--- @param failCallback function? Called if condition fails
--- @return any The modified item with condition attached
function DialogueHelpers.CreateCondition<T>(condition: boolean | (() -> boolean), item: T, failCallback: (() -> ())?): T
	local conditionFunc: () -> boolean
	if typeof(condition) == "boolean" then
		local boolVal = condition
		conditionFunc = function()
			return boolVal
		end
	else
		conditionFunc = condition :: () -> boolean
	end

	local result = item :: any
	result.Condition = conditionFunc

	if failCallback then
		result.FailCallback = failCallback
	end

	return result
end

--- Wires nodes together into a complete dialogue tree
--- @param nodes table Array of dialogue nodes
--- @return table DialogueTree
function DialogueHelpers.CreateTree(nodes: { DialogueNode }): DialogueTree
	for _, node in ipairs(nodes) do
		node.DialogueTree = nodes
	end

	for _, node in ipairs(nodes) do
		if node.Options then
			for _, option in ipairs(node.Options) do
				if option.Next == nil then
					option.Next = -1
				end
			end
		end
	end

	return nodes
end

return DialogueHelpers
