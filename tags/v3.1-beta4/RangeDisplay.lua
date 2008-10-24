--[[
Name: RangeDisplay
Revision: $Revision$
Author(s): mitch0
Website: http://www.wowace.com/projects/range-display/
SVN: svn://svn.wowace.com/wow/range-display/maguiInline/trunk
Description: RangeDisplay displays the estimated range to the current target based on spell ranges and other measurable ranges
Dependencies: LibStub, LibRangeCheck-2.0, Ace3, LibSharedMedia-3.0(optional)
License: Public Domain
]]

local AppName = "RangeDisplay"
local VERSION = AppName .. "-r" .. ("$Revision$"):match("%d+")

local rc = LibStub("LibRangeCheck-2.0")
local SML = LibStub:GetLibrary("LibSharedMedia-3.0", true)
local L = LibStub("AceLocale-3.0"):GetLocale(AppName)

-- internal vars

local _ -- throwaway

-- cached stuff

local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit

-- hard-coded config stuff

local UpdateDelay = .1 -- update frequency == 1/UpdateDelay
local DefaultFontPath = GameFontNormal:GetFont()
local DefaultFontName = "Friz Quadrata TT"
local FrameWidth = 120
local FrameHeight = 30

local MaxRangeSpells = {
    ["HUNTER"] = {
        53351, -- ["Kill Shot"] -- 5-45 (Hawk Eye: 47, 49, 51)
        75, -- ["Auto Shot"], -- 5-35 (Hawk Eye: 37, 39, 41)
    },
    ["MAGE"] = {
        133, -- ["Fireball"], -- 35 (Flame Throwing: 38, 41)
        116, -- ["Frostbolt"], -- 30 (Arctic Reach: 33, 36)
        5143, -- ["Arcane Missiles"], -- 30 (Magic Attunement: 33, 36)
    },
    ["SHAMAN"] = {
		403, -- ["Lightning Bolt"], -- 30 (Storm Reach: 33, 36)
		8050, -- ["Flame Shock"], -- 30 (Lava Flows: 25, 30, 35; Gladiator Gloves: +5)
    },
    ["WARLOCK"] = {
        348, -- ["Immolate"], -- 30 (Destructive Reach: 33, 36)
        172, -- ["Corruption"], -- 30 (Grim Reach: 33, 36)
    },
}

---------------------------------

RangeDisplay = LibStub("AceAddon-3.0"):NewAddon(AppName, "AceConsole-3.0", "AceEvent-3.0")
RangeDisplay:SetDefaultModuleState(false)

RangeDisplay.version = VERSION
RangeDisplay.AppName = AppName

-- Default DB stuff

local function makeColor(r, g, b, a)
    a = a or 1.0
    return { ["r"] = r, ["g"] = g, ["b"] = b, ["a"] = a }
end

local defaults = {
    profile = {
        locked = false,
        minimap = {},
        units = {
            ["**"] = {
                enabled = true,
                point = "CENTER",
                relPoint = "CENTER",
                x = 0,
                y = 0,
                font = DefaultFontName,
                fontSize = 24,
                fontOutline = "",
                strata = "HIGH",
                checkVisibility = false,
                enemyOnly = false,
                maxRangeOnly = false,
                suffix = "",

				rangeLimit = 100,
                overLimitDisplay = false,
                overLimitSuffix = " +",

                oorSection = {
                    enabled = true,
                    color = makeColor(0.9, 0.055, 0.075),
                    range = 40,
                },
                color = makeColor(1.0, 0.82, 0),
                mrSection = {
                    enabled = true,
                    color = makeColor(0.035, 0.865, 0.0),
                    range = 30,
                },
                srSection = {
                    enabled = true,
                    color = makeColor(0.055, 0.875, 0.825),
                    range = 20,
                },
                crSection = {
                    enabled = true,
                    color = makeColor(0.9, 0.9, 0.9),
                    range = 5,
                },
            },
            ["focus"] = {
                x = -(FrameWidth + 10),
            },
            ["pet"] = {
                enabled = false,
                x = (FrameWidth + 10),
            },
        },
    },
}

