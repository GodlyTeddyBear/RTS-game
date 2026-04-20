--!strict
--[[
    =========  TEXT EFFECTS  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Pre-made text animations using centralized Scheduler.
]]

--[[
    =========  MODULES  =========
]]
local Config = require(script.Parent.Parent.Config)
local Check = require(script.Parent.Parent.Utils.Check)
local AnimationFactory = require(script.Parent.Parent.Core.AnimationFactory)
local Helpers = require(script.Parent.Parent.Utils.Helpers)
local Transform = require(script.Parent.Parent.Utils.Transform)
local Types = require(script.Parent.Parent.Core.Types)

local assertArg = Check._assertArg
local isValidElement = Helpers._isValidElement
local TextDefaults = Config.TextDefaults
local Defaults = Config.Defaults
local getEasing = Helpers._getEasing

--[[
    =========  TYPES  =========
]]
type TypewriterConfig = Types.TypewriterConfig
type ScrambleConfig = Types.ScrambleConfig
type RollValueConfig = Types.RollValueConfig
type ColorCycleConfig = Types.ColorCycleConfig
type ColorPulseConfig = Types.ColorPulseConfig
type GlitchConfig = Types.GlitchConfig
type TransitionConfig = Types.TransitionConfig
type EffectController = Types.EffectController

--[[
    =========  HELPER FUNCTIONS  =========
]]
local function isTextElement(element: Instance): boolean
    return element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox")
end

local function hsvToColor3(h: number, s: number, v: number): Color3
    return Color3.fromHSV(h % 1, s, v)
end

--[[
    =========  MAIN MODULE  =========
]]
local TextEffect = {}

