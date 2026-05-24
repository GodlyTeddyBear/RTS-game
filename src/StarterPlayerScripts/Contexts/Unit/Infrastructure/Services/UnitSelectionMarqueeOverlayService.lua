--!strict

local Players = game:GetService("Players")

local UnitSelectionTypes = require(game:GetService("ReplicatedStorage").Contexts.Unit.Types.UnitSelectionTypes)

type TMarqueeRect = UnitSelectionTypes.TMarqueeRect

local GUI_NAME = "UnitSelectionMarqueeOverlay"
local FRAME_NAME = "MarqueeRect"
local STROKE_NAME = "MarqueeRectStroke"

local UnitSelectionMarqueeOverlayService = {}
UnitSelectionMarqueeOverlayService.__index = UnitSelectionMarqueeOverlayService

function UnitSelectionMarqueeOverlayService.new()
	local self = setmetatable({}, UnitSelectionMarqueeOverlayService)
	self._screenGui = nil :: ScreenGui?
	self._frame = nil :: Frame?
	return self
end

function UnitSelectionMarqueeOverlayService:Show(rect: TMarqueeRect)
	local frame = self:_GetFrame()
	frame.Visible = true
	frame.Position = UDim2.fromOffset(rect.Min.X, rect.Min.Y)
	frame.Size = UDim2.fromOffset(rect.Size.X, rect.Size.Y)
end

function UnitSelectionMarqueeOverlayService:Hide()
	if self._frame ~= nil then
		self._frame.Visible = false
	end
end

function UnitSelectionMarqueeOverlayService:Destroy()
	if self._screenGui ~= nil then
		self._screenGui:Destroy()
		self._screenGui = nil
		self._frame = nil
	end
end

function UnitSelectionMarqueeOverlayService:_GetFrame(): Frame
	if self._frame ~= nil then
		return self._frame
	end

	local localPlayer = Players.LocalPlayer
	assert(localPlayer ~= nil, "UnitSelectionMarqueeOverlayService requires LocalPlayer")
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = GUI_NAME
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = FRAME_NAME
	frame.AnchorPoint = Vector2.zero
	frame.BackgroundColor3 = Color3.fromRGB(255, 221, 87)
	frame.BackgroundTransparency = 0.85
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screenGui

	local stroke = Instance.new("UIStroke")
	stroke.Name = STROKE_NAME
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.1
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame

	self._screenGui = screenGui
	self._frame = frame

	return frame
end

return UnitSelectionMarqueeOverlayService