-- Per unit data

local function isTargetValid(ud)
    local unit = ud.unit
    return UnitExists(unit) and (not UnitIsDeadOrGhost(unit))
            and (not ud.db.enemyOnly or UnitCanAttack("player", unit))
            and (not UnitIsUnit(unit, "player"))
end

local function targetChanged(ud)
    if (ud:isTargetValid()) then
        ud.rangeFrame:Show()
        ud.lastUpdate = UpdateDelay -- to force update in next onUpdate()
    elseif (ud.locked) then
        ud.rangeFrame:Hide()
    end
end

local function profileChanged(ud, db) 
    ud.db = db
end

local function applyFontSettings(ud, isCallback)
    local dbFontPath
    if (SML) then
        dbFontPath = SML:Fetch("font", ud.db.font, true)
        if (not dbFontPath) then
            if (isCallback) then
                return
            end
            SML.RegisterCallback(ud, "LibSharedMedia_Registered", "applyFontSettings", true)
            dbFontPath = DefaultFontPath
        else
            SML.UnregisterCallback(ud, "LibSharedMedia_Registered")
        end
    else
        dbFontPath = DefaultFontPath
    end
    local fontPath, fontSize, fontOutline = ud.rangeFrameText:GetFont()
    fontOutline = fontOutline or ""
    if (dbFontPath ~= fontPath or ud.db.fontSize ~= fontSize or ud.db.fontOutline ~= fontOutline) then
        ud.rangeFrameText:SetFont(dbFontPath, ud.db.fontSize, ud.db.fontOutline)
    end
end

local function applySettings(ud)
    if (ud.db.enabled) then
        if (not ud.rangeFrame) then
            ud:createFrame()
        end
        ud.rangeFrame:ClearAllPoints()
        ud.rangeFrame:SetPoint(ud.db.point, UIParent, ud.db.relPoint, ud.db.x, ud.db.y)
        ud.rangeFrame:SetFrameStrata(ud.db.strata)
        ud.rangeFrameText:SetTextColor(ud.db.color.r, ud.db.color.g, ud.db.color.b, ud.db.color.a)
        ud:applyFontSettings()
        ud.lastMinRange, ud.lastMaxRange = false, false -- to force update
        if (ud.locked) then
            ud:lock()
        else
            ud:unlock()
        end
    else
        ud:disable()
    end
end

local function lock(ud)
    ud.locked = true
    if (ud.db.enabled) then
        ud.rangeFrame:EnableMouse(false)
        if (ud.rangeFrameBG) then
            ud.rangeFrameBG:Hide()
            ud.rangeFrameBGText:Hide()
        end
        if (not ud:isTargetValid()) then
            ud.rangeFrame:Hide()
        end
    end
end

local function createFrameBG(ud)
    local unit = ud.unit

    ud.rangeFrameBG = ud.rangeFrame:CreateTexture("RangeDisplayFrameBG_" .. unit, "BACKGROUND")
    ud.rangeFrameBG:SetTexture(0, 0, 0, 0.42)
    ud.rangeFrameBG:SetWidth(ud.rangeFrame:GetWidth())
    ud.rangeFrameBG:SetHeight(ud.rangeFrame:GetHeight())
    ud.rangeFrameBG:SetPoint("CENTER", ud.rangeFrame, "CENTER", 0, 0)


    ud.rangeFrameBGText = ud.rangeFrame:CreateFontString("RangeDisplayFrameBGText_" .. unit, "OVERLAY", "GameFontNormal")
    ud.rangeFrameBGText:SetFont(DefaultFontPath, 10, "")
    ud.rangeFrameBGText:SetJustifyH("CENTER")
    ud.rangeFrameBGText:SetPoint("BOTTOM", ud.rangeFrame, "BOTTOM", 0, 0)
    ud.rangeFrameBGText:SetText(L[unit])
