--[[
Name: RangeCheck-1.0
Revision: $Revision$
Author(s): mitch0
Website: http://www.wowace.com/wiki/RangeCheck-1.0
Documentation: http://www.wowace.com/wiki/RangeCheck-1.0
SVN: http://svn.wowace.com/wowace/trunk/RangeCheck-1.0/
Description: A range checking library based on interact distances and spell ranges
Dependencies: AceLibrary, Babble-2.0, Gratuity-2.0
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
local InteractList = { { index = 3, range = 9 }, { index = 2, range = 10 }, { index = 4, range = 28 }}

-- interact distance to check if a spell with minimum range fails due to the min range or the max range
local InteractMinRangeCheckIndex = 2
local RealMinRange = 9.5 -- this is the 8yd range as measured... go figure...
local MeleeRange = 5

-- list of friendly spells that have different ranges
local FriendSpells = {}
-- list of harmful spells that have different ranges
local HarmSpells = {}

FriendSpells["MAGE"] = { BS["Remove Lesser Curse"], BS["Arcane Brilliance"] }
HarmSpells["MAGE"] = { BS["Fire Blast"], BS["Arcane Missiles"], BS["Frostbolt"], BS["Scorch"], BS["Fireball"], BS["Detect Magic"] }

HarmSpells["HUNTER"] = { BS["Auto Shot"], BS["Scatter Shot"], BS["Wing Clip"] }

HarmSpells["WARRIOR"] = { BS["Charge"], BS["Rend"] }

FriendSpells["SHAMAN"] = { BS["Healing Wave"], BS["Cure Poison"] }
HarmSpells["SHAMAN"] = { BS["Lightning Bolt"], BS["Purge"], BS["Earth Shock"] }

HarmSpells["ROGUE"] = { BS["Deadly Throw"], BS["Blind"], BS["Eviscerate"] }

FriendSpells["PRIEST"] = { BS["Lesser Heal"], BS["Power Word: Fortitude"] }
HarmSpells["PRIEST"] = { BS["Mind Soothe"], BS["Smite"], BS["Shadow Word: Pain"], BS["Dispel Magic"], BS["Mind Flay"] }

FriendSpells["PALADIN"] = { BS["Holy Light"], BS["Blessing of Might"], BS["Holy Shock"] }
HarmSpells["PALADIN"] = { BS["Hammer of Wrath"], BS["Holy Shock"], BS["Judgement"] } 

FriendSpells["DRUID"] = { BS["Healing Touch"], BS["Mark of the Wild"] }
HarmSpells["DRUID"] = { BS["Wrath"], BS["Growl"],  }

FriendSpells["WARLOCK"] = { BS["Unending Breath"] }
HarmSpells["WARLOCK"] = { BS["Immolate"], BS["Corruption"], BS["Fear"], BS["Shadowburn"] }

-- >> END OF STATIC CONFIG

local INIT_EVENT = "MEETINGSTONE_CHANGED"

-- helper functions and cache

local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local GetSpellName = GetSpellName
local UnitCanAttack = UnitCanAttack
local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local tonumber = tonumber
local tostring = tostring
local CheckInteractDistance = CheckInteractDistance
local IsSpellInRange = IsSpellInRange

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

local function addChecker(t, range, checker)
	local rc = { ["range"] = range, ["checker"] = checker }
	for i, v in ipairs(t) do
		if (rc.range == v.range) then return end
        if (rc.range > v.range) then
        	table.insert(t, i, rc)
        	return
    	end
	end
	table.insert(t, rc)
end

local function createCheckerList(spellList)
	local res = {}
	for i, v in ipairs(InteractList) do
		addChecker(res, v.range, function(unit)
			if (CheckInteractDistance(unit, v.index)) then return true end
		end)
    end
    if (not spellList) then return res end
    for i, v in ipairs(spellList) do
    	local spellId = findSpellId(v)
    	local range, minRange = getSpellRange(spellId, BOOKTYP_SPELL)
    	if (range) then
    		if (minRange) then
    			addChecker(res, range, function(unit)
    				if (IsSpellInRange(spellId, BOOKTYPE_SPELL, unit) == 1 or CheckInteractDistance(unit, InteractMinRangeCheckIndex)) then return true end
    			end)
    		else
    			addChecker(res, range, function(unit)
    				if (IsSpellInRange(spellId, BOOKTYPE_SPELL, unit) == 1) then return true end
    			end)
    		end
    	end
    end
    return res
end

-- returns minRange, maxRange or nil
local function getRange(unit, checkerList)
	local min = 0
    local max = nil
    for i, rc in ipairs(checkerList) do
        if (rc.checker(unit)) then
	        max = rc.range
        elseif (not max) then
        	return nil
        else
			return rc.range, max
        end
    end
    return 0, max
end

-- OK, here comes the actual lib

local RangeCheck = {}

-- "export" it, maybe someone will need it for formatting
RangeCheck.MeleeRange = MeleeRange

-- returns range[, minRange] of the given spell if applicable
function RangeCheck:getSpellRange(spellId, bookType)
	return getSpellRange(spellId, bookType)
end

-- return the spellId of the given spell by scanning the spellbook
function RangeCheck:findSpellId(spellName)
	return findSpellId(spellName)
end

-- returns minRange, maxRange or nil
function RangeCheck:getRange(unit)
	if (not isTargetValid(unit)) then return nil end
	if (UnitCanAttack("player", unit)) then
	    return getRange(unit, self.harmRC)
	elseif (UnitCanAssist("player", unit)) then
	    return getRange(unit, self.friendRC)
	else
		return getRange(unit, self.miscRC)
	end
end

-- returns the range estimate as a string
function RangeCheck:getRangeAsString(unit)
	local minRange, maxRange = self:getRange(unit)
	if (not maxRange) then return nil end
	lastStr = tostring(minRange) .. " - " .. tostring(maxRange)
	return lastStr
end

-- initialize RangeCheck if not yet initialized or if "forced"
function RangeCheck:init(forced)
	if (self.initialized and (not forced)) then return end
	self.initialized = true
	local _, playerClass = UnitClass("player")
	self.friendRC = createCheckerList(FriendSpells[playerClass])
	self.harmRC = createCheckerList(HarmSpells[playerClass])
	self.miscRC = createCheckerList(nil)
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

local function firstInit(self)
	self:init()
	print(MAJOR_VERSION .. "-r" .. MINOR_VERSION .. " initialized")
end

RangeCheck[INIT_EVENT] = function(self)
	self.frame:UnregisterEvent(INIT_EVENT)
	firstInit(self)
end

local function activate(self, oldLib, oldDeactivate)
    if (oldLib) then -- rescue oldLib's frame
    	self.frame = oldLib.frame
    	if (oldLib.initialized) then
    		firstInit(self) -- oldLib could already initialize itself, so it's probably safe to call init here
    	end
    else
    	local frame = CreateFrame("Frame")
    	self.frame = frame
	   	frame:RegisterEvent(INIT_EVENT);
		frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
		frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
	--	frame:RegisterEvent("SPELLS_CHANGED")
    end
	self.frame:SetScript("OnEvent", function(frame, ...) self:OnEvent(...) end)

	if (oldDeactivate) then -- clean up the old library
		oldDeactivate(oldLib)
	end
end

AceLibrary:Register(RangeCheck, MAJOR_VERSION, MINOR_VERSION, activate)
RangeCheck = nil
