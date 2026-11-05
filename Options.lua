-- Tentoesframes 1.1.1: Compact, content-aware Simple / Advanced settings layout.
local _, TTF = ...
local panel, refreshers = nil, {}
local paletteIndex, selectedProfile = 1, 1

local function Text(parent, string, x, y, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    text:SetText(string)
    return text
end

local function Button(parent, name, x, y, w, h, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    b:SetSize(w, h)
    b:SetText(name)
    b:SetScript("OnClick", callback)
    return b
end

local function RefreshWith(fn)
    refreshers[#refreshers+1] = fn
    fn()
end

local function Header(parent, string, x, y)
    return Text(parent, string, x, y, "GameFontHighlightLarge")
end

local function Checkbox(parent, caption, key, x, y)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    local label = Text(parent, caption, x + 28, y + 3)
    c:SetScript("OnClick", function(self) TTF:Set(key, not not self:GetChecked()) end)
    RefreshWith(function() c:SetChecked(TTF.db[key]) end)
    return c, label
end

local function Stepper(parent, caption, key, step, x, y, format)
    Text(parent, caption, x, y+3)
    local val = Text(parent, "", x+199, y+3)
    val:SetWidth(51)
    val:SetJustifyH("CENTER")
    Button(parent, "-", x+167, y, 27, 22, function()
        TTF:Set(key, math.floor((TTF.db[key]-step)*1000+0.5)/1000)
    end)
    Button(parent, "+", x+251, y, 27, 22, function()
        TTF:Set(key, math.floor((TTF.db[key]+step)*1000+0.5)/1000)
    end)
    RefreshWith(function()
        local n = TTF.db[key]
        val:SetText(format and format(n) or tostring(n))
    end)
end

local function Choice(parent, caption, key, options, x, y)
    Text(parent, caption, x, y+3)
    local value = Text(parent, "", x+177, y+3)
    value:SetWidth(73)
    value:SetJustifyH("CENTER")
    local function cycle(delta)
        local index = 1
        for i, v in ipairs(options) do if v == TTF.db[key] then index=i break end end
        TTF:Set(key, options[(index - 1 + delta + #options) % #options + 1])
    end
    Button(parent, "<", x+147, y, 26, 22, function() cycle(-1) end)
    Button(parent, ">", x+252, y, 26, 22, function() cycle(1) end)
    RefreshWith(function() value:SetText(TTF.db[key]) end)
end

local function ColorRow(parent, label, key, x, y)
    Text(parent, label, x, y+3)
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(47, 23)
    swatch:SetPoint("TOPLEFT", parent, "TOPLEFT", x+160, -y)
    swatch:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    swatch:SetBackdropBorderColor(0,0,0,1)
    local function Pick()
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local old = TTF.Clone(TTF.db[key])
        local color = TTF.db[key]
        ColorPickerFrame:SetupColorPickerAndShow({
            r=color[1], g=color[2], b=color[3], hasOpacity=false,
            swatchFunc=function() TTF:Set(key, {ColorPickerFrame:GetColorRGB()}) end,
            cancelFunc=function() TTF:Set(key, old) end,
        })
    end
    swatch:SetScript("OnClick", Pick)
    Button(parent, "Edit", x+213, y, 62, 23, Pick)
    RefreshWith(function()
        local c = TTF.db[key]
        swatch:SetBackdropColor(c[1], c[2], c[3], 1)
    end)
end

local function Edit(parent, x, y, width, maxLetters)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    e:SetSize(width, 23)
    e:SetAutoFocus(false)
    e:SetMaxLetters(maxLetters or 2048)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

function TTF:RefreshOptions()
    if not panel then return end
    local db = self.db
    for _, refresh in ipairs(refreshers) do refresh() end
    -- Content-aware layout: no reserved blank space for collapsed controls.
    local extra = db.secondaryEnabled and 70 or 0
    panel.secondaryDetails:SetShown(db.secondaryEnabled)
    local paletteTop = 320 + extra
    local switchTop = paletteTop + 123
    local advancedTop = switchTop + 38
    panel.paletteBlock:ClearAllPoints()
    panel.paletteBlock:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 20, -paletteTop)
    panel.advancedSwitch:ClearAllPoints()
    panel.advancedSwitch:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 20, -switchTop)
    panel.advancedSwitchLabel:ClearAllPoints()
    panel.advancedSwitchLabel:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 49, -(switchTop + 3))
    panel.advancedDetails:ClearAllPoints()
    panel.advancedDetails:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 20, -advancedTop)
    panel.advancedDetails:SetShown(db.advancedUI)
    panel.flashOptions:SetShown(db.flashEnabled)
    panel.glowOptions:SetShown(db.glowEnabled)

    -- The right column grows only when glow controls are enabled.
    local frameTop = db.glowEnabled and 244 or 79
    panel.frameOptions:ClearAllPoints()
    panel.frameOptions:SetPoint("TOPLEFT", panel.advancedDetails, "TOPLEFT", 290, -frameTop)
    -- Both columns must finish before Profiles & Sharing begins.
    local profileTop = math.max(351, frameTop + 205)
    panel.profileSection:ClearAllPoints()
    panel.profileSection:SetPoint("TOPLEFT", panel.advancedDetails, "TOPLEFT", 0, -profileTop)
    local contentHeight = db.advancedUI and (advancedTop + profileTop + 304) or (switchTop + 45)
    panel.content:SetHeight(contentHeight)
    -- If the user collapses Advanced while scrolled to the bottom, avoid
    -- showing an empty scroll viewport below the Simple settings.
    if panel.scroll and panel.scroll.GetVerticalScroll and panel.scroll.SetVerticalScroll then
        local maxScroll = math.max(0, contentHeight - panel.scroll:GetHeight())
        if panel.scroll:GetVerticalScroll() > maxScroll then
            panel.scroll:SetVerticalScroll(maxScroll)
        end
    end
    if panel.styleInfo then
        panel.styleInfo:SetText("Preview: " .. db.style .. (db.secondaryEnabled and "  |  Two colors" or "  |  One color"))
    end
    if panel.profileSelected then
        local names = self:ProfileNames()
        if #names == 0 then
            selectedProfile = 1
            panel.profileSelected:SetText("No saved profiles")
        else
            selectedProfile = (selectedProfile - 1) % #names + 1
            panel.profileSelected:SetText(names[selectedProfile] .. " (" .. selectedProfile .. "/" .. #names .. ")")
        end
    end
end

local function BuildPanel()
    local f = CreateFrame("Frame", "TentoesframesOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    f:Hide() -- An unfinished frame never opens as a grey modal.
    f:SetSize(650, 548)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local title = f.TitleText or f.title
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", f, "TOP", 0, -7)
    end
    title:SetText("Tentoesframes  |  Raid Target Highlights  v1.1.1")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 48)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(594, 490)
    scroll:SetScrollChild(content)
    f.content = content
    f.scroll = scroll

    Header(content, "Selected-player preview", 20, 10)
    local preview = CreateFrame("Frame", nil, content, "BackdropTemplate")
    preview:SetSize(212, 34)
    preview:SetPoint("TOPLEFT", content, "TOPLEFT", 201, -23)
    preview:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    preview:SetBackdropColor(0.12,0.15,0.20,1)
    preview:SetBackdropBorderColor(0.27,0.32,0.36,1)
    local sampleName = preview:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    sampleName:SetPoint("CENTER",preview,"CENTER",0,0)
    sampleName:SetText("Selected Raid Member")
    TTF.previewFrame = preview
    f.styleInfo = Text(content,"",20,67,"GameFontHighlightSmall")

    Checkbox(content,"Enable Tentoesframes","enabled",20,88)
    Header(content,"Quick Setup",20,125)
    Choice(content,"Border style","style",TTF.STYLES,20,158)
    Stepper(content,"Border thickness","thickness",1,20,193)
    ColorRow(content,"Primary color","primary",20,228)
    Checkbox(content,"Enable secondary color","secondaryEnabled",20,266)

    local second = CreateFrame("Frame", nil, content)
    second:SetSize(280,68)
    second:SetPoint("TOPLEFT",content,"TOPLEFT",20,-298)
    ColorRow(second,"Secondary color","secondary",0,0)
    Stepper(second,"Secondary opacity","secondaryOpacity",0.05,0,34,
        function(n) return math.floor(n*100+0.5).."%" end)
    f.secondaryDetails = second

    Header(content,"Visibility",306,125)
    Checkbox(content,"Tint Blizzard target highlight","tintBlizzardHighlight",306,159)
    Checkbox(content,"Flash on new target","flashEnabled",306,199)
    local flash = CreateFrame("Frame",nil,content)
    flash:SetSize(284,70)
    flash:SetPoint("TOPLEFT",content,"TOPLEFT",306,-237)
    Stepper(flash,"Flash duration","flashDuration",0.1,0,0,
        function(n) return string.format("%.2fs",n) end)
    Stepper(flash,"Flash intensity","flashStrength",0.05,0,36,
        function(n) return math.floor(n*100+0.5).."%" end)
    f.flashOptions = flash

    local palette = CreateFrame("Frame",nil,content)
    palette:SetSize(565,116)
    Header(palette,"High Contrast Color Presets",0,0)
    Text(palette,"Arrow buttons apply colors immediately:",0,31,"GameFontHighlightSmall")
    local paletteLabel = Text(palette,"",35,65)
    paletteLabel:SetWidth(180)
    Button(palette,"<",0,60,28,24,function()
        paletteIndex = (paletteIndex-2+#TTF.PALETTES) % #TTF.PALETTES + 1
        TTF:ApplyPalette(paletteIndex)
    end)
    Button(palette,">",222,60,28,24,function()
        paletteIndex = paletteIndex % #TTF.PALETTES + 1
        TTF:ApplyPalette(paletteIndex)
    end)
    RefreshWith(function() paletteLabel:SetText(TTF.PALETTES[paletteIndex].name) end)
    Text(palette,"Secondary colors remain optional.",0,95,"GameFontHighlightSmall")
    f.paletteBlock = palette

    local advancedSwitch = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    advancedSwitch:SetSize(24,24)
    f.advancedSwitchLabel = Text(content,"Show advanced options and profiles",49,446)
    advancedSwitch:SetScript("OnClick",function(self) TTF:Set("advancedUI",not not self:GetChecked()) end)
    RefreshWith(function() advancedSwitch:SetChecked(TTF.db.advancedUI) end)
    f.advancedSwitch = advancedSwitch

    local advanced = CreateFrame("Frame",nil,content)
    advanced:SetSize(574,760)
    f.advancedDetails = advanced
    Header(advanced,"Detailed Border Controls",0,0)
    Stepper(advanced,"Outside spacing","padding",1,0,37)
    Stepper(advanced,"Stripe / dot count","density",1,0,73)
    Stepper(advanced,"Bracket length","cornerLength",2,0,109)
    Stepper(advanced,"Border opacity","opacity",0.05,0,145,
        function(n) return math.floor(n*100+0.5).."%" end)
    Checkbox(advanced,"Add corner accents","cornerAccents",0,184)
    Choice(advanced,"Side marker","markerPosition",TTF.MARKERS,0,225)
    Checkbox(advanced,"Show TARGET label","labelEnabled",0,265)
    Choice(advanced,"Label position","labelPosition",TTF.LABEL_POSITIONS,0,303)

    Header(advanced,"Glow & Animation",290,0)
    Checkbox(advanced,"Enable glow","glowEnabled",290,37)
    local glow = CreateFrame("Frame",nil,advanced)
    glow:SetSize(281,163)
    glow:SetPoint("TOPLEFT", advanced, "TOPLEFT",290,-73)
    ColorRow(glow,"Glow color","glow",0,0)
    Stepper(glow,"Glow size","glowSize",1,0,34)
    Stepper(glow,"Glow intensity","glowAlpha",0.05,0,68,
        function(n) return math.floor(n*100+0.5).."%" end)
    Checkbox(glow,"Pulse glow","pulseEnabled",0,107)
    Stepper(glow,"Pulse speed","pulseSpeed",0.25,0,139,
        function(n) return string.format("%.2fx",n) end)
    f.glowOptions = glow

    local frames = CreateFrame("Frame",nil,advanced)
    frames:SetSize(281,187)
    Header(frames,"Blizzard Frame Support",0,0)
    Checkbox(frames,"Flat raid frames","showRaid",0,32)
    Checkbox(frames,"Grouped raid frames","showGroups",0,64)
    Checkbox(frames,"Party frames","showParty",0,96)
    Checkbox(frames,"Pet frames (if supported)","showPets",0,128)
    Checkbox(frames,"Only when grouped","onlyInGroups",0,160)
    f.frameOptions = frames

    -- Profiles always starts immediately after the longer advanced column.
    -- Position is recalculated when Glow is enabled or disabled.
    local profiles = CreateFrame("Frame",nil,advanced)
    profiles:SetSize(568,291)
    f.profileSection = profiles
    Header(profiles,"Profiles & Sharing",0,0)
    Text(profiles,"Profile name (1-24 characters)",0,34,"GameFontHighlightSmall")
    local nameInput = Edit(profiles,0,57,188,24)
    f.profileNameInput = nameInput
    local status = Text(profiles,"",0,268,"GameFontHighlightSmall")
    status:SetWidth(552)
    f.profileStatus = status
    local function Message(ok, msg) status:SetText((ok and "Success: " or "Error: ")..msg) end
    Button(profiles,"Save",198,55,68,25,function()
        local ok,msg=TTF:SaveProfile(nameInput:GetText())
        Message(ok,msg)
    end)
    Button(profiles,"Load",271,55,68,25,function()
        local ok,msg=TTF:LoadProfile(nameInput:GetText())
        Message(ok,msg)
    end)
    Button(profiles,"Delete",344,55,81,25,function()
        local ok,msg=TTF:DeleteProfile(nameInput:GetText())
        Message(ok,msg)
    end)
    local chosen = Text(profiles,"",40,103)
    chosen:SetWidth(214)
    f.profileSelected = chosen
    local function CycleProfile(delta)
        local names=TTF:ProfileNames()
        if #names == 0 then return end
        selectedProfile = (selectedProfile-1+delta+#names) % #names + 1
        TTF:RefreshOptions()
    end
    Button(profiles,"<",0,99,28,24,function() CycleProfile(-1) end)
    Button(profiles,">",257,99,28,24,function() CycleProfile(1) end)
    Button(profiles,"Load selected",303,99,122,24,function()
        local names=TTF:ProfileNames()
        if #names > 0 then
            local ok,msg=TTF:LoadProfile(names[selectedProfile])
            nameInput:SetText(names[selectedProfile])
            Message(ok,msg)
        end
    end)

    Text(profiles,"Export current appearance (select and copy):",0,140,"GameFontHighlightSmall")
    local exportInput = Edit(profiles,0,161,439,2048)
    f.exportInput = exportInput
    Button(profiles,"Generate",448,159,108,25,function()
        exportInput:SetText(TTF:ExportProfile())
        exportInput:SetFocus()
        exportInput:HighlightText()
        Message(true,"Share code ready to copy (Ctrl+C).")
    end)

    Text(profiles,"Import shared appearance (paste and apply):",0,203,"GameFontHighlightSmall")
    local importInput = Edit(profiles,0,225,439,2048)
    f.importInput = importInput
    Button(profiles,"Import",448,223,108,25,function()
        local ok,msg=TTF:ImportProfile(importInput:GetText())
        Message(ok,msg)
    end)

    Button(f,"Reset appearance",20,505,145,27,function()
        TTF:Reset()
        if f.profileStatus then f.profileStatus:SetText("Original one-color green defaults restored.") end
    end)
    Button(f,"Close",514,505,114,27,function() f:Hide() end)

    panel = f
    table.insert(UISpecialFrames,"TentoesframesOptionsFrame")
    f:SetScript("OnShow",function() TTF:RefreshOptions() TTF:RefreshAll() end)
    TTF:RefreshOptions()
    return f
end

function TTF:ToggleOptions()
    if not self.db then return end
    local window = panel or BuildPanel()
    window:SetShown(not window:IsShown())
end
