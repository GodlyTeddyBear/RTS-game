--!strict
--[[
    =========  HELPERS  =========
    Made by @RiseBit, Discord: risebit, Github: https://github.com/RiseBit

    Centralized helper functions used across Effects modules.
]]

--[[
    =========  MODULES  =========
]]
local Easing = require(script.Parent.Easing)

--[[
    =========  MAIN MODULE  =========
]]
local Helpers = {}

function Helpers._setTransparency(element: GuiObject, alpha: number)
    if not element then
        warn("[BitFrames] Element is nil")
        return
    end
    if not alpha then
        warn("[BitFrames] Alpha is nil")
        return
    end

    element.BackgroundTransparency = alpha
    if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
        (element :: TextLabel).TextTransparency = alpha
    end
    if element:IsA("ImageLabel") or element:IsA("ImageButton") then
        (element :: ImageLabel).ImageTransparency = alpha
    end
end

function Helpers._getTransparencyProps(element: GuiObject, config: any?): {string}
	if config and config.transparencyProperties then
		return config.transparencyProperties
	end

	local props = { "BackgroundTransparency" }
	if element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("TextBox") then
		table.insert(props, "TextTransparency")
	end
	if element:IsA("ImageLabel") or element:IsA("ImageButton") then
		table.insert(props, "ImageTransparency")
	end
	return props
end

function Helpers._setSelectiveTransparency(element: GuiObject, alpha: number, props: {string})
	for _, prop in props do
		(element :: any)[prop] = alpha
	end
end

function Helpers._lerpSelectiveTransparency(
	element: GuiObject,
	originals: {[string]: any},
	alpha: number,
	props: {string}
)
	for _, prop in props do
		local orig = originals[prop] or 0
		(element :: any)[prop] = orig + (1 - orig) * alpha
	end
end

function Helpers._getEasing(name: string): (number) -> number
	local fn = Easing.get(name)
	if not fn then
		warn(`[BitFrames] Unknown easing '{name}', using default 'OutQuad'`)
		return Easing.OutQuad
	end
	return fn
end

function Helpers._isValidElement(element: Instance): boolean
	return element ~= nil and element.Parent ~= nil
end

return table.freeze(Helpers)
