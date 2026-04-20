--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

--[=[
	@interface TQuestFooterProps
	Props for the quest footer component.
	@within QuestFooter
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
]=]
export type TQuestFooterProps = {
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	@class QuestFooter
	Footer bar component for quest screens.
	Provides visual closure to quest UI screens.
	@client
]=]
local function QuestFooter(props: TQuestFooterProps)
	return e(Frame, {
		Size = UDim2.fromScale(1, 0.08105),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		LayoutOrder = 4,
		ZIndex = 0,
	})
end

return QuestFooter
