--!strict

local ZoneTargetUtils = {}

function ZoneTargetUtils.FindTargetInZone(zoneFolder: Instance, targetId: string, preferredFolderName: string?): Instance?
	if preferredFolderName then
		local preferredFolder = zoneFolder:FindFirstChild(preferredFolderName)
		if preferredFolder then
			local foundInPreferred = preferredFolder:FindFirstChild(targetId)
			if foundInPreferred then
				return foundInPreferred
			end
		end
	end

	return zoneFolder:FindFirstChild(targetId)
end

return ZoneTargetUtils
