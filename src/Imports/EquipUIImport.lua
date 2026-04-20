return React.createElement("ScreenGui", {
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, {
	Equip = React.createElement("Frame", {
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, {
		Header = React.createElement("Frame", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(1, 0.09766),
		}, {
			UIGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
					ColorSequenceKeypoint.new(0.533654, Color3.fromRGB(45, 44, 44)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.533654, 0),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),

			UIStroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = Color3.new(1, 1, 1),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4,
			}, {
				UIGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 204, 0)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 242, 210)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 0)),
					}),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}),
			}),

			Title = React.createElement("TextLabel", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothicA1.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.4316, 0.5),
				Size = UDim2.new(0.34653, 6, 0.3, 6),
				Text = "Adventurer",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 50,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				UIStroke = React.createElement("UIStroke", {
					Color = Color3.fromRGB(21, 20, 20),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 3,
				}),
			}),

			BackButton = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				LayoutOrder = 1,
				Position = UDim2.new(0.175, -6, 0.5, 0),
				Size = UDim2.new(0.04653, 12, 0.5, 12),
				Text = "",
				TextSize = 1,
			}, {
				UIGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
						ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(45, 44, 44)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
					}),
					Rotation = -140.856,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.519231, 0),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}),

				UIStroke = React.createElement("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.new(1, 1, 1),
					Thickness = 6,
				}, {
					UIGradient = React.createElement("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 204, 0)),
							ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 242, 210)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 0)),
						}),
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.5, 0),
							NumberSequenceKeypoint.new(1, 0),
						}),
					}),
				}),

				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(),
				}),

				Vector = React.createElement("ImageLabel", {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "rbxassetid://",
					ImageColor3 = Color3.new(1, 1, 1),
					Position = UDim2.fromScale(0.50746, 0.5),
					Size = UDim2.fromScale(0.44776, 0.6),
				}),
			}),
		}),

		Footer = React.createElement("Frame", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, 0.08105),
		}, {
			UIGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
					ColorSequenceKeypoint.new(0.533654, Color3.fromRGB(45, 44, 44)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.533654, 0),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),
		}),

		ListContainer = React.createElement("Frame", {
			Active = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			LayoutOrder = 2,
			Position = UDim2.fromScale(0.5, 0.5083),
			Size = UDim2.new(1, 8, 0.82129, 8),
		}, {
			UIGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
					ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
				}),
				Rotation = -140.856,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.519231, 0),
					NumberSequenceKeypoint.new(1, 0),
				}),
			}),

			UIStroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4,
			}, {
				UIGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 204, 0)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 242, 210)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 204, 0)),
					}),
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.5, 0),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}),
			}),

			LoadoutContainer = React.createElement("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.new(0.02708, -4, 0.5, 0),
				Size = UDim2.new(0.34444, 8, 0.9239, 8),
			}, {
				UIGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 47, 47)),
						ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(28, 23, 23)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(37, 34, 34)),
					}),
					Rotation = -140.856,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.519231, 0),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}),

				UIStroke = React.createElement("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.new(1, 1, 1),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 4,
				}, {
					UIGradient = React.createElement("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 98, 98)),
							ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(117, 80, 80)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 75, 75)),
						}),
						Rotation = -140.856,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.519231, 0),
							NumberSequenceKeypoint.new(1, 0),
						}),
					}),
				}),

				ArrayOne = React.createElement("Frame", {
					Active = true,
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.05444, 0.5),
					Size = UDim2.fromScale(0.33266, 0.93565),
				}, {
					SlotButton = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						Position = UDim2.fromScale(0.50303, 0.01651),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Weapon",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),

					SlotButton2 = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.50303, 0.36864),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Helmet",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),

					SlotButton3 = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 2,
						Position = UDim2.fromScale(0.50303, 0.96974),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Legs",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),

					SlotButton4 = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 3,
						Position = UDim2.fromScale(0.50303, 0.61761),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Torso",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),
				}),

				ArrayTwo = React.createElement("Frame", {
					Active = true,
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					LayoutOrder = 1,
					Position = UDim2.fromScale(0.94355, 0.5),
					Size = UDim2.fromScale(0.33266, 0.93565),
				}, {
					SlotButton = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						Position = UDim2.fromScale(0.50303, 0.01651),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Accesory1",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),

					SlotButton2 = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 1,
						Position = UDim2.fromScale(0.50303, 0.36864),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Accessory2",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),

					SlotButton3 = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 2,
						Position = UDim2.fromScale(0.50303, 0.96974),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Accessory4",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),

					SlotButton4 = React.createElement("TextButton", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						LayoutOrder = 3,
						Position = UDim2.fromScale(0.50303, 0.61761),
						Size = UDim2.fromScale(0.90909, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Accessory3",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),
				}),
			}),

			ItemContainer = React.createElement("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				LayoutOrder = 1,
				Position = UDim2.new(0.97292, 4, 0.5, 0),
				Size = UDim2.new(0.35, 8, 0.9239, 8),
			}, {
				UIGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 47, 47)),
						ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(28, 23, 23)),
						ColorSequenceKeypoint.new(1, Color3.fromRGB(37, 34, 34)),
					}),
					Rotation = -140.856,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.519231, 0),
						NumberSequenceKeypoint.new(1, 0),
					}),
				}),

				UIStroke = React.createElement("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.new(1, 1, 1),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 4,
				}, {
					UIGradient = React.createElement("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 98, 98)),
							ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(117, 80, 80)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 75, 75)),
						}),
						Rotation = -140.856,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(0.519231, 0),
							NumberSequenceKeypoint.new(1, 0),
						}),
					}),
				}),

				ItemContainerScroll = React.createElement("ScrollingFrame", {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutomaticCanvasSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.87302, 0.93565),
				}, {
					SlotButton = React.createElement("TextButton", {
						BackgroundColor3 = Color3.new(1, 1, 1),
						ClipsDescendants = true,
						Size = UDim2.fromScale(0.34091, 0.20633),
						Text = "",
						TextSize = 1,
					}, {
						UIGradient = React.createElement("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
								ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(26, 19, 19)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
							}),
							Rotation = -140.856,
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(0.519231, 0),
								NumberSequenceKeypoint.new(1, 0),
							}),
						}),

						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 9),
						}),

						Decore = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0.9, 6, 0.9, 6),
						}, {
							UIStroke = React.createElement("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.new(1, 1, 1),
								Thickness = 3,
							}, {
								UIGradient = React.createElement("UIGradient", {
									Color = ColorSequence.new({
										ColorSequenceKeypoint.new(0, Color3.fromRGB(4, 4, 4)),
										ColorSequenceKeypoint.new(0.5, Color3.fromRGB(63, 50, 50)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 4, 4)),
									}),
									Rotation = -43.907,
									Transparency = NumberSequence.new({
										NumberSequenceKeypoint.new(0, 0),
										NumberSequenceKeypoint.new(0.5, 0),
										NumberSequenceKeypoint.new(1, 0),
									}),
								}),
							}),

							UICorner = React.createElement("UICorner", {
								CornerRadius = UDim.new(),
							}),
						}),

						Label = React.createElement("TextLabel", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 1),
							BackgroundTransparency = 1,
							FontFace = Font.new(
								"rbxasset://fonts/families/GothicA1.json",
								Enum.FontWeight.Bold,
								Enum.FontStyle.Normal
							),
							Interactable = false,
							LayoutOrder = 1,
							Position = UDim2.new(0.5, 0, 0.9, 5),
							Size = UDim2.new(0.9, 9, 0.12, 9),
							Text = "Item",
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 22,
							TextWrapped = true,
						}, {
							UIStroke = React.createElement("UIStroke", {
								Color = Color3.fromRGB(4, 4, 4),
								LineJoinMode = Enum.LineJoinMode.Miter,
								Thickness = 4.5,
							}),
						}),

						Icon = React.createElement("Frame", {
							Active = true,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.new(1, 1, 1),
							ClipsDescendants = true,
							LayoutOrder = 2,
							Position = UDim2.fromScale(0.5, 0.415),
							Size = UDim2.fromScale(0.68, 0.51),
						}, {
							UIGradient = React.createElement("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(65, 55, 55)),
									ColorSequenceKeypoint.new(0.519231, Color3.fromRGB(42, 37, 37)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(57, 51, 51)),
								}),
								Rotation = -140.856,
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.519231, 0),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),

							UICorner = React.createElement("UICorner"),
						}),
					}),
				}),
			}),

			Frame1 = React.createElement("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				LayoutOrder = 2,
				Position = UDim2.fromScale(0.5, 0.48038),
				Size = UDim2.fromScale(0.19167, 0.7396),
			}),

			Stat = React.createElement("Frame", {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Position = UDim2.fromScale(0.5, 0.18668),
				Size = UDim2.fromScale(0.19167, 0.03805),
			}, {
				Label = React.createElement("TextLabel", {
					Active = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/GothicA1.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0.285, 0.46875),
					Size = UDim2.fromScale(0.57, 0.9375),
					Text = "StatName:",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),

				Amount = React.createElement("TextLabel", {
					Active = true,
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
					LayoutOrder = 1,
					Position = UDim2.fromScale(1, 0.53125),
					Size = UDim2.fromScale(0.39333, 0.9375),
					Text = "100",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}),
		}),
	}),
})
