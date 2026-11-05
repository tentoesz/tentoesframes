-- Tentoesframes: selectable, visual-only highlights for Blizzard compact frames.
-- No secure action, unit targeting, or combat decisions are changed by this addon.
local addonName, TTF = ...

TTF.VERSION = "1.1.1"
TTF.STYLES = { "Solid", "Zebra", "Dashed", "Dotted", "Double", "Brackets", "Neon", "Bars", "Rail", "Ticks", "Corner Dots", "Split" }
TTF.MARKERS = { "Off", "Left", "Right", "Top" }
TTF.LABEL_POSITIONS = { "Top", "Bottom" }
TTF.PALETTES = {
    { name = "Electric Lime", primary = { 0.25, 1.00, 0.20 }, secondary = { 0.06, 0.12, 0.07 }, glow = { 0.35, 1.00, 0.25 } },
    { name = "Amber Alert", primary = { 1.00, 0.70, 0.08 }, secondary = { 0.13, 0.17, 0.39 }, glow = { 1.00, 0.49, 0.04 } },
    { name = "Magenta Flash", primary = { 1.00, 0.15, 0.72 }, secondary = { 1.00, 1.00, 1.00 }, glow = { 1.00, 0.08, 0.85 } },
    { name = "Frozen Blue", primary = { 0.20, 0.85, 1.00 }, secondary = { 0.16, 0.25, 0.80 }, glow = { 0.35, 0.88, 1.00 } },
    { name = "Crimson White", primary = { 1.00, 0.13, 0.16 }, secondary = { 1.00, 1.00, 1.00 }, glow = { 1.00, 0.21, 0.24 } },
    { name = "Black & White", primary = { 1.00, 1.00, 1.00 }, secondary = { 0.04, 0.04, 0.04 }, glow = { 0.80, 0.84, 1.00 } },
    { name = "Violet Gold", primary = { 0.68, 0.30, 1.00 }, secondary = { 1.00, 0.74, 0.05 }, glow = { 0.80, 0.42, 1.00 } },
}

local DEFAULTS = {
    -- Match the original SelectionColor on new installs AND on /ttf reset.
    enabled = true, style = "Solid", thickness = 3, padding = 0,
    density = 12, cornerLength = 18, opacity = 1,
    primary = { 0.2, 1, 0.2 }, secondary = { 0.06, 0.12, 0.07 },
    secondaryEnabled = false, secondaryOpacity = 1,
    glow = { 0.35, 1, 0.25 }, glowEnabled = false, glowSize = 6,
    glowAlpha = 0.25, pulseEnabled = false, pulseSpeed = 1.5,
    flashEnabled = false, flashDuration = 0.5, flashStrength = 0.75,
    cornerAccents = false, labelEnabled = false, labelPosition = "Top",
    markerPosition = "Off", tintBlizzardHighlight = true,
    showRaid = true, showGroups = true, showParty = true, showPets = false,
    onlyInGroups = false, advancedUI = false,
}
TTF.DEFAULTS = DEFAULTS

local LIMITS = {
    thickness = { 0, 10 }, padding = { 0, 12 }, density = { 4, 20 },
    cornerLength = { 8, 40 }, opacity = { 0.2, 1 }, secondaryOpacity = { 0.1, 1 },
    glowSize = { 2, 16 }, glowAlpha = { 0.05, 0.8 }, pulseSpeed = { 0.5, 4 },
    flashDuration = { 0.15, 1.5 }, flashStrength = { 0.2, 1 },
}

local EXPORT_KEYS = {
    "enabled", "style", "thickness", "padding", "density", "cornerLength", "opacity",
    "primary", "secondary", "secondaryEnabled", "secondaryOpacity", "glow",
    "glowEnabled", "glowSize", "glowAlpha", "pulseEnabled", "pulseSpeed",
    "flashEnabled", "flashDuration", "flashStrength", "cornerAccents",
    "labelEnabled", "labelPosition", "markerPosition", "tintBlizzardHighlight",
    "showRaid", "showGroups", "showParty", "showPets", "onlyInGroups",
}
TTF.EXPORT_KEYS = EXPORT_KEYS
local unpack = unpack or table.unpack

