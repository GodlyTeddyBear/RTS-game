--!strict

--[[
    DragBoxService - Owns the drag-selection rectangle UI lifecycle.

    Responsibilities:
    - Create ScreenGui + Frame for the drag box
    - Show/update/hide the drag rectangle
]]

local DragBoxService = {}
DragBoxService.__index = DragBoxService

export type TDragBoxService = typeof(setmetatable({} :: {
	_DragFrame: Frame?,
	_DragScreenGui: ScreenGui?,
}, DragBoxService))

function DragBoxService.new(): TDragBoxService
	local self = setmetatable({}, DragBoxService)
	self._DragFrame = nil
	self._DragScreenGui = nil
	self:_CreateUI()
	return self
end

function DragBoxService:_CreateUI()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	if not player then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NPCCommandDragUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "DragBox"
	frame.Visible = false
	frame.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	frame.BackgroundTransparency = 0.7
	frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	frame.BorderSizePixel = 2
	frame.Parent = screenGui

	self._DragScreenGui = screenGui
	self._DragFrame = frame
end

function DragBoxService:Update(startPos: Vector2, currentPos: Vector2)
	local frame = self._DragFrame
	if not frame then
		return
	end

	local minX = math.min(startPos.X, currentPos.X)
	local minY = math.min(startPos.Y, currentPos.Y)
	local maxX = math.max(startPos.X, currentPos.X)
	local maxY = math.max(startPos.Y, currentPos.Y)

	frame.Position = UDim2.fromOffset(minX, minY)
	frame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
	frame.Visible = true
end

function DragBoxService:Hide()
	if self._DragFrame then
		self._DragFrame.Visible = false
	end
end

return DragBoxService
