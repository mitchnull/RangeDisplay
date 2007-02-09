--[[

  RangeCheck is part of SpellCaster addon, just separated out for clarity.
  copyright 2007 by mitch
       
]]

local RangeCheck = { L = {}, elapsed = 0, isDebug = nil};
SpellCaster.RangeCheck = RangeCheck;

-- cached stuff
local L_RC = RangeCheck.L;
local print = SpellCaster.print;
local tooltip = SpellCasterTip;
local tooltipRangeText = SpellCasterTipTextRight2;
local rangeText = SpellCasterRangeCheckFrameText;
local rangeFrameBG = SpellCasterRangeCheckFrameBG;
local rangeFrame = SpellCasterRangeCheckFrame;

local UpdateDelay = .05; -- update frequency == 1/UpdateDelay
local lastUpdate = 0; -- time since last real update
local lastRange = nil;

-- helper functions

-- parse the spell range from the tooltip
local function getSpellRange(spellId, bookType)
    if (spellId == nil) then return nil; end
	-- ### dunno why SetOwner() and Show()/Hide() magic is needed, if
	-- someone could find a nice way to do it, please fix it [mitch]
	tooltip:SetOwner(this);
    tooltip:SetSpell(spellId, bookType);
	tooltip:Show();
    local ttt = tooltipRangeText:GetText();
	tooltip:Hide();
    if (ttt == nil) then return nil; end
	-- ### TODO: check hunter spells with minimum range.
    local _, _, range = string.find(ttt, L_RC.RangePattern, 1);
    if (range == nil) then return nil; end
    return tonumber(range);
end

local function findSpellId(spellName)
	local i = 1
	while true do
	    local spell, rank = GetSpellName(i, BOOKTYPE_SPELL)
	    if (not spell) then return nil; end
	    if (spell == spellName) then return i; end
	    i = i + 1;
	end
	return nil;
end


-- <<< RangeCheckSpell --------------------------------
-- RangeChecker class that implements range checking based on spell ranges

local RangeCheckSpell = {};
function RangeCheckSpell:new(spellName)
    local res = { name = spellName }
    setmetatable(res, self);
    self.__index = self;
    return res:init();
end

function RangeCheckSpell:init()
    self.id = findSpellId(self.name);
    self.range = getSpellRange(self.id, BOOKTYPE_SPELL);
    if (self.range == nil) then return nil; end
    if (RangeCheck.isDebug) then
	    print("### new spell: " .. self.name .. ", range: " .. tostring(self.range));
	end
    return self;
end

function RangeCheckSpell:isInRange(unit)
	if (IsSpellInRange(self.id, BOOKTYPE_SPELL, unit) == 1) then return self.range; end
	return nil;
end

function RangeCheckSpell:print()
    print(self.name .. ": " .. tostring(self.range));
end

-- >>> RangeCheckSpell --------------------------------

-- <<< RangeCheckInteract -----------------------------
-- RangeChecker class that implements range checking based on interact distance

local RangeCheckInteract = {};

function RangeCheckInteract:new(index, range)
    local res = { index = index, range = range };
    setmetatable(res, self);
    self.__index = self;
    return res;
end

function RangeCheckInteract:isInRange(unit)
    if (CheckInteractDistance(unit, self.index)) then return self.range; end
    return nil;
end

function RangeCheckInteract:print()
    print("Interact" .. tostring(self.index) .. ": " .. tostring(self.range));
end

-- >>> RangeCheckInteract -----------------------------

-- <<< RCList ------------------------------------------------
-- RangeChecker list that stores RangeCheckers in sorted order
-- We have one for Harm spells and one for Friend spells

local RCList = {};
function RCList:new(spellList)
    local res = {};
    setmetatable(res, self);
    self.__index = self;
    for i, v in ipairs(RangeCheck.InteractList) do
	    res:insertRangeCheck(RangeCheckInteract:new(v.index, v.range));
    end
    if (spellList == nil) then return res; end
    for i, v in ipairs(spellList) do
        res:insertRangeCheck(RangeCheckSpell:new(v));
    end
    return res;
