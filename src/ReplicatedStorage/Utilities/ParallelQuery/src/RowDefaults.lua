--!strict

local Types = require(script.Parent.Types)

type TResultField = Types.TResultField

local RowDefaults = {}

local function _BuildDefaultValue(field: TResultField): any
	if field.Type == "boolean" then
		return false
	end
	if field.Type == "string" then
		return ""
	end
	if field.Type == "vector2" then
		return Vector2.zero
	end
	if field.Type == "vector2i16" then
		return Vector2int16.new(0, 0)
	end
	if field.Type == "vector3" then
		return Vector3.zero
	end
	if field.Type == "vector3i16" then
		return Vector3int16.new(0, 0, 0)
	end
	if field.Type == "cframe" or field.Type == "cframef32" or field.Type == "cframe18" then
		return CFrame.identity
	end
	if field.Type == "color3" or field.Type == "color3b16" then
		return Color3.new(0, 0, 0)
	end
	return 0
end

function RowDefaults.BuildFlatDefaults(schema: { TResultField }): { any }
	local defaults = table.create(#schema)

	for index, field in ipairs(schema) do
		defaults[index] = _BuildDefaultValue(field)
	end

	return defaults
end

function RowDefaults.BuildPackedValues(
	schema: { TResultField },
	defaults: { any },
	row: { [string]: any } | { any }
): { any }
	local values = table.create(#schema)

	for index, field in ipairs(schema) do
		local value = row[field.Name]
		if value == nil then
			value = row[index]
		end
		if value == nil then
			value = defaults[index]
		end

		values[index] = value
	end

	return values
end

function RowDefaults.BuildNamedRow(schema: { TResultField }, overrides: { [string]: any }?): { [string]: any }
	local row = {}
	local overrideValues = if overrides ~= nil then overrides else {}

	for _, field in ipairs(schema) do
		local value = overrideValues[field.Name]
		if value == nil then
			value = _BuildDefaultValue(field)
		end
		row[field.Name] = value
	end

	return row
end

return table.freeze(RowDefaults)
