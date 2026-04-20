--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef
local useEffect = React.useEffect

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)
local useSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useSpring)
local useReducedMotion = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useReducedMotion)

export type TGuildDetailPanelProps = {
	Name: string?,
	Type: string?,
	StatsLabel: string?,
	Description: string?,
	CostLabel: string?,
	ActionLabel: string?,
	ActionGradient: ColorSequence?,
	ActionStroke: ColorSequence?,
	OnAction: (() -> ())?,
}

local GRADIENT_ROTATION = -141

local function GuildDetailPanel(props: TGuildDetailPanelProps)
	local hasItem = props.Name ~= nil
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()
	local contentRef = useRef(nil :: Frame?)
	local actionBtnRef = useRef(nil :: TextButton?)
	local actionHover = useHoverSpring(actionBtnRef, AnimationTokens.Interaction.ActionButton)

	-- Animate content entrance when item changes (scale-up effect)
	useEffect(function()
		if not hasItem or not contentRef.current or prefersReducedMotion then
			return
		end
		-- Start from 95% scale, animate to full size
		contentRef.current.Size = UDim2.fromScale(0.95157 * 0.95, 0.97467 * 0.95)
		spring(contentRef, {
			Size = UDim2.fromScale(0.95157, 0.97467),
		}, "Responsive")
	end, { props.Name } :: { any })

	-- Empty state
	if not hasItem then
		return e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.new(0.97847, 3, 0.5, 0),
			Size = UDim2.new(0.28681, 6, 0.96154, 6),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.GOLD_STROKE_SUBTLE,
					Rotation = -180,
				}),
			}),

			PlaceholderText = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.1),
				Text = "Select an adventurer to view details",
				TextColor3 = Color3.fromRGB(100, 100, 100),
				TextSize = 18,
				TextWrapped = true,
			}),
		})
	end

	-- Extract name abbreviation for icon (e.g. "Paladin" → "PA")
	local nameAbbr = if props.Name then string.sub(props.Name, 1, 2):upper() else "?"
	-- Use provided gradients or fall back to green (hire) defaults
	local actionGradient = props.ActionGradient or GradientTokens.GREEN_BUTTON_GRADIENT
	local actionStroke = props.ActionStroke or GradientTokens.GREEN_BUTTON_STROKE

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0.97847, 3, 0.5, 0),
		Size = UDim2.new(0.28681, 6, 0.96154, 6),
	}, {
		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 3,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE_SUBTLE,
				Rotation = -180,
			}),
		}),

		-- Inner slot wrapper
		SlotButton = e("TextButton", {
			ref = contentRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.49933),
			Size = UDim2.fromScale(0.95157, 0.97467),
			Text = "",
			TextSize = 1,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.SLOT_GRADIENT,
				Rotation = GRADIENT_ROTATION,
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 9),
			}),

			Decore = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0.9542, 6, 0.97538, 6),
			}, {
				UIStroke = e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.new(1, 1, 1),
					Thickness = 3,
				}, {
					UIGradient = e("UIGradient", {
						Color = GradientTokens.SLOT_DECORE_STROKE,
						Rotation = -44,
					}),
				}),

				UICorner = e("UICorner", {
					CornerRadius = UDim.new(),
				}),
			}),

			-- Rarity label (top-left)
			Rarity = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Interactable = false,
				Position = UDim2.new(0.4771, 0, 0.02326, -4),
				Size = UDim2.new(0.77608, 8, 0.04514, 8),
				Text = "Common",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 37,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				UIStroke = e("UIStroke", {
					Color = Color3.new(1, 1, 1),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 4,
				}, {
					UIGradient = e("UIGradient", {
						Color = GradientTokens.SLOT_GRADIENT,
						Rotation = GRADIENT_ROTATION,
					}),
				}),
			}),

			-- Category label
			Category = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Interactable = false,
				Position = UDim2.fromScale(0.26972, 0.07524),
				Size = UDim2.fromScale(0.36132, 0.0301),
				Text = props.Type or "Unknown",
				TextColor3 = Color3.fromRGB(69, 69, 69),
				TextSize = 16,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			-- Stats line
			Stats = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				Interactable = false,
				Position = UDim2.fromScale(0.51399, 0.10534),
				Size = UDim2.fromScale(0.84987, 0.0301),
				Text = props.StatsLabel or "",
				TextColor3 = Color3.fromRGB(69, 69, 69),
				TextSize = 16,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			-- Icon area (centered portrait)
			Icon = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.50127, 0.36662),
				Size = UDim2.new(0.72774, 12, 0.39124, 12),
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.SLOT_ICON_GRADIENT,
					Rotation = GRADIENT_ROTATION,
				}),

				UIStroke = e("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.new(1, 1, 1),
					Thickness = 6,
				}, {
					UIGradient = e("UIGradient", {
						Color = GradientTokens.DETAIL_ICON_STROKE,
						Rotation = GRADIENT_ROTATION,
					}),
				}),

				UICorner = e("UICorner"),

				IconText = e("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = nameAbbr,
					TextColor3 = Color3.fromRGB(150, 150, 150),
					TextScaled = true,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothicA1.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
				}),
			}),

			-- Adventurer name (large)
			Label = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothicA1.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Interactable = false,
				Position = UDim2.fromScale(0.50127, 0.61423),
				Size = UDim2.new(0.82443, 9, 0.06566, 9),
				Text = props.Name or "Unknown",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 42,
				TextWrapped = true,
			}, {
				UIStroke = e("UIStroke", {
					Color = Color3.fromRGB(4, 4, 4),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 4.5,
				}),
			}),

			-- Description
			DescriptionContainer = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.49746, 0.86047),
				Size = UDim2.fromScale(0.83206, 0.19425),
			}, {
				Description = e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					Position = UDim2.fromScale(0.5, 0.50352),
					Size = UDim2.fromScale(1, 0.99296),
					Text = props.Description or "No description available.",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 21,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
			}),

			-- Options container with action button
			OptionsContainer = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.49746, 0.97127),
				Size = UDim2.fromScale(0.72519, 0.09166),
			}, {
				ActionButton = if props.OnAction
					then e("TextButton", {
						ref = actionBtnRef,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						Position = UDim2.fromScale(0.50175, 0.50746),
						Size = UDim2.fromScale(0.71579, 0.89552),
						Text = "",
						TextSize = 1,
						[React.Event.MouseEnter] = actionHover.onMouseEnter,
						[React.Event.MouseLeave] = actionHover.onMouseLeave,
						[React.Event.Activated] = actionHover.onActivated(function()
							if props.OnAction then
								props.OnAction()
							end
						end),
					}, {
						UIGradient = e("UIGradient", {
							Color = actionGradient,
							Rotation = GRADIENT_ROTATION,
						}),

						UICorner = e("UICorner"),

						Decore = e("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.49755, 0.5),
							Size = UDim2.fromScale(0.94608, 0.86667),
						}, {
							UIStroke = e("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								BorderStrokePosition = Enum.BorderStrokePosition.Inner,
								Color = Color3.new(1, 1, 1),
								Thickness = 2,
							}, {
								UIGradient = e("UIGradient", {
									Color = actionStroke,
								}),
							}),

							UICorner = e("UICorner", {
								CornerRadius = UDim.new(0, 4),
							}),
						}),

						Label = e("TextLabel", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.91176, 4, 0.86667, 4),
							Text = props.ActionLabel or "Action",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 14,
							TextWrapped = true,
						}, {
							UIStroke = e("UIStroke", {
								Color = Color3.new(1, 1, 1),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 2,
							}, {
								UIGradient = e("UIGradient", {
									Color = actionStroke,
								}),
							}),
						}),
					})
					else nil,
			}),

			-- Cost label below options
			Cost = if props.CostLabel
				then e("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					Interactable = false,
					Position = UDim2.new(0.50127, 0, 0.86867, 2),
					Size = UDim2.new(0.36132, 4, 0.01368, 4),
					Text = props.CostLabel,
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 12,
					TextWrapped = true,
				}, {
					UIStroke = e("UIStroke", {
						Color = Color3.fromRGB(4, 4, 4),
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 2,
					}),
				})
				else nil,
		}),
	})
end

return GuildDetailPanel
