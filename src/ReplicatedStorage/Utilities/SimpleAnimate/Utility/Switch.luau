type Switch<U, T...> = {
	Switch: (self: Switch<U, T...>, state: U, T...) -> (),
	Get: (self: Switch<U, T...>) -> U
}

local function switch_switch(self: any, new: boolean, ...)
	if new ~= self._state then
		self._state = new
		self._fn(new, ...)
	end
end

local function switch_get(self: any)
	return self._state
end

-- Creates a new <code>Switch</code>
local function switch_new<U, T...>(default: U, fn: (U, T...) -> ()): Switch<U, T...>
	assert(default ~= nil, "A default state must be provided")
	
	return {
		_fn = fn,
		_state = default,
		
		Switch = switch_switch,
		Get = switch_get
	}
end

return {
	new = switch_new
}