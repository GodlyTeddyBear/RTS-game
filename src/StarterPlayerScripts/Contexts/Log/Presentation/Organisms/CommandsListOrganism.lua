--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local LogCommandTypes = require(ReplicatedStorage.Contexts.Log.Types.LogCommandTypes)

local CommandsViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.CommandsViewModel)

type GroupedCommands = CommandsViewModel.GroupedCommands
type CommandExecutionResult = LogCommandTypes.CommandExecutionResult

type ExecutionResult = CommandExecutionResult & { timestamp: number }

type Props = {
	groupedCommands: { GroupedCommands },
	expandedCommands: { [string]: boolean },
	paramValues: { [string]: { [string]: string } },
	executionResults: { [string]: ExecutionResult },
	isExecuting: { [string]: boolean },
	onToggleExpand: (commandName: string) -> (),
	onParamChange: (commandName: string, paramName: string, value: string) -> (),
	onExecute: (commandName: string) -> (),
}

local PANEL_COLOR = Color3.fromRGB(28, 28, 34)
local SECTION_HEADER_COLOR = Color3.fromRGB(22, 22, 28)
local CARD_COLOR = Color3.fromRGB(34, 34, 42)
local FIELD_COLOR = Color3.fromRGB(24, 24, 30)
local TEXT_COLOR = Color3.fromRGB(220, 220, 220)
local DIM_TEXT_COLOR = Color3.fromRGB(120, 120, 140)
local SUCCESS_COLOR = Color3.fromRGB(150, 220, 170)
local FAILURE_COLOR = Color3.fromRGB(255, 100, 100)
local EXECUTE_COLOR = Color3.fromRGB(50, 50, 65)

local function _formatTimestamp(clockSeconds: number): string
	local unixSeconds = os.time() - math.max(0, math.floor(os.clock() - clockSeconds))
	return DateTime.fromUnixTimestamp(unixSeconds):FormatLocalTime("HH:mm:ss", "en-us")
end

local function _renderCommand(
	command: LogCommandTypes.CommandManifestEntry,
	index: number,
	props: Props
): any
	local commandName = command.name
	local isExpanded = props.expandedCommands[commandName] == true
	local params = command.params or {}
	local commandParamValues = props.paramValues[commandName] or {}
	local result = props.executionResults[commandName]
	local executing = props.isExecuting[commandName] == true

	local children: { [string]: any } = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		HeaderButton = e("TextButton", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = "",
			LayoutOrder = 1,
			[React.Event.Activated] = function()
				props.onToggleExpand(commandName)
			end,
		}, {
			Name = e("TextLabel", {
				Size = UDim2.new(0.6, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = commandName,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = TEXT_COLOR,
				TextSize = 13,
				Font = Enum.Font.GothamBold,
			}),
			Expand = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(28, 20),
				BackgroundTransparency = 1,
				Text = if isExpanded then "[-]" else "[+]",
				TextColor3 = Color3.fromRGB(100, 200, 255),
				TextSize = 13,
				Font = Enum.Font.GothamBold,
			}),
			Description = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -34, 0.5, 0),
				Size = UDim2.new(0.4, -24, 1, 0),
				BackgroundTransparency = 1,
				Text = command.description or "",
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = DIM_TEXT_COLOR,
				TextSize = 11,
				Font = Enum.Font.Gotham,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
		}),
	}

	if isExpanded then
		local bodyChildren: { [string]: any } = {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
		}

		local layoutOrder = 1
		for _, param in ipairs(params) do
			local paramName = param.name
			bodyChildren["Param_" .. paramName] = e("Frame", {
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundTransparency = 1,
				LayoutOrder = layoutOrder,
			}, {
				Label = e("TextLabel", {
					Size = UDim2.new(1, 0, 0, 14),
					BackgroundTransparency = 1,
					Text = param.label,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = DIM_TEXT_COLOR,
					TextSize = 11,
					Font = Enum.Font.GothamBold,
				}),
				Input = e("TextBox", {
					Position = UDim2.fromOffset(0, 18),
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundColor3 = FIELD_COLOR,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Text = commandParamValues[paramName] or "",
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = TEXT_COLOR,
					PlaceholderText = param.default or "",
					PlaceholderColor3 = DIM_TEXT_COLOR,
					TextSize = 12,
					Font = Enum.Font.Code,
					[React.Change.Text] = function(rbx)
						props.onParamChange(commandName, paramName, rbx.Text)
					end,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
					Padding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
				}),
			})
			layoutOrder += 1
		end

		bodyChildren.ExecuteButton = e("TextButton", {
			Size = UDim2.fromOffset(100, 24),
			BackgroundColor3 = EXECUTE_COLOR,
			BorderSizePixel = 0,
			Text = if executing then "..." else "Execute",
			TextColor3 = TEXT_COLOR,
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = not executing,
			Active = not executing,
			LayoutOrder = layoutOrder,
			[React.Event.Activated] = function()
				props.onExecute(commandName)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		})
		layoutOrder += 1

		if result ~= nil then
			local timestampLabel = _formatTimestamp(result.timestamp)
			bodyChildren.Result = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = string.format("%s %s (%s)", if result.success then "[OK]" else "[ERR]", result.message, timestampLabel),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = if result.success then SUCCESS_COLOR else FAILURE_COLOR,
				TextSize = 12,
				Font = Enum.Font.Gotham,
				LayoutOrder = layoutOrder,
			})
		end

		children.Body = e("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, bodyChildren)
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CARD_COLOR,
		BorderSizePixel = 0,
		LayoutOrder = index,
	}, children)
end

local function CommandsListOrganism(props: Props)
	if #props.groupedCommands == 0 then
		return e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = PANEL_COLOR,
			BorderSizePixel = 0,
		}, {
			Empty = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(320, 24),
				BackgroundTransparency = 1,
				Text = "No commands registered.",
				TextColor3 = DIM_TEXT_COLOR,
				TextSize = 14,
				Font = Enum.Font.GothamBold,
			}),
		})
	end

	local contentChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
	}

	local layoutOrder = 1
	for groupIndex, group in ipairs(props.groupedCommands) do
		local groupChildren: { [string]: any } = {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			Header = e("TextLabel", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = SECTION_HEADER_COLOR,
				BorderSizePixel = 0,
				Text = "  " .. group.contextName,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = TEXT_COLOR,
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				LayoutOrder = 1,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
		}

		for commandIndex, command in ipairs(group.commands) do
			groupChildren["Command_" .. command.name] = _renderCommand(command, commandIndex + 1, props)
		end

		contentChildren["Group_" .. tostring(groupIndex)] = e("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = PANEL_COLOR,
			BorderSizePixel = 0,
			LayoutOrder = layoutOrder,
		}, groupChildren)
		layoutOrder += 1
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PANEL_COLOR,
		BorderSizePixel = 0,
	}, {
		Scroller = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100),
		}, contentChildren),
	})
end

return CommandsListOrganism
