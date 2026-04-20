--!strict
--[[
    =========  TYPE VALIDATION  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Centralized validation functions used across all BitFrames modules.
]]

local Check = {}

function Check._assertArg(value: any, argName: string, expectedType: string, level: number?)
    local errorLevel = (level or 2) + 1
    if value == nil then
        error(string.format("Missing argument: '%s' (expected %s)", argName, expectedType), errorLevel)
    end
    if typeof(value) ~= expectedType then
        error(string.format("Invalid argument: '%s' (expected %s, got %s)", argName, expectedType, typeof(value)), errorLevel)
    end
end

function Check._assertGuiObject(value: any, argName: string, level: number?)
    local errorLevel = (level or 2) + 1
    if value == nil then
        error(string.format("Missing argument: '%s' (expected GuiObject)", argName), errorLevel)
    end
    if typeof(value) ~= "Instance" or not value:IsA("GuiObject") then
        local actualType = typeof(value) == "Instance" and value.ClassName or typeof(value)
        error(string.format("Invalid argument: '%s' (expected GuiObject, got %s)", argName, actualType), errorLevel)
    end
end

return table.freeze(Check)

