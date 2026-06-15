local _, Private = ...

local Pairs = pairs
local Select = select
local GetMapZones = GetMapZones

local C_Map = C_Map or {}

local function LoadZones(Object, ...)
	for i=1, Select('#', ...) do
		Object[i] = Select(i, ...)
	end
end

function C_Map.IsWorldMap(UIMap) 
	if ( not C_Map.WorldMap ) then
		C_Map.WorldMap = {}
		for ContinentIndex = 1, 4 do
			LoadZones(C_Map.WorldMap, GetMapZones(ContinentIndex))
		end
	end

	for _, Zone in Pairs(C_Map.WorldMap) do
		if ( Zone == UIMap ) then
			return true
		end
	end
end

C_Map.GetBestMapForUnit = Private.Void

-- Global
_G.C_Map = C_Map