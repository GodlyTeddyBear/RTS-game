--!strict

local Types = require(script.Parent.Types)

local ScopeMethods = {}
ScopeMethods.__index = ScopeMethods

local Lifecycle = {}

function ScopeMethods:Add(handle: any): any
	table.insert(self._Handles, handle)
	return handle
end

function ScopeMethods:CancelAll()
	for _, handle in ipairs(self._Handles) do
		if type(handle) == "table" and type(handle.Cancel) == "function" then
			handle:Cancel()
		elseif type(handle) == "table" and type(handle.Destroy) == "function" then
			handle:Destroy()
		end
	end
end

function ScopeMethods:PauseAll()
	for _, handle in ipairs(self._Handles) do
		if type(handle) == "table" and type(handle.Pause) == "function" then
			handle:Pause()
		end
	end
end

function ScopeMethods:ResumeAll()
	for _, handle in ipairs(self._Handles) do
		if type(handle) == "table" and type(handle.Resume) == "function" then
			handle:Resume()
		end
	end
end

function ScopeMethods:Destroy()
	self:CancelAll()
	table.clear(self._Handles)
end

function ScopeMethods:GetCount(): number
	return #self._Handles
end

function Lifecycle.Scope(): Types.TScope
	return setmetatable({
		_Handles = {},
	}, ScopeMethods) :: any
end

return Lifecycle
