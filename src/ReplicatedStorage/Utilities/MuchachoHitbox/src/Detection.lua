--!strict

local Types = require(script.Parent.Parent.Types)

type THitbox = Types.Hitbox

local Detection = {}

local function resolveHumanoid(hit: BasePart): Humanoid?
	local character = hit:FindFirstAncestorOfClass("Model") or hit.Parent
	if character == nil then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

function Detection.FindTouchEnded(hitbox: THitbox, currentPartsSet: { [BasePart]: boolean })
	local previousTouchingPartsSet = hitbox.TouchingPartsSet
	if previousTouchingPartsSet == nil or next(previousTouchingPartsSet) == nil then
		return
	end

	for part in pairs(previousTouchingPartsSet) do
		if not currentPartsSet[part] then
			hitbox.TouchEnded:Fire(part)
		end
	end
end

function Detection.TrackHumanoidHit(hitbox: THitbox, humanoid: Humanoid): boolean
	local hitListSet = hitbox.HitListSet
	if hitListSet == nil then
		hitListSet = {}
		hitbox.HitListSet = hitListSet
	end

	if hitListSet[humanoid] then
		return false
	end

	hitListSet[humanoid] = true
	table.insert(hitbox.HitList, humanoid)
	return true
end

function Detection.Cast(hitbox: THitbox, parts: { BasePart })
	local currentParts = table.create(#parts)
	local currentPartsSet = {}

	for _, hit in ipairs(parts) do
		if not currentPartsSet[hit] then
			currentPartsSet[hit] = true
			table.insert(currentParts, hit)
		end
	end

	Detection.FindTouchEnded(hitbox, currentPartsSet)
	hitbox.TouchingParts = currentParts
	hitbox.TouchingPartsSet = currentPartsSet

	local mode = hitbox.DetectionMode
	if mode == "HitParts" then
		for _, hit in ipairs(currentParts) do
			hitbox.Touched:Fire(hit, nil)
		end
		return
	end

	for _, hit in ipairs(currentParts) do
		local humanoid = resolveHumanoid(hit)
		if mode == "Default" then
			if humanoid ~= nil and Detection.TrackHumanoidHit(hitbox, humanoid) then
				hitbox.Touched:Fire(hit, humanoid)
			end
		elseif mode == "ConstantDetection" then
			if humanoid ~= nil then
				hitbox.Touched:Fire(hit, humanoid)
			end
		elseif mode == "HitOnce" then
			if humanoid ~= nil then
				hitbox.Touched:Fire(hit, humanoid)
				hitbox.TouchEnded:Fire(hit)
				hitbox:Destroy()
				return
			end
		end
	end
end

return Detection
