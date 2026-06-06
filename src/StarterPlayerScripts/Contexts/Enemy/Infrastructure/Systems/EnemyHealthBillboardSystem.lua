--!strict

local EnemyHealthBillboardSystem = {}
EnemyHealthBillboardSystem.__index = EnemyHealthBillboardSystem

local function _CreateBillboard(model: Model): BillboardGui?
	local adornee = model:FindFirstChild("Head") or model.PrimaryPart
	if adornee == nil or not adornee:IsA("BasePart") then
		return nil
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NPCHealthBillboard"
	billboard.Size = UDim2.fromScale(4, 0.35)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Adornee = adornee
	billboard.Parent = adornee
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
	background.BorderSizePixel = 0
	background.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = background
	return billboard
end

function EnemyHealthBillboardSystem.new(entityController: any)
	return setmetatable({
		_entityController = entityController,
		_billboardByEntity = {},
	}, EnemyHealthBillboardSystem)
end

function EnemyHealthBillboardSystem:Run()
	local active = {}
	for _, record in ipairs(self._entityController:GetByFeature("Enemy")) do
		local health = record.Health
		local model = self._entityController:FindInstanceByEntity(record.Entity)
		if type(health) ~= "table" or model == nil or not model:IsA("Model") then
			continue
		end
		active[record.Entity] = true
		local billboard = self._billboardByEntity[record.Entity]
		if billboard == nil or billboard.Parent == nil then
			billboard = _CreateBillboard(model)
			self._billboardByEntity[record.Entity] = billboard
		end
		if billboard ~= nil then
			local background = billboard:FindFirstChild("Background")
			local fill = if background ~= nil then background:FindFirstChild("Fill") else nil
			if fill ~= nil and fill:IsA("Frame") then
				fill.Size = UDim2.fromScale(math.clamp((health.Current or 0) / math.max(health.Max or 1, 1), 0, 1), 1)
			end
			billboard.Enabled = (health.Current or 0) > 0
		end
	end
	for entity, billboard in pairs(self._billboardByEntity) do
		if active[entity] ~= true then
			billboard:Destroy()
			self._billboardByEntity[entity] = nil
		end
	end
end

function EnemyHealthBillboardSystem:Destroy()
	for entity, billboard in pairs(self._billboardByEntity) do
		billboard:Destroy()
		self._billboardByEntity[entity] = nil
	end
end

return EnemyHealthBillboardSystem
