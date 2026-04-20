--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Border = require(script.Parent.Parent.Parent.Parent.App.Config.BorderTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local OverlayContext = require(script.Parent.Parent.Parent.Infrastructure.OverlayContext)

--[=[
	@class ActionDropdown
	Dropdown button component with portal overlay, item locking, and hover animation.
	@client
]=]

--[=[
	@interface TDropdownItem
	@within ActionDropdown
	.Id string -- Unique item identifier
	.DisplayName string -- Human-readable display name
	.IsLocked boolean? -- Whether the item is locked/unavailable
]=]

export type TDropdownItem = {
	Id: string,
	DisplayName: string,
	IsLocked: boolean?,
}

--[=[
	@interface TActionDropdownProps
	@within ActionDropdown
	.TriggerLabel string -- Trigger button text
	.ButtonGradient ColorSequence -- Trigger button gradient
	.ButtonStroke ColorSequence -- Trigger button stroke
	.LabelStroke Color3 -- Text stroke color
	.DropdownStroke ColorSequence -- Dropdown panel stroke
	.DropdownGradient ColorSequence? -- Dropdown panel background gradient (optional)
	.SelectedId string? -- Currently selected item ID
	.Items { TDropdownItem } -- List of dropdown items
	.OnSelect (itemId: string) -> () -- Callback when item is selected
	.Size UDim2? -- Component size (optional)
	.Position UDim2? -- Component position (optional)
	.AnchorPoint Vector2? -- Anchor point (optional)
	.LayoutOrder number? -- Layout order (optional)
]=]

export type TActionDropdownProps = {
	TriggerLabel: string,
	ButtonGradient: ColorSequence,
	ButtonStroke: ColorSequence,
	LabelStroke: Color3,
	DropdownStroke: ColorSequence,
	DropdownGradient: ColorSequence?,
	SelectedId: string?,
	Items: { TDropdownItem },
	OnSelect: (itemId: string) -> (),
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

-- Internal menu item component (rendered per-item so useHoverSpring works individually)
type TDropdownMenuItemProps = {
	Item: TDropdownItem,
	IsSelected: boolean,
	LayoutOrder: number,
	ButtonGradient: ColorSequence,
	ButtonStroke: ColorSequence,
	LabelStroke: Color3,
	OnSelect: () -> (),
}

-- Visual constants for locked items
local LOCKED_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 40)),
})
local LOCKED_STROKE = ColorSequence.new(Color3.fromRGB(80, 80, 80))
local LOCKED_TEXT_COLOR = Color3.fromRGB(120, 120, 120)
local LOCKED_STROKE_COLOR = Color3.fromRGB(60, 60, 60)

-- Render a single dropdown menu item with locked state styling
-- Render a single dropdown menu item with locked state styling
local function DropdownMenuItem(props: TDropdownMenuItemProps)
	local buttonRef = useRef(nil :: TextButton?)
	local isLocked = props.Item.IsLocked == true
	-- Locked items don't animate on hover
	local hover = useHoverSpring(buttonRef, if isLocked then nil else AnimationTokens.Interaction.DropdownItem)

	local gradient = if isLocked then LOCKED_GRADIENT else props.ButtonGradient
	local stroke = if isLocked then LOCKED_STROKE else props.ButtonStroke
	local textColor = if isLocked then LOCKED_TEXT_COLOR else Color3.new(1, 1, 1)
	local textStroke = if isLocked then LOCKED_STROKE_COLOR else props.LabelStroke
	-- Add lock emoji to locked items, checkmark to selected items
	local label = if isLocked
		then "\u{1F512} " .. props.Item.DisplayName
		else props.Item.DisplayName .. (if props.IsSelected then " \u{2713}" else "")

	return e("TextButton", {
		ref = buttonRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, 35),
		LayoutOrder = props.LayoutOrder,
		Text = "",
		TextSize = 1,
		AutoButtonColor = not isLocked,
		[React.Event.MouseEnter] = if not isLocked then hover.onMouseEnter else nil,
		[React.Event.MouseLeave] = if not isLocked then hover.onMouseLeave else nil,
		[React.Event.Activated] = if not isLocked
			then hover.onActivated(function()
				props.OnSelect()
			end)
			else nil,
	}, {
		UIGradient = e("UIGradient", {
			Color = gradient,
			Rotation = -4,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),

		Decore = e(Frame, {
			Size = UDim2.fromScale(0.97, 0.88),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			CornerRadius = UDim.new(0, 4),
			StrokeColor = stroke,
			StrokeThickness = 2,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
		}),

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/GothamSSm.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Interactable = false,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.8),
			Text = label,
			TextColor3 = textColor,
			TextScaled = true,
			TextStrokeColor3 = textStroke,
			TextStrokeTransparency = 0,
			TextWrapped = true,
		}),
	})
end

