---@diagnostic disable: undefined-global, undefined-field

STM_CONFIG = {
	isLocked = false,
	showClassIcons = true,
	warnThreshold = 115
}

local STL = LibStub:GetLibrary("StormforgeThreatLib")
local threatTable = STL.threatTable

local stringsub, stringfind, stringlower, stringformat, min, floor = string.sub, string.find, string.lower, string
	.format, math.min, math.floor

local meter = CreateFrame("Frame", "SFTM_Frame", UIParent)
local scale = GetCVar("uiScale")
local font_path = "Interface\\AddOns\\StormforgeThreatMeter\\media\\skurri.ttf"
local font_size = 10
local sound_warning_file = "Sound\\Spells\\SeepingGaseous_Fel_Nova.wav"
local min_bars = 5
local max_bars = 25
local max_currently_visible_bars = 5
local bar_height = 15
local bar_padding = 2
local left_margin = bar_height

--meter window
meter:SetFrameStrata("MEDIUM")
meter:SetHeight((bar_height + bar_padding + 0.05) / scale * (max_currently_visible_bars + 1))
meter:SetWidth(140 / scale)
meter:SetPoint("CENTER", UIParent, "CENTER", 300 / scale, 0)
meter.background = meter:CreateTexture(nil, "BACKGROUND")
meter.background:SetTexture(0, 0, 0, 1)
meter.background:SetAllPoints()
meter:SetClampedToScreen(true)
meter:SetMovable(true)
meter:EnableMouse(true)
meter:SetResizable(true)
meter:SetMinResize(120 / scale, (bar_height + bar_padding + 0.05) / scale * min_bars)
meter:SetMaxResize(500 / scale, (bar_height + bar_padding + 0.05) / scale * max_bars)
meter:RegisterForDrag("LeftButton")
meter:SetScript("OnDragStart", meter.StartMoving)
meter:SetScript("OnDragStop", meter.StopMovingOrSizing)
meter.timeSinceLastUpdate = 0
meter.targetGUID = nil
meter.targetName = nil
meter.GUIDwithAggro = nil
meter.GUIDwithAggroThreat = nil
meter.soundWarnedTime = 0

local function calculateMaxVisibleBars()
	return floor(meter:GetHeight() / ((bar_height + bar_padding) / scale) - 1)
end

--meter title
meter.title = meter:CreateFontString(nil, "ARTWORK")
meter.title:SetFont(font_path, font_size / scale)
meter.title:SetHeight(10 / scale)
meter.title:SetPoint("TOPLEFT", meter, "TOPLEFT", 0, 13 / scale)
meter.title:SetPoint("TOPRIGHT", meter, "TOPRIGHT", 0, -5 / scale)
meter.title:SetJustifyH("LEFT")
meter.title:SetTextColor(1, 0.549, 0, 1)
meter.title:SetShadowColor(0, 0, 0, 1)
meter.title:SetShadowOffset(1, -1)
meter.title:SetText("Stormforge Threat Meter (/stm)")

--resize button
meter.resizeButton = CreateFrame("Button", nil, meter)
meter.resizeButton:SetWidth(16 / scale)
meter.resizeButton:SetHeight(16 / scale)
meter.resizeButton:SetPoint("BOTTOMRIGHT")
meter.resizeButton:SetNormalTexture("Interface\\AddOns\\StormforgeThreatMeter\\media\\resize.tga")
meter.resizeButton:SetScript("OnMouseDown", function(self, button)
	meter:StartSizing("BOTTOMRIGHT")
end)
meter.resizeButton:SetScript("OnMouseUp", function(self, button)
	meter:StopMovingOrSizing()
	max_currently_visible_bars = calculateMaxVisibleBars()
	meter:update()
end)
meter:SetScript("OnSizeChanged", function(self)
	max_currently_visible_bars = calculateMaxVisibleBars()
	meter:update()
end)

local function addText(bar, justify)
	local text = bar:CreateFontString(nil, "ARTWORK")
	text:SetHeight(bar:GetHeight())
	text:SetFont(font_path, font_size / scale)
	text:SetJustifyH(justify)
	text:SetTextColor(1, 1, 1, 1)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetShadowOffset(1, -1)
	return text
end