end

-- insert new RangeChecker at the correct position
function RCList:insertRangeCheck(rc)
    if (rc == nil) then return; end
    for i, v in ipairs(self) do
        if (rc.range == v.range) then return; end
        if (rc.range > v.range) then
            table.insert(self, i, rc);
            return;
        end
    end
    table.insert(self, rc);
end

-- return the current range estimate to unit
-- the format is "min - max"
function RCList:getRange(unit)
    local max = nil;
    for i, v in ipairs(self) do
        if (not v:isInRange(unit)) then
            if (max == nil) then return L_RC.OutOfRange ; end
            return tostring(v.range) .. " - " .. tostring(max);
        end
        max = v.range;
    end
    return "0 - " .. tostring(max);
end

function RCList:print()
    for i, v in ipairs(self) do
        v:print();
    end
end

-- >>> RCList ------------------------------------------------

-- <<< RangeCheck constants and functions

-- hard-coded interact distances [based on wowwiki]
RangeCheck.InteractList = { { index = 3, range = 10 }, { index = 2, range = 11 }, { index = 4, range = 28 } };
RangeCheck.FriendSpells = {};
RangeCheck.HarmSpells = {};

-- initialize RangeCheck if not yet initialized or if "forced"
function RangeCheck:init(forced)
	if (self.isInitialized and (not forced)) then return; end
	self.isInitialized = true;
	local playerClass = UnitClass("player");
	self.friendRC = RCList:new(L_RC.FriendSpells[playerClass]);
	self.harmRC = RCList:new(L_RC.HarmSpells[playerClass]);
	self.lastRange = nil;
    if (self.isDebug) then
        print("FriendRangeCheck:");
        self.friendRC:print();
        print("HarmRangeCheck:");
        self.harmRC:print();
	end
	if (SpellCasterState.RangeCheck) then
		self:enable();
	else
		self:disable();
	end
	if (SpellCasterState.RangeCheckLocked) then
		self:lock();
	else
		self:unlock();
	end
	if (SpellCasterState.RangeCheckHeight) then
		self:setHeight(SpellCasterState.RangeCheckHeight);
	end
end

-- ### TODO: probly dead units are also invalid
local function isTargetValid(unit)
	return (UnitExists(unit));
end

function RangeCheck:getRange(unit)
	-- TODO: check what happens if unit is dead, etc
	if (not isTargetValid(unit)) then return nil; end
	if (UnitIsFriend("player", unit)) then
	    return self.friendRC:getRange(unit);
	else
	    return self.harmRC:getRange(unit);
	end
end

function RangeCheck:OnUpdate(elapsed)
	lastUpdate = lastUpdate + elapsed;
	if (lastUpdate < UpdateDelay) then return; end
	lastUpdate = 0;
	local range = self:getRange("target");
	if (range == lastRange) then return; end
	lastRange = range;
	rangeText:SetText(range);
end

-- frame setup stuff

function RangeCheck:resetPosition()
	rangeFrame:ClearAllPoints();
	rangeFrame:SetPoint("CENTER", UIParent, "CENTER");
end

function RangeCheck:lock()
	rangeFrame:EnableMouse(false);
	rangeFrameBG:Hide();
end

function RangeCheck:unlock()
	rangeFrame:EnableMouse(true);
	rangeFrameBG:Show();
end

function RangeCheck:targetChanged()
	if (not isTargetValid("target")) then
		rangeFrame:Hide();
	else
		rangeFrame:Show();
		lastUpdate = UpdateDelay; -- to force update in next OnUpdate()
	end
end

function RangeCheck:enable()
	self:targetChanged();
end

function RangeCheck:disable()
	rangeFrame:Hide();
end

function RangeCheck:setHeight(height)
	local path, _, flags = rangeText:GetFont();
	rangeText:SetFont(path, height, flags);
end

