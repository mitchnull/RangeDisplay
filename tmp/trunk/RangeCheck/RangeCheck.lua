--[[

  RangeCheck displays the estimated range to the current target based on spell ranges and other measurable ranges
  copyright 2007 by mitch
       
]]

local VERSION = "2.1.1-r" .. ("$Revision$"):match("%d+")


-- we use Babble-Spell for spell name localization if available, otherwise we use the default spell names
local BS
if (AceLibrary) then
	BS = AceLibrary("Babble-Spell-2.2")
end
if (BS == nil) then
	BS = {}
	setmetatable(BS, {__index = function(self, k) return k end})
end

-- list of friendly spells that have different ranges
local FriendSpells = {}
-- list of harmful spells that have different ranges
local HarmSpells = {}

FriendSpells["Mage"] = { BS["Remove Lesser Curse"] }
HarmSpells["Mage"] = { BS["Fire Blast"], BS["Arcane Missiles"], BS["Frostbolt"], BS["Scorch"], BS["Fireball"], BS["Detect Magic"] }

RangeCheck = { L = {}, isDebug = nil}

local DefaultDB = {
	Enabled = true,
	Height = 24,
	Locked = false
}

RangeCheckDB = RangeCheckDB or DefaultDB


-- cached stuff
local db = RangeCheckDB
local L = RangeCheck.L
local tooltip = RangeCheckTip
local tooltipRangeText = RangeCheckTipTextRight2;
local rangeText = RangeCheckFrameText
local rangeFrameBG = RangeCheckFrameBG
local rangeFrame = RangeCheckFrame

local UpdateDelay = .05 -- update frequency == 1/UpdateDelay
local lastUpdate = 0 -- time since last real update
local lastRange = nil

-- helper functions

local function print(text)
	if ( DEFAULT_CHAT_FRAME ) then 
		DEFAULT_CHAT_FRAME:AddMessage(text)
	end
end

-- parse the spell range from the tooltip
local function getSpellRange(spellId, bookType)
    if (spellId == nil) then return nil end
	-- ### dunno why SetOwner() and Show()/Hide() magic is needed, if
	-- someone could find a nice way to do it, please fix it [mitch]
	tooltip:SetOwner(this)
    tooltip:SetSpell(spellId, bookType)
	tooltip:Show()
    local ttt = tooltipRangeText:GetText()
	tooltip:Hide()
    if (ttt == nil) then return nil end
	-- ### TODO: check hunter spells with minimum range.
    local _, _, range = string.find(ttt, L.RangePattern, 1)
    if (range == nil) then return nil end
    return tonumber(range)
end

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
    self.range = getSpellRange(self.id, BOOKTYPE_SPELL)
    if (self.range == nil) then return nil end
    return self
end

function RangeCheckSpell:isInRange(unit)
	if (IsSpellInRange(self.id, BOOKTYPE_SPELL, unit) == 1) then return self.range end
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
    local res = { index = index, range = range }
    setmetatable(res, self)
    self.__index = self
    return res
end

function RangeCheckInteract:isInRange(unit)
    if (CheckInteractDistance(unit, self.index)) then return self.range end
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
    for i, v in ipairs(RangeCheck.InteractList) do
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
    local max = nil
    for i, v in ipairs(self) do
        if (not v:isInRange(unit)) then
            if (max == nil) then return L.OutOfRange  end
            return tostring(v.range) .. " - " .. tostring(max)
        end
        max = v.range
    end
    return "0 - " .. tostring(max)
end

function RCList:print()
    for i, v in ipairs(self) do
        v:print()
    end
end

-- >>> RCList ------------------------------------------------

-- <<< RangeCheck constants and functions

-- hard-coded interact distances [based on wowwiki]
RangeCheck.InteractList = { { index = 3, range = 10 }, { index = 2, range = 11 }, { index = 4, range = 28 } }
RangeCheck.FriendSpells = {}
RangeCheck.HarmSpells = {}

-- initialize RangeCheck if not yet initialized or if "forced"
function RangeCheck:init(forced)
	if (self.isInitialized and (not forced)) then return end
	self.isInitialized = true
	local playerClass = UnitClass("player")
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
	if (db.Enabled) then
		self:enable()
	else
		self:disable()
	end
	if (db.Locked) then
		self:lock()
	else
		self:unlock()
	end
	if (db.Height) then
		self:setHeight(db.Height)
	end
end

local function isTargetValid(unit)
	return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
end

