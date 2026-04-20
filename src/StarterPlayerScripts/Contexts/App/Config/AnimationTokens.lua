--!strict
--[=[
	@class AnimationTokens
	Design token constants for animation timings, spring physics, easing curves, and interaction presets.
	@client
]=]

local AnimationTokens = {
	-- Duration tokens (in seconds)
	-- Use these for tween and count-up animations
	Duration = table.freeze({
		Instant = 0,
		Fast = 0.15,
		Normal = 0.3,
		Slow = 0.5,
		VerySlow = 0.8,
	}),

	-- Spring physics presets (dampingRatio, frequency)
	-- Higher damping = more controlled, lower = bouncier
	-- Higher frequency = faster, lower = slower
	Spring = table.freeze({
		-- Gentle, smooth springs (high damping, low frequency)
		Gentle = table.freeze({
			DampingRatio = 1,
			Frequency = 1,
		}),
		Smooth = table.freeze({
			DampingRatio = 0.8,
			Frequency = 1.5,
		}),

		-- Responsive springs (medium damping, medium frequency)
		Default = table.freeze({
			DampingRatio = 0.7,
			Frequency = 2,
		}),
		Responsive = table.freeze({
			DampingRatio = 0.6,
			Frequency = 2.5,
		}),

		-- Bouncy springs (low damping, high frequency)
		Bouncy = table.freeze({
			DampingRatio = 0.5,
			Frequency = 3,
		}),
		Wobbly = table.freeze({
			DampingRatio = 0.3,
			Frequency = 3.5,
		}),
	}),

	-- Tween easing styles (for non-spring animations)
	-- Used with TweenService for predictable, linear-style tweens
	Easing = table.freeze({
		Linear = Enum.EasingStyle.Linear,
		Quad = Enum.EasingStyle.Quad,
		Cubic = Enum.EasingStyle.Cubic,
		Quart = Enum.EasingStyle.Quart,
		Quint = Enum.EasingStyle.Quint,
		Sine = Enum.EasingStyle.Sine,
		Expo = Enum.EasingStyle.Exponential,
		Circular = Enum.EasingStyle.Circular,
		Back = Enum.EasingStyle.Back,
		Elastic = Enum.EasingStyle.Elastic,
		Bounce = Enum.EasingStyle.Bounce,
	}),

	-- Easing direction
	Direction = table.freeze({
		In = Enum.EasingDirection.In,
		Out = Enum.EasingDirection.Out,
		InOut = Enum.EasingDirection.InOut,
	}),

	-- Interaction presets (for useHoverSpring)
	-- Define scale factors and spring presets per UI element type
	Interaction = table.freeze({
		SlotCell = table.freeze({
			HoverScale = 1.04,
			PressScale = 0.96,
			SpringPreset = "Responsive",
		}),
		ActionButton = table.freeze({
			HoverScale = 1.06,
			PressScale = 0.93,
			SpringPreset = "Bouncy",
		}),
		Tab = table.freeze({
			HoverScale = 1.02,
			PressScale = 0.97,
			SpringPreset = "Smooth",
		}),
		Card = table.freeze({
			HoverScale = 1.015,
			PressScale = 0.985,
			SpringPreset = "Gentle",
		}),
		DropdownItem = table.freeze({
			HoverScale = 1.03,
			PressScale = 0.95,
			SpringPreset = "Responsive",
		}),
	}),

	-- Panel transition presets (for useAnimatedVisibility)
	Panel = table.freeze({
		DetailPanel = table.freeze({
			Mode = "slideRight",
			SpringPreset = "Smooth",
		}),
		Dropdown = table.freeze({
			Mode = "slideUp",
			SpringPreset = "Responsive",
		}),
	}),

	-- Stagger presets (for useStaggeredMount)
	Stagger = table.freeze({
		Grid = table.freeze({
			Delay = 0.025,
			MaxDelay = 0.3,
		}),
		List = table.freeze({
			Delay = 0.04,
			MaxDelay = 0.35,
		}),
	}),

	-- Screen transition defaults (for useScreenTransition element animations)
	ScreenEntrance = table.freeze({
		DefaultOffset = 0.1,
		DefaultStaggerDelay = 0.04,
		DefaultScaleFrom = 0.85,
	}),

	-- Screen transition configurations
	-- Pre-configured animations for common transition types
	Transition = table.freeze({
		Slide = table.freeze({
			Duration = 0.35,
			Spring = table.freeze({
				DampingRatio = 0.4,
				Frequency = 4,
			}),
		}),
		Fade = table.freeze({
			Duration = 0.3,
			Spring = table.freeze({
				DampingRatio = 0.55,
				Frequency = 4,
			}),
		}),
		Scale = table.freeze({
			Duration = 0.3,
			Spring = table.freeze({
				DampingRatio = 0.35,
				Frequency = 4.5,
			}),
		}),
	}),
}

export type TAnimationTokens = typeof(AnimationTokens)
return table.freeze(AnimationTokens)
