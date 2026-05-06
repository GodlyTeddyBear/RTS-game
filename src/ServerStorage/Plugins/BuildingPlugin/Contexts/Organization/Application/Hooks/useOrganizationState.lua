--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local OrganizationAtom = require(script.Parent.Parent.Parent.Infrastructure.OrganizationAtom)

local function useOrganizationState()
	return ReactCharm.useAtom(OrganizationAtom.GetAtom())
end

return useOrganizationState