function RangeCheck:debug(text)
	if (not self.isDebug) then return end
	self.print(tostring(text))
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

function RangeCheck:OnUpdate(elapsed)
	lastUpdate = lastUpdate + elapsed
	if (lastUpdate < UpdateDelay) then return end
	lastUpdate = 0
	local range = self:getRange("target")
	if (range == lastRange) then return end
	lastRange = range
	rangeText:SetText(range)
end

-- frame setup stuff

function RangeCheck:resetPosition()
	rangeFrame:ClearAllPoints()
	rangeFrame:SetPoint("CENTER", UIParent, "CENTER")
end

function RangeCheck:lock()
	rangeFrame:EnableMouse(false)
	rangeFrameBG:Hide()
	if (not isTargetValid("target")) then
		rangeFrame:Hide()
	end
end

function RangeCheck:unlock()
	rangeFrame:EnableMouse(true)
	rangeFrame:Show()
	rangeFrameBG:Show()
end

function RangeCheck:targetChanged()
	if (isTargetValid("target")) then
		rangeFrame:Show()
		lastUpdate = UpdateDelay -- to force update in next OnUpdate()
	elseif (db.Locked) then
		rangeFrame:Hide()
	end
end

function RangeCheck:enable()
	self:targetChanged()
end

function RangeCheck:disable()
	rangeFrame:Hide()
end

function RangeCheck:setHeight(height)
	local path, _, flags = rangeText:GetFont()
	rangeText:SetFont(path, height, flags)
end


-- boring stuff

function RangeCheck:OnLoad()
	-- register our slash command
	SLASH_RANGECHECK1 = "/rangecheck"
	SlashCmdList["RANGECHECK"] = function(msg)
		RangeCheck:SlashCmd(msg)
	end

	this:RegisterEvent("VARIABLES_LOADED")
	this:RegisterEvent("LEARNED_SPELL_IN_TAB")
	this:RegisterEvent("CHARACTER_POINTS_CHANGED")
	this:RegisterEvent("PLAYER_TARGET_CHANGED")
--	this:RegisterEvent("PLAYER_ALIVE")
--	this:RegisterEvent("SPELLS_CHANGED")
end

function RangeCheck:OnEvent(event, ...)
	if (type(self[event]) == 'function') then
		self[event](self, event, ...)
	else
		self:debug("unexpected event: " .. tostring(event))
	end
end

function RangeCheck:VARIABLES_LOADED()
	db = RangeCheckDB
	print("RangeCheck " .. VERSION .. " loaded. Type /rangecheck for help")
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
	if (db.Enabled) then
		self:init(true)
	end
end

function RangeCheck:CHARACTER_POINTS_CHANGED()
	if (db.Enabled) then
		self.RangeCheck:init(true)
	end
end

function RangeCheck:PLAYER_TARGET_CHANGED()
	if (db.Enabled) then
		self:init() -- remove it if we can reliably init from PLAYER_ALIVE
		self:targetChanged()
	end
end

function RangeCheck:SlashCmd(args)
	if (args == nil) then return end
	local _, _, cmd, cmdParam = string.find(string.lower(args), "^%s*(%S+)%s*(%S*)")
	if (cmd == "on" or cmd == "enable") then
		db.Enabled = true
		self:init(true)
		self:enable()
		print("RangeCheck enabled")
	elseif (cmd == "off" or cmd == "disable") then
		db.Enabled = false
		self:disable()
		print("RangeCheck disabled")
	elseif (cmd == "lock") then
		db.Locked = true
		self:lock()
		print("RangeCheck locked")
	elseif (cmd == "unlock") then
		db.Locked = false
		self:unlock()
		print("RangeCheck is unlocked")
	elseif (cmd == "height" or cmdParam == "h") then
			local _, _, h = string.find(args, "(%d+\.?%d*)")
			if (h == nil) then
				self:showStatus()
				return
			end
			local hh = tonumber(h)
			if (5 <= hh and hh < 40) then
				self:setHeight(hh)
				db.Height = hh
				print("RangeCheckHeight set to " .. tostring(hh))
			end
	elseif (cmd == "reset") then
		self:resetPosition()
		self:setHeight(db.Height)
		if (db.Enabled) then
			self:init(true)
			self:enable()
		else
			self:disable()
		end
	else
		self:showStatus()
	end
end

function RangeCheck:showStatus()
	print("usage: /rangecheck lock | unlock | enable | disable | height XX | reset")
	for k, v in pairs(db) do
		print(k .. ": " .. tostring(v))
	end
end

