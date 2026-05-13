--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)

local Signals = {}

function Signals.Create(stash: any, key: string)
	local signal = GoodSignal.new()
	stash:Add(signal, {
		CleanupMethod = "DisconnectAll",
		Key = key,
		Label = key,
	})
	return signal
end

return table.freeze(Signals)