--threat bars
local function createThreatBar(y)
	local bar = CreateFrame("Frame", nil, meter)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", meter, "TOPLEFT", left_margin / scale, y / scale)
	bar:SetPoint("TOPRIGHT", meter, "TOPRIGHT", 0, y / scale)
	bar:SetHeight(bar_height / scale)

	bar.background = bar:CreateTexture(nil, "BACKGROUND")
	bar.background:SetTexture(0.1, 0.1, 0.1, 1)
	bar.background:SetAllPoints(bar)

	bar.foreground = bar:CreateTexture(nil, "LOW")
	bar.foreground:SetTexture(0.592, 0.463, 0.333, 1)
	bar.foreground:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	bar.foreground:SetHeight(bar:GetHeight())

	bar.nameText = addText(bar, "LEFT")
	bar.nameText:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	bar.nameText:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -70 / scale, 0)

	bar.threatText = addText(bar, "RIGHT")
	bar.threatText:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -35 / scale, 0)
	bar.threatText:SetWidth(35 / scale)

	bar.threatPrctText = addText(bar, "RIGHT")
	bar.threatPrctText:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -3 / scale, 0)
	bar.threatPrctText:SetWidth(33 / scale)

	bar.icon = bar:CreateTexture(nil, "OVERLAY")
	bar.icon:SetPoint("TOPLEFT", -left_margin / scale, 0)
	bar.icon:SetHeight(bar_height / scale)
	bar.icon:SetWidth(bar_height / scale)
	bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) --slight zoom in
	bar.icon:Hide()

	bar:Hide()
	return bar
end

local pullAggroBar = createThreatBar(0)
pullAggroBar.background:SetTexture(0.8, 0.1, 0.1, 1)
pullAggroBar.foreground:Hide()
pullAggroBar.nameText:SetText("Pull Aggro")
pullAggroBar.threatPrctText:SetText("130%")

meter.threatBars = {}
for i = 1, max_bars do
	table.insert(meter.threatBars, createThreatBar(-(bar_height + bar_padding) * i))
end

function meter.hideThreatBars()
	for i = 1, #meter.threatBars do
		meter.threatBars[i]:Hide()
	end
end

local function lockTimers()
	STM_CONFIG["isLocked"] = true
	meter.title:Hide()
	meter:EnableMouse(false)
	meter.background:SetTexture(0, 0, 0, 0)
	meter.resizeButton:Hide()
end

local function unlockTimers()
	STM_CONFIG["isLocked"] = false
	meter.title:Show()
	meter:EnableMouse(true)
	meter.background:SetTexture(0, 0, 0, 1)
	meter.resizeButton:Show()
end

local function unitInMeleeRange(unitID)
	--unitID like "target", not unitGUID
	return UnitExists(unitID) and UnitIsVisible(unitID) and CheckInteractDistance(unitID, 3)
end

local function getPrctToAggroUnit(unitID)
	--unitID like "target", not unitGUID
	if unitInMeleeRange(unitID) then return 1.1 else return 1.3 end
end

local function getGUIDwithAggroThreat(npcGUID, unitGUID)
	if npcGUID == nil or unitGUID == nil then return nil end
	if threatTable[npcGUID][unitGUID] == nil then return nil end
	return threatTable[npcGUID][unitGUID].threat
end

local function getGUIDofBar(npcGUID, madePlayerBar, barIndex, isLastBar)
	local GUIDofBar = threatTable[npcGUID].GUIDsByThreatRank[barIndex]
	if GUIDofBar == stringlower(UnitGUID("player")) then madePlayerBar = true end
	if not madePlayerBar and isLastBar and threatTable[npcGUID][stringlower(UnitGUID("player"))] then
		GUIDofBar = stringlower(UnitGUID("player"))
	end
	return GUIDofBar, madePlayerBar
end

local function colorThreatBar(bar, GUIDofBar)
	if meter.GUIDwithAggro == GUIDofBar then
		if threatTable[meter.targetGUID][meter.GUIDwithAggro].unitName == UnitName("player") then
			bar.foreground:SetTexture(0, 0.5, 0.5, 1)
		else
			bar.foreground:SetTexture(0, 0, 1, 1)
		end
	else
		if threatTable[meter.targetGUID][GUIDofBar].unitName == UnitName("player") then
			bar.foreground:SetTexture(0, 0.529, 0.130, 1)
		else
			bar.foreground:SetTexture(0.592, 0.463, 0.333, 1)
		end
	end
end

local function setThreatText(bar, threat)
	if threat == 0 then
		bar.threatPrctText:SetText("0%")
		bar.threatText:SetText("0")
		bar.foreground:Hide()
	else
		local threat_prct_of_pull_aggro
		if meter.GUIDwithAggroThreat then
			threat_prct_of_pull_aggro = (threat / meter.GUIDwithAggroThreat) / getPrctToAggroUnit("target")
			bar.threatPrctText:SetText(stringformat("%.0f%%", threat / meter.GUIDwithAggroThreat * 100))
		else
			local firstOnThreatGUID = threatTable[meter.targetGUID].GUIDsByThreatRank[1]
			threat_prct_of_pull_aggro = (threat / threatTable[meter.targetGUID][firstOnThreatGUID].threat)
			bar.threatPrctText:SetText(stringformat("%.0f%%",
				threat / threatTable[meter.targetGUID][firstOnThreatGUID].threat * 100))
		end
		bar.foreground:SetWidth(min(bar:GetWidth(), bar:GetWidth() * threat_prct_of_pull_aggro))
		bar.threatText:SetText(stringformat("%.1fk", threat / 10 ^ 3))
		bar.foreground:Show()
	end
