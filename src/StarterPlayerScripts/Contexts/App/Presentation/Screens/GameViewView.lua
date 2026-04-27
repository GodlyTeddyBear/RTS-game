--!strict
--[=[
	@class GameViewView
	Wrapper screen connecting GameView to the game view controller and child feature screens.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local RunPresentation = require(script.Parent.Parent.Parent.Parent.Run.Presentation)
local InventoryPresentation = require(script.Parent.Parent.Parent.Parent.Inventory.Presentation)
local Button = require(script.Parent.Parent.Atoms.Button)
local Text = require(script.Parent.Parent.Atoms.Text)
local VStack = require(script.Parent.Parent.Layouts.VStack)

type TGameViewViewProps = {
	containerRef: { current: Frame? },
	isMenuOpen: boolean,
	isHudEnabled: boolean,
	isRunActive: boolean,
	onToggleMenu: () -> (),
	onNavigateFromMenu: (string) -> (),
	onOpenSettings: () -> (),
	onExitGame: () -> (),
	onStartPhase2: () -> (),
	onStructureSelected: (string) -> (),
	isInventoryOpen: boolean,
	onToggleInventory: () -> (),
	onCloseInventory: () -> (),
	playerUsername: string,
	playerLevel: number,
}

local function GameViewView(props: TGameViewViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			RunHUD = props.isHudEnabled and props.isRunActive and e(RunPresentation.RunHUD, {
				onStructureSelected = props.onStructureSelected,
				onToggleInventory = props.onToggleInventory,
			}) or nil,
			InventoryPopup = props.isHudEnabled and props.isRunActive and props.isInventoryOpen and e(
				InventoryPresentation.InventoryPopup,
				{
					onClose = props.onCloseInventory,
				}
			) or nil,
			Phase2Launch = (not props.isRunActive) and e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(10, 14, 24),
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			}, {
				Panel = e("Frame", {
					Size = UDim2.fromScale(0.44, 0.34),
					Position = UDim2.fromScale(0.5, 0.58),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(19, 25, 39),
					BackgroundTransparency = 0.06,
					BorderSizePixel = 0,
				}, {
					Corner = e("UICorner", {
						CornerRadius = UDim.new(0, 18),
					}),
					Stroke = e("UIStroke", {
						Color = Color3.fromRGB(96, 137, 206),
						Thickness = 2,
						Transparency = 0.3,
					}),
					Layout = e(VStack, {
						Size = UDim2.fromScale(1, 1),
						Gap = 16,
						Align = "Center",
						Justify = "Center",
						BackgroundTransparency = 1,
						Padding = 20,
					}, {
						Title = e(Text, {
							Size = UDim2.fromScale(1, 0.2),
							Text = "Phase 2 Ready",
							Variant = "heading",
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
						}),
						Body = e(Text, {
							Size = UDim2.fromScale(1, 0.16),
							Text = "Launch into the map when you are ready.",
							Variant = "body",
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
						}),
						LaunchButton = e(Button, {
							Size = UDim2.fromScale(0.56, 0.22),
							Text = "Enter Phase 2",
							Variant = "primary",
							[React.Event.Activated] = props.onStartPhase2,
						}),
					}),
				}),
			}) or nil,
		}),
	})
end

return GameViewView
