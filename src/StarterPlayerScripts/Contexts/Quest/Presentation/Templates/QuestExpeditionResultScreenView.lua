--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local ExpeditionViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ExpeditionViewModel)

type TQuestExpeditionResultScreenViewProps = {
	backdropRef: { current: CanvasGroup? },
	cardRef: { current: Frame? },
	scaleRef: { current: UIScale? },
	viewModel: ExpeditionViewModel.TExpeditionViewModel,
	onReturnToGuild: () -> (),
}

local _BuildBanner
local _BuildGoldRow
local _BuildLootSection
local _BuildPartySection
local _BuildSectionTitle
local _BuildListRow
local _BuildSectionChildren
local _GetSectionHeight

local function QuestExpeditionResultScreenView(props: TQuestExpeditionResultScreenViewProps)
	local vm = props.viewModel

	return e("CanvasGroup", {
		ref = props.backdropRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Active = true,
	}, {
		Modal = e("Frame", {
			ref = props.cardRef,
			Size = UDim2.fromScale(0.6, 0.72),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(28, 28, 32),
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			UIStroke = e("UIStroke", {
				Color = vm.StatusColor,
				Thickness = 2,
				Transparency = 0.2,
			}),
			UIScale = e("UIScale", {
				ref = props.scaleRef,
				Scale = 0.8,
			}),
			Content = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, {
				UIPadding = e("UIPadding", {
					PaddingTop = UDim.new(0.045, 0),
					PaddingBottom = UDim.new(0.045, 0),
					PaddingLeft = UDim.new(0.045, 0),
					PaddingRight = UDim.new(0.045, 0),
				}),
				UIListLayout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0.018, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Banner = _BuildBanner(vm),
				Gold = if vm.GoldEarned > 0 then _BuildGoldRow(vm.GoldEarned) else nil,
				Loot = if #vm.LootItems > 0 then _BuildLootSection(vm.LootItems) else nil,
				Dead = if #vm.DeadAdventurers > 0 then _BuildPartySection("Lost Adventurers", vm.DeadAdventurers, Color3.fromRGB(255, 120, 120), 4) else nil,
				Survivors = _BuildPartySection("Surviving Party", vm.SurvivingParty, Color3.fromRGB(210, 210, 210), 5),
				ReturnButton = e(Button, {
					Text = "Return to Guild",
					Size = UDim2.fromScale(0.44, 0.085),
					Variant = "primary",
					TextScaled = true,
					LayoutOrder = 6,
					[React.Event.Activated] = props.onReturnToGuild,
				}),
			}),
		}),
	})
end

function _BuildBanner(vm: ExpeditionViewModel.TExpeditionViewModel)
	return e("Frame", {
		Size = UDim2.fromScale(1, 0.18),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.04, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Status = e(Text, {
			Text = string.upper(vm.StatusLabel),
			Variant = "heading",
			TextSize = 42,
			TextColor3 = vm.StatusColor,
			Size = UDim2.fromScale(1, 0.6),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
			LayoutOrder = 1,
		}),
		Zone = e(Text, {
			Text = vm.ZoneName,
			Variant = "label",
			Size = UDim2.fromScale(1, 0.25),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 2,
		}),
	})
end

function _BuildGoldRow(goldEarned: number)
	return e(Text, {
		Text = "+" .. tostring(goldEarned) .. " gold",
		Variant = "body",
		TextColor3 = Color3.fromRGB(255, 220, 100),
		Size = UDim2.fromScale(1, 0.06),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = 2,
	})
end

function _BuildLootSection(lootItems: { ExpeditionViewModel.TExpeditionLootItem })
	local rows = {
		Title = _BuildSectionTitle("Loot", 1),
	}
	for index, item in ipairs(lootItems) do
		rows["Loot" .. index] = _BuildListRow(tostring(item.Quantity) .. " x " .. item.ItemId, index + 1)
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, _GetSectionHeight(#lootItems)),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
	}, _BuildSectionChildren(rows))
end

function _BuildPartySection(title: string, adventurerIds: { string }, color: Color3, layoutOrder: number)
	local rows = {
		Title = _BuildSectionTitle(title, 1),
	}

	if #adventurerIds == 0 then
		rows.Empty = _BuildListRow("None", 2, Color3.fromRGB(150, 150, 150))
	else
		for index, adventurerId in ipairs(adventurerIds) do
			rows["Adventurer" .. index] = _BuildListRow(adventurerId, index + 1, color)
		end
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, _GetSectionHeight(math.max(#adventurerIds, 1))),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
	}, _BuildSectionChildren(rows))
end

function _BuildSectionTitle(title: string, layoutOrder: number)
	return e(Text, {
		Text = title,
		Variant = "label",
		Size = UDim2.fromScale(1, 0.24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		LayoutOrder = layoutOrder,
	})
end

function _BuildListRow(text: string, layoutOrder: number, textColor: Color3?)
	return e("Frame", {
		Size = UDim2.fromScale(0.72, 0.2),
		BackgroundColor3 = Color3.fromRGB(42, 42, 48),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0.12, 0),
			PaddingBottom = UDim.new(0.12, 0),
			PaddingLeft = UDim.new(0.04, 0),
			PaddingRight = UDim.new(0.04, 0),
		}),
		Label = e(Text, {
			Text = text,
			Variant = "body",
			TextColor3 = textColor,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = true,
			TextScaled = true,
		}),
	})
end

function _BuildSectionChildren(rows: { [string]: any }): { [string]: any }
	rows.UIListLayout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0.035, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	return rows
end

function _GetSectionHeight(rowCount: number): number
	return math.clamp(0.12 + (rowCount * 0.06), 0.18, 0.28)
end

return QuestExpeditionResultScreenView