end

local iconTexture = {
	["DRUID"] = "inv_misc_monsterclaw_04",
	["HUNTER"] = "inv_weapon_bow_07",
	["MAGE"] = "inv_staff_13",
	["PALADIN"] = "ability_thunderbolt",
	["PRIEST"] = "inv_staff_30",
	["ROGUE"] = "inv_throwingknife_04",
	["SHAMAN"] = "inv_jewelry_talisman_04",
	["WARLOCK"] = "spell_nature_drowsy",
	["WARRIOR"] = "inv_sword_27"
}

local function setClassIcon(bar)
	if STM_CONFIG["showClassIcons"] and UnitClass(bar.nameText:GetText()) then
		local _, class = UnitClass(bar.nameText:GetText())
		bar.icon:SetTexture("Interface\\Icons\\" .. iconTexture[class])
		bar.icon:Show()
	else
		bar.icon:Hide()
		bar.nameText:SetTextColor(1, 1, 1, 1)
	end
end

local function hasTalent(tab, talentId)
	local _, _, _, _, pointsSpent = GetTalentInfo(tab, talentId)
	if pointsSpent > 0 then return true end
	return false
end

local function playerIsTank()
	if UnitClass("player") == "Druid" and hasTalent(2, 5) then     --thick hide
		return true
	elseif UnitClass("player") == "Warrior" and hasTalent(3, 19) then --shield slam
		return true
	elseif UnitClass("player") == "Paladin" and hasTalent(2, 19) then --holy shield
		return true
	end

	return false
end

local function handleSoundWarning()
	if STM_CONFIG["warnThreshold"] == 0 then return end
	if GetTime() - meter.soundWarnedTime < 10 then return end
	if not threatTable[meter.targetGUID].lastAggroSwitchTime then return end
	if not threatTable[meter.targetGUID][stringlower(UnitGUID("player"))] then return end
	if not threatTable[meter.targetGUID].GUIDsByThreatRank then return end
	if #threatTable[meter.targetGUID].GUIDsByThreatRank < 2 then return end
	if not meter.GUIDwithAggro or not meter.GUIDwithAggroThreat then return end
	if meter.GUIDwithAggroThreat < 5 then return end
	if playerIsTank() then return end
	if GetTime() - threatTable[meter.targetGUID].lastAggroSwitchTime <= 2.5 then return end
	if threatTable[meter.targetGUID][stringlower(UnitGUID("player"))].threat / meter.GUIDwithAggroThreat > getPrctToAggroUnit("target") then return end
	if threatTable[meter.targetGUID][stringlower(UnitGUID("player"))].threat / meter.GUIDwithAggroThreat < (STM_CONFIG["warnThreshold"] / 100) then return end

	meter.soundWarnedTime = GetTime()
	PlaySoundFile(sound_warning_file)
end

function meter.update()
	pullAggroBar:Hide()
	meter.hideThreatBars()

	if meter.targetName == nil then return end
	if threatTable[meter.targetGUID] == nil then return end
	if threatTable[meter.targetGUID].GUIDsByThreatRank == nil then return end

	meter.GUIDwithAggro = threatTable[meter.targetGUID].GUIDwithAggro
	meter.GUIDwithAggroThreat = getGUIDwithAggroThreat(meter.targetGUID, meter.GUIDwithAggro)

	if meter.GUIDwithAggroThreat and meter.GUIDwithAggroThreat >= 0 then
		pullAggroBar.threatText:SetText(stringformat("%.1fk", meter.GUIDwithAggroThreat * 1.3 / 10 ^ 3))
		pullAggroBar.threatPrctText:SetText(stringformat("%.0f%%", getPrctToAggroUnit("target") * 100))
		pullAggroBar:Show()
	end

	handleSoundWarning()

	local madePlayerBar = false
	local GUIDofBar
	for i = 1, max_currently_visible_bars do
		if threatTable[meter.targetGUID].GUIDsByThreatRank[i] == nil then return end --this breaks the loop when out of GUIDs
		GUIDofBar, madePlayerBar = getGUIDofBar(meter.targetGUID, madePlayerBar, i, i == max_currently_visible_bars)
		if threatTable[meter.targetGUID][GUIDofBar] == nil then return end
		meter.threatBars[i].nameText:SetText(threatTable[meter.targetGUID][GUIDofBar].unitName)
		colorThreatBar(meter.threatBars[i], GUIDofBar)
		local threat = threatTable[meter.targetGUID][GUIDofBar].threat
		if threat then setThreatText(meter.threatBars[i], threat) end
		setClassIcon(meter.threatBars[i])
		meter.threatBars[i]:Show()
	end
