--[=[
	@class Types
	Type definitions for MuchachoHitbox components.
	@server
	@client
]=]

local GoodSignal = require(script.Parent.GoodSignal)

local types = {}

--[=[
	@interface HitboxProperties
	@within Types
	Base configuration properties common to all hitbox instances.
	.Visualizer boolean -- Whether to render a debug visualization part
	.DetectionMode "Default" | "ConstantDetection" | "HitOnce" | "HitParts" -- Event firing behavior
	.AutoDestroy boolean -- Whether to automatically clean up signals on stop
	.Key string -- Unique identifier for tracking active hitboxes
	.OverlapParams OverlapParams -- Roblox query configuration (group filters, etc.)
	.Size Vector3 -- Hitbox dimensions (extent for blocks, radius for balls)
	.Shape Enum.PartType -- Block or Ball shape
	.CFrame CFrame -- World position and rotation
	.Offset CFrame -- Local offset from the source CFrame
	.VelocityPredictionTime number? -- Seconds ahead to predict movement
	.VelocityPrediction boolean? -- Whether to enable velocity-based prediction
	.Touched GoodSignal.Signal<BasePart, Humanoid?> -- Signal fired on collision
	.TouchEnded GoodSignal.Signal<BasePart, Humanoid?> -- Signal fired on separation
]=]
export type HitboxProperties = {
	Visualizer: boolean,
	DetectionMode: ("Default" | "ConstantDetection" | "HitOnce" | "HitParts"),
	AutoDestroy: boolean,
	Key: string,

	OverlapParams: OverlapParams,

	Size: Vector3,
	Shape: Enum.PartType,
	CFrame: CFrame,
	Offset: CFrame,

	VelocityPredictionTime: number?,
	VelocityPrediction: boolean?,

	Touched: GoodSignal.Signal<BasePart, Humanoid?>,
	TouchEnded: GoodSignal.Signal<BasePart, Humanoid?>,
} & any

--[=[
	@type Hitbox
	@within Types
	Complete hitbox instance with all configuration, events, and methods.
	Extends HitboxProperties with visualization color, methods, and internal state.
]=]
export type Hitbox = {
	-- Visualization configuration
	Visualizer: boolean,
	VisualizerColor: Color3?,
	VisualizerTransparency: number,

	-- Detection configuration
	DetectionMode: ("Default" | "ConstantDetection" | "HitOnce" | "HitParts"),
	AutoDestroy: boolean,
	Key: string,

	OverlapParams: OverlapParams,

	-- Geometry
	Size: Vector3,
	Shape: Enum.PartType,
	CFrame: CFrame,
	Offset: CFrame,

	-- Velocity prediction
	VelocityPredictionTime: number?,
	VelocityPrediction: boolean?,

	-- Collision events
	Touched: GoodSignal.Signal<BasePart, Humanoid?>,
	TouchEnded: GoodSignal.Signal<BasePart, Humanoid?>,

	-- Lifecycle methods
	Start: (self: Hitbox) -> (),
	Stop: (self: Hitbox) -> (),
	Destroy: (self: Hitbox) -> (boolean),

	-- Internal state (for debugging)
	HitList: {Model}?,
	TouchingParts: {BasePart}?,
	Connection: RBXScriptConnection?,
	Box: BoxHandleAdornment? | SphereHandleAdornment?,
} & any

return types