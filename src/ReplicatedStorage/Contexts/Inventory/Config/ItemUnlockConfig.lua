--!strict

--[[
	Derived unlock entries for shop items from `ItemConfig`.
	Owning context: Inventory.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(script.Parent.ItemConfig)
local ItemData = require(script.Parent.Parent.Types.ItemData)
local UnlockEntryTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockEntryTypes)

type TUnlockEntry = UnlockEntryTypes.TUnlockEntry

local exports: { [string]: TUnlockEntry } = {}

for itemId, raw in ItemConfig do
	local item = raw :: ItemData.ItemData
	local meta = item.Unlock
	if meta then
		exports[itemId] = {
			TargetId = itemId,
			Category = meta.Category,
			DisplayName = meta.DisplayName or item.name,
			Description = meta.Description or item.description,
			Conditions = meta.Conditions,
			AutoUnlock = meta.AutoUnlock,
			StartsUnlocked = meta.StartsUnlocked,
		}
	end
end

return exports
