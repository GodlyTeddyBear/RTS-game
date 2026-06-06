--!strict

local StructureConstructionPresentationSystem = {}
StructureConstructionPresentationSystem.__index = StructureConstructionPresentationSystem

local function _CaptureParts(model: Model)
	local entries = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			table.insert(entries, {
				Part = descendant,
				Transparency = descendant.Transparency,
			})
		end
	end
	return entries
end

function StructureConstructionPresentationSystem.new(entityController: any)
	return setmetatable({
		_entityController = entityController,
		_entriesByEntity = {},
	}, StructureConstructionPresentationSystem)
end

function StructureConstructionPresentationSystem:Run()
	local active = {}
	for _, record in ipairs(self._entityController:GetByFeature("Structure")) do
		local construction = record.Components["Structure.Construction"]
		local model = self._entityController:FindInstanceByEntity(record.Entity)
		if type(construction) ~= "table" or model == nil or not model:IsA("Model") then
			continue
		end
		active[record.Entity] = true
		local entries = self._entriesByEntity[record.Entity]
		if entries == nil then
			entries = _CaptureParts(model)
			self._entriesByEntity[record.Entity] = entries
		end
		local required = construction.RequiredWork or 0
		local alpha = if required > 0 then math.clamp((construction.CurrentWork or 0) / required, 0, 1) else 1
		for _, entry in ipairs(entries) do
			if entry.Part.Parent ~= nil then
				entry.Part.Transparency = 0.95 + ((entry.Transparency - 0.95) * alpha)
			end
		end
	end
	for entity, entries in pairs(self._entriesByEntity) do
		if active[entity] == true then
			continue
		end
		for _, entry in ipairs(entries) do
			if entry.Part.Parent ~= nil then
				entry.Part.Transparency = entry.Transparency
			end
		end
		self._entriesByEntity[entity] = nil
	end
end

function StructureConstructionPresentationSystem:Destroy()
	for entity, entries in pairs(self._entriesByEntity) do
		for _, entry in ipairs(entries) do
			if entry.Part.Parent ~= nil then
				entry.Part.Transparency = entry.Transparency
			end
		end
		self._entriesByEntity[entity] = nil
	end
end

return StructureConstructionPresentationSystem
