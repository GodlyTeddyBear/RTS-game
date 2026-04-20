--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

export type TTaskCardProps = {
	Task: any,
	LayoutOrder: number,
	OnClaim: (taskId: string) -> (),
}

local function _BuildObjectiveRows(objectives: { any })
	local rows = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, objective in ipairs(objectives) do
		rows["Objective_" .. index] = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = objective.Text .. " (" .. objective.Amount .. "/" .. objective.Required .. ")",
			TextColor3 = if objective.IsComplete then Color3.fromRGB(124, 210, 146) else Color3.fromRGB(219, 219, 219),
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	return rows
end

local function TaskCard(props: TTaskCardProps)
	local task = props.Task

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(28, 31, 36),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(0.94, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = e("UIStroke", {
			Color = if task.CanClaim then Color3.fromRGB(233, 195, 73) else Color3.fromRGB(83, 91, 103),
			Thickness = 1,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold),
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = task.Title,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 21,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Description = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = task.Description,
			TextColor3 = Color3.fromRGB(196, 200, 207),
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Objectives = e("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, _BuildObjectiveRows(task.Objectives)),
		Reward = e("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = "Reward: " .. task.RewardLabel,
			TextColor3 = Color3.fromRGB(233, 195, 73),
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		ClaimButton = if task.CanClaim
			then e("TextButton", {
				BackgroundColor3 = Color3.fromRGB(233, 195, 73),
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold),
				LayoutOrder = 5,
				Size = UDim2.fromOffset(150, 36),
				Text = "Claim",
				TextColor3 = Color3.fromRGB(25, 25, 25),
				TextSize = 16,
				[React.Event.Activated] = function()
					props.OnClaim(task.TaskId)
				end,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			})
			else nil,
	})
end

return TaskCard
