--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)

--[=[
	@interface TQuestHeaderProps
	Props for the quest board header component.
	@within QuestHeader
	.OnBack () -> () -- Called when back button is pressed
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
]=]
export type TQuestHeaderProps = {
	OnBack: () -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	@class QuestHeader
	Header component for the quest board screen.
	Displays "Quest Board" title and back button.
	@client
]=]
local function QuestHeader(props: TQuestHeaderProps)
	return e(ScreenHeader, {
		Title = "Quest Board",
		OnBack = props.OnBack,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
	})
end

return QuestHeader
