--!strict

--[=[
    @class SetupAimCommand
    Resolves supported aim setup requests into a running client-side aim runtime.

    Owns strategy dispatch only. It selects the supported aim strategy and returns
    the cleanup handle produced by the runtime implementation.
    @client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)
local IKControlAimRuntime = require(script.Parent.Parent.Parent.Infrastructure.IKControlAimRuntime)

type TSetupAimRequest = Types.TSetupAimRequest

local SetupAimCommand = {}
SetupAimCommand.__index = SetupAimCommand

-- ── Public API ──────────────────────────────────────────────────────────────

--[=[
    Constructs a new setup command instance.
    @within SetupAimCommand
    @return SetupAimCommand -- Command instance used to execute aim setup requests.
]=]
function SetupAimCommand.new()
	return setmetatable({}, SetupAimCommand)
end

--[=[
    Starts the supported aim runtime for the given request.
    @within SetupAimCommand
    @param request TSetupAimRequest -- Fully resolved aim request from the animation controller.
    @return (() -> ())? -- Cleanup handle when the runtime starts, or nil if the strategy is unsupported.
]=]
function SetupAimCommand:Execute(request: TSetupAimRequest): (() -> ())?
	if request.Strategy == "IKControl" then
		return IKControlAimRuntime.Start(request)
	end

	warn("SetupAimCommand: unsupported strategy", tostring(request.Strategy))
	return nil
end

return SetupAimCommand
