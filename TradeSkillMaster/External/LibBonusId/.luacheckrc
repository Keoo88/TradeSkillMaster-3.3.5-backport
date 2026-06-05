local opt = {}
opt.std = "lua51c"

-- Load globals
opt.globals = {}
opt.read_globals = {
	-- Addon Globals
	"LibStub",

	-- Math Functions
	"floor",
	"max",
	"min",

	-- String Functions
	"gmatch",
	"strmatch",
	"tonumber",
	"tostring",

	-- Table Functions
	"sort",
	"tinsert",
	"tremove",
	"wipe",

	-- Strictly Required WoW APIs
	"GetBuildInfo",
}

-- No max line length
opt.max_line_length = false

-- Show warning codes in output
opt.codes = true

-- Ignore warnings
opt.ignore = {
	"311", -- pre-setting locals to nil
	"542", -- empty if blocks
	"212", -- unused function arguments
}

-- Only output files with warnings / errors
opt.quiet = 1

opt.exclude_files = {
	"LibStub/",
	"Data.lua",
	"Test.lua",
}

return opt
