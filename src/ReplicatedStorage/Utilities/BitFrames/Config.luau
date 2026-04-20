--!strict
--[[
    =========  DEFAULTS  =========
]]
local Defaults = table.freeze({
    DURATION = 0.3,
    EASING = "OutQuad",
    DAMPING = 0.8,
    FREQUENCY = 3,
    DELAY = 0,
})

--[[
    =========  EASING ENUM  =========
]]
local Easing = table.freeze({
    Linear = "Linear",
    InQuad = "InQuad", OutQuad = "OutQuad", InOutQuad = "InOutQuad",
    InCubic = "InCubic", OutCubic = "OutCubic", InOutCubic = "InOutCubic",
    InQuart = "InQuart", OutQuart = "OutQuart", InOutQuart = "InOutQuart",
    InQuint = "InQuint", OutQuint = "OutQuint", InOutQuint = "InOutQuint",
    InSine = "InSine", OutSine = "OutSine", InOutSine = "InOutSine",
    InExpo = "InExpo", OutExpo = "OutExpo", InOutExpo = "InOutExpo",
    InCirc = "InCirc", OutCirc = "OutCirc", InOutCirc = "InOutCirc",
    InElastic = "InElastic", OutElastic = "OutElastic", InOutElastic = "InOutElastic",
    InBack = "InBack", OutBack = "OutBack", InOutBack = "InOutBack",
    InBounce = "InBounce", OutBounce = "OutBounce", InOutBounce = "InOutBounce",
})

--[[
    =========  SPRING PRESETS  =========
]]
local Spring = {
    Default = { damping = 1, frequency = 1 },
    Gentle = { damping = 0.9, frequency = 2 },
    Bouncy = { damping = 0.5, frequency = 4 },
    Stiff = { damping = 0.8, frequency = 8 },
    Slow = { damping = 0.9, frequency = 1 },
    Molasses = { damping = 1.2, frequency = 0.5 },
}

--[[
    =========  TEXT EFFECT DEFAULTS  =========
]]
local TextDefaults = table.freeze({
    TYPEWRITER_SPEED = 0.05,
    CURSOR = "|",
    SCRAMBLE_DURATION = 1,
    SCRAMBLE_CHARS = "!@#$%^&*()_+-=[]{}|;:,.<>?",
})

--[[
    =========  ATTENTION EFFECT DEFAULTS  =========
]]
local AttentionDefaults = table.freeze({
    DURATION = 0.4,
    LOOPS = 1,
})

return table.freeze({
    Defaults = Defaults,
    Easing = Easing,
    Spring = table.freeze(Spring),
    TextDefaults = TextDefaults,
    AttentionDefaults = AttentionDefaults,
})