--!strict

local Types = require(script.Parent.Types)

type TSelectDropdownConfig = Types.TSelectDropdownConfig
type TSelectDropdownOption = Types.TSelectDropdownOption
type TNormalizedSelectDropdownConfig = Types.TNormalizedSelectDropdownConfig
type TNormalizedSelectDropdownOption = Types.TNormalizedSelectDropdownOption

local Config = {}

local function _NormalizeOption(index: number, option: TSelectDropdownOption): TNormalizedSelectDropdownOption
	assert(type(option) == "table", ("SelectDropdownController option at index %d must be a table"):format(index))
	assert(
		type(option.Id) == "string" and #option.Id > 0,
		("SelectDropdownController option at index %d requires a non-empty Id"):format(index)
	)
	assert(
		type(option.Label) == "string" and #option.Label > 0,
		("SelectDropdownController option '%s' requires a non-empty Label"):format(option.Id)
	)
	assert(
		option.Disabled == nil or type(option.Disabled) == "boolean",
		("SelectDropdownController option '%s' Disabled must be a boolean"):format(option.Id)
	)

	return table.freeze({
		Id = option.Id,
		Label = option.Label,
		Disabled = option.Disabled == true,
	})
end

function Config.NormalizeConfig(config: TSelectDropdownConfig): TNormalizedSelectDropdownConfig
	assert(type(config) == "table", "SelectDropdownController requires a config table")
	assert(type(config.Id) == "string" and #config.Id > 0, "SelectDropdownController requires a non-empty Id")
	assert(type(config.Options) == "table", "SelectDropdownController requires an Options array")
	assert(config.InitialOpen == nil or type(config.InitialOpen) == "boolean", "InitialOpen must be a boolean")
	assert(
		config.InitialSelectedId == nil or type(config.InitialSelectedId) == "string",
		"InitialSelectedId must be a string"
	)
	assert(
		config.PlaceholderLabel == nil or type(config.PlaceholderLabel) == "string",
		"PlaceholderLabel must be a string"
	)
	assert(config.CloseOnSelect == nil or type(config.CloseOnSelect) == "boolean", "CloseOnSelect must be a boolean")
	assert(
		config.AllowEmptySelection == nil or type(config.AllowEmptySelection) == "boolean",
		"AllowEmptySelection must be a boolean"
	)

	local normalizedOptions = {}
	local optionsById: { [string]: TNormalizedSelectDropdownOption } = {}

	for index, option in config.Options do
		assert(type(index) == "number", "SelectDropdownController Options must be an array")

		local normalizedOption = _NormalizeOption(index, option)
		assert(
			optionsById[normalizedOption.Id] == nil,
			("SelectDropdownController option ids must be unique: '%s'"):format(normalizedOption.Id)
		)

		table.insert(normalizedOptions, normalizedOption)
		optionsById[normalizedOption.Id] = normalizedOption
	end

	local allowEmptySelection = config.AllowEmptySelection ~= false
	local initialSelectedId = config.InitialSelectedId
	if initialSelectedId ~= nil then
		local initialOption = optionsById[initialSelectedId]
		assert(initialOption ~= nil, "InitialSelectedId must reference a registered option")
		assert(not initialOption.Disabled, "InitialSelectedId cannot reference a disabled option")
	elseif not allowEmptySelection then
		error("InitialSelectedId is required when AllowEmptySelection is false")
	end

	return table.freeze({
		Id = config.Id,
		Options = table.freeze(normalizedOptions),
		OptionsById = table.freeze(optionsById),
		InitialOpen = config.InitialOpen == true,
		InitialSelectedId = initialSelectedId,
		PlaceholderLabel = config.PlaceholderLabel,
		CloseOnSelect = config.CloseOnSelect ~= false,
		AllowEmptySelection = allowEmptySelection,
	})
end

return table.freeze(Config)
