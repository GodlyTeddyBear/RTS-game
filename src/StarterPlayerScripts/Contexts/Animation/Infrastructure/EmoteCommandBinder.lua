--!strict

local TextChatService = game:GetService("TextChatService")

local EmoteCommandBinder = {}

local function _ToActionKey(emoteName: string): string
	return emoteName:sub(1, 1):upper() .. emoteName:sub(2):lower()
end

function EmoteCommandBinder.Bind(
	character: Model,
	janitor: any,
	action: any,
	core: any,
	validEmotes: { [string]: boolean }
)
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return
	end

	local activeEmoteTrack: AnimationTrack? = nil
	local emoteCleanupConnections: { RBXScriptConnection } = {}

	local function stopEmote()
		for _, connection in emoteCleanupConnections do
			connection:Disconnect()
		end
		table.clear(emoteCleanupConnections)

		if activeEmoteTrack then
			activeEmoteTrack:Stop(0.1)
			activeEmoteTrack = nil
		end

		if core and core.PoseController then
			core.PoseController:SetCoreCanPlayAnims(true)
		end
	end

	local function playEmote(emoteName: string)
		if not validEmotes[emoteName] or not core or not core.PoseController then
			return
		end

		local poseController = core.PoseController
		if poseController:GetPose() ~= "Idle" then
			return
		end

		stopEmote()

		poseController:SetCoreCanPlayAnims(false)
		poseController:StopCoreAnimations(0.1)

		local track = action:PlayAction(emoteName)
		if not track then
			poseController:SetCoreCanPlayAnims(true)
			return
		end

		activeEmoteTrack = track

		table.insert(emoteCleanupConnections, track.Stopped:Once(function()
			stopEmote()
		end))
		table.insert(emoteCleanupConnections, humanoid.Running:Once(function(speed: number)
			if speed > 0.5 then
				stopEmote()
			end
		end))
		table.insert(emoteCleanupConnections, humanoid.Jumping:Once(function()
			stopEmote()
		end))
	end

	local textChatCommands = TextChatService:FindFirstChild("TextChatCommands")
	if textChatCommands then
		local emoteCommand = Instance.new("TextChatCommand")
		emoteCommand.Name = "EmoteCommand"
		emoteCommand.PrimaryAlias = "/e"
		emoteCommand.SecondaryAlias = "/emote"
		emoteCommand.Parent = textChatCommands

		emoteCommand.Triggered:Connect(function(_originTextSource, unfilteredText)
			local emoteName = unfilteredText:match("^/e%s+(%w+)") or unfilteredText:match("^/emote%s+(%w+)")
			if emoteName then
				playEmote(_ToActionKey(emoteName))
			end
		end)

		janitor:Add(emoteCommand, "Destroy")
	end

	local playEmoteBindable = character:FindFirstChild("PlayEmote")
	if playEmoteBindable and playEmoteBindable:IsA("BindableFunction") then
		playEmoteBindable.OnInvoke = function(emoteName: string)
			local actionKey = _ToActionKey(emoteName)
			if validEmotes[actionKey] then
				playEmote(actionKey)
				return true
			end
			return false
		end
	end

	janitor:Add(function()
		stopEmote()
	end, true)
end

return EmoteCommandBinder
