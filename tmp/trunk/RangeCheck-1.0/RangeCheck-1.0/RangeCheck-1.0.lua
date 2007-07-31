--[[
Name: RangeCheck-1.0
Revision: $Revision$
Author(s): mitch0
Website: http://www.wowace.com/wiki/RangeCheck-1.0
Documentation: http://www.wowace.com/wiki/RangeCheck-1.0
SVN: http://svn.wowace.com/wowace/trunk/RangeCheck-1.0/
Description: A range checking library based on interact distances and spell ranges
Dependencies: AceLibrary, Babble-2.2, GratuityLib
License: Public Domain
]]

local MAJOR_VERSION = "RangeCheck-1.0"
local MINOR_VERSION = ("$Revision$"):match("%d+")

if (not AceLibrary) then error(MAJOR_VERSION .. " requires AceLibrary.") end
if (not AceLibrary:IsNewVersion(MAJOR_VERSION, MINOR_VERSION)) then return end

local libBS = "Babble-Spell-2.2"
local libGratuity = "Gratuity-2.0"

local BS = AceLibrary:HasInstance(libBS) and AceLibrary(libBS)
if (not BS) then error(MAJOR_VERSION .. " requires " .. libBS) end
local gratuity = AceLibrary:HasInstance(libGratuity) and AceLibrary(libGratuity)
if (not gratuity) then error(MAJOR_VERSION .. " requires " .. libGratuity) end

-- << STATIC CONFIG

local RangePattern = SPELL_RANGE:gsub("%%s", "(%%d+)")
local RangePattern2 = SPELL_RANGE:gsub("%%s", "(%%d+)-(%%d+)")
local RangePatternMelee = MELEE_RANGE

-- interact distance based checks. ranges are based on my own measurements (thanks for all the folks who helped me with this)
local DefaultInteractList = {
	[3] = 8,
	[2] = 9,
	[4] = 27,
}

-- interact list overrides for races
local InteractLists = {
	["Tauren"] = {
		[3] = 6,
		[2] = 7,
		[4] = 25,
	},
}

-- interact distance to check if a spell with minimum range fails due to the min range or the max range
local InteractMinRangeCheckIndex = 2
local MeleeRange = 5
local VisibleRange = 100

-- list of friendly spells that have different ranges
local FriendSpells = {}
-- list of harmful spells that have different ranges
local HarmSpells = {}

FriendSpells["MAGE"] = { BS["Remove Lesser Curse"], BS["Arcane Brilliance"] }
HarmSpells["MAGE"] = { BS["Shoot"], BS["Fire Blast"], BS["Arcane Missiles"], BS["Frostbolt"], BS["Scorch"], BS["Fireball"], BS["Detect Magic"] }

FriendSpells["HUNTER"] = {}
HarmSpells["HUNTER"] = { BS["Throw"], BS["Auto Shot"], BS["Scatter Shot"], BS["Wing Clip"] }

FriendSpells["WARRIOR"] = {}
HarmSpells["WARRIOR"] = { BS["Shoot"], BS["Throw"], BS["Charge"], BS["Rend"] }

FriendSpells["SHAMAN"] = { BS["Healing Wave"], BS["Cure Poison"] }
HarmSpells["SHAMAN"] = { BS["Lightning Bolt"], BS["Purge"], BS["Earth Shock"] }

FriendSpells["ROGUE"] = {}
HarmSpells["ROGUE"] = { BS["Throw"], BS["Deadly Throw"], BS["Blind"], BS["Eviscerate"] }

FriendSpells["PRIEST"] = { BS["Lesser Heal"], BS["Power Word: Fortitude"] }
HarmSpells["PRIEST"] = { BS["Shoot"], BS["Smite"], BS["Shadow Word: Pain"], BS["Dispel Magic"], BS["Mind Flay"] }

FriendSpells["PALADIN"] = { BS["Holy Light"], BS["Blessing of Might"], BS["Holy Shock"] }
HarmSpells["PALADIN"] = { BS["Hammer of Wrath"], BS["Holy Shock"], BS["Judgement"] } 

FriendSpells["DRUID"] = { BS["Healing Touch"], BS["Mark of the Wild"] }
HarmSpells["DRUID"] = { BS["Wrath"], BS["Growl"],  }

FriendSpells["WARLOCK"] = { BS["Unending Breath"] }
HarmSpells["WARLOCK"] = { BS["Shoot"], BS["Immolate"], BS["Corruption"], BS["Fear"], BS["Shadowburn"] }

-- This could've been done by checking player race as well and creating tables for those, but it's easier like this
for k, v in pairs(FriendSpells) do
	tinsert(v, BS["Gift of the Naaru"])
end
for k, v in pairs(HarmSpells) do
	tinsert(v, BS["Mana Tap"])
end

-- >> END OF STATIC CONFIG

-- cache

local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local GetSpellName = GetSpellName
local UnitCanAttack = UnitCanAttack
local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local tonumber = tonumber
local CheckInteractDistance = CheckInteractDistance
local IsSpellInRange = IsSpellInRange
local UnitIsVisible = UnitIsVisible
local tinsert = tinsert
local GetInventoryItemLink = GetInventoryItemLink
local HandSlotId = GetInventorySlotInfo("HandsSlot")

