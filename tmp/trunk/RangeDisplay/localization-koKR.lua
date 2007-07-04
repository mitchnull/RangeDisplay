local L = AceLibrary("AceLocale-2.2"):new("RangeDisplay")
L:RegisterTranslations("koKR", function() return {

-- Hi, I've changed some of the lines for clarity, please check that the translation is still
-- meaningful or not (the general meaning remained in most cases)
-- I flagged these lines with "-- ###" at the end of the line.
-- Please emove these markers (and this message :) if you fix them
-- Thanks for the translations!
-- Cheers, mitch

 ["Enabled"] = "사용",
 ["Enable/Disable the mod"] = "모드를 사용하거나 사용하지 않습니다.",
 ["Locked"] = "잠금",
 ["Lock/Unlock display frame"] = "화면 프레임을 잠그거나 이동시킵니다.",
 ["Out of range display"] = "사정 거리 벗어남 표시", -- ### 
 ["Show/Hide display if the target is out of range"] = "대상이 사정 거리를 벗어날 경우 최대 체크 거리를 표시합니다. 그렇지 않으면 화면에서 숨김니다.", -- ###
 ["Check visibility"] = "눈에 보이는 범위 체크",
 ["If set, the max range to check will be 'visibility range'"] = "만약 설정시, 최대 범위는 '눈에 보이는 범위'입니다.", -- ###
-- ["Font"] = true,
-- ["Default"] = true,
 ["Font size"] = "글꼴 크기",
-- ["Font outline"] = true,
-- ["None"] = true,
-- ["Normal"] = true,
-- ["Thick"] = true,
-- ["Color"] = true,
 ["Reset"] = "초기화",
 ["Restore default settings"] = "기본 설정값으로 초기화 합니다.",
 ["RangeDisplay"] = "RangeDisplay",
-- ["Either Waterfall or Dewdrop is needed for this option"] = true,
-- ["Dewdrop is needed for this option"] = true,
-- ["Waterfall is needed for this option"] = true,
-- ["%s loaded. Type /rangedisplay for help"] = true,

} end)