end

local function unlock(ud)
    ud.locked = false
    if (ud.db.enabled) then
        if (not ud.rangeFrameBG) then
            createFrameBG(ud)
        end
        ud.rangeFrame:EnableMouse(true)
        ud.rangeFrame:Show()
        ud.rangeFrameBG:Show()
        ud.rangeFrameBGText:Show()
    end
end

local function createFrame(ud)
    local unit = ud.unit
    ud.isMoving = false
    ud.rangeFrame = CreateFrame("Frame", "RangeDisplayFrame_" .. unit, UIParent)
    ud.rangeFrame:Hide()
    ud.rangeFrame:SetFrameStrata(ud.db.strata)
    ud.rangeFrame:EnableMouse(false)
    ud.rangeFrame:SetClampedToScreen()
    ud.rangeFrame:SetMovable(true)
    ud.rangeFrame:SetWidth(FrameWidth)
    ud.rangeFrame:SetHeight(FrameHeight)
    ud.rangeFrame:SetPoint(ud.db.point, UIParent, ud.db.relPoint, ud.db.x, ud.db.y)

    ud.rangeFrameText = ud.rangeFrame:CreateFontString("RangeDisplayFrameText_" .. unit, "OVERLAY", "GameFontNormal")
    ud.rangeFrameText:SetFont(DefaultFontPath, ud.db.fontSize, ud.db.fontOutline)
    ud.rangeFrameText:SetJustifyH("CENTER")
    ud.rangeFrameText:SetPoint("CENTER", ud.rangeFrame, "CENTER", 0, 0)

    ud.lastUpdate = 0
    ud.rangeFrame:SetScript("OnMouseDown", function(frame, button)
        if (button == "LeftButton") then
            ud.rangeFrame:StartMoving()
            ud.isMoving = true
        elseif (button == "RightButton") then
            RangeDisplay:openConfigDialog(ud)
        end
    end)
    ud.rangeFrame:SetScript("OnMouseUp", function(frame, button)
        if (ud.isMoving and button == "LeftButton") then
            ud.rangeFrame:StopMovingOrSizing()
            ud.isMoving = false
            ud.db.point, _, ud.db.relPoint, ud.db.x, ud.db.y = ud.rangeFrame:GetPoint()
        end
    end)
    ud.rangeFrame:SetScript("OnUpdate", function(frame, elapsed)
        ud.lastUpdate = ud.lastUpdate + elapsed
        if (ud.lastUpdate < UpdateDelay) then return end
        ud.lastUpdate = 0
        ud:update()
    end)
end

local function enable(ud)
    if (not ud.rangeFrame) then
        ud:createFrame()
    end
end

local function disable(ud)
    if (ud.rangeFrame) then
        ud.rangeFrame:Hide()
    end
end

local function update(ud)
    local minRange, maxRange = rc:getRange(ud.unit, ud.db.checkVisibility)
    if (minRange == ud.lastMinRange and maxRange == ud.lastMaxRange) then return end
    ud.lastMinRange, ud.lastMaxRange = minRange, maxRange
    local range = nil
    local color = nil
    if (minRange) then
		if (minRange >= ud.db.rangeLimit) then maxRange = nil end
        if (maxRange) then
            if (ud.db.maxRangeOnly) then
                range = maxRange .. ud.db.suffix
            else
                range = minRange .. " - " .. maxRange .. ud.db.suffix
            end
            if (ud.db.crSection.enabled and maxRange <= ud.db.crSection.range) then
                color = ud.db.crSection.color
            elseif (ud.db.srSection.enabled and maxRange <= ud.db.srSection.range) then
                color = ud.db.srSection.color
            elseif (ud.db.mrSection.enabled and maxRange <= ud.db.mrSection.range) then
                color = ud.db.mrSection.color
            elseif (ud.db.oorSection.enabled and minRange >= ud.db.oorSection.range) then
                color = ud.db.oorSection.color
            else
                color = ud.db.color
            end
        elseif (ud.db.overLimitDisplay) then
            color = (ud.db.oorSection.enabled and minRange >= ud.db.oorSection.range) and ud.db.oorSection.color or ud.db.color
            range = minRange .. ud.db.overLimitSuffix
        end
    end
    ud.rangeFrameText:SetText(range)
    if (color) then
        ud.rangeFrameText:SetTextColor(color.r, color.g, color.b, color.a)
    end
