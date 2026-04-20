--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local function useLogs(logsAtom: () -> { any }): { any }
	return ReactCharm.useAtom(logsAtom) or {}
end

return useLogs
