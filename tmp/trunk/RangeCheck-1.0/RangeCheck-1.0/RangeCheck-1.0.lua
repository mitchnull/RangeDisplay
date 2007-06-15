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

local BS = AceLibrary("Babble-Spell-2.2");
if (not BS) then error(MAJOR_VERSION .. " requires Babble-Spell-2.2") end
local gratuity = AceLibrary("Gratuity-2.0");
if (not gratuity) then error(MAJOR_VERSION .. " requires Gratuity-2.0") end

-- << LOCALIZATION

local locale = GetLocale()

local L = {}

-- default enUS values

L.RangePattern = "(%d+) yd range"
L.RangePattern2 = "(%d+)-(%d+) yd range"
L.RangePatternMelee = "Melee Range"
-- uncomment it if you prefer an Out of range display instead of hiding the display
-- L.OutOfRange = "Out of range"
-- comment this out if you prefer a "0 - 5" display in melee range
L.MeleeRange = "Melee"

if locale == "deDE" then
	
elseif locale == "frFR" then
	
elseif locale == "zhCN" then
	
elseif locale == "zhTW" then
	
elseif locale == "koKR" then
	
elseif locale == "esES" then
	
end

-- >> END OF LOCALIZATION


-- << STATIC CONFIG

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

FriendSpells["PALADIN"] = { BS["Holy Light"], BS["Blessing of Might"],  }
HarmSpells["PALADIN"] = { BS["Exorcism"], BS["Turn Undead"], BS["Judgement"] } 

FriendSpells["DRUID"] = { BS["Healing Touch"], BS["Mark of the Wild"] }
HarmSpells["DRUID"] = { BS["Wrath"], BS["Growl"],  }

FriendSpells["WARLOCK"] = { BS["Unending Breath"] }
HarmSpells["WARLOCK"] = { BS["Immolate"], BS["Corruption"], BS["Banish"], BS["Fear"], BS["Shadowburn"] }

-- >> END OF STATIC CONFIG

-- helper functions and cache

local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local GetSpellName = GetSpellName
local UnitCanAttack = UnitCanAttack
local UnitCanAssist = UnitCanAssist
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

local function print(text)
	if ( DEFAULT_CHAT_FRAME ) then 
		DEFAULT_CHAT_FRAME:AddMessage(text)
	end
end

local function isTargetValid(unit)
	return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
end

-- OK, here comes the actual lib

local RangeCheck = {}

-- returns range[, minRange] of the given spell if applicable
function RangeCheck:getSpellRange(spellId, bookType)
    if (spellId == nil) then return nil end
    -- TODO: copy-waste the actual implementation here
	return nil
end

-- return the spellId of the given spell by scanning the spellbook
function RangeCheck:findSpellId(spellName)
	local i = 1
	while true do
	    local spell, rank = GetSpellName(i, BOOKTYPE_SPELL)
	    if (not spell) then return nil end
	    if (spell == spellName) then return i end
	    i = i + 1
	end
	return nil
end

function RangeCheck:getRange(unit)
	-- TODO: check what happens if unit is dead, etc
	if (not isTargetValid(unit)) then return nil end
	if (UnitCanAttack("player", unit)) then
	    return self.harmRC:getRange(unit)
	elseif (UnitCanAssist("player", unit)) then
	    return self.friendRC:getRange(unit)
	else
		return self.miscRC:getRange(unit)
	end
end

-- <<< RangeCheckSpell --------------------------------
-- RangeChecker class that implements range checking based on spell ranges

local RangeCheckSpell = {}
function RangeCheckSpell:new(spellName)
    local res = { name = spellName }
    setmetatable(res, self)
    self.__index = self
    return res:init()
end

function RangeCheckSpell:init()
    self.id = findSpellId(self.name)
    self.range, self.minRange = getSpellRange(self.id, BOOKTYPE_SPELL)
    if (self.range == nil) then return nil end
    return self
end

function RangeCheckSpell:isInRange(unit)
	if (IsSpellInRange(self.id, BOOKTYPE_SPELL, unit) == 1) then return true end
	return nil
end

function RangeCheckSpell:print()
    print(self.name .. ": " .. tostring(self.range))
end

-- >>> RangeCheckSpell --------------------------------

-- <<< RangeCheckInteract -----------------------------
-- RangeChecker class that implements range checking based on interact distance

local RangeCheckInteract = {}