end

local units = {
    {
        unit = "playertarget",
        event = "PLAYER_TARGET_CHANGED",
    },
    {
        unit = "focus",
        event = "PLAYER_FOCUS_CHANGED",
    },
    {
        unit = "pet",
        event = "UNIT_PET",
        targetChanged = function(ud, event, unitId, ...)
                if (unitId ~= "player") then return end
                targetChanged(ud, event, unitId, ...)
            end
    },
}

local function autoAdjust(ud)
    local _, playerClass = UnitClass("player")
    local maxRangeSpells = MaxRangeSpells[playerClass]
    if (maxRangeSpells) then
        local oor
        for _, sid in ipairs(maxRangeSpells) do
            local name, _, _, _, _, _, _, _, range = GetSpellInfo(sid)
            if (range and (not oor or oor < range) and rc:findSpellIndex(name)) then
                oor = range
            end
        end
        if (oor) then
            ud.db.oorSection.range = oor
        end
    end
end

for _, ud in ipairs(units) do
    ud.profileChanged = ud.profileChanged or profileChanged
    ud.applySettings = ud.applySettings or applySettings
    ud.applyFontSettings = ud.applyFontSettings or applyFontSettings
    ud.targetChanged = ud.targetChanged or targetChanged
    ud.isTargetValid = ud.isTargetValid or isTargetValid
    ud.lock = ud.lock or lock
    ud.unlock = ud.unlock or unlock
    ud.createFrame = ud.createFrame or createFrame
    ud.update = ud.update or update
    ud.autoAdjust = autoAdjust
    ud.enable = enable
    ud.disable = disable
end

-- AceAddon stuff

function RangeDisplay:OnInitialize()
    self.units = units
    self.db = LibStub("AceDB-3.0"):New("RangeDisplayDB3", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "profileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "profileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "profileChanged")
    self:setupOptions()
    self:profileChanged()
end

function RangeDisplay:OnEnable(first)
end

function RangeDisplay:OnDisable()
    for _, ud in ipairs(units) do
        ud:disable()
    end
    self:UnregisterAllEvents()
end

function RangeDisplay:applySettings()
    if (not self:IsEnabled()) then
        self:OnDisable()
        return
    end
    local locked = self.db.profile.locked
    for _, ud in ipairs(units) do
        if (ud.db.enabled) then
            ud:enable()
            if (locked) then
                ud:lock()
            else
                ud:unlock()
            end
            ud:applySettings()
            self:registerTargetChangedEvent(ud)
        else
            ud:disable()
            self:unregisterTargetChangedEvent(ud)
        end
    end
end

-- for now we assume that each unitdata is using only 1 event, and there are no overlapping events, as it's faster like this
function RangeDisplay:registerTargetChangedEvent(ud)
    if (ud.event) then
        ud.eventHandler = ud.eventHandler or function(...)
                ud:targetChanged(...)
            end
        self:RegisterEvent(ud.event, ud.eventHandler)
    end
end

function RangeDisplay:unregisterTargetChangedEvent(ud)
    if (ud.event) then
        self:UnregisterEvent(ud.event)
    end
end

function RangeDisplay:profileChanged()
    for _, ud in ipairs(units) do
        local db = self.db.profile.units[ud.unit]
        ud:profileChanged(db)
    end
    self:applySettings()
end

