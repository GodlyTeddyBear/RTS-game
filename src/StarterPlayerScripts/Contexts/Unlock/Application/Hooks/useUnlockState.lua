--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState

local useAtom = ReactCharm.useAtom

--[[
	Read hook that subscribes to the unlock state atom from UnlockController.

	@return Current unlock state { [targetId]: true } or {} if not yet hydrated
]]
local function useUnlockState(): TUnlockState
	local unlockController = Knit.GetController("UnlockController")
	if not unlockController then
		warn("useUnlockState: UnlockController not available")
		return {}
	end
	local unlocksAtom = unlockController:GetUnlocksAtom()
	local atomValue = useAtom(unlocksAtom)
	-- Unlock sync payload shape is `{ unlocks = { [targetId] = true } }`.
	-- Accept both envelope and raw map for compatibility.
	if atomValue == nil then
		return {}
	end
	if atomValue.unlocks ~= nil then
		return atomValue.unlocks
	end
	return atomValue
end

return useUnlockState