function RangeCheckInteract:new(index, range)
    local res = { index = index, range = range, name = "interact" .. index }
    setmetatable(res, self)
    self.__index = self
    return res
end

function RangeCheckInteract:isInRange(unit)
    if (CheckInteractDistance(unit, self.index)) then return true end
    return nil
end

function RangeCheckInteract:print()
    print("Interact" .. tostring(self.index) .. ": " .. tostring(self.range))
end

-- >>> RangeCheckInteract -----------------------------

-- <<< RCList ------------------------------------------------
-- RangeChecker list that stores RangeCheckers in sorted order
-- We have one for Harm spells and one for Friend spells

local RCList = {}
function RCList:new(spellList)
    local res = {}
    setmetatable(res, self)
    self.__index = self
    for i, v in ipairs(InteractList) do
	    res:insertRangeCheck(RangeCheckInteract:new(v.index, v.range))
    end
    if (spellList == nil) then return res end
    for i, v in ipairs(spellList) do
        res:insertRangeCheck(RangeCheckSpell:new(v))
    end
    return res
end

-- insert new RangeChecker at the correct position
function RCList:insertRangeCheck(rc)
    if (rc == nil) then return end
    for i, v in ipairs(self) do
        if (rc.range == v.range) then return end
        if (rc.range > v.range) then
            table.insert(self, i, rc)
            return
        end
    end
    table.insert(self, rc)
end

-- return the current range estimate to unit
-- the format is "min - max"
function RCList:getRange(unit)
	local min = 0
    local max = nil
    for i, v in ipairs(self) do
        if (v:isInRange(unit)) then
	        max = v.range
        elseif (v.minRange and CheckInteractDistance(unit, InteractMinRangeCheckIndex)) then
--        	max = v.minRange 
			-- we do not bother with using this for the maxRange,
			-- as it's just a little difference between interact2 and interact3 anyway
			-- and it would just cause a lot of flicker and would make the code a bit more complex
        elseif (not max) then
        	return L.OutOfRange
        else
			min = v.range
		    break;
        end
    end
    if (L.MeleeRange and max <= MeleeRange) then
    	return L.MeleeRange
    end
    return tostring(min) .. " - " .. tostring(max)
end

function RCList:print()
    for i, v in ipairs(self) do
        v:print()
    end
end

-- >>> RCList ------------------------------------------------

-- <<< RangeCheck constants and functions

-- initialize RangeCheck if not yet initialized or if "forced"
function RangeCheck:init(forced)
	if (self.initialized and (not forced)) then return end
	self.initialized = true
	local _, playerClass = UnitClass("player")
	self.friendRC = RCList:new(FriendSpells[playerClass])
	self.harmRC = RCList:new(HarmSpells[playerClass])
	self.miscRC = RCList:new(nil)
	self.lastRange = nil
    if (self.isDebug) then
        print("FriendRangeCheck:")
        self.friendRC:print()
        print("HarmRangeCheck:")
        self.harmRC:print()
	end
end


function RangeCheck:OnEvent(event, ...)
	if (type(self[event]) == 'function') then
		self[event](self, event, ...)
	else
		self:debug("unexpected event: " .. tostring(event))
	end
end

--[[
function RangeCheck:PLAYER_ALIVE()
-- talent info should be ready, but it's not :( [at least spell ranges are not updated]
-- we'll do RangeCheck:init() when first needed
--	if (db.Enabled) then
-- 		self:init()
--	end
end
]]

function RangeCheck:LEARNED_SPELL_IN_TAB()
	self:init(true)
end

function RangeCheck:CHARACTER_POINTS_CHANGED()
	self:init(true)
end

local function activate(self, oldLib, oldDeactivate)
    if oldLib then -- if upgrading
    	self.frame = oldLib.frame
    	self.initialized = oldLib.initialized
    end
    if (not self.frame) then
    	self.frame = createFrame("Frame")
    	local frame = self.frame
    	if (not self.initialized) then
		   	frame:RegisterEvent("MEETINGSTONE_CHANGED"); -- maybe we can use this to initialize once
		end
		frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
		frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
	--	frame:RegisterEvent("PLAYER_ALIVE")
	--	frame:RegisterEvent("SPELLS_CHANGED")
	
		frame:SetScript("OnEvent", self:OnEvent)
    end
end

AceLibrary:Register(RangeCheck, MAJOR_VERSION, MINOR_VERSION, activate)
RangeCheck = nil
