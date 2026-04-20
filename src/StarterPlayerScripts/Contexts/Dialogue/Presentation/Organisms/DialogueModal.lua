--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useDialogueModalController =
	require(script.Parent.Parent.Parent.Application.Hooks.Animations.useDialogueModalController)
local DialogueModalView = require(script.Parent.DialogueModalView)

local e = React.createElement

--[=[
	@type TDialogueOption
	@within DialogueModal
	.Id string -- Unique identifier for the option
	.Text string -- Display text shown to the player
]=]
export type TDialogueOption = {
	Id: string,
	Text: string,
}

--[=[
	@interface TDialogueModalProps
	@within DialogueModal
	.NPCName string -- Name of the speaking NPC
	.DialogueText string -- Full dialogue text to display
	.Options { TDialogueOption } -- Available dialogue choices
	.OptionsCanvasHeight number -- Precomputed canvas height for the options scroll container
	.OnSelectOption (optionId: string) -> () -- Callback when player selects an option
	.OnClose () -> () -- Callback when player closes the dialogue
]=]
export type TDialogueModalProps = {
	NPCName: string,
	DialogueText: string,
	Options: { TDialogueOption },
	OptionsCanvasHeight: number,
	OnSelectOption: (optionId: string) -> (),
	OnClose: () -> (),
}

--[=[
	Animated dialogue modal wrapper. Calls the animation controller hook and
	delegates all rendering to DialogueModalView.
	@within DialogueModal
	@param props TDialogueModalProps
	@return Frame
	@client
]=]
local function DialogueModal(props: TDialogueModalProps)
	local controller = useDialogueModalController(props.DialogueText, props.Options)

	return e(DialogueModalView, {
		PanelRef = controller.panelRef,
		ScrollLayoutRef = controller.scrollLayoutRef,
		OptionScaleRefs = controller.optionScaleRefs,
		NPCName = props.NPCName,
		DisplayedText = controller.displayedDialogueText,
		Options = props.Options,
		OptionsCanvasHeight = props.OptionsCanvasHeight,
		PanelPosition = controller.panelTargetPosition,
		OnSelectOption = props.OnSelectOption,
		OnClose = props.OnClose,
	})
end

return DialogueModal
