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

-- internal vars

local _ -- throwaway

-- cached stuff

local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitCanAttack = UnitCanAttack
local UnitIsUnit = UnitIsUnit

-- hard-coded config stuff

local UpdateDelay = .1 -- update frequency == 1/UpdateDelay
local MinFontSize = 5
local MaxFontSize = 40
local DefaultFontName = "Friz Quadrata TT"
local DefaultFontPath = GameFontNormal:GetFont()
local FrameWidth = 120
local FrameHeight = 30

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
        units = {
            ["*"] = {
                enabled = true,
                point = "CENTER",
                relPoint = "CENTER",
                x = 0,
                y = 0,
                font = DefaultFontName,
                fontSize = 24,
                fontOutline = "",
                outOfRangeDisplay = false,
                checkVisibility = false,
                enemyOnly = false,
                maxRangeOnly = false,
                color = makeColor(1.0, 0.82, 0),
                oorSection = {
                    enabled = true,
                    color = makeColor(0.9, 0.2, 0.1),
                    range = 40,
                },
                mrSection = {
                    enabled = true,
                    color = makeColor(0.4, 0.75, 0.24),
                    range = 30,
                },
                srSection = {
                    enabled = true,
                    color = makeColor(0.26, 0.6, 0.73),
                    range = 20,
                },
                mlrSection = {
                    enabled = true,
                    color = makeColor(0.9, 0.9, 0.9),
                },
                suffix = "",
                oorSuffix = " +",
                strata = "HIGH",
            },
            ["focus"] = {
                x = -(FrameWidth / 2 + 10),
            },
            ["pet"] = {
                enabled = false,
                x = (FrameWidth / 2 + 10),
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
            SML.RegisterCallback(ud, "LibSharedMedia_Registered", "sharedMediaCallback")
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
            self:createFrame(ud)
        end
        ud.rangeFrame:ClearAllPoints()
        ud.rangeFrame:SetPoint(ud.db.point, UIParent, ud.db.relPoint, ud.db.x, ud.db.y)
        ud.rangeFrame:SetFrameStrata(ud.db.strata)
        ud.rangeFrameText:SetTextColor(ud.db.color.r, ud.db.color.g, ud.db.color.b, ud.db.color.a)
        ud:applyFontSettings()
        ud.lastMinRange, ud.lastMaxRange = false, false -- to force update
        ud:targetChanged()
    else
        ud:disable()
    end
end

local function lock(ud)
    ud.locked = true
    if (ud.db.enabled) then
        ud.rangeFrame:EnableMouse(false)
        ud.rangeFrameBG:Hide()
        if (not ud:isTargetValid()) then
            ud.rangeFrame:Hide()
        end
    end
end

local function unlock(ud)
    ud.locked = false
    if (ud.db.enabled) then
        ud.rangeFrame:EnableMouse(true)
        ud.rangeFrame:Show()
        ud.rangeFrameBG:Show()
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

    ud.rangeFrameBG = ud.rangeFrame:CreateTexture("RangeDisplayFrameBG_" .. unit, "BACKGROUND")
    ud.rangeFrameBG:SetTexture(0, 0, 0, 0.42)
    ud.rangeFrameBG:SetWidth(ud.rangeFrame:GetWidth())
    ud.rangeFrameBG:SetHeight(ud.rangeFrame:GetHeight())
    ud.rangeFrameBG:SetPoint("CENTER", ud.rangeFrame, "CENTER", 0, 0)

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
        if (maxRange) then
            if (ud.db.maxRangeOnly) then
                range = maxRange .. ud.db.suffix
            else
                range = minRange .. " - " .. maxRange .. ud.db.suffix
            end
            if (maxRange <= 5 and ud.db.mlrSection.enabled) then
                color = ud.db.mlrSection.color
            elseif (ud.db.srSection.enabled and maxRange <= ud.db.srSection.range) then
                color = ud.db.srSection.color
            elseif (ud.db.mrSection.enabled and maxRange <= ud.db.mrSection.range) then
                color = ud.db.mrSection.color
            elseif (ud.db.oorSection.enabled and minRange >= ud.db.oorSection.range) then
                color = ud.db.oorSection.color
            else
                color = ud.db.color
            end
        elseif (ud.db.outOfRangeDisplay) then
            color = (ud.db.oorSection.enabled and minRange >= ud.db.oorSection.range) and ud.db.oorSection.color or ud.db.color
            range = minRange .. ud.db.oorSuffix
        end
    end
    ud.rangeFrameText:SetText(range)
    if (color) then
        ud.rangeFrameText:SetTextColor(color.r, color.g, color.b, color.a)
    end
end

local units = {
    playertarget = {
        event = "PLAYER_TARGET_CHANGED",
        order = 10,
    },
    focus = {
        event = "PLAYER_FOCUS_CHANGED",
        order = 20,
    },
    pet = {
        event = "UNIT_PET",
        order = 30,
        targetChanged = function(ud, event, unitId, ...)
                if (unitId ~= "player") then return end
                targetChanged(ud, event, unitId, ...)
            end
    },
}

for unit, ud in pairs(units) do
    ud.unit = unit
    ud.profileChanged = ud.profileChanged or profileChanged
    ud.applySettings = ud.applySettings or applySettings
    ud.applyFontSettings = ud.applyFontSettings or applyFontSettings
    ud.targetChanged = ud.targetChanged or targetChanged
    ud.isTargetValid = ud.isTargetValid or isTargetValid
    ud.lock = ud.lock or lock
    ud.unlock = ud.unlock or unlock
    ud.createFrame = ud.createFrame or createFrame
    ud.update = ud.update or update
end

-- AceAddon stuff

function RangeDisplay:OnInitialize()
    self.units = units
    self.db = LibStub("AceDB-3.0"):New("RangeDisplayDB3", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "profileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "profileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "profileChanged")
    self:setupOptions()
end

function RangeDisplay:OnEnable(first)
    self:profileChanged()
end

function RangeDisplay:OnDisable()
    for _, ud in pairs(units) do
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
    for unit, ud in pairs(units) do
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
    for unit, ud in pairs(units) do
        local db = self.db.profile.units[unit]
        ud:profileChanged(db)
    end
    self:applySettings()
end

