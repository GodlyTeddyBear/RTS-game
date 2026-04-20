--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])

--[[
	Base Sync Service (Server)

	Eliminates boilerplate across server-side sync services. Provides:
	- CharmSync.server + Blink init-only payload wiring
	- HydratePlayer / Destroy lifecycle
	- Deep clone utility and read-only getters
	- LoadUserData / RemoveUserData for common atom operations

	Subclass via standard Lua inheritance:

		local MySync = setmetatable({}, { __index = BaseSyncService })
		MySync.__index = MySync
		MySync.AtomKey = "myKey"
		MySync.BlinkEventName = "SyncMyKey"
		MySync.CreateAtom = SharedAtoms.CreateServerAtom

		function MySync.new()
			return setmetatable({}, MySync)
		end
]]

local BaseSyncService = {}
BaseSyncService.__index = BaseSyncService

local function deepClone(tbl: any): any
	if type(tbl) ~= "table" then
		return tbl
	end

	local clone = {}
	for key, value in pairs(tbl) do
		clone[key] = deepClone(value)
	end

	return clone
end

function BaseSyncService:Init(registry: any, _name: string)
	self.BlinkServer = registry:Get("BlinkServer")
	self.Atom = self.CreateAtom()

	local atomKey = self.AtomKey
	local blinkEventName = self.BlinkEventName

	self.Syncer = CharmSync.server({
		atoms = { [atomKey] = self.Atom },
		interval = 0.33,
		preserveHistory = false,
		autoSerialize = false,
	})

	self.Cleanup = self.Syncer:connect(function(player: Player, _: any)
		local userId = player.UserId
		local allState = self.Atom()
		local playerState = allState[userId]

		if playerState == nil then
			return
		end

		local fullStatePayload = {
			type = "init",
			data = { [atomKey] = playerState },
		}

		self.BlinkServer[blinkEventName].Fire(player, fullStatePayload)
	end)
end

function BaseSyncService:HydratePlayer(player: Player)
	self.Syncer:hydrate(player)
end

function BaseSyncService:GetAtom()
	return self.Atom
end

--- Deep clones atom()[userId] for safe read-only access
function BaseSyncService:GetReadOnly(userId: number): any?
	local allState = self.Atom()
	local userState = allState[userId]
	return userState and deepClone(userState) or nil
end

--- Deep clones atom()[userId][key] for safe read-only access
function BaseSyncService:GetNestedReadOnly(userId: number, key: string): any?
	local allState = self.Atom()
	local userState = allState[userId]
	if not userState then
		return nil
	end
	local nested = userState[key]
	return nested and deepClone(nested) or nil
end

--- Sets atom[userId] = data
function BaseSyncService:LoadUserData(userId: number, data: any)
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = data
		return updated
	end)
end

--- Clears atom[userId]
function BaseSyncService:RemoveUserData(userId: number)
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = nil
		return updated
	end)
end

function BaseSyncService:Destroy()
	if self.Cleanup then
		self.Cleanup()
	end
end

return BaseSyncService
