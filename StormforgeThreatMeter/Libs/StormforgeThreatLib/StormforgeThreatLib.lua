---@diagnostic disable: undefined-global
--[[
===================================================
Functionality
===================================================
threatTable[npcGUID]                             --a hash table that stores data related to threat on an NPC

threatTable[npcGUID].unitName                    --returns the unit name of the npc
threatTable[npcGUID].GUIDwithAggro               --returns the GUID of the unit who currently has aggro on the npc
threatTable[npcGUID].lastAggroSwitchTime         --stores the result of GetTime() on the last time SMSG_HIGHEST_THREAT_UPDATE event fired off on this npcGUID
threatTable[npcGUID].GUIDsByThreatRank[n]        --returns the GUID of the unit who is at rank n on the npc's threat list

threatTable[npcGUID].GUID.unitName               --returns the unit name of the GUID on the npc's threat list
threatTable[npcGUID].GUID.threatRank             --returns the threat rank of the GUID on the npc's threat list
threatTable[npcGUID].GUID.threat                 --returns the threat the of the GUID on the npc's threat list

--data structure--
threatTable[npcGUID] = {
	[unitName] = "Gurtogg Bloodboil",
	[GUIDwithAggro] = "0x17379391382510114265",
	[GUIDsByThreatRank] = {"0x17379391382510114265", "0x17379391380412961343", "0x1737934561612961343"},
	[0x1737934561612961343] = {
		[unitName] = "Mec",
		[threatRank] = 3,
		[threat] = 10570,
	},
	[0x17379391382510114265] = {
		[unitName] = "Vkm",
		[threatRank] = 1,
		[threat] = 32101,
	},
	[0x17379391380412961343] = {
		[unitName] = "Cillo",
		[threatRank] = 2,
		[threat] = 27889,
	}
}

===================================================
Stormforge CHAT_MSG_ADDON documentation
===================================================
These CHAT_MSG_ADDON events are sent out every second to the client from the Stormforge server.
Be careful, because the GUIDs from the server are lowercase whereas the WoW client's in-game UnitGUID() function is uppercase.

SMSG_HIGHEST_THREAT_UPDATE -> sends threat list for a given npc (sent when current victim changes). Current victim's unit name is appended with an asterisk.
SMSG_THREAT_UPDATE  -> sends threat list for a given npc (sent when any changes occur) [1sec frequency limit]. Current victim's unit name is appended with an asterisk.
SMSG_THREAT_REMOVE -> sends guid of a unit who has been removed from a given npc's threat list
SMSG_THREAT_CLEAR -> sent when an npc's threat list has been wiped
]]

local version = 1.2
local STL = LibStub:NewLibrary("StormforgeThreatLib", version)

if not STL then return end
if not STL.frame then STL.frame = CreateFrame("Frame") end
STL.threatTable = STL.threatTable or {}

local stringsub, tableinsert = string.sub, table.insert
local threatTable = STL.threatTable

function STL.split(str)
	local list = {}
	local prior_delim_index = 0
	local c
	for i = 1, #str do
		c = stringsub(str, i, i)
		if c == "/" or c == "~" or c == ";" then
			tableinsert(list, stringsub(str, prior_delim_index + 1, i - 1))
			prior_delim_index = i
		elseif i == #str then
			tableinsert(list, stringsub(str, prior_delim_index + 1, i))
		end
	end

	return list
end

function STL.parseThreatUpdateMsg(msg, msg_type)
	--threat_data: {npcGUID, npcUnitName, unit1GUID, unit1Name, unit1Threat, unit2GUID, unit2Name, unit2Threat, ...}
	local threat_data = STL.split(msg)
	local npcGUID = threat_data[1]
	local npcUnitName = threat_data[2]

	if not threatTable[npcGUID] then threatTable[npcGUID] = {} end
	if not threatTable[npcGUID].unitName then threatTable[npcGUID].unitName = npcUnitName end

	local unitGUID, unitName, threat
	local GUIDsByThreatRank = {}
	for i = 3, #threat_data, 3 do
		unitGUID = threat_data[i]
		if stringsub(threat_data[i + 1], -1, -1) == "*" then
			--this unit has aggro
			unitName = stringsub(threat_data[i + 1], 1, -2)
			threatTable[npcGUID].GUIDwithAggro = unitGUID

			if msg_type == "SMSG_HIGHEST_THREAT_UPDATE" then
				threatTable[npcGUID].lastAggroSwitchTime = GetTime()
			end
		else
			unitName = threat_data[i + 1]
		end
		threat = tonumber(threat_data[i + 2])
		if not threatTable[npcGUID][unitGUID] then threatTable[npcGUID][unitGUID] = {} end
		if not threatTable[npcGUID][unitGUID].unitName then threatTable[npcGUID][unitGUID].unitName = unitName end
		threatTable[npcGUID][unitGUID].threat = threat

		tableinsert(GUIDsByThreatRank, {
			unitGUID = unitGUID,
			threat = threat
		})
	end

	threatTable[npcGUID].GUIDsByThreatRank = {}

	table.sort(GUIDsByThreatRank, function(k1, k2) return k1.threat > k2.threat end)
	for i=1, #GUIDsByThreatRank do
		tableinsert(threatTable[npcGUID].GUIDsByThreatRank, GUIDsByThreatRank[i].unitGUID)
	end

	GUIDsByThreatRank = nil
end

function STL.parseThreatClear(msg)
	local npcGUID = STL.split(msg)[1]
	if threatTable[npcGUID] then
		threatTable[npcGUID] = nil
	end
end

function STL.parseThreatRemove(msg)
	--threat_data: {npcGUID, unitGUID}
	local threat_data = STL.split(msg)
	local npcGUID = threat_data[1]
	local unitGUID = threat_data[2]
	if not threatTable[npcGUID] then return end
	if threatTable[npcGUID][unitGUID] then threatTable[npcGUID][unitGUID] = nil end
end

function STL.frame:OnEvent(event, ...)
	if event == "CHAT_MSG_ADDON" then
		if arg1 == "SMSG_THREAT_UPDATE" or arg1 == "SMSG_HIGHEST_THREAT_UPDATE" then
			STL.parseThreatUpdateMsg(arg2, arg1)
		elseif arg1 == "SMSG_THREAT_CLEAR" then
			STL.parseThreatClear(arg2)
		elseif arg1 == "SMSG_THREAT_REMOVE" then
			STL.parseThreatRemove(arg2)
		end
	end
end

STL.frame:RegisterEvent("CHAT_MSG_ADDON")
STL.frame:SetScript("OnEvent", STL.frame.OnEvent)
