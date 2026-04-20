--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useEffect = React.useEffect
local useRef = React.useRef

local CUSTOM_FONT = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular)

local COLOR_HP_BG = Color3.fromRGB(14, 14, 14)
local COLOR_HP_FILL = Color3.fromRGB(220, 60, 60)
local COLOR_NAME = Color3.fromRGB(255, 255, 255)

local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type TNPCHealthBillboardProps = {
	DisplayName: string,
	HP: number,
	MaxHP: number,
}

local function NPCHealthBillboard(props: TNPCHealthBillboardProps)
	local hpFill = math.clamp(if props.MaxHP > 0 then props.HP / props.MaxHP else 0, 0, 1)
	local fillRef = useRef(nil :: Frame?)

	-- Tween the fill frame's Size toward the new hpFill whenever it changes
	useEffect(function()
		local frame = fillRef.current
		if not frame then return end
		local tween = TweenService:Create(frame, TWEEN_INFO, {
			Size = UDim2.fromScale(hpFill, 1),
		})
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { hpFill } :: { any })

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.06, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		NameLabel = e("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = props.DisplayName,
			TextColor3 = COLOR_NAME,
			TextScaled = true,
			FontFace = CUSTOM_FONT,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),

		HPBar = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.28),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = COLOR_HP_BG,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),

			Fill = e("Frame", {
				Size = UDim2.fromScale(hpFill, 1),
				Position = UDim2.fromScale(0, 0.5),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = COLOR_HP_FILL,
				BorderSizePixel = 0,
				ref = fillRef,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
	})
end

return NPCHealthBillboard
