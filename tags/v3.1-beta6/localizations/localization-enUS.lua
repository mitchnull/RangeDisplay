local L = LibStub("AceLocale-3.0"):NewLocale("RangeDisplay", "enUS", true)
if not L then return end
        
L["Locked"] = true
L["Lock/Unlock display frame"] = true
L["Range limit"] = true
L["Ranges above this are not reported"] = true
L["Over limit display"] = true
L["Show/Hide display if the target is further than range limit"] = true
L["Check visibility"] = true
L["If set, the max range to check will be 'visibility range'"] = true
L["Max range only"] = true
L["Show the maximum range only"] = true
L["Font"] = true
L["Default"] = true
L["Font size"] = true
L["Font outline"] = true
L["None"] = true
L["Normal"] = true
L["Thick"] = true
L["Color"] = true
L["Default section"] = true
L["Out of range section"] = true
L["Medium range section"] = true
L["Short range section"] = true
L["Close range section"] = true
L["Enable this color section"] = true
L["Range limit"] = true
L["Auto adjust"] = true
L["%s loaded. Type /rangedisplay for help"] = true
L["Enemy only"] = true
L["Show range for enemy targets only"] = true
L["Strata"] = true
L["Frame strata"] = true
L["High"] = true
L["Medium"] = true
L["Low"] = true
L["Configure"] = true
L["Bring up GUI configure dialog"] = true
L["Suffix"] = true
L["A free-form suffix to append to the range display when you are in range"] = true
L["Over limit suffix"] = true
L["A free-form suffix to append to the range display when you are further than range limit"] = true

L["Range Display"] = true
L["Estimated range display"] = true
L["Enabled"] = true

L["|cffeda55fLeft Click|r to lock/unlock frames"] = true
L["|cffeda55fRight Click|r to open the configuration window"] = true
L["Hide minimap icon"] = true

L["RangeDisplay: %s"] = true -- %s will be Target, Focus, etc
L["|cffeda55fControl + Left Click|r to lock frames"] = true
L["|cffeda55fDrag|r to move the frame"] = true

L["playertarget"] = "Target"
L["focus"] = "Focus"
L["pet"] = "Pet"
