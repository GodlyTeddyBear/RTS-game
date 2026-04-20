--!strict
--[=[
	@class TransitionPresets
	Configuration table of named screen transition animation presets, each defining enter and exit phases with per-element timing and easing.
	@client
]=]

export type TDirection = "fromTop" | "fromBottom" | "fromLeft" | "fromRight" | "none"

export type TElementAnimation = {
	Direction: TDirection?,
	Offset: number?,
	Scale: boolean?,
	ScaleFrom: number?,
	Spring: string?,
	Delay: number?,
	StaggerIndex: number?,
}

export type TPhase = {
	Name: string?,
	ParallelGroup: string?,
	Elements: { [string]: TElementAnimation },
	StaggerDelay: number?,
	DefaultSpring: string?,
}

export type TPresetConfig = {
	Elements: { string },
	Enter: { TPhase },
	Exit: { TPhase },
}

local TransitionPresets: { [string]: TPresetConfig } = {
	--[[
		Standard - Universal screen layout: Header, TabBar, Content, Footer.

		Enter:
			Phase group "StandardEnter" (parallel):
				EdgeEntrance: Header from top then Footer from bottom (staggered)
				ContentEntrance: TabBar then Content slide from right (staggered)

		Exit (reverse):
			Phase group "StandardExit" (parallel):
				ContentExit: TabBar then Content slide out to right (staggered)
				EdgeExit: Header slides up then Footer slides down (staggered)
	]]
	--[[
		Simple - Minimal screen layout with a single Content element.

		Enter:
			Phase 1: Content scales up and fades in from right

		Exit (reverse):
			Phase 1: Content slides out to right
	]]
	Simple = {
		Elements = { "Content" },
		Enter = {
			{
				Name = "ContentEntrance",
				Elements = {
					Content = { Direction = "fromRight", Offset = 0.15, Scale = true, ScaleFrom = 0.9 },
				},
				DefaultSpring = "Smooth",
			},
		},
		Exit = {
			{
				Name = "ContentExit",
				Elements = {
					Content = { Direction = "fromRight", Offset = 0.15 },
				},
				DefaultSpring = "Responsive",
			},
		},
	},

	HUD = {
		Elements = { "Header" },
		Enter = {
			{
				Name = "HeaderEntrance",
				Elements = {
					Header = { Direction = "fromTop", Offset = 0.14 },
				},
				DefaultSpring = "Smooth",
			},
		},
		Exit = {
			{
				Name = "HeaderExit",
				Elements = {
					Header = { Direction = "fromTop", Offset = 0.14 },
				},
				DefaultSpring = "Responsive",
			},
		},
	},

	Standard = {
		Elements = { "Header", "TabBar", "Content", "Footer" },
		Enter = {
			{
				Name = "EdgeEntrance",
				ParallelGroup = "StandardEnter",
				StaggerDelay = 0.03,
				Elements = {
					Header = { Direction = "fromTop", Offset = 0.1, StaggerIndex = 0 },
					Footer = { Direction = "fromBottom", Offset = 0.1, StaggerIndex = 1 },
				},
				DefaultSpring = "Smooth",
			},
			{
				Name = "ContentEntrance",
				ParallelGroup = "StandardEnter",
				StaggerDelay = 0.04,
				Elements = {
					TabBar = { Direction = "fromRight", Offset = 1.2, StaggerIndex = 0 },
					Content = { Direction = "fromRight", Offset = 1.2, StaggerIndex = 1 },
				},
				DefaultSpring = "Smooth",
			},
		},
		Exit = {
			{
				Name = "ContentExit",
				ParallelGroup = "StandardExit",
				StaggerDelay = 0.03,
				Elements = {
					TabBar = { Direction = "fromRight", Offset = 1.2, StaggerIndex = 0 },
					Content = { Direction = "fromRight", Offset = 1.2, StaggerIndex = 1 },
				},
				DefaultSpring = "Responsive",
			},
			{
				Name = "EdgeExit",
				ParallelGroup = "StandardExit",
				StaggerDelay = 0.03,
				Elements = {
					Header = { Direction = "fromTop", Offset = 0.1, StaggerIndex = 0 },
					Footer = { Direction = "fromBottom", Offset = 0.1, StaggerIndex = 1 },
				},
				DefaultSpring = "Responsive",
			},
		},
	},
}

return table.freeze(TransitionPresets)