function TextEffect.typewriter(element: GuiObject, text: string, config: TypewriterConfig?): EffectController
    assertArg(element, "element", "Instance")
    assertArg(text, "text", "string")

    if not isTextElement(element) then
        error("Element must be TextLabel, TextButton, or TextBox", 2)
    end
    
    local textElement = element :: TextLabel
    local speed = config and config.speed or TextDefaults.TYPEWRITER_SPEED
    local cursor = config and config.cursor or TextDefaults.CURSOR
    local onComplete = config and config.onComplete

    local elapsed = 0
    local charIndex = 0
    local totalChars = #text
    local showCursor = true
    local cursorTimer = 0
    local lastCursorState = true

    textElement.Text = ""

    local function reset()
        textElement.Text = text
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(element) then return true end

            elapsed = elapsed + dt
            cursorTimer = cursorTimer + dt

            if cursorTimer >= 0.5 then
                cursorTimer = 0
                showCursor = not showCursor
            end
            
            local targetIndex = math.floor(elapsed / speed)
            local charAdvanced = targetIndex > charIndex and charIndex < totalChars
            local cursorChanged = showCursor ~= lastCursorState

            if charAdvanced then
                charIndex = math.min(targetIndex, totalChars)
                local displayText = string.sub(text, 1, charIndex)
                if cursor ~= "" and charIndex < totalChars then
                    displayText = displayText .. (showCursor and cursor or "")
                end
                textElement.Text = displayText
                
                local soundSource = config and config.sound
                if soundSource then
                    local soundToPlay: Instance? = nil
                    if soundSource:IsA("Folder") then
                         local sounds = soundSource:GetChildren()
                         if #sounds > 0 then
                            soundToPlay = sounds[math.random(1, #sounds)]
                         end
                    elseif soundSource:IsA("Sound") then
                        soundToPlay = soundSource
                    end
                    
                    if soundToPlay and soundToPlay:IsA("Sound") then
                        local sfx = soundToPlay:Clone()
                        sfx.Name = "TypewriterSFX"
                        sfx.Parent = game:GetService("SoundService")
                        sfx:Play()
                        task.delay(sfx.TimeLength + 1, function()
                            if sfx then sfx:Destroy() end
                        end)
                    end
                end

            elseif cursorChanged and charIndex < totalChars then
                local displayText = string.sub(text, 1, charIndex)
                if cursor ~= "" then
                    displayText = displayText .. (showCursor and cursor or "")
                end
                textElement.Text = displayText
                lastCursorState = showCursor
            end

            if charIndex >= totalChars then
                -- Persist final text
                textElement.Text = text
                return true
            end
            return false
        end,
        onComplete,
        reset,
        "typewriter",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

function TextEffect.scramble(element: GuiObject, text: string, config: ScrambleConfig?): EffectController
    assertArg(element, "element", "Instance")
    assertArg(text, "text", "string")

    if not isTextElement(element) then
        error("Element must be TextLabel, TextButton, or TextBox", 2)
    end
    
    local textElement = element :: TextLabel
    local duration = math.max(config and config.duration or TextDefaults.SCRAMBLE_DURATION, 0.001)
    local chars = config and config.chars or TextDefaults.SCRAMBLE_CHARS
    local charsLen = #chars
    local onComplete = config and config.onComplete

    if charsLen == 0 then
        chars = TextDefaults.SCRAMBLE_CHARS
        charsLen = #chars
    end

    local elapsed = 0
    local totalChars = #text
    local random = Random.new()

    local function reset()
        if isValidElement(textElement) then
            textElement.Text = text
        end
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(textElement) then return true end
            
            elapsed = elapsed + dt
            local progress = math.clamp(elapsed / duration, 0, 1)

            local revealedCount = math.floor(progress * totalChars)
            local charTable = table.create(totalChars)

            for i = 1, totalChars do
                if i <= revealedCount then
                    charTable[i] = string.sub(text, i, i)
                else
                    local idx = random:NextInteger(1, charsLen)
                    charTable[i] = string.sub(chars, idx, idx)
                end
            end

            textElement.Text = table.concat(charTable)

            if progress >= 1 then
                textElement.Text = text -- Ensure final text is correct
                return true
            end
            return false
        end,
        onComplete,
        reset,
        "scramble",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

function TextEffect.colorCycle(element: GuiObject, config: ColorCycleConfig?): EffectController
    assertArg(element, "element", "Instance")
    if not isTextElement(element) then
        error("Element must be TextLabel, TextButton, or TextBox", 2)
    end
    Transform._saveState(element)

    local textElement = element :: TextLabel
    local speed = config and config.speed or 1
    local saturation = config and config.saturation or 1
    local brightness = config and config.brightness or 1

    local elapsed = 0

    local function reset()
        if isValidElement(element) then
            Transform._restoreState(element)
        end
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(textElement) then return true end
            elapsed = elapsed + dt * speed
            textElement.TextColor3 = hsvToColor3(elapsed, saturation, brightness)
            return false
        end,
        nil,
        reset,
        "colorCycle",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

function TextEffect.colorPulse(element: GuiObject, config: ColorPulseConfig?): EffectController
    assertArg(element, "element", "Instance")

    if not isTextElement(element) then
        error("Element must be TextLabel, TextButton, or TextBox", 2)
    end
    Transform._saveState(element)

    local textElement = element :: TextLabel
    local fromColor = config and config.fromColor or Color3.new(1, 1, 1)
    local toColor = config and config.toColor or Color3.new(1, 0, 0)
    local speed = config and config.speed or 1

    local elapsed = 0

    local function reset()
        if isValidElement(element) then
            Transform._restoreState(element)
        end
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(textElement) then return true end
            elapsed = elapsed + dt * speed
            local progress = (math.sin(elapsed * math.pi * 2) + 1) / 2
            textElement.TextColor3 = fromColor:Lerp(toColor, progress)
            return false
        end,
        nil,
        reset,
        "colorPulse",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

function TextEffect.glitch(element: GuiObject, config: GlitchConfig?): EffectController
    assertArg(element, "element", "Instance")

    if not isTextElement(element) then
        error("Element must be TextLabel, TextButton, or TextBox", 2)
    end
    Transform._saveState(element)

    local textElement = element :: TextLabel
    local intensity = config and config.intensity or 0.3
    local speed = config and config.speed or 10

    local originalText = Transform._getOriginal(element).Text or textElement.Text
    local originalColor = Transform._getOriginal(element).TextColor3 or textElement.TextColor3
    
    local random = Random.new()
    local elapsed = 0
    local nextGlitch = 0

    local glitchChars = "!@#$%^&*()_+-=[]{}|;:,.<>?/\\~`"

    local function reset()
        if isValidElement(element) then
            Transform._restoreState(element)
        end
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(textElement) then return true end
            elapsed = elapsed + dt

            if elapsed >= nextGlitch then
                nextGlitch = elapsed + (1 / speed)

                if random:NextNumber() < intensity then
                    local result = ""
                    for i = 1, #originalText do
                        if random:NextNumber() < intensity then
                            local idx = random:NextInteger(1, #glitchChars)
                            result = result .. string.sub(glitchChars, idx, idx)
                        else
                            result = result .. string.sub(originalText, i, i)
                        end
                    end
                    textElement.Text = result
                    textElement.TextColor3 = Color3.new(
                        random:NextNumber(),
                        random:NextNumber(),
                        random:NextNumber()
                    )
                else
                    textElement.Text = originalText
                    textElement.TextColor3 = originalColor
                end
            end

            return false
        end,
        nil,
        reset,
        "glitch",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

function TextEffect.fadeColor(element: GuiObject, toColor: Color3, config: TransitionConfig?): EffectController
    assertArg(element, "element", "Instance")

    if not isTextElement(element) then
        error("Element must be TextLabel, TextButton, or TextBox", 2)
    end
    
    local textElement = element :: TextLabel
    local duration = config and config.duration or 0.3
    local onComplete = config and config.onComplete

    local fromColor = textElement.TextColor3
    local elapsed = 0

    local function reset()
        textElement.TextColor3 = fromColor
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(textElement) then return true end
            elapsed = elapsed + dt
            local progress = math.clamp(elapsed / duration, 0, 1)
            textElement.TextColor3 = fromColor:Lerp(toColor, progress)

            if progress >= 1 then
                textElement.TextColor3 = toColor
                return true
            end
            return false
        end,
        onComplete,
        reset,
        "fadeColor",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

function TextEffect.rollValue(element: GuiObject, targetValue: number, config: RollValueConfig?): EffectController
    assertArg(element, "element", "Instance")
    assertArg(targetValue, "targetValue", "number")

    if not isTextElement(element) then
        error("Element must be TextLabel, TextButton, or TextBox", 2)
    end
    
    local textElement = element :: TextLabel
    local duration = math.max(config and config.duration or 0.5, 0.001)
    local easingName = config and config.easing or "OutQuad"
    local customFormat = config and config.format
    local onComplete = config and config.onComplete

    local text = textElement.Text
    local currentText = text:gsub("[^%d%.%-]", "")
    local startValue = config and config.startValue or tonumber(currentText) or 0
    local elapsed = 0

    local easingFn = Helpers._getEasing(easingName)

    local function formatNumber(value: number): string
        if customFormat then
            return customFormat(value)
        end
        return tostring(math.floor(value + 0.5))
    end

    local function reset()
        if isValidElement(textElement) then
            textElement.Text = formatNumber(targetValue)
        end
    end

    local animation = AnimationFactory._create(
        function(dt: number): boolean
            if not isValidElement(textElement) then return true end

            elapsed = elapsed + dt
            local progress = math.clamp(elapsed / duration, 0, 1)
            local easedProgress = easingFn(progress)
            local currentValue = startValue + (targetValue - startValue) * easedProgress

            textElement.Text = formatNumber(currentValue)

            if progress >= 1 then
                textElement.Text = formatNumber(targetValue)
                return true
            end
            return false
        end,
        onComplete,
        reset,
        "rollValue",
        element
    )

    AnimationFactory._start(animation)
    return AnimationFactory._createController(animation, reset)
end

return table.freeze(TextEffect)