local function Clone(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, child in pairs(v) do c[k] = Clone(child) end
    return c
end
TTF.Clone = Clone

local function Lookup(list, needle)
    for i, value in ipairs(list) do if value == needle then return i end end
end

local function Clamp(n, lo, hi)
    return math.max(lo, math.min(hi, n))
end

function TTF:SanitizeValue(key, value)
    local default = DEFAULTS[key]
    if default == nil then return nil end
    if type(default) == "boolean" then
        return type(value) == "boolean" and value or (type(value) ~= "boolean" and default)
    elseif type(default) == "number" then
        if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return default end
        return Clamp(value, LIMITS[key][1], LIMITS[key][2])
    elseif type(default) == "string" then
        local list = key == "style" and self.STYLES or
            key == "labelPosition" and self.LABEL_POSITIONS or self.MARKERS
        return Lookup(list, value) and value or default
    elseif type(default) == "table" then
        if type(value) ~= "table" then return Clone(default) end
        local color = {}
        for i = 1, 3 do
            local channel = value[i]
            if type(channel) ~= "number" or channel ~= channel or channel == math.huge or channel == -math.huge then
                channel = default[i]
            end
            color[i] = Clamp(channel, 0, 1)
        end
        return color
    end
end

local function Snapshot(db)
    local data = {}
    for _, key in ipairs(EXPORT_KEYS) do data[key] = Clone(db[key]) end
    return data
end

local function CleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if #name == 0 or #name > 24 or not name:match("^[%w _%-]+$") then return nil end
    return name
end

local function ValidateProfiles(raw)
    local clean, count = {}, 0
    if type(raw) ~= "table" then return clean end
    for name, settings in pairs(raw) do
        if count >= 20 then break end
        local safeName = CleanName(name)
        if safeName and type(settings) == "table" then
            local profile = {}
            for _, key in ipairs(EXPORT_KEYS) do
                profile[key] = TTF:SanitizeValue(key, settings[key])
            end
            clean[safeName] = profile
            count = count + 1
        end
    end
    return clean
end

function TTF:LoadSettings()
    local previous = type(TentoesframesDB) == "table" and TentoesframesDB or {}
    local exists = next(previous) ~= nil
    -- Upgrades preserve the original user's choices, including the legacy two-tone looks.
    if exists and previous.tintBlizzardHighlight == nil then previous.tintBlizzardHighlight = false end
    if exists and previous.secondaryEnabled == nil then
        local s = previous.style
        previous.secondaryEnabled = s == "Zebra" or s == "Double" or s == "Neon" or
            s == "Bars" or previous.cornerAccents == true
    end
    for key, default in pairs(DEFAULTS) do
        previous[key] = self:SanitizeValue(key, previous[key] == nil and Clone(default) or previous[key])
    end
    previous.profiles = ValidateProfiles(previous.profiles)
    TentoesframesDB = previous
    self.db = previous
    self.changeVersion = (self.changeVersion or 0) + 1
end

function TTF:Changed()
    self.changeVersion = (self.changeVersion or 0) + 1
    if self.RefreshAll then self:RefreshAll() end
    if self.RefreshOptions then self:RefreshOptions() end
end

function TTF:Set(key, value)
    if not self.db or DEFAULTS[key] == nil then return end
    self.db[key] = self:SanitizeValue(key, value)
    self:Changed()
end

function TTF:Reset()
    if not self.db then return end
    for key, value in pairs(DEFAULTS) do self.db[key] = Clone(value) end
    -- Resetting appearance never deletes the user's named profiles.
    self:Changed()
end

function TTF:ApplyPalette(index)
    local p = self.PALETTES[index]
    if not p or not self.db then return false end
    self.db.primary, self.db.secondary, self.db.glow = Clone(p.primary), Clone(p.secondary), Clone(p.glow)
    -- The palette only changes RGB. In particular, never turn on secondary/glow.
    self:Changed()
    return true
end

function TTF:ProfileNames()
    local names = {}
    for name in pairs(self.db.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function TTF:SaveProfile(name)
    name = CleanName(name)
    if not name then return false, "Use 1-24 letters, numbers, spaces, - or _." end
    local profiles = self.db.profiles
    if not profiles[name] and #self:ProfileNames() >= 20 then return false, "Maximum 20 profiles." end
    profiles[name] = Snapshot(self.db)
    if self.RefreshOptions then self:RefreshOptions() end
    return true, "Saved profile: " .. name
end

function TTF:LoadProfile(name)
    local saved = self.db.profiles[name]
    if not saved then return false, "Profile not found." end
    for _, key in ipairs(EXPORT_KEYS) do self.db[key] = self:SanitizeValue(key, saved[key]) end
    self:Changed()
    return true, "Loaded profile: " .. name
end

function TTF:DeleteProfile(name)
    if not self.db.profiles[name] then return false, "Profile not found." end
    self.db.profiles[name] = nil
    if self.RefreshOptions then self:RefreshOptions() end
    return true, "Deleted profile: " .. name
end

-- Share code format: TTF1:<30 pipe-delimited values>:<simple checksum>.
-- Fixed-order values are type checked, there is no loadstring/eval or external library.
-- Import is atomic: invalid codes never mutate current settings.
local function PackValue(key, value)
    local kind = type(DEFAULTS[key])
    if kind == "boolean" then return value and "1" or "0" end
    if kind == "number" then return string.format("%.5f", value) end
    if kind == "string" then
        local list = key == "style" and TTF.STYLES or
            key == "labelPosition" and TTF.LABEL_POSITIONS or TTF.MARKERS
        return tostring(Lookup(list, value) or 1)
    end
    return string.format("%.5f,%.5f,%.5f", value[1], value[2], value[3])
end

local function Checksum(s)
    local sum = 0
    for i = 1, #s do sum = (sum * 31 + s:byte(i)) % 65521 end
    return string.format("%04X", sum)
end

function TTF:ExportProfile()
    if not self.db then return nil end
    local values = {}
    for _, key in ipairs(EXPORT_KEYS) do values[#values + 1] = PackValue(key, self.db[key]) end
    local payload = table.concat(values, "|")
    return "TTF1:" .. payload .. ":" .. Checksum(payload)
end

local function ReadValue(key, raw)
    local default = DEFAULTS[key]
    local kind = type(default)
    if kind == "boolean" then
        if raw ~= "0" and raw ~= "1" then return nil end
        return raw == "1"
    elseif kind == "number" then
        if not raw:match("^%-?%d+%.%d+$") then return nil end
        local n = tonumber(raw)
        if not n or n ~= n then return nil end
        local bound = LIMITS[key]
        if n < bound[1] or n > bound[2] then return nil end
        return n
    elseif kind == "string" then
        if not raw:match("^%d+$") then return nil end
        local list = key == "style" and TTF.STYLES or
            key == "labelPosition" and TTF.LABEL_POSITIONS or TTF.MARKERS
        return list[tonumber(raw)]
    else
        local r, g, b = raw:match("^(%d+%.%d+),(%d+%.%d+),(%d+%.%d+)$")
        if not r then return nil end
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if r > 1 or g > 1 or b > 1 then return nil end
        return { r, g, b }
    end
end

function TTF:ImportProfile(code)
    if not self.db or type(code) ~= "string" or #code > 2048 then return false, "Invalid share code." end
    code = code:match("^%s*(.-)%s*$")
    local payload, hash = code:match("^TTF1:(.+):(%x%x%x%x)$")
    if not payload or Checksum(payload) ~= hash then return false, "Invalid code or checksum." end
    local raw = {}
    for item in (payload .. "|"):gmatch("(.-)|") do raw[#raw + 1] = item end
    if #raw ~= #EXPORT_KEYS then return false, "Wrong share-code length." end
    local candidate = {}
    for i, key in ipairs(EXPORT_KEYS) do
        local parsed = ReadValue(key, raw[i])
        if parsed == nil then return false, "Invalid value: " .. key end
        candidate[key] = parsed
    end
    for _, key in ipairs(EXPORT_KEYS) do self.db[key] = candidate[key] end
    self:Changed()
    return true, "Shared appearance applied. Save it as a named profile if desired."
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        TTF:LoadSettings()
        TTF:InitializeRenderer()
        return
    end
    if TTF.db and TTF.RefreshAll then TTF:RefreshAll() end
end)

SLASH_TENTOESFRAMES1 = "/tentoes"
SLASH_TENTOESFRAMES2 = "/ttf"
SLASH_TENTOESFRAMES3 = "/ttframes"
SlashCmdList.TENTOESFRAMES = function(message)
    if not TTF.db then return end
    local cmd = (message or ""):lower():match("^%s*(%S*)")
    if cmd == "reset" then TTF:Reset()
    elseif cmd == "on" then TTF:Set("enabled", true)
    elseif cmd == "off" then TTF:Set("enabled", false)
    else TTF:ToggleOptions() end
end
