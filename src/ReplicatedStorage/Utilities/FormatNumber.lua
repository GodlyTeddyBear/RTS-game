--!strict

-- FormatNumber: Number abbreviation system for large numbers
-- Handles numbers up to 1e50+ with K, M, B, T, Qa, etc. suffixes

local FormatNumber = {}

-- Format large numbers with suffixes
function FormatNumber.format(value: number): string
	-- Handle negative numbers
	local isNegative = value < 0
	value = math.abs(value)

	-- Suffixes for thousands, millions, billions, etc.
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

	-- Calculate tier (thousands = 1, millions = 2, billions = 3, etc.)
	local tier = math.floor(math.log10(value) / 3)

	-- Small numbers (< 1000): show whole number
	if tier == 0 then
		local formatted = tostring(math.floor(value))
		return isNegative and "-" .. formatted or formatted
	end

	-- Get appropriate suffix
	local suffix = suffixes[tier + 1] or string.format("e%d", tier * 3)

	-- Scale the number
	local scaled = value / (10 ^ (tier * 3))

	-- Format with 2 decimal places
	local formatted = string.format("%.2f%s", scaled, suffix)

	return isNegative and "-" .. formatted or formatted
end

-- Format number with specific decimal places
function FormatNumber.formatWithDecimals(value: number, decimals: number): string
	local isNegative = value < 0
	value = math.abs(value)

	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
	local tier = math.floor(math.log10(value) / 3)

	if tier == 0 then
		local formatted = string.format("%." .. decimals .. "f", value)
		return isNegative and "-" .. formatted or formatted
	end

	local suffix = suffixes[tier + 1] or string.format("e%d", tier * 3)
	local scaled = value / (10 ^ (tier * 3))
	local formatted = string.format("%." .. decimals .. "f%s", scaled, suffix)

	return isNegative and "-" .. formatted or formatted
end

-- Format number as whole number with commas (for smaller values)
function FormatNumber.formatWithCommas(value: number): string
	local isNegative = value < 0
	value = math.abs(value)

	local formatted = tostring(math.floor(value))

	-- Add commas
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end

	return isNegative and "-" .. formatted or formatted
end

-- Format for display: use commas for < 10K, suffixes for >= 10K
function FormatNumber.formatForDisplay(value: number): string
	if math.abs(value) < 10000 then
		return FormatNumber.formatWithCommas(value)
	else
		return FormatNumber.format(value)
	end
end

return FormatNumber
