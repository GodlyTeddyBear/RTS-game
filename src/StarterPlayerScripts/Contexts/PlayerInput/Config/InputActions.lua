--!strict

--[[
	Input Actions Configuration

	Defines all keybind actions grouped by OmrezKeyBind context.
	Each context can be enabled/disabled independently at runtime.

	Structure:
	  [ContextName] = {
	    Enabled = boolean?,  -- defaults to true
	    [ActionName] = {
	      PC = { Input = ..., Toggle = boolean?, Priority = number?, Combo = ...? },
	      Gamepad = { ... },
	      Touch = { ... },
	    },
	  }
]]

return {
	Movement = {
		Sprint = {
			PC = { Input = Enum.KeyCode.X, Toggle = true },
		},
	},
}
