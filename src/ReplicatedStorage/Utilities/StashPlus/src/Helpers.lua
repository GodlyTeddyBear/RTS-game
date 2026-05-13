--!strict

local Types = require(script.Parent.Types)

type TAddOptions = Types.TAddOptions
type TCleanupMethod = Types.TCleanupMethod

local HelperMethods = {}

local function _BuildOptions(keyOrOptions: any, cleanupMethod: TCleanupMethod?, label: string?): TAddOptions
	if type(keyOrOptions) == "table" then
		local options = table.clone(keyOrOptions)
		if options.CleanupMethod == nil then
			options.CleanupMethod = cleanupMethod
		end
		if options.Label == nil then
			options.Label = label
		end
		return options
	end

	return {
		CleanupMethod = cleanupMethod,
		Key = keyOrOptions,
		Label = label,
	}
end

function HelperMethods:AddCallback(label: string, callback: () -> (), keyOrOptions: any?): (() -> ())
	return self:Add(callback, _BuildOptions(keyOrOptions, true, label))
end

function HelperMethods:AddConnection(connection: RBXScriptConnection, keyOrOptions: any?): RBXScriptConnection
	return self:Add(connection, _BuildOptions(keyOrOptions, "Disconnect", nil))
end

function HelperMethods:AddFunction(callback: () -> (), keyOrOptions: any?): (() -> ())
	return self:Add(callback, _BuildOptions(keyOrOptions, true, nil))
end

function HelperMethods:AddInstance(instance: Instance, keyOrOptions: any?): Instance
	return self:Add(instance, _BuildOptions(keyOrOptions, "Destroy", nil))
end

function HelperMethods:AddPromise(promiseObject: any, keyOrOptions: any?): any
	self:_AssertAlive()
	self:_AssertNotCleaning("AddPromise")

	local options = _BuildOptions(keyOrOptions, nil, nil)
	local key = options.Key
	local label = options.Label
	local trackedPromise = self._janitor:AddPromise(promiseObject, key)

	if key ~= nil then
		self._trackedKeys[key] = trackedPromise
		self._trackedMetadata[key] = {
			Resource = trackedPromise,
			CleanupMethod = nil,
			Label = if label ~= nil then label else tostring(key),
		}
	end

	return trackedPromise
end

function HelperMethods:AddStash(stash: any, keyOrOptions: any?): any
	return self:Add(stash, _BuildOptions(keyOrOptions, "Destroy", nil))
end

function HelperMethods:AddTask(cleanupThread: thread, keyOrOptions: any?): thread
	return self:Add(cleanupThread, _BuildOptions(keyOrOptions, true, nil))
end

function HelperMethods:AddThread(cleanupThread: thread, keyOrOptions: any?): thread
	return self:AddTask(cleanupThread, keyOrOptions)
end

function HelperMethods:LinkToInstance(instance: Instance, allowMultiple: boolean?): RBXScriptConnection
	self:_AssertAlive()
	self:_AssertNotCleaning("LinkToInstance")
	assert(typeof(instance) == "Instance", "StashPlus:LinkToInstance requires an Instance")

	local connection = instance.Destroying:Connect(function()
		if self:IsDestroyed() then
			return
		end

		self:Destroy()
	end)

	local linkKey = if allowMultiple then connection else "__StashPlusLinkToInstance"
	self._janitor:Add(connection, "Disconnect", linkKey)
	return connection
end

return table.freeze(HelperMethods)