-- helper functions

local function print(text)
	if (DEFAULT_CHAT_FRAME) then 
		DEFAULT_CHAT_FRAME:AddMessage(text)
	end
end

local function isTargetValid(unit)
	return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
end

-- returns range[, minRange] of the given spell if applicable
local function getSpellRange(spellId, bookType)
    if (not spellId) then return nil end
    if (not bookType) then bookType = BOOKTYPE_SPELL end
	gratuity:SetSpell(spellId, bookType)
	if (gratuity:Find(RangePatternMelee, 2, 2)) then return MeleeRange end
	local _, _, minRange, range = gratuity:Find(RangePattern2, 2, 2)
	if (range) then return tonumber(range), tonumber(minRange) end
	_, _, range = gratuity:Find(RangePattern, 2, 2)
	if (range) then return tonumber(range) end
	return nil
end

-- return the spellId of the given spell by scanning the spellbook
local function findSpellId(spellName)
	local i = 1
	while true do
	    local spell, rank = GetSpellName(i, BOOKTYPE_SPELL)
	    if (not spell) then return nil end
	    if (spell == spellName) then return i end
	    i = i + 1
	end
	return nil
end

-- minRange should be nil if there's no minRange, not 0
local function addChecker(t, range, minRange, checker)
	local rc = { ["range"] = range, ["minRange"] = minRange, ["checker"] = checker }
	for i, v in ipairs(t) do
		if (rc.range == v.range) then return end
        if (rc.range > v.range) then
        	tinsert(t, i, rc)
        	return
    	end
	end
	tinsert(t, rc)
end

local function createCheckerList(spellList, interactList)
	local res = {}
    if (spellList) then
	    for i, v in ipairs(spellList) do
	    	local spellId = findSpellId(v)
	    	local range, minRange = getSpellRange(spellId, BOOKTYP_SPELL)
	    	if (range) then
				addChecker(res, range, minRange, function(unit)
					if (IsSpellInRange(spellId, BOOKTYPE_SPELL, unit) == 1) then return true end
				end)
			end
	    end
    end
	if (not interactList) then interactList = DefaultInteractList end
	for index, range in pairs(interactList) do
		addChecker(res, range, nil, function(unit)
			if (CheckInteractDistance(unit, index)) then return true end
		end)
    end
    return res
end

-- returns minRange, maxRange or nil
local function getRange(unit, checkerList, checkVisible)
	local min, max = 0, nil
    if (checkVisible) then
    	if (UnitIsVisible(unit)) then
    		max = VisibleRange
    	else
    		return VisibleRange, nil
    	end
    end
    for i, rc in ipairs(checkerList) do
		if (not max or max >= rc.range) then
			if (rc.checker(unit)) then
				max = rc.range
				if (rc.minRange) then
					min = rc.minRange
				end
			elseif (rc.minRange and CheckInteractDistance(unit, InteractMinRangeCheckIndex)) then
				max = rc.minRange
			elseif (min > rc.range) then
				return min, max
			else
				return rc.range, max
			end
		end
    end
    return min, max
end

-- OK, here comes the actual lib

local RangeCheck = {}

-- pre-initialize the checkerLists here so that we can return some meaningful result even if
-- someone manages to call us before we're properly initialized. miscRC should be independent of
-- race/class/talents, so it's safe to initialize it here
-- friendRC and harmRC will be properly initialized later when we have all the necessary data for them
RangeCheck.miscRC = createCheckerList()
RangeCheck.friendRC = RangeCheck.miscRC
RangeCheck.harmRC = RangeCheck.miscRC

-- "export" it, maybe someone will need it for formatting
RangeCheck.MeleeRange = MeleeRange
RangeCheck.VisibleRange = VisibleRange

-- returns range[, minRange] of the given spell if applicable
function RangeCheck:getSpellRange(spellId, bookType)
	return getSpellRange(spellId, bookType)
end

-- return the spellId of the given spell by scanning the spellbook
function RangeCheck:findSpellId(spellName)
	return findSpellId(spellName)
end

-- returns minRange, maxRange or nil
function RangeCheck:getRange(unit, checkVisible)
	if (not isTargetValid(unit)) then return nil end
	if (UnitCanAttack("player", unit)) then
	    return getRange(unit, self.harmRC, checkVisible)
	elseif (UnitCanAssist("player", unit)) then
	    return getRange(unit, self.friendRC, checkVisible)
	else
		return getRange(unit, self.miscRC, checkVisible)
	end
end

-- returns the range estimate as a string
function RangeCheck:getRangeAsString(unit, checkVisible, showOutOfRange)
	local minRange, maxRange = self:getRange(unit, checkVisible)
	if (not minRange) then return nil end
	if (not maxRange) then
		return showOutOfRange and minRange .. " +" or nil
	end
	return minRange .. " - " .. maxRange
end

