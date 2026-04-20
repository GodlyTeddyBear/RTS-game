--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef
local useEffect = React.useEffect

local spr = require(ReplicatedStorage.Utilities.BitFrames.Dependencies.spr)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useReducedMotion = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useReducedMotion)

local HStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.HStack)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)

local EquippableItemViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.EquippableItemViewModel)

export type TEquippableItemListProps = {
	SlotType: string,
	Items: { EquippableItemViewModel.TEquippableItemViewData },
	OnSelectItem: (slotIndex: number) -> (),
	OnClose: () -> (),
}

local function EquippableItemList(props: TEquippableItemListProps)
	local prefersReducedMotion = useReducedMotion()
	local backdropRef = useRef(nil :: Frame?)
	local modalRef = useRef(nil :: Frame?)

	-- Animate modal entrance: fade backdrop, bounce-in content from 92% scale
	useEffect(function()
		if prefersReducedMotion then
			return
		end
		local bouncyPreset = AnimationTokens.Spring.Bouncy
		local smoothPreset = AnimationTokens.Spring.Smooth

		-- Animate backdrop fade
		if backdropRef.current then
			backdropRef.current.BackgroundTransparency = 0.85
			spr.target(backdropRef.current, smoothPreset.DampingRatio, smoothPreset.Frequency, {
				BackgroundTransparency = 0.4,
			})
		end

		-- Animate modal content: scale-up + fade-in
		if modalRef.current then
			local uiScale = Instance.new("UIScale")
			uiScale.Name = "ModalScale"
			uiScale.Scale = 0.92
			uiScale.Parent = modalRef.current
			modalRef.current.BackgroundTransparency = 1
			spr.target(modalRef.current, bouncyPreset.DampingRatio, bouncyPreset.Frequency, {
				BackgroundTransparency = 0,
			})
			spr.target(uiScale, bouncyPreset.DampingRatio, bouncyPreset.Frequency, { Scale = 1 })
			return function()
				if uiScale and uiScale.Parent then
					uiScale:Destroy()
				end
			end
		end
		return nil
	end, {})

	local listChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = if #props.Items == 0
				then Enum.VerticalAlignment.Center
				else Enum.VerticalAlignment.Top,
			Padding = UDim.new(0.01, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
			PaddingTop = UDim.new(0.015, 0),
			PaddingBottom = UDim.new(0.015, 0),
		}),
	}

	-- Render item list or empty state
	if #props.Items == 0 then
		listChildren["EmptyText"] = e(Text, {
			Text = "No " .. props.SlotType .. " items in inventory.",
			Variant = "body",
			Color = "Text.Muted",
			Size = UDim2.fromScale(1, 0.2),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	else
		-- Render each equippable item as a selectable row
		for i, item in ipairs(props.Items) do
			listChildren["Item_" .. tostring(item.SlotIndex)] = e(HStack, {
				Size = UDim2.fromScale(1, 0.13),
				Padding = 8,
				Gap = 8,
				Align = "Center",
				Justify = "Start",
				Bg = "Surface.Tertiary",
				BorderRadius = UDim.new(0, 6),
				LayoutOrder = i,
			}, {
				Info = e(VStack, {
					Size = UDim2.fromScale(0.6, 1),
					Gap = 2,
					Align = "Start",
					Justify = "Center",
					LayoutOrder = 1,
				}, {
					NameLabel = e(Text, {
						Text = item.Name,
						Variant = "body",
						Size = UDim2.fromScale(1, 0.5),
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
					}),
					StatsLabel = if item.StatsText ~= ""
						then e(Text, {
							Text = item.StatsText,
							Variant = "caption",
							Color = "Text.Secondary",
							Size = UDim2.fromScale(1, 0.35),
							TextXAlignment = Enum.TextXAlignment.Left,
							LayoutOrder = 2,
						})
						else nil,
				}),
				SelectButton = e(Button, {
					Text = "Select",
					Size = UDim2.fromScale(0.3, 0.6),
					Variant = "primary",
					LayoutOrder = 2,
					[React.Event.Activated] = function()
						props.OnSelectItem(item.SlotIndex)
					end,
				}),
			})
		end
	end

	return e("Frame", {
		ref = backdropRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, {
		ModalFrame = e("Frame", {
			ref = modalRef,
			Size = UDim2.fromScale(0.8, 0.6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(35, 35, 40),
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", { CornerRadius = UDim.new(0.02, 0) }),

			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			ModalHeader = e(HStack, {
				Size = UDim2.fromScale(1, 0.12),
				Padding = 12,
				Gap = 8,
				Align = "Center",
				Justify = "Start",
				LayoutOrder = 1,
			}, {
				TitleText = e(Text, {
					Text = "Select " .. props.SlotType,
					Variant = "heading",
					Size = UDim2.fromScale(0.7, 1),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					LayoutOrder = 1,
				}),
				CloseButton = e(Button, {
					Text = "Close",
					Size = UDim2.fromScale(0.25, 0.7),
					Variant = "ghost",
					LayoutOrder = 2,
					[React.Event.Activated] = props.OnClose,
				}),
			}),

			ItemList = e("ScrollingFrame", {
				Size = UDim2.fromScale(1, 0.88),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromScale(0, 0),
				LayoutOrder = 2,
			}, listChildren),
		}),
	})
end

return EquippableItemList
