local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(RangeDisplay.AppName)
local SML = LibStub:GetLibrary("LibSharedMedia-3.0", true)
local rc = LibStub("LibRangeCheck-2.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

local Icon = "Interface\\Icons\\INV_Misc_Spyglass_02"
local MinFontSize = 5
local MaxFontSize = 30
local DefaultFontName = "Friz Quadrata TT"

local _

local function getFonts()
    local fonts = SML and SML:List("font") or { [1] = DefaultFontName }
    local res = {}
    for i, v in ipairs(fonts) do
        res[v] = v
    end
    return res
end

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

local function addUnitOptions(ud, order)
    local unit = ud.unit
    local opts = {
        type = 'group',
        name = L[unit],
        handler = ud,
        get = "getUnitOption",
        set = "setUnitOption",
        order = order or 1,
        args = {
            enabled = {
                type = 'toggle',
                name = L["Enabled"],
                order = 114,
            },
            enemyOnly = {
                type = 'toggle',
                disabled = "isUnitDisabled",
                name = L["Enemy only"],
                desc = L["Show range for enemy targets only"],
                order = 115,
            },
            maxRangeOnly = {
                type = 'toggle',
                disabled = "isUnitDisabled",
                name = L["Max range only"],
                desc = L["Show the maximum range only"],
                order = 116,
            },
            outOfRangeDisplay = {
                type = 'toggle',
                disabled = "isUnitDisabled",
                name = L["Out of range display"],
                desc = L["Show/Hide display if the target is out of range"],
                order = 120,
            },
            checkVisibility = {
                type = 'toggle',
                disabled = "isUnitDisabled",
                name = L["Check visibility"],
                desc = L["If set, the max range to check will be 'visibility range'"],
                order = 130,
            },
            font = {
                type = 'select',
                disabled = "isUnitDisabled",
                name = L["Font"],
                --desc = L["Font"],
                values = getFonts,
                order = 135
            },
            fontSize = {
                type = 'range',
                disabled = "isUnitDisabled",
                name = L["Font size"],
                --desc = L["Font size"],
                min = MinFontSize,
                max = MaxFontSize,
                step = 1,
                order = 140,
            },
            fontOutline = {
                type = 'select',
                disabled = "isUnitDisabled",
                name = L["Font outline"],
                --desc = L["Font outline"],
                values = FontOutlines,
                order = 150,
            },
            -- we monkey around a bit with default color for nicer gui/cmd line
            defaultSection = {
                type = 'group',
                name = L["Default section"],
                name = L["Default section"],
                inline = true,
                cmdHidden = true,
                disabled = "isUnitDisabled",
                order = 160,
                args = {
                    enabled = {
                        type = 'toggle',
                        width = 'half',
                        disabled = "isUnitDisabled",
                        cmdHidden = true,
                        name = "",
                        set = function() end,
                        get = function() return true end,
                        order = 10,
                    },
                    color = {
                        type = 'color',
                        disabled = "isUnitDisabled",
                        width = 'half',
                        hasAlpha = true,
                        name = L["Color"],
                        --desc = L["Color"],
                        set = "setUnitColor",
                        get = "getUnitColor",
                        order = 20,
                    },
                },
            },
            color = {
                type = 'color',
                disabled = "isUnitDisabled",
                guiHidden = true,
                width = 'half',
                hasAlpha = true,
                name = L["Color"],
                --desc = L["Color"],
                set = "setUnitColor",
                get = "getUnitColor",
                order = 160,
            },
            mlrSection = {
                type = 'group',
                disabled = "isUnitDisabled",
                name = L["Melee range section"],
                --desc = L["Melee range section"],
                guiInline = true,
                order = 165,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "",
                        desc = L["Enable this color section"],
                        set = "setSectionOption",
                        get = "getSectionOption",
                        width = 'half',
                        order = 10,
                    },
                    color = {
                        type = 'color',
                        hasAlpha = true,
                        name = L["Color"],
                        --desc = L["Color"],
                        disabled = "isSectionDisabled",
                        set = "setSectionColor",
                        get = "getSectionColor",
                        width = 'half',
                        order = 20,
                    },
                },
            },
            srSection = {
                type = 'group',
                disabled = "isUnitDisabled",
                name = L["Short range section"],
                --desc = L["Short range section"],
                guiInline = true,
                order = 170,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "", -- L["Enabled"],
                        desc = L["Enable this color section"],
                        set = "setSectionOption",
                        get = "getSectionOption",
                        width = 'half',
                        order = 10,
                    },
                    color = {
                        type = 'color',
                        hasAlpha = true,
                        name = L["Color"],
                        --desc = L["Color"],
                        disabled = "isSectionDisabled",
                        set = "setSectionColor",
                        get = "getSectionColor",
                        width = 'half',
                        order = 20,
                    },
                    range = {
                        type = 'range',
                        name = L["Range limit"],
                        --desc = L["Range limit"],
                        disabled = "isSectionDisabled",
                        set = "setSectionOption",
                        get = "getSectionOption",
                        min = MinRangeLimit,
                        max = MaxRangeLimit,
                        step = 1,
                        order = 30,
                    },
                },
            },
            mrSection = {
                type = 'group',
                disabled = "isUnitDisabled",
                name = L["Medium range section"],
                --desc = L["Medium range section"],
                guiInline = true,
                order = 173,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "", -- L["Enabled"],
                        desc = L["Enable this color section"],
                        set = "setSectionOption",
                        get = "getSectionOption",
                        width = 'half',
                        order = 10,
                    },
                    color = {
                        type = 'color',
                        hasAlpha = true,
                        name = L["Color"],
                        --desc = L["Color"],
                        disabled = "isSectionDisabled",
                        set = "setSectionColor",
                        get = "getSectionColor",
                        width = 'half',
                        order = 20,
                    },
                    range = {
                        type = 'range',
                        name = L["Range limit"],
                        --desc = L["Range limit"],
                        disabled = "isSectionDisabled",
                        set = "setSectionOption",
                        get = "getSectionOption",
                        min = MinRangeLimit,
                        max = MaxRangeLimit,
                        step = 1,
                        order = 30,
                    },
                },
            },
            oorSection = {
                type = 'group',
                disabled = "isUnitDisabled",
                name = L["Out of range section"],
                --desc = L["Out of range section"],
                guiInline = true,
                order = 175,
                args = {
                    enabled = {
                        type = 'toggle',
                        name = "", -- L["Enabled"],
                        desc = L["Enable this color section"],
                        set = "setSectionOption",
                        get = "getSectionOption",
                        width = 'half',
                        order = 10,
                    },
                    color = {
                        type = 'color',
                        hasAlpha = true,
                        name = L["Color"],
                        --desc = L["Color"],
                        disabled = "isSectionDisabled",
                        set = "setSectionColor",
                        get = "getSectionColor",
                        width = 'half',
                        order = 20,
                    },
                    range = {
                        type = 'range',
                        name = L["Range limit"],
                        --desc = L["Range limit"],
                        disabled = "isSectionDisabled",
                        set = "setSectionOption",
                        get = "getSectionOption",
                        min = MinRangeLimit,
                        max = MaxRangeLimit,
                        step = 1,
                        order = 30,
                    },
                },
            },
            autoAdjust = {
                type = 'execute',
                disabled = "isUnitDisabled",
                name = L["Auto adjust"],
                width = 'full',
                func = function()
                    ud:autoAdjust()
                end,
                order = 185,
            },
            suffix = {
                type = 'input',
                disabled = "isUnitDisabled",
                name = L["Suffix"],
                desc = L["A free-form suffix to append to the range display when you are in range"],
                order = 190,
            },
            oorSuffix = {
                type = 'input',
                disabled = "isUnitDisabled",
                name = L["Out of range suffix"],
                desc = L["A free-form suffix to append to the range display when you are out of range"],
                order = 195,
            },
            strata = {
                type = 'select',
                disabled = "isUnitDisabled",
                name = L["Strata"],
                desc = L["Frame strata"],
                values = FrameStratas,
                order = 200,
            },
        },
    }
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
        ud.rangeFrameText:SetTextColor(r, g, b, a)
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

local function isUnitDisabled(ud, info)
    return not ud.db.enabled
end

local function isSectionDisabled(ud, info)
    return (not ud.db.enabled) or (not ud.db[info[#info - 1]].enabled)
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

function RangeDisplay:toggleLocked(flag)
    if (flag == nil) then flag = not self.db.profile.locked end
    if (flag == not self.db.profile.locked) then
        self.db.profile.locked = flag
        self:applySettings()
    end
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

