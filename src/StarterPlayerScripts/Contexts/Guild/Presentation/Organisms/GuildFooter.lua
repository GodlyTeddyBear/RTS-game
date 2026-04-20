--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

export type TGuildFooterProps = {
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local function GuildFooter(props: TGuildFooterProps)
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

return GuildFooter