-- initialize RangeCheck if not yet initialized or if "forced"
function RangeCheck:init(forced)
	if (self.initialized and (not forced)) then return end
	self.initialized = true
	local _, playerClass = UnitClass("player")
	local _, playerRace = UnitRace("player")
	if (playerClass == "HUNTER" or playerRace == "Tauren") then
		-- for Hunters it's best to use interact4 (~27yd),
		-- and for Taurens interact4 is actually closer than 25yd and interact2 is closer than 8yd, so we can't use that
		InteractMinRangeCheckIndex = 4
	end
	local interactList = InteractLists[playerRace]
	self.friendRC = createCheckerList(FriendSpells[playerClass], interactList)
	self.harmRC = createCheckerList(HarmSpells[playerClass], interactList)
	self.miscRC = createCheckerList(nil, interactList)
	self.handSlotItem = GetInventoryItemLink("player", HandSlotId)
end

function RangeCheck:OnEvent(event, ...)
	if (type(self[event]) == 'function') then
		self[event](self, event, ...)
	end
end

function RangeCheck:LEARNED_SPELL_IN_TAB()
	self:init(true)
end

function RangeCheck:CHARACTER_POINTS_CHANGED()
	self:init(true)
end

function RangeCheck:UNIT_INVENTORY_CHANGED(event, unit)
	if (self.initialized and unit == "player" and self.handSlotItem ~= GetInventoryItemLink("player", HandSlotId)) then
		self:init(true)
	end
end

local function activate(self, oldLib, oldDeactivate)
    if (oldLib) then -- rescue oldLib's frame
    	self.frame = oldLib.frame
    else
    	local frame = CreateFrame("Frame")
    	self.frame = frame
		frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
		frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
		local _, playerClass = UnitClass("player")
		if (playerClass == "MAGE" or playerClass == "SHAMAN") then
			-- Mage and Shaman gladiator gloves modify spell ranges
			frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
		end
    end
	self.frame:SetScript("OnEvent", function(frame, ...) self:OnEvent(...) end)
	self.frame:SetScript("OnUpdate", function(frame, ...)
		self:init()
		frame:SetScript("OnUpdate", nil)
		frame:Hide()
	end)

	if (oldDeactivate) then -- clean up the old library
		oldDeactivate(oldLib)
	end
end

-- << DEBUG STUFF

function RangeCheck:startMeasurement(unit, resultTable)
	if (self.measurements) then
		print(MAJOR_VERSION .. ": measurements already running")
		return
	end
	print(MAJOR_VERSION .. ": starting measurements")
	local _, playerClass = UnitClass("player")
	local spellList
	if (UnitCanAttack("player", unit)) then
		spellList = HarmSpells[playerClass]
	elseif (UnitCanAssist("player", unit)) then
		spellList = FriendSpells[playerClass]
	end
	self.spellsToMeasure = {}
	if (spellList) then
		for _, name in ipairs(spellList) do
			local spellId = self:findSpellId(name)
			if (spellId) then
				self.spellsToMeasure[name] = spellId
			end
		end
	end
	self.measurements = resultTable
	self.measurementUnit = unit
	self.measurementStart = GetTime()
	self.lastMeasurements = {}
	self:updateMeasurements()
	self.frame:SetScript("OnUpdate", function(frame, elapsed) self:updateMeasurements() end)
	self.frame:Show()
end

function RangeCheck:stopMeasurement()
	print(MAJOR_VERSION .. ": stopping measurements")
	self.frame:Hide()
	self.frame:SetScript("OnUpdate", nil)
	self.measurements = nil
end

local GetTime = GetTime
local GetPlayerMapPosition = GetPlayerMapPosition
function RangeCheck:updateMeasurements()
	local now = GetTime() - self.measurementStart
	local x, y = GetPlayerMapPosition("player");
	local t = self.measurements[now]
	local unit = self.measurementUnit
	for name, id in pairs(self.spellsToMeasure) do
		local last = self.lastMeasurements[name]
		local curr = (IsSpellInRange(id, BOOKTYPE_SPELL, unit) == 1) and true or false
		if (last == nil or last ~= curr) then
			print("### " .. tostring(name) .. ": " .. tostring(last) .. " ->  " .. tostring(curr))
			if (t == nil) then
				t = {}
				t.x, t.y, t.stamp, t.states = x, y, now, {}
				self.measurements[now] = t
			end
			t.states[name]= curr
			self.lastMeasurements[name] = curr
		end
	end
	for i, v in pairs(DefaultInteractList) do
		local name = "interact" .. i
		local last = self.lastMeasurements[name]
		local curr = CheckInteractDistance(unit, i) and true or false
		if (last == nil or last ~= curr) then
			print("### " .. tostring(name) .. ": " .. tostring(last) .. " ->  " .. tostring(curr))
			if (t == nil) then
				t = {}
				t.x, t.y, t.stamp, t.states = x, y, now, {}
				self.measurements[now] = t
			end
			t.states[name] = curr
			self.lastMeasurements[name] = curr
		end
	end
end

-- >> DEBUG STUFF

AceLibrary:Register(RangeCheck, MAJOR_VERSION, MINOR_VERSION, activate)
RangeCheck = nil
