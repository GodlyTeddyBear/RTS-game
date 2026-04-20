--!strict

--[=[
	@class ProfileInit
	Entry point for player data persistence — creates the `ProfileStore` and passes it to `SessionManager`.
	All session lifecycle logic lives in `SessionManager`.
	@server
]=]

local RunService = game:GetService("RunService")
local ServerScript = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScript.ServerPackages.Profilestore)
local SessionManager = require(ServerScript.Persistence.SessionManager)
local Template = require(ServerScript.Persistence.Template)

local storeName = RunService:IsStudio() and "Test" or "Live"
local pStore = ProfileStore.New(storeName, Template)

SessionManager(pStore)
