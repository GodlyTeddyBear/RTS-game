--!strict

local Types = require(script.Parent.Types)

type TFieldType = Types.TFieldType
type TResultField = Types.TResultField

local Field = {}

local function _Create(name: string, fieldType: TFieldType, length: number?): TResultField
	assert(type(name) == "string" and name ~= "", "ParallelQuery.Field requires a non-empty field name")

	local field: TResultField = {
		Name = name,
		Type = fieldType,
		Length = length,
	}

	return table.freeze(field)
end

function Field.Create(name: string, fieldType: TFieldType, length: number?): TResultField
	return _Create(name, fieldType, length)
end

function Field.u8(name: string): TResultField
	return _Create(name, "u8", nil)
end

function Field.u16(name: string): TResultField
	return _Create(name, "u16", nil)
end

function Field.u32(name: string): TResultField
	return _Create(name, "u32", nil)
end

function Field.i8(name: string): TResultField
	return _Create(name, "i8", nil)
end

function Field.i16(name: string): TResultField
	return _Create(name, "i16", nil)
end

function Field.i32(name: string): TResultField
	return _Create(name, "i32", nil)
end

function Field.f32(name: string): TResultField
	return _Create(name, "f32", nil)
end

function Field.f64(name: string): TResultField
	return _Create(name, "f64", nil)
end

function Field.boolean(name: string): TResultField
	return _Create(name, "boolean", nil)
end

function Field.string(name: string, length: number): TResultField
	return _Create(name, "string", length)
end

function Field.vector2(name: string): TResultField
	return _Create(name, "vector2", nil)
end

function Field.vector2i16(name: string): TResultField
	return _Create(name, "vector2i16", nil)
end

function Field.vector3(name: string): TResultField
	return _Create(name, "vector3", nil)
end

function Field.vector3i16(name: string): TResultField
	return _Create(name, "vector3i16", nil)
end

function Field.cframe(name: string): TResultField
	return _Create(name, "cframe", nil)
end

function Field.cframef32(name: string): TResultField
	return _Create(name, "cframef32", nil)
end

function Field.cframe18(name: string): TResultField
	return _Create(name, "cframe18", nil)
end

function Field.color3(name: string): TResultField
	return _Create(name, "color3", nil)
end

function Field.color3b16(name: string): TResultField
	return _Create(name, "color3b16", nil)
end

return table.freeze(Field)
