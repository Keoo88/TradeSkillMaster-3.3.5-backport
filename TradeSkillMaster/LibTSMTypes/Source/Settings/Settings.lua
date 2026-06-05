-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Settings = LibTSMTypes:Init("Settings")
local SettingsSchema = LibTSMTypes:IncludeClassType("SettingsSchema")
local SettingsDB = LibTSMTypes:IncludeClassType("SettingsDB")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new settings schema.
---@param version number The current version
---@param minVersion minVersion The minimum version
---@return SettingsSchema
function Settings.NewSchema(version, minVersion)
	return SettingsSchema.New(version, minVersion)
end

---Loads a new settings DB.
---@param name string The name of the global table
---@param schema SettingsSchema The schema
---@param realmName string The current realm name
---@param factionName string The current faction name
---@param characterName string The current character name
---@param connectedRealms? string[] Connected realm names
---@param accessibleFactions string[] Accessible faction names
---@return SettingsDB
---@return SettingsMigration
function Settings.NewDB(name, schema, realmName, factionName, characterName, connectedRealms, accessibleFactions)
	return SettingsDB.New(name, schema, realmName, factionName, characterName, connectedRealms, accessibleFactions)
end