--[=[
	Render an action dropdown button with portal-based menu overlay.
	@within ActionDropdown
	@param props TActionDropdownProps -- Component props
	@return React.Element -- Rendered dropdown button and optional menu portal
]=]
local function ActionDropdown(props: TActionDropdownProps)
	local isOpen, setIsOpen = useState(false)
	local triggerRef = useRef(nil :: TextButton?)
	local overlayContainer = OverlayContext.useOverlayContainer()

	-- Trigger button hover animation
	local triggerHover = useHoverSpring(triggerRef, AnimationTokens.Interaction.ActionButton)

	-- Close dropdown when X key is pressed
	useEffect(function()
		if not isOpen then
			return
		end

		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.X then
				setIsOpen(false)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { isOpen })

	local itemCount = #props.Items

	-- Default dropdown background gradient
	local dropdownBgGradient = props.DropdownGradient
		or ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
			ColorSequenceKeypoint.new(0.481, Color3.fromRGB(30, 20, 32)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
		})

	-- Build dropdown items
	local menuItems: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, item in ipairs(props.Items) do
		menuItems["Item_" .. item.Id] = e(DropdownMenuItem, {
			Item = item,
			IsSelected = item.Id == props.SelectedId,
			LayoutOrder = i,
			ButtonGradient = props.ButtonGradient,
			ButtonStroke = props.ButtonStroke,
			LabelStroke = props.LabelStroke,
			OnSelect = function()
				props.OnSelect(item.Id)
				setIsOpen(false)
			end,
		})
	end

	-- Build dropdown panel (rendered via portal if overlay available, otherwise as child)
	local dropdownPanel = nil
	if isOpen and itemCount > 0 then
		-- Derive scale position from trigger's absolute position relative to the overlay container
		local panelPosition = UDim2.fromScale(0, 1) -- fallback: directly below trigger
		local panelSize = UDim2.fromScale(1, 0)
		local fullHeightPx = itemCount * 35 + 8

		if triggerRef.current and overlayContainer then
			local trigger = triggerRef.current
			local overlaySize = overlayContainer.AbsoluteSize
			local overlayPos = overlayContainer.AbsolutePosition
			local absPos = trigger.AbsolutePosition
			local absSize = trigger.AbsoluteSize
			-- Position X aligned to trigger, Y just below the WorkerCard's bottom edge
			local card = trigger.Parent
			local cardBottomY = if card and card:IsA("GuiObject")
				then card.AbsolutePosition.Y + card.AbsoluteSize.Y
				else absPos.Y + absSize.Y
			local relX = absPos.X - overlayPos.X
			local relY = cardBottomY - overlayPos.Y + 6
			local scaleSizeX = (absSize.X + 8) / overlaySize.X
			local panelHeightPx = math.min(fullHeightPx, 183)
			local scaleSizeY = panelHeightPx / overlaySize.Y
			-- Clamp Y so panel never goes off the bottom of the overlay
			local maxRelY = overlaySize.Y - panelHeightPx - 4
			local clampedRelY = math.min(relY, maxRelY)
			local scaleX = (relX - 4) / overlaySize.X
			local scaleY = clampedRelY / overlaySize.Y
			panelPosition = UDim2.fromScale(scaleX, scaleY)
			panelSize = UDim2.fromScale(scaleSizeX, scaleSizeY)
		end

		local panelElement = e(Frame, {
			Size = panelSize,
			Position = panelPosition,
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			ClipsDescendants = false,
			CornerRadius = Border.Radius.SM,
			StrokeColor = props.DropdownStroke,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			Gradient = dropdownBgGradient,
			ZIndex = 2,
			children = {
				DropListScroll = e("ScrollingFrame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.976, 0.976),
					ScrollBarThickness = 3,
					ScrollBarImageColor3 = Color3.fromRGB(255, 204, 0),
				}, menuItems),
			},
		})

		if overlayContainer then
			local backdrop = e("TextButton", {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0, 0),
				BackgroundTransparency = 1,
				Text = "",
				TextSize = 1,
				ZIndex = 1,
				[React.Event.Activated] = function()
					setIsOpen(false)
				end,
			})
			dropdownPanel = ReactRoblox.createPortal({
				Backdrop = backdrop,
				Panel = panelElement,
			}, overlayContainer)
		else
			dropdownPanel = panelElement
		end
	end

	return e("TextButton", {
		ref = triggerRef,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Text = "",
		TextSize = 1,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = triggerHover.onMouseEnter,
		[React.Event.MouseLeave] = triggerHover.onMouseLeave,
		[React.Event.Activated] = triggerHover.onActivated(function()
			setIsOpen(not isOpen)
		end),
	}, {
		UICorner = e("UICorner"),

		UIGradient = e("UIGradient", {
			Color = props.ButtonGradient,
			Rotation = -4,
		}),

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.fromEnum(Enum.Font.GothamBold),
			Interactable = false,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.95, 4, 0.59, 4),
			Text = props.TriggerLabel,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = props.LabelStroke,
			TextStrokeTransparency = 0,
			TextWrapped = true,
		}),

		Decore = e(Frame, {
			Size = UDim2.fromScale(0.95, 0.82),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			CornerRadius = UDim.new(0, 4),
			StrokeColor = props.ButtonStroke,
			StrokeThickness = 2,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
		}),

		DropdownPanel = dropdownPanel,
	})
end

return ActionDropdown
