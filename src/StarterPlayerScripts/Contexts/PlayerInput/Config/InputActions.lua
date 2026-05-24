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

local selectionContext = {
	Enabled = false,
	ShiftSelectionModifier = {
		PC = { Input = { Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift } },
	},
	AltSelectionClearModifier = {
		PC = { Input = { Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt } },
	},
	ControlGroupModifier = {
		PC = { Input = { Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl } },
	},
}

local controlGroupKeyCodes = {
	[0] = Enum.KeyCode.Zero,
	[1] = Enum.KeyCode.One,
	[2] = Enum.KeyCode.Two,
	[3] = Enum.KeyCode.Three,
	[4] = Enum.KeyCode.Four,
	[5] = Enum.KeyCode.Five,
	[6] = Enum.KeyCode.Six,
	[7] = Enum.KeyCode.Seven,
	[8] = Enum.KeyCode.Eight,
	[9] = Enum.KeyCode.Nine,
}

for slot, keyCode in pairs(controlGroupKeyCodes) do
	selectionContext[`RecallControlGroup{slot}`] = {
		PC = { Input = keyCode },
	}
end

return {
	Movement = {
		Sprint = {
			PC = { Input = Enum.KeyCode.X, Toggle = true },
		},
	},
	SelectionMode = {
		ToggleSelectionMode = {
			PC = { Input = Enum.KeyCode.Z },
		},
	},
	Placement = {
		Enabled = false,
		CancelPlacement = {
			PC = { Input = Enum.KeyCode.Q },
		},
		RotatePlacement = {
			PC = { Input = Enum.KeyCode.R },
		},
	},
	Selection = selectionContext,
}
