local Types = require(script.Parent.Parent.Types)

return function(animsTable: {Types.AnimInfo}): (AnimationTrack, number, Types.AnimInfo)
	local totalWeight = 0

	for i = 1, #animsTable do
		local animInfo = animsTable[i]

		totalWeight += animInfo.weight or 1
	end

	local randomWeight = math.random() * totalWeight
	local cumulativeWeight = 0

	for i = 1, #animsTable do
		local animInfo = animsTable[i]

		cumulativeWeight += animInfo.weight or 1
		if randomWeight <= cumulativeWeight then
			return animInfo.anim, #animsTable, animInfo
		end
	end

	local info = animsTable[#animsTable]
	-- Fallback
	return info.anim, #animsTable, info
end