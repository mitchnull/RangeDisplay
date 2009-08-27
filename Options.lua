local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(RangeDisplay.AppName)
local rc = LibStub("LibRangeCheck-2.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

local Icon = "Interface\\Icons\\INV_Misc_Spyglass_02"
local MinFontSize = 5
local MaxFontSize = 30

local _

local FontOutlines = {
    [""] = L["None"],
    ["OUTLINE"] = L["Normal"],
    ["THICKOUTLINE"] = L["Thick"],
}

local FrameStratas = {
    ["HIGH"] = L["High"],
    ["MEDIUM"] = L["Medium"],
    ["LOW"] = L["Low"],
}

local options = {
    type = "group",
    name = RangeDisplay.AppName,
    handler = RangeDisplay,
    get = "getOption",
    set = "setOption",
    args = {
        main = {
            type = 'group',
            childGroups = 'tab',
            inline = true,
            name = RangeDisplay.AppName,
            handler = RangeDisplay,
            get = "getOption",
            set = "setOption",
            order = 10,
            args = {
                locked = {
                    type = 'toggle',
                    width = 'full',
                    name = L["Locked"],
                    desc = L["Lock/Unlock display frame"],
                    order = 110,
                },
                config = {
                    type = 'execute',
                    name = L["Configure"],
                    desc = L["Bring up GUI configure dialog"],
                    guiHidden = true,
                    order = 300,
                    func = function() RangeDisplay:openConfigDialog() end,
                },
            },
        },
    },
}

local function makeSectionOptions(ud, order, name, isDefault)
     return  {
        type = 'group',
        disabled = "isSectionDisabled",
        set = "setSectionOption",
        get = "getSectionOption",
        name = L[name],
        guiInline = true,
        order = order,
        args = {
            enabled = {
                type = 'toggle',
                name = "", -- L["Enabled"],
                desc = (not isDefault) and L["Enable this color section"] or nil,
                disabled = (not isDefault) and "isUnitDisabled" or false,
                get = isDefault and function() return true end or nil,
                set = isDefault and function() end or nil,
                width = 'half',
                order = 10,
            },
            color = {
                type = 'color',
                hasAlpha = true,
                name = L["Color"],
                --desc = L["Color"],
                set = isDefault and "setUnitColor" or "setSectionColor",
                get = isDefault and "getUnitColor" or "getSectionColor",
                width = 'half',
                order = 20,
            },
            range = (not isDefault) and {
                type = 'range',
                name = L["Range limit"],
                --desc = L["Range limit"],
                min = MinRangeLimit,
                max = MaxRangeLimit,
                step = 1,
                order = 30,
            } or nil,
            useText = {
                type = 'toggle',
                name = L["Use Text"],
                desc = L["Use static text instead of the numeric range"],
                -- width = 'half',
                order = 40,
            },
            text = {
                type = 'input',
                name = L["Text"],
                desc = L["A free-form text to display for this section instead of the numeric range"],
                disabled = "isSectionTextDisabled",
                -- width = 'half',
                order = 50,
            },
        },
    }
end

local function addUnitOptions(ud, order)
    local unit = ud.unit
    local opts = {
        type = 'group',
        name = L[unit],
        handler = ud,
        get = "getUnitOption",
        set = "setUnitOption",
        disabled = "isUnitDisabled",
        order = order or 1,
        args = {
            enabled = {
                type = 'toggle',
                name = L["Enabled"],
                order = 113,
                disabled = false,
                width = 'full', -- to make the layout nicer
            },
            enemyOnly = {
                type = 'toggle',
                name = L["Enemy only"],
                desc = L["Show range for enemy targets only"],
                order = 115,
            },
            maxRangeOnly = {
                type = 'toggle',
                name = L["Max range only"],
                desc = L["Show the maximum range only"],
                order = 116,
            },
            rangeLimit = {
                type = 'range',
                name = L["Range limit"],
                desc = L["Ranges above this are not reported"],
                min = MinRangeLimit,
                max = MaxRangeLimit,
                step = 1,
                order = 118,

            },

            suffix = {
                type = 'input',
                name = L["Suffix"],
                desc = L["A free-form suffix to append to the range display when you are in range"],
                order = 119,
            },

            overLimitDisplay = {
                type = 'toggle',
                name = L["Over limit display"],
                desc = L["Show/Hide display if the target is further than range limit"],
                order = 124,
            },
            overLimitSuffix = {
                type = 'input',
                name = L["Over limit suffix"],
                desc = L["A free-form suffix to append to the range display when you are further than range limit"],
                order = 125,
                disabled = function() return not ud.db.enabled or not ud.db.overLimitDisplay end,
            },

            font = {
                type = "select", dialogControl = 'LSM30_Font',
                name = L["Font"],
                --desc = L["Font"],
                values = AceGUIWidgetLSMlists.font,
                order = 135,
            },
            fontSize = {
                type = 'range',
                name = L["Font size"],
                --desc = L["Font size"],
                min = MinFontSize,
                max = MaxFontSize,
                step = 1,
                order = 140,
            },
            fontOutline = {
                type = 'select',
                name = L["Font outline"],
                --desc = L["Font outline"],
                values = FontOutlines,
                order = 150,
            },
            strata = {
                type = 'select',
                name = L["Strata"],
                desc = L["Frame strata"],
                values = FrameStratas,
                order = 155,
            },
            bg = {
                type = "group",
                name = L["Background Options"],
                disabled = function() return not ud.db.enabled or not ud.db.bgEnabled end,
                guiInline = true,
                order = 158,
                args = {
                    bgEnabled = {
                        type = 'toggle',
                        order = 1,
                        name = L["Enabled"],
                        disabled = "isUnitDisabled",
                    },
                    frameWidth = {
                        type = 'range',
                        disabled = "isUnitDisabled",
                        name = L["Width"],
                        min = 32,
                        max = 256,
                        step = 1,
                        order = 5,
                    },
                    frameHeight = {
                        type = 'range',
                        disabled = "isUnitDisabled",
                        name = L["Height"],
                        min = 16,
                        max = 64,
                        step = 1,
                        order = 6,
                    },
                    bgTexture = {
                        type = "select", dialogControl = 'LSM30_Background',
                        order = 11,
                        name = L["Background Texture"],
                        desc = L["Texture to use for the frame's background"],
                        values = AceGUIWidgetLSMlists.background,
                    },
                    bgBorderTexture = {
                        type = "select", dialogControl = 'LSM30_Border',
                        order = 12,
                        name = L["Border Texture"],
                        desc = L["Texture to use for the frame's border"],
                        values = AceGUIWidgetLSMlists.border,
                    },
                    bgColor = {
                        type = "color",
                        order = 13,
                        name = L["Background Color"],
                        desc = L["Frame's background color"],
                        hasAlpha = true,
                        set = "setBGColor",
                        get = "getBGColor",
                    },
                    bgBorderColor = {
                        type = "color",
                        order = 14,
                        name = L["Border Color"],
                        desc = L["Frame's border color"],
                        hasAlpha = true,
                        set = "setBGColor",
                        get = "getBGColor",
                    },
                    bgTile = {
                        type = "toggle",
                        order = 2,
                        name = L["Tile Background"],
                        desc = L["Tile the background texture"],
                    },
                    bgTileSize = {
                        type = "range",
                        order = 16,
                        name = L["Background Tile Size"],
                        desc = L["The size used to tile the background texture"],
                        min = 16, max = 256, step = 1,
                        disabled = function() return not ud.db.enabled or not ud.db.bgEnabled or not ud.db.bgTile end,
                    },
                    bgEdgeSize = {
                        type = "range",
                        order = 17,
                        name = L["Border Thickness"],
                        desc = L["The thickness of the border"],
                        min = 1, max = 16, step = 1,
                    },
                    bgAutoHide = {
                        type = 'toggle',
                        order = 18,
                        name = L["Auto hide"],
                        desc = L["Hide the background if the range display is not active"],
                    },
                    bgUseSectionColors = {
                        type = 'toggle',
                        order = 19,
                        name = L["Use Section Colors"],
                        desc = L["Use section colors for background and background color for text"],
                    },
                },
            },

            color = {
                type = 'color',
                guiHidden = true,
                width = 'half',
                hasAlpha = true,
                name = L["Color"],
                --desc = L["Color"],
                set = "setUnitColor",
                get = "getUnitColor",
                order = 160,
            },
            crSection = makeSectionOptions(ud, 165, "Close range section"),
            srSection = makeSectionOptions(ud, 170, "Short range section"),
            mrSection = makeSectionOptions(ud, 173, "Medium range section"),
            lrSection = makeSectionOptions(ud, 174, "Long range section"),
            defaultSection = makeSectionOptions(ud, 175, "Default section", true),
            oorSection = makeSectionOptions(ud, 176, "Out of range section"),
            autoAdjust = {
                type = 'execute',
                name = L["Auto adjust"],
                width = 'full',
                func = function()
                    ud:autoAdjust()
                end,
                order = 185,
            },
        },
    }
    if (ud.mouseAnchor) then
        opts.args.enabled.width = nil
        opts.args.mouseAnchor = {
            type = 'toggle',
            name = L["Anchor to Mouse"],
            order = 114,
        }
    end
    options.args[unit] = opts
    return opts
end

local function getUnitOption(ud, info)
    return ud.db[info[#info]]
end

local function setUnitOption(ud, info, value)
    ud.db[info[#info]] = value
    ud:applySettings()
end

local function getSectionOption(ud, info)
    return ud.db[info[#info - 1]][info[#info]]
end

local function setSectionOption(ud, info, value)
    ud.db[info[#info - 1]][info[#info]] = value
    ud:applySettings()
end

local function setColor(ud, dbcolor, r, g, b, a)
    dbcolor.r, dbcolor.g, dbcolor.b, dbcolor.a = r, g, b, a
    if (ud.rangeFrameText) then
        ud:setDisplayColor(dbcolor)
    end
end

local function getColor(ud, dbcolor)
    return dbcolor.r, dbcolor.g, dbcolor.b, dbcolor.a
end

local function getUnitColor(ud, info)
    local dbcolor = ud.db[info[#info]]
    return getColor(ud, dbcolor)
end

local function setUnitColor(ud, info, r, g, b, a)
    local dbcolor = ud.db[info[#info]]
    setColor(ud, dbcolor, r, g, b, a)
end

local function getSectionColor(ud, info)
    local dbcolor =  ud.db[info[#info - 1]][info[#info]]
    return getColor(ud, dbcolor)
end

local function setSectionColor(ud, info, r, g, b, a)
    local dbcolor =  ud.db[info[#info - 1]][info[#info]]
    setColor(ud, dbcolor, r, g, b, a)
end

local function setBGColor(ud, info, r, g, b, a)
    local dbcolor = ud.db[info[#info]]
    dbcolor.r, dbcolor.g, dbcolor.b, dbcolor.a = r, g, b, a
    if (not ud.bgFrame) then
         return
    end
    if (ud.db.bgUseSectionColors) then
        ud.rangeFrameText:SetTextColor(ud.db.bgColor.r, ud.db.bgColor.g, ud.db.bgColor.b, ud.db.bgColor.a)
    else
        ud.bgFrame:SetBackdropColor(ud.db.bgColor.r, ud.db.bgColor.g, ud.db.bgColor.b, ud.db.bgColor.a)
    end
    ud.bgFrame:SetBackdropBorderColor(ud.db.bgBorderColor.r, ud.db.bgBorderColor.g, ud.db.bgBorderColor.b, ud.db.bgBorderColor.a)
end

local function getBGColor(ud, info)
    local dbcolor = ud.db[info[#info]]
    return getColor(ud, dbcolor)
end

local function isUnitDisabled(ud, info)
    return not ud.db.enabled
end

local function isSectionDisabled(ud, info)
    return (not ud.db.enabled) or (not ud.db[info[#info - 1]].enabled)
end

local function isSectionTextDisabled(ud, info)
    return (not ud.db.enabled) or (not ud.db[info[#info - 1]].enabled) or (not ud.db[info[#info - 1]].useText)
end

local function addConfigFunctions(units)
    for _, ud in ipairs(units) do
        ud.getUnitOption = getUnitOption
        ud.setUnitOption = setUnitOption
        ud.getUnitColor = getUnitColor
        ud.setUnitColor = setUnitColor
        ud.getSectionColor = getSectionColor
        ud.setSectionColor = setSectionColor
        ud.getSectionOption = getSectionOption
        ud.setSectionOption = setSectionOption
        ud.isUnitDisabled = isUnitDisabled
        ud.isSectionDisabled = isSectionDisabled
        ud.isSectionTextDisabled = isSectionTextDisabled
        ud.setBGColor = setBGColor
        ud.getBGColor = getBGColor
    end
end

function RangeDisplay:registerSubOptions(name, opts)
    local appName = self.AppName .. "." .. name
    AceConfig:RegisterOptionsTable(appName, opts)
    return ACD:AddToBlizOptions(appName, opts.name or name, self.AppName)
end

function RangeDisplay:setupOptions()
    addConfigFunctions(self.units)
    self:setupLDB()
    AceConfig:RegisterOptionsTable(self.AppName, options.args.main)
    self.opts = ACD:AddToBlizOptions(self.AppName, self.AppName)
    for i, ud in ipairs(self.units) do
        local unitOpts = addUnitOptions(ud, 100 + i)
        ud.opts = self:registerSubOptions(ud.unit, unitOpts)
    end
    local profiles =  AceDBOptions:GetOptionsTable(self.db)
    LibStub("LibDualSpec-1.0"):EnhanceOptions(profiles, self.db)
    profiles.order = 900
    options.args.profiles = profiles
    self.profiles = self:registerSubOptions('profiles', profiles)
    self:setupDebugOptions()
    AceConfig:RegisterOptionsTable(self.AppName .. '.Cmd', options, "rangedisplay")
end

function RangeDisplay:setupLDB()
    if (not LDB) then return end
    local ldb = {
        type = "launcher",
        icon = Icon,
        OnClick = function(frame, button)
            if (button == "LeftButton") then
                self:toggleLocked()
            elseif (button == "RightButton") then
                self:openConfigDialog()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(self.AppName)
            tt:AddLine(L["|cffeda55fLeft Click|r to lock/unlock frames"])
            tt:AddLine(L["|cffeda55fRight Click|r to open the configuration window"])
        end,
    }
    LDB:NewDataObject(self.AppName, ldb)
    if (not LDBIcon) then return end
    LDBIcon:Register(self.AppName, ldb, self.db.profile.minimap)
    options.args.main.args.minimap = {
        type = 'toggle',
        name = L["Hide minimap icon"],
        width = 'full',
        order = 111,
        get = function() return self.db.profile.minimap.hide end,
        set = function(info, value)
            if (value) then
                LDBIcon:Hide(self.AppName)
            else
                LDBIcon:Show(self.AppName)
            end
            self.db.profile.minimap.hide = value
        end,
    }
end

function RangeDisplay:openConfigDialog(ud)
    if (ud) then
        InterfaceOptionsFrame_OpenToCategory(ud.opts)
    else
        InterfaceOptionsFrame_OpenToCategory(self.profiles) -- to expand our tree
        InterfaceOptionsFrame_OpenToCategory(self.opts)
    end
end

function RangeDisplay:getOption(info)
    return self.db.profile[info[#info]]
end

function RangeDisplay:setOption(info, value)
    self.db.profile[info[#info]] = value
    self:applySettings()
end

function RangeDisplay:setupDebugOptions()
    if (self.db.profile.debug) then
        local debugOptions = {
            type = 'group',
            name = "Debug",
            inline = true,
            args = {
                startMeasurement = {
                    type = 'execute',
                    name = "StartMeasurement",
                    --desc = "StartMeasurement",
                    func = function()
                        if (not self.db.profile.measurements) then
                            self.db.profile.measurements = {}
                        end
                        self.db.profile.measurements[UnitName("player")] = {}
                        rc:startMeasurement("target", self.db.profile.measurements[UnitName("player")])
                    end,
                },
                stopMeasurement = {
                    type = 'execute',
                    name = "StopMeasurement",
                    --desc = "StopMeasurement",
                    func = function()
                        rc:stopMeasurement()
                    end,
                },
                clearMeasurement = {
                    type = 'execute',
                    name = "ClearMeasurement",
                    --desc = "ClearMeasurement",
                    func = function()
                        self.db.profile.measurements = nil
                    end,
                },
                cacheAllItems = {
                    type = 'execute',
                    name = "CacheAllItems",
                    --desc = "CacheAllItems",
                    func = function()
                        rc:cacheAllItems()
                    end,
                },
                checkAllItems = {
                    type = 'execute',
                    name = "CheckAllItems",
                    --desc = "CheckAllItems",
                    func = function()
                        rc:checkAllItems()
                    end,
                },
                checkAllCheckers = {
                    type = 'execute',
                    name = "CheckAllCheckers",
                    --desc = "CheckAllCheckers",
                    func = function()
                        rc:checkAllCheckers()
                    end,
                },
            },
        }
        options.args.debug = debugOptions
        self:registerSubOptions('debug', debugOptions)
    end
end

