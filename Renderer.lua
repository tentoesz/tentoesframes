-- Tentoesframes 1.1: cached layout renderer, on-demand texture pool, short target flash.
-- Regions are allocated only outside combat. The default Solid mode needs four.
local _, TTF = ...
local min, max, sin, pi = math.min, math.max, math.sin, math.pi
local overlays = setmetatable({}, { __mode = "k" })
local savedTints = setmetatable({}, { __mode = "k" })
local clock, driver, elapsedSinceTick = 0, nil, 0

local function Combat() return InCombatLockdown and InCombatLockdown() end
local function Secret(v) return issecretvalue and issecretvalue(v) end

local function FrameKind(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return nil end
    local name = frame:GetName()
    if type(name) ~= "string" or Secret(name) then return nil end
    if name:match("^CompactRaidFrame%d+$") then return "showRaid" end
    if name:match("^CompactRaidGroup%d+Member%d+$") then return "showGroups" end
    if name:match("^CompactPartyFrameMember%d+$") then return "showParty" end
    if name:match("^CompactPartyFramePet%d+$") or name:match("^CompactPartyFrameMember%d+Pet$") or
       name:match("^CompactRaidFramePet%d+$") or name:match("^CompactRaidFrame%d+Pet$") or
       name:match("^CompactRaidGroup%d+Pet%d+$") or
       name:match("^CompactRaidGroup%d+Member%d+Pet$") then return "showPets" end
    return nil
end
TTF.FrameKind = FrameKind

local function TintBlizzard(frame, db, showOnFrame)
    local hl = frame.selectionHighlight
    if not hl or (hl.IsForbidden and hl:IsForbidden()) then return end
    if showOnFrame and db.tintBlizzardHighlight then
        if not savedTints[hl] then
            local r, g, b, a = 1, 1, 1, 1
            if hl.GetVertexColor then
                local cr, cg, cb, ca = hl:GetVertexColor()
                if not (Secret(cr) or Secret(cg) or Secret(cb) or Secret(ca)) and
                    type(cr) == "number" and type(cg) == "number" and
                    type(cb) == "number" and type(ca) == "number" then
                    r, g, b, a = cr, cg, cb, ca
                end
            end
            savedTints[hl] = { r, g, b, a }
        end
        hl:SetVertexColor(db.primary[1], db.primary[2], db.primary[3], 1)
    elseif savedTints[hl] then
        local c = savedTints[hl]
        hl:SetVertexColor(c[1], c[2], c[3], c[4])
        savedTints[hl] = nil
    end
end

local function Required(db)
    if db.thickness == 0 then return 0 end
    local style = db.style
    local count = 4
    if style == "Zebra" or style == "Dashed" or style == "Dotted" or style == "Ticks" then
        count = db.density * 4
    elseif style == "Double" or style == "Brackets" or style == "Neon" or style == "Rail" then
        count = 8
    elseif style == "Bars" then
        count = 2
    elseif style == "Corner Dots" then
        count = 4
    end
    if db.glowEnabled then count = count + 4 end
    if db.cornerAccents and style ~= "Brackets" and style ~= "Corner Dots" then count = count + 4 end
    if db.markerPosition ~= "Off" then count = count + 1 end
    if db.flashEnabled then count = count + 4 end
    return count
end
TTF.RequiredRegions = Required

local function NewTexture(frame)
    local t = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetColorTexture(1, 1, 1, 1)
    t:Hide()
    return t
end

local function EnsureCapacity(ov, count)
    if count <= #ov.pool then return true end
    if Combat() then return false end
    for i = #ov.pool + 1, count do ov.pool[i] = NewTexture(ov.frame) end
    return true
end

local function OverlayFor(frame, db)
    local ov = overlays[frame]
    if not ov then
        if Combat() then return nil end
        ov = { frame = frame, pool = {}, used = 0, active = false, glowParts = {}, flashParts = {} }
        overlays[frame] = ov
        frame:HookScript("OnSizeChanged", function(self)
            local o = overlays[self]
            if o then o.version = nil end
            if TTF.db then TTF:UpdateFrame(self) end
        end)
        frame:HookScript("OnShow", function(self)
            if TTF.db then TTF:UpdateFrame(self) end
        end)
        frame:HookScript("OnHide", function(self)
            local o = overlays[self]
            if o then TTF:HideOverlay(o) end
        end)
    end
    EnsureCapacity(ov, Required(db))
    if db.labelEnabled and not ov.label and not Combat() then
        ov.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ov.label:Hide()
    end
    return ov
end

function TTF:HideOverlay(ov)
    for i = 1, ov.used do ov.pool[i]:Hide() end
    if ov.label then ov.label:Hide() end
    ov.active, ov.used, ov.flashUntil = false, 0, nil
end

local function Draw(ov, x, y, w, h, color, alpha, category)
    if w <= 0 or h <= 0 then return end
    local region = ov.pool[ov.used + 1]
    if not region then return end
    ov.used = ov.used + 1
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", ov.frame, "TOPLEFT", x, -y)
    region:SetSize(w, h)
    region:SetColorTexture(color[1], color[2], color[3], alpha)
    region:SetAlpha(1)
    region:Show()
    if category == "glow" then ov.glowParts[#ov.glowParts + 1] = region end
    if category == "flash" then ov.flashParts[#ov.flashParts + 1] = region end
end

local function Outline(ov, x, y, w, h, thick, color, opacity, category)
    thick = min(thick, w / 2, h / 2)
    if thick <= 0 then return end
    Draw(ov, x, y, w, thick, color, opacity, category)
    Draw(ov, x, y + h - thick, w, thick, color, opacity, category)
    Draw(ov, x, y + thick, thick, h - 2 * thick, color, opacity, category)
    Draw(ov, x + w - thick, y + thick, thick, h - 2 * thick, color, opacity, category)
end

local function Segments(ov, x, y, w, h, thick, count, style, db, opacity)
    for i = 1, count do
        local a, b = (i - 1) / count, i / count
        local slotX, slotY = w / count, h / count
        local fraction = style == "Dashed" and 0.65 or style == "Dotted" and 0.23 or
                         style == "Ticks" and 0.12 or 1
        local twoTone = style == "Zebra" and db.secondaryEnabled and i % 2 == 0
        local color = twoTone and db.secondary or db.primary
        local alpha = twoTone and opacity * db.secondaryOpacity or opacity
        if style == "Dotted" or style == "Ticks" then
            local ww = style == "Dotted" and min(thick, slotX * 0.5) or min(slotX * 0.65, thick * 2)
            local hh = style == "Dotted" and min(thick, slotY * 0.5) or min(slotY * 0.65, thick * 2)
            Draw(ov, x + w * (a+b)/2 - ww/2, y, ww, thick, color, alpha)
            Draw(ov, x + w * (a+b)/2 - ww/2, y+h-thick, ww, thick, color, alpha)
            Draw(ov, x, y+h * (a+b)/2 - hh/2, thick, hh, color, alpha)
            Draw(ov, x+w-thick, y+h * (a+b)/2 - hh/2, thick, hh, color, alpha)
        else
            local insetX, insetY = slotX * (1-fraction)/2, slotY * (1-fraction)/2
            Draw(ov, x + a*w + insetX, y, slotX*fraction, thick, color, alpha)
            Draw(ov, x + a*w + insetX, y+h-thick, slotX*fraction, thick, color, alpha)
            Draw(ov, x, y + a*h + insetY, thick, slotY*fraction, color, alpha)
            Draw(ov, x+w-thick, y + a*h + insetY, thick, slotY*fraction, color, alpha)
        end
    end
end

local function Brackets(ov, x, y, w, h, t, span, color, alpha)
    local sx, sy = min(span, w/2), min(span, h/2)
    Draw(ov, x, y, sx, t, color, alpha)
    Draw(ov, x+w-sx, y, sx, t, color, alpha)
    Draw(ov, x, y+h-t, sx, t, color, alpha)
    Draw(ov, x+w-sx, y+h-t, sx, t, color, alpha)
    Draw(ov, x, y, t, sy, color, alpha)
    Draw(ov, x+w-t, y, t, sy, color, alpha)
    Draw(ov, x, y+h-sy, t, sy, color, alpha)
    Draw(ov, x+w-t, y+h-sy, t, sy, color, alpha)
end

local function Label(ov, x, y, h, db)
    if not db.labelEnabled or not ov.label then
        if ov.label then ov.label:Hide() end
        return
    end
    ov.label:ClearAllPoints()
    if db.labelPosition == "Bottom" then
        ov.label:SetPoint("TOP", ov.frame, "TOP", 0, -y-h-3)
    else
        ov.label:SetPoint("BOTTOM", ov.frame, "TOP", 0, 5-y)
    end
    ov.label:SetText("TARGET")
    ov.label:SetTextColor(db.primary[1], db.primary[2], db.primary[3], 1)
    ov.label:Show()
end

function TTF:RenderFrame(frame, ov, preview)
    local db = self.db
    local w0, h0 = frame:GetWidth(), frame:GetHeight()
    if Secret(w0) or Secret(h0) or type(w0) ~= "number" or type(h0) ~= "number" or
        w0 < 8 or h0 < 8 then return end
    local required = Required(db)
    local hasCapacity = EnsureCapacity(ov, required)
    -- Changing to a region-heavy style during combat degrades to Solid safely;
    -- outside combat (on regen) the requested style is restored automatically.
    local fallback = not hasCapacity
    local t, pad = db.thickness, db.padding
    local x, y, w, h = -pad, -pad, w0 + 2*pad, h0 + 2*pad
    local alpha, first = db.opacity, db.primary
    local second = db.secondaryEnabled and db.secondary or first
    local secondAlpha = db.secondaryEnabled and alpha * db.secondaryOpacity or alpha
    local justActivated = not ov.active
    self:HideOverlay(ov)
    ov.glowParts, ov.flashParts = {}, {}
    if t > 0 then
        if fallback then
            Outline(ov, x, y, w, h, t, first, alpha)
        else
            if db.glowEnabled then
                local outer = db.glowSize
                Outline(ov, x-outer/2, y-outer/2, w+outer, h+outer,
                    t+outer, db.glow, db.glowAlpha, "glow")
            end
            local style = db.style
            if style == "Solid" then
                Outline(ov, x, y, w, h, t, first, alpha)
            elseif style == "Zebra" or style == "Dashed" or style == "Dotted" or style == "Ticks" then
                Segments(ov, x, y, w, h, t, db.density, style, db, alpha)
            elseif style == "Double" then
                Outline(ov, x, y, w, h, t, first, alpha)
                local inset = t + 2
                Outline(ov, x+inset, y+inset, w-2*inset, h-2*inset, max(1, t-1), second, secondAlpha)
            elseif style == "Brackets" then
                Brackets(ov, x, y, w, h, t, db.cornerLength, first, alpha)
            elseif style == "Neon" then
                Outline(ov, x, y, w, h, t+1, first, alpha)
                Outline(ov, x+t+1, y+t+1, w-2*(t+1), h-2*(t+1), 1, second, secondAlpha)
            elseif style == "Bars" then
                Draw(ov, x, y, w, t, first, alpha)
                Draw(ov, x, y+h-t, w, t, second, secondAlpha)
            elseif style == "Rail" then
                Outline(ov, x, y, w, h, max(1, t-1), first, alpha)
                Outline(ov, x+t+3, y+t+3, w-2*(t+3), h-2*(t+3), 1, second, secondAlpha)
            elseif style == "Corner Dots" then
                local dot = max(5, t*2)
                Draw(ov, x, y, dot, dot, first, alpha)
                Draw(ov, x+w-dot, y, dot, dot, second, secondAlpha)
                Draw(ov, x, y+h-dot, dot, dot, second, secondAlpha)
                Draw(ov, x+w-dot, y+h-dot, dot, dot, first, alpha)
            elseif style == "Split" then
                Draw(ov, x, y, w, t, first, alpha)
                Draw(ov, x, y+t, t, h-2*t, first, alpha)
                Draw(ov, x, y+h-t, w, t, second, secondAlpha)
                Draw(ov, x+w-t, y+t, t, h-2*t, second, secondAlpha)
            end
            if db.cornerAccents and style ~= "Brackets" and style ~= "Corner Dots" then
                local c = max(3, t+2)
                Draw(ov, x, y, c, c, second, secondAlpha)
                Draw(ov, x+w-c, y, c, c, second, secondAlpha)
                Draw(ov, x, y+h-c, c, c, second, secondAlpha)
                Draw(ov, x+w-c, y+h-c, c, c, second, secondAlpha)
            end
            if db.markerPosition ~= "Off" then
                local mw, mh = max(7, t*3), max(5, t*2)
                if db.markerPosition == "Left" then
                    Draw(ov, x-mw, y+(h-mh)/2, mw, mh, first, alpha)
                elseif db.markerPosition == "Right" then
                    Draw(ov, x+w, y+(h-mh)/2, mw, mh, first, alpha)
                else
                    Draw(ov, x+(w-mw)/2, y-mh, mw, mh, first, alpha)
                end
            end
            if db.flashEnabled then
                local white = { 1, 1, 1 }
                Outline(ov, x, y, w, h, t, white, db.flashStrength, "flash")
            end
        end
    end
    Label(ov, x, y, h, db)
    ov.active, ov.version = true, (hasCapacity and self.changeVersion or nil)
    if justActivated and not preview and db.flashEnabled and #ov.flashParts > 0 then
        ov.flashUntil = clock + db.flashDuration
    end
    self:AnimateOverlay(ov)
    self:UpdateAnimationDriver()
end

function TTF:AnimateOverlay(ov)
    if not ov.active then return end
    local db = self.db
    local pulse = (db.glowEnabled and db.pulseEnabled) and
        (0.58 + 0.42*(0.5 + 0.5*sin(clock*pi*2*db.pulseSpeed))) or 1
    for _, t in ipairs(ov.glowParts) do t:SetAlpha(pulse) end
    local strength = 0
    if ov.flashUntil and db.flashEnabled and clock < ov.flashUntil then
        strength = (ov.flashUntil - clock) / db.flashDuration
    else
        ov.flashUntil = nil
    end
    for _, t in ipairs(ov.flashParts) do t:SetAlpha(strength) end
end

function TTF:UpdateAnimationDriver()
    if not driver then return end
    local hasFlash = false
    for _, ov in pairs(overlays) do
        if ov.active and ov.flashUntil then hasFlash = true break end
    end
    if hasFlash or (self.db and self.db.glowEnabled and self.db.pulseEnabled) then
        if not driver:GetScript("OnUpdate") then
            driver:SetScript("OnUpdate", function(_, elapsed)
                clock = clock + elapsed
                elapsedSinceTick = elapsedSinceTick + elapsed
                if elapsedSinceTick < 1/30 then return end
                elapsedSinceTick = 0
                for _, ov in pairs(overlays) do
                    if ov.active then TTF:AnimateOverlay(ov) end
                end
                TTF:UpdateAnimationDriver()
            end)
        end
    else
        driver:SetScript("OnUpdate", nil)
    end
end

function TTF:UpdateFrame(frame, preview)
    if not self.db then return end
    local ov = overlays[frame]
    if preview then
        if self.db.enabled then
            ov = OverlayFor(frame, self.db)
            if ov and (not ov.active or ov.version ~= self.changeVersion) then self:RenderFrame(frame, ov, true) end
        elseif ov then self:HideOverlay(ov) end
        return
    end
    local kind = FrameKind(frame)
    if not kind then return end
    local db = self.db
    local showOnFrame = db.enabled and db[kind] and
        not (db.onlyInGroups and IsInGroup and not IsInGroup())
    -- Turning a frame category off must also restore Blizzard's own tint.
    TintBlizzard(frame, db, showOnFrame)
    if not showOnFrame then
        if ov then self:HideOverlay(ov) end
        return
    end
    if frame.IsShown then
        local shown = frame:IsShown()
        if Secret(shown) or not shown then
            if ov then self:HideOverlay(ov) end
            return
        end
    end
    -- Ensure the current style's pool even for non-selected visible frames,
    -- so the NEXT target does not allocate textures during combat.
    ov = OverlayFor(frame, db)
    if not ov then return end
    local selected = false
    local hl = frame.selectionHighlight
    if hl and not (hl.IsForbidden and hl:IsForbidden()) and hl.IsShown then
        local shown = hl:IsShown()
        if not Secret(shown) then selected = shown end
    elseif UnitIsUnit then
        local unit = frame.displayedUnit or frame.unit
        if type(unit) == "string" and not Secret(unit) then
            local isTarget = UnitIsUnit(unit, "target")
            if not Secret(isTarget) then selected = isTarget end
        end
    end
    if selected then
        if not ov.active or ov.version ~= self.changeVersion then self:RenderFrame(frame, ov, false) end
    elseif ov.active then
        self:HideOverlay(ov)
    end
end

function TTF:RefreshAll()
    if not self.db then return end
    -- Always visit previously prepared frames, even if their category just
    -- got disabled, to remove stale borders immediately.
    for frame in pairs(overlays) do
        if FrameKind(frame) then self:UpdateFrame(frame) end
    end
    local function Inspect(name)
        local f = _G[name]
        if f then self:UpdateFrame(f) end
    end
    if self.db.showRaid then
        for i=1,40 do Inspect("CompactRaidFrame" .. i) end
    end
    if self.db.showGroups then
        for g=1,8 do for m=1,5 do Inspect("CompactRaidGroup"..g.."Member"..m) end end
    end
    if self.db.showParty then
        for i=1,5 do Inspect("CompactPartyFrameMember"..i) end
    end
    if self.db.showPets then
        for i=1,5 do
            Inspect("CompactPartyFramePet"..i)
            Inspect("CompactPartyFrameMember"..i.."Pet")
        end
        for i=1,40 do
            Inspect("CompactRaidFramePet"..i)
            Inspect("CompactRaidFrame"..i.."Pet")
        end
        for g=1,8 do for m=1,5 do
            Inspect("CompactRaidGroup"..g.."Pet"..m)
            Inspect("CompactRaidGroup"..g.."Member"..m.."Pet")
        end end
    end
    if self.previewFrame then self:UpdateFrame(self.previewFrame, true) end
    self:UpdateAnimationDriver()
end

function TTF:InitializeRenderer()
    if self.rendererReady then return end
    self.rendererReady = true
    if type(CompactUnitFrame_UpdateSelectionHighlight) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateSelectionHighlight", function(frame)
            if TTF.db then TTF:UpdateFrame(frame) end
        end)
    end
    driver = CreateFrame("Frame")
    self:RefreshAll()
end
