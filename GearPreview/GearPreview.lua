----------------------------------------------------------------
-- GearPreview: a character window button that builds a link to the
-- scryTome Gear Preview (https://scrytome.org/ror-gear-preview/) from the
-- worn items, their dyes and their appearance overrides.
-- Contract: docs/addon-link.md in the ror-gear-preview repository.
-- No network, no file writes, no saved settings.
----------------------------------------------------------------

GearPreview = GearPreview or {}
local GP = GearPreview

GP.VERSION = "0.1.0"
GP.BASE_URL = "https://scrytome.org/ror-gear-preview/"
GP.WINDOW = "GearPreviewWindow"
GP.BUTTON = "GearPreviewButton"
GP.BUTTON_TEMPLATE = "GearPreviewButtonTemplate"
GP.PARENT = "CharacterWindow"
GP.TITLE_BAR = "CharacterWindowTitleBar"
-- Left of ClosetGoblin's title bar icon (36 wide at -76), with a 4 gap.
GP.BUTTON_X = -116
-- The button face: the addon's own 36x36 icon, GearPreviewIcon in the XML.
GP.ICON = "GearPreviewIcon"

-- The last link built, for scripts and checks: GearPreview.link
GP.link = nil
GP.info = nil

-- Page slot keys in the page's order, with the GameData.EquipSlots name and
-- the number measured on 2026-10-31 as the fallback.
GP.SLOTS = {
    { key = "helm",      name = "HELM",       slot = 9 },
    { key = "shoulders", name = "SHOULDERS",  slot = 10 },
    { key = "body",      name = "BODY",       slot = 6 },
    { key = "gloves",    name = "GLOVES",     slot = 7 },
    { key = "belt",      name = "BELT",       slot = 14 },
    { key = "boots",     name = "BOOTS",      slot = 8 },
    { key = "back",      name = "BACK",       slot = 13 },
    { key = "main_hand", name = "RIGHT_HAND", slot = 1 },
    { key = "off_hand",  name = "LEFT_HAND",  slot = 2 },
    { key = "ranged",    name = "RANGED",     slot = 3 },
}

-- GameData.Player.career.line (a GameData.CareerLine value, measured
-- 2026-10-31) to the page's career key.
GP.CAREERS = {
    [1] = "IRON_BREAKER",
    [2] = "SLAYER",
    [3] = "RUNE_PRIEST",
    [4] = "ENGINEER",
    [5] = "BLACK_ORC",
    [6] = "CHOPPA",
    [7] = "SHAMAN",
    [8] = "SQUIG_HERDER",
    [9] = "WITCH_HUNTER",
    [10] = "KNIGHT_OF_THE_BLAZING_SUN",
    [11] = "BRIGHT_WIZARD",
    [12] = "WARRIOR_PRIEST",
    [13] = "CHOSEN",
    [14] = "MARAUDER",
    [15] = "ZEALOT",
    [16] = "MAGUS",
    [17] = "SWORD_MASTER",
    [18] = "SHADOW_WARRIOR",
    [19] = "WHITE_LION",
    [20] = "ARCHMAGE",
    [21] = "BLACK_GUARD",
    [22] = "WITCH_ELF",
    [23] = "DISCIPLE_OF_KHAINE",
    [24] = "SORCERER",
}

local announced = false

----------------------------------------------------------------
-- Safe reads
----------------------------------------------------------------

-- Walks root[k1][k2]... and returns nil instead of raising.
local function get(root, ...)
    local keys = { ... }
    local ok, value = pcall(function()
        local node = root
        for i = 1, #keys do
            if type(node) ~= "table" then return nil end
            node = node[keys[i]]
        end
        return node
    end)
    if ok then return value end
    return nil
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

-- A non-negative whole number as decimal text, or nil.
local function whole(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value >= 2147483648 then return nil end
    if value ~= math.floor(value) then return nil end
    return string.format("%d", value)
end

----------------------------------------------------------------
-- Text: wide strings to UTF-8 and URL encoding
----------------------------------------------------------------

-- The UTF-16 units of a wide string, or nil.
local function units(value)
    if type(value) ~= "wstring" then return nil end
    if type(wstring) == "table" and type(wstring.byte) == "function" and type(wstring.len) == "function" then
        local list = {}
        local ok = pcall(function()
            local length = wstring.len(value)
            for first = 1, length, 128 do
                local chunk = { wstring.byte(value, first, math.min(first + 127, length)) }
                for i = 1, #chunk do list[#list + 1] = chunk[i] end
            end
        end)
        if ok then return list end
    end
    -- Fallback: the client's narrowing keeps each unit's low byte (Latin-1).
    local narrow = call(WStringToString, value)
    if type(narrow) ~= "string" then return nil end
    local list = {}
    for i = 1, string.len(narrow) do list[i] = string.byte(narrow, i) end
    return list
end

local function utf8char(cp)
    if cp < 128 then return string.char(cp) end
    if cp < 2048 then
        return string.char(192 + math.floor(cp / 64), 128 + cp % 64)
    end
    if cp < 65536 then
        return string.char(224 + math.floor(cp / 4096), 128 + math.floor(cp / 64) % 64, 128 + cp % 64)
    end
    return string.char(240 + math.floor(cp / 262144), 128 + math.floor(cp / 4096) % 64,
        128 + math.floor(cp / 64) % 64, 128 + cp % 64)
end

-- UTF-16 units (first..last) to UTF-8; lone surrogates become U+FFFD.
local function utf8(list, first, last)
    local out = {}
    local i = first
    while i <= last do
        local unit = list[i]
        local nextUnit = list[i + 1]
        if unit >= 55296 and unit <= 56319 and i < last and nextUnit >= 56320 and nextUnit <= 57343 then
            out[#out + 1] = utf8char(65536 + (unit - 55296) * 1024 + (nextUnit - 56320))
            i = i + 2
        else
            if unit >= 55296 and unit <= 57343 then unit = 65533 end
            out[#out + 1] = utf8char(unit)
            i = i + 1
        end
    end
    return table.concat(out)
end

-- A wide (or narrow UTF-8) value as UTF-8, or nil.
function GP.ToUtf8(value)
    if type(value) == "string" then return value end
    local list = units(value)
    if not list then return nil end
    return utf8(list, 1, #list)
end

-- UTF-8 bytes to %XX for anything outside the unreserved characters.
function GP.UrlEncode(text)
    return (string.gsub(text, "[^A-Za-z0-9%-%._~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

-- The player's name without its "^M" style suffix: UTF-8, wide, and the
-- suffix letter (upper case) if there was one.
local function playerName()
    local list = units(get(GameData, "Player", "name"))
    if not list then return nil, nil, nil end
    local stop, suffix = #list, nil
    for i = 1, #list do
        if list[i] == 94 then -- "^"
            stop = i - 1
            if list[i + 1] then suffix = string.upper(string.char(list[i + 1] % 256)) end
            break
        end
    end
    local text = utf8(list, 1, stop)
    local wide = nil
    if type(wstring) == "table" and type(wstring.char) == "function" then
        wide = call(function()
            local result = towstring("")
            for first = 1, stop, 128 do
                result = result .. wstring.char(unpack(list, first, math.min(first + 127, stop)))
            end
            return result
        end)
    end
    return text, wide or call(towstring, text), suffix
end

----------------------------------------------------------------
-- The link
----------------------------------------------------------------

local function slotNumber(entry)
    local number = get(GameData, "EquipSlots", entry.name)
    if type(number) == "number" then return number end
    return entry.slot
end

local function careerKey()
    local line = get(GameData, "Player", "career", "line")
    if type(line) == "number" then return GP.CAREERS[line] end
    return nil
end

-- One "i=" value for a worn item; otherwise nil and "empty" or "unreadable".
local function itemEntry(key, data)
    if type(data) ~= "table" then return nil, "empty" end
    local uid = get(data, "uniqueID")
    local model = get(data, "id")
    local present = (type(uid) == "number" and uid > 0) or (type(model) == "number" and model > 0)
    if not present then return nil, "empty" end
    local id = whole(uid)
    local dyeA = whole(get(data, "dyeTintA"))
    local dyeB = whole(get(data, "dyeTintB"))
    if not id or id == "0" or not dyeA or not dyeB then return nil, "unreadable" end
    local entry = key .. ":" .. id .. ":" .. dyeA .. ":" .. dyeB
    local icon = get(data, "customizedIconNum")
    if type(icon) == "number" and icon ~= 0 and whole(icon) then
        local name = GP.ToUtf8(get(data, "customizedIconName")) or ""
        entry = entry .. ":" .. GP.UrlEncode(name) .. ":" .. whole(icon)
    end
    return entry
end

-- Builds the link from the live client. Returns the link and a table with
-- items, skipped, career, sex, name (UTF-8), nameWide and length (fragment).
function GP.BuildLink()
    local info = { items = 0, skipped = 0 }
    local parts = { "eq=1" }

    info.career = careerKey()
    if info.career then parts[#parts + 1] = "c=" .. info.career end

    local name, nameWide, suffix = playerName()
    local gender = get(GameData, "Player", "gender")
    if gender == 1 then
        info.sex = "M"
    elseif gender == 2 then
        info.sex = "F"
    elseif suffix == "M" or suffix == "F" then
        info.sex = suffix
    end
    if info.sex then parts[#parts + 1] = "s=" .. info.sex end

    info.name, info.nameWide = name, nameWide
    if name and name ~= "" then parts[#parts + 1] = "n=" .. GP.UrlEncode(name) end

    local equipment = nil
    if type(DataUtils) == "table" then equipment = call(DataUtils.GetEquipmentData) end
    if type(equipment) ~= "table" then
        info.equipmentUnreadable = true
    else
        for _, slot in ipairs(GP.SLOTS) do
            local ok, entry, reason = pcall(itemEntry, slot.key, get(equipment, slotNumber(slot)))
            if ok and entry then
                parts[#parts + 1] = "i=" .. entry
                info.items = info.items + 1
            elseif not ok or reason == "unreadable" then
                info.skipped = info.skipped + 1
            end
        end
    end

    local fragment = table.concat(parts, ";")
    local link = GP.BASE_URL .. "#" .. fragment
    info.length = string.len(fragment)
    GP.link, GP.info = link, info
    return link, info
end

local function countText(info)
    local text
    if info.equipmentUnreadable then
        text = "The equipment could not be read; the link has no items."
    elseif info.items == 1 then
        text = "1 item in the link."
    else
        text = info.items .. " items in the link."
    end
    if info.skipped == 1 then
        text = text .. " 1 slot left out: its data could not be read."
    elseif info.skipped > 1 then
        text = text .. " " .. info.skipped .. " slots left out: their data could not be read."
    end
    return text
end

----------------------------------------------------------------
-- Chat
----------------------------------------------------------------

local function printLine(text)
    if type(EA_ChatWindow) == "table" and type(EA_ChatWindow.Print) == "function" then
        pcall(EA_ChatWindow.Print, towstring("[Gear Preview] " .. text))
    end
end

----------------------------------------------------------------
-- The window
----------------------------------------------------------------

local function ensureWindow()
    if call(DoesWindowExist, GP.WINDOW) then return true end
    if not call(function() CreateWindow(GP.WINDOW, false) return true end) then return false end
    local w = GP.WINDOW
    call(LabelSetText, w .. "TitleBarText", towstring("scryTome Gear Preview"))
    call(LabelSetText, w .. "Hint", towstring("Copy: Ctrl+A, Ctrl+C"))
    call(ButtonSetText, w .. "CloseButton", towstring("Close"))
    return call(DoesWindowExist, w) == true
end

function GP.Open()
    if not ensureWindow() then return false end
    local w = GP.WINDOW
    local ok, link, info = pcall(GP.BuildLink)
    if not ok or type(link) ~= "string" then
        link, info = GP.BASE_URL, { items = 0, skipped = 0, equipmentUnreadable = true }
    end
    call(LabelSetText, w .. "Name", info.nameWide or towstring("Unknown character"))
    call(LabelSetText, w .. "Count", towstring(countText(info)))
    call(TextEditBoxSetText, w .. "Link", towstring(link))
    call(WindowSetShowing, w, true)
    call(WindowAssignFocus, w .. "Link", true)
    call(TextEditBoxSelectAll, w .. "Link")
    if not announced then
        announced = true
        printLine("Link ready. Press Ctrl+A, Ctrl+C in the window and paste it into a browser.")
    end
    return true
end

function GP.Close()
    if not call(DoesWindowExist, GP.WINDOW) then return end
    call(WindowAssignFocus, GP.WINDOW .. "Link", false)
    call(WindowSetShowing, GP.WINDOW, false)
end

function GP.Toggle()
    if call(DoesWindowExist, GP.WINDOW) and call(WindowGetShowing, GP.WINDOW) then
        GP.Close()
    else
        GP.Open()
    end
end

----------------------------------------------------------------
-- The character window button
----------------------------------------------------------------

function GP.InstallButton()
    if call(DoesWindowExist, GP.BUTTON) then return true end
    if not call(DoesWindowExist, GP.PARENT) or not call(DoesWindowExist, GP.TITLE_BAR) then return false end
    local created = call(function()
        CreateWindowFromTemplate(GP.BUTTON, GP.BUTTON_TEMPLATE, GP.PARENT)
        return true
    end)
    if not created or not call(DoesWindowExist, GP.BUTTON) then return false end
    call(WindowClearAnchors, GP.BUTTON)
    call(WindowAddAnchor, GP.BUTTON, "topright", GP.TITLE_BAR, "topright", GP.BUTTON_X, 0)
    local scale = call(WindowGetScale, GP.PARENT)
    if type(scale) == "number" and scale > 0 then call(WindowSetScale, GP.BUTTON, scale) end
    call(DynamicImageSetTexture, GP.BUTTON .. "Icon", GP.ICON, 0, 0)
    call(WindowSetShowing, GP.BUTTON, true)
    return true
end

function GP.OnButton()
    GP.Toggle()
end

function GP.OnButtonMouseOver()
    call(WindowSetShowing, GP.BUTTON .. "Highlight", true)
    call(function()
        Tooltips.CreateTextOnlyTooltip(GP.BUTTON, towstring("scryTome Gear Preview: a link to your gear"))
        Tooltips.AnchorTooltip(Tooltips.ANCHOR_WINDOW_TOP)
    end)
end

function GP.OnButtonMouseOverEnd()
    call(WindowSetShowing, GP.BUTTON .. "Highlight", false)
end

function GP.OnLoadingEnd()
    GP.InstallButton()
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------

function GP.Initialize()
    announced = false
    GP.InstallButton()
    if type(LibSlash) == "table" and type(LibSlash.RegisterSlashCmd) == "function" then
        pcall(LibSlash.RegisterSlashCmd, "gearpreview", function() GP.Toggle() end)
        pcall(LibSlash.RegisterSlashCmd, "gp", function() GP.Toggle() end)
    end
    local event = get(SystemData, "Events", "LOADING_END")
    if event ~= nil and type(RegisterEventHandler) == "function" then
        pcall(RegisterEventHandler, event, "GearPreview.OnLoadingEnd")
    end
end