end

local function getnpcGUIDfromMsg(msg)
	return stringsub(msg, 1, stringfind(msg, "[%d%a]/"))
end

function meter:OnEvent(event, ...)
	if event == "ADDON_LOADED" then
		if STM_CONFIG["isLocked"] then lockTimers() else unlockTimers() end
		max_currently_visible_bars = calculateMaxVisibleBars()

		if STM_CONFIG["isLocked"] == nil then STM_CONFIG["isLocked"] = true end
		if STM_CONFIG["showClassIcons"] == nil then STM_CONFIG["showClassIcons"] = true end
		if STM_CONFIG["warnThreshold"] == nil then STM_CONFIG["warnThreshold"] = 115 end
	elseif event == "UNIT_TARGET" then
		if arg1 ~= "player" then return end
		meter.targetName = UnitName("target")
		if UnitGUID("target") then
			meter.targetGUID = stringlower(UnitGUID("target"))
			meter.GUIDwithAggro = nil
			meter.GUIDwithAggroThreat = nil
			meter.usedTargetTargetGUIDtrick = false
		else
			meter.targetGUID = nil
		end
		meter.update()
	elseif event == "CHAT_MSG_ADDON" then
		if stringsub(arg1, 1, 4) ~= "SMSG" then return end
		if getnpcGUIDfromMsg(arg2) ~= meter.targetGUID then return end

		meter.update()
		if arg1 == "SMSG_HIGHEST_THREAT_UPDATE" then
			if STM_CONFIG["warnThreshold"] == 0 then return end
			if not meter.GUIDwithAggro then return end
			if meter.GUIDwithAggro ~= stringlower(UnitGUID("player")) then return end
			if playerIsTank() then return end

			PlaySoundFile(sound_warning_file)
		end
	end
end

meter:RegisterEvent("ADDON_LOADED")
meter:RegisterEvent("UNIT_TARGET")
meter:RegisterEvent("CHAT_MSG_ADDON")
meter:SetScript("OnEvent", meter.OnEvent)

meter:SetScript("OnUpdate", function(self, elapsed)
	meter.timeSinceLastUpdate = meter.timeSinceLastUpdate + elapsed

	if meter.timeSinceLastUpdate > 0.25 then
		meter.timeSinceLastUpdate = 0
		meter.update()
	end
end)

---------------------------------------------------
--Chat commands
---------------------------------------------------
local function print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function tokenize(str)
	local tokens = {}
	for token in string.gmatch(str, '%S+') do tinsert(tokens, token) end
	return tokens
end

_G.SLASH_STORMFORGETHREATMETER1 = '/stm'
function SlashCmdList.STORMFORGETHREATMETER(command)
	if not command then return end
	local arguments = tokenize(command)
	if not arguments[1] then
		print("Stormforge Threat Meter commands:")
		print("/stm lock - Locks or unlocks the meter.")
		print("/stm warnThreshold # - Plays sound when over #% threat.")
		print("/stm toggleClassIcons - Shows or hides class icons.")
	else
		local arg1 = string.lower(arguments[1])
		if arg1 == 'lock' then
			if STM_CONFIG["isLocked"] then unlockTimers() else lockTimers() end
		elseif arg1 == 'warnthreshold' then
			if not arguments[2] or tonumber(arguments[2]) == nil then
				print(
					"Please enter a threat threshold, which can range from 60 to 130, e.g. /stm warnThreshold 110 to warn when you go over 110% threat. At 130% threat, you pull aggro. Set it to 0 to never play a sound.")
			else
				local threshold_number = tonumber(arguments[2])
				if threshold_number == 0 then
					print("Disabled playing warning sounds.")
				elseif threshold_number <= 1.3 and threshold_number >= 0.6 then
					STM_CONFIG["warnThreshold"] = threshold_number * 100
					print("warnThreshold is now set to " .. STM_CONFIG["warnThreshold"] .. "%.")
				elseif threshold_number < 60 or threshold_number > 130 then
					print("Please enter a threat threshold between 60 and 130, e.g. /sct warnThreshold 110")
				else
					STM_CONFIG["warnThreshold"] = threshold_number
					print("warnThreshold is now set to " .. STM_CONFIG["warnThreshold"] .. "%.")
				end
			end
		elseif arg1 == 'toggleclassicons' then
			STM_CONFIG["showClassIcons"] = not STM_CONFIG["showClassIcons"]
			if STM_CONFIG["showClassIcons"] then
				print("Class icons are now showing.")
			else
				print("Class icons are now hidden.")
			end
			meter.update()
		end
	end
end
