--!strict

--[[
    SelectionConfig - Visual and input configuration for NPC selection system.
]]

return table.freeze({
	-- Highlight colors
	HighlightFillColor = Color3.fromRGB(0, 170, 255),
	HighlightOutlineColor = Color3.fromRGB(255, 255, 255),
	HighlightFillTransparency = 0.75,
	HighlightOutlineTransparency = 0.3,

	-- Ground circle (selected adventurers)
	CircleColor = Color3.fromRGB(255, 255, 255),
	CircleSize = Vector3.new(0.1, 5, 5),
	CircleTransparency = 0.5,
	CircleYOffset = -2.5, -- Below NPC feet

	-- Targeted enemy ground circle
	TargetedCircleColor = Color3.fromRGB(255, 40, 40),
	TargetedCircleSize = Vector3.new(0.1, 5, 5),
	TargetedCircleTransparency = 0.5,

	-- Selection box (drag rectangle)
	BoxColor = Color3.fromRGB(0, 170, 255),
	BoxTransparency = 0.7,
	BoxBorderColor = Color3.fromRGB(255, 255, 255),
	BoxBorderSize = 2,

	-- Move marker (persistent ground circle)
	MoveMarkerColor = Color3.fromRGB(0, 255, 100),
	MoveMarkerSize = Vector3.new(0.1, 3, 3),
	MoveMarkerTransparency = 0.3,

	-- Box selection hit tolerance (pixels expanded on each side of the drag rect)
	BoxSelectPadding = 20,

	-- Enemy target highlight (pick-target mode hover)
	EnemyHighlightFillColor = Color3.fromRGB(255, 40, 40),
	EnemyHighlightOutlineColor = Color3.fromRGB(255, 80, 80),
	EnemyHighlightFillTransparency = 0.6,
	EnemyHighlightOutlineTransparency = 0.2,

	-- Confirmed target highlight (persistent after E confirm)
	TargetedHighlightFillColor = Color3.fromRGB(0, 0, 0),
	TargetedHighlightOutlineColor = Color3.fromRGB(0, 0, 0),
	TargetedHighlightFillTransparency = 0.7,
	TargetedHighlightOutlineTransparency = 0.1,

	-- Tags
	NPCTag = "CombatNPC",
})
