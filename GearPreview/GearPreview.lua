----------------------------------------------------------------
-- GearPreview: a button on the character window and the barber window
-- that builds a link to the scryTome Gear Preview
-- (https://scrytome.org/ror-gear-preview/) from the worn items, their dyes,
-- their appearance overrides, the helm and cloak settings and the face
-- features the barber reports.
-- Contract: docs/link.md.
-- No network, no file writes, no saved settings.
----------------------------------------------------------------

GearPreview = GearPreview or {}
local GP = GearPreview

GP.VERSION = "0.2.0"
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

-- The same button on the stock barber window (EA_BarbershopWindow). The
-- window is EA_Window_Barbershop; its frame is EA_Window_BarbershopMain. The
-- button is a child of the frame, so it shows and hides with it, and sits
-- 10 right of the Check Out button's top right corner: beside the Reset and
-- Check Out pair, below the mirror and left of the feature combo boxes.
GP.BARBER_BUTTON = "GearPreviewBarberButton"
GP.BARBER_WINDOW = "EA_Window_Barbershop"
GP.BARBER_PARENT = "EA_Window_BarbershopMain"
GP.BARBER_ANCHOR = "EA_Window_BarbershopMainCheckOutButton"

-- true adds v= (helm, cloak and heraldry shown) and f= (barber face
-- features) to the link. Keep false until the scryTome page reads both keys.
GP.LINK_LOOKS = false

-- The last VISIBLE_EQUIPMENT_UPDATED payload this session:
-- { helm = bool, cloak = bool, heraldry = bool }, or nil before the first.
GP.visibility = nil
-- Barber captures by character name, kept in memory for this session only:
-- the addon has no saved variables, so /reloadui and logging out clear them.
-- looks[name] = { worn = capture, shown = capture }, where a capture is
-- { line = "9", gender = "1", values = { "0", "7", ... } }.
GP.looks = {}

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

local function digit(value)
    if value == true then return "1" end
    if value == false then return "0" end
    return nil
end

-- The helm, cloak and heraldry flags: the last event payload, or the
-- client getters before the first event (they can be stale). Returns the
-- "v=" value or nil, the flags and whether they came from the event.
local function visibilityValue()
    local flags = GP.visibility
    local fromEvent = flags ~= nil
    if not flags then
        flags = {
            helm = call(GetEquippedItemVisible, slotNumber({ name = "HELM", slot = 9 })),
            cloak = call(GetEquippedItemVisible, slotNumber({ name = "BACK", slot = 13 })),
            heraldry = call(IsShowingCloakHeraldry),
        }
    end
    local a, b, c = digit(flags.helm), digit(flags.cloak), digit(flags.heraldry)
    if not a or not b or not c then return nil, nil, fromEvent end
    return a .. b .. c, flags, fromEvent
end

local function barberShowing()
    return call(DoesWindowExist, GP.BARBER_WINDOW) == true and call(WindowGetShowing, GP.BARBER_WINDOW) == true
end

-- The barber capture for this character: what the mirror shows while the
-- barber is open, otherwise the looks the character wears. Returns the
-- "f=" value or nil.
local function looksValue()
    local name = playerName()
    local record = name and GP.looks[name]
    if not record then return nil end
    local capture = record.worn
    if barberShowing() and record.shown then capture = record.shown end
    if not capture then return nil end
    return capture.line .. "." .. capture.gender .. "." .. table.concat(capture.values, ",")
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
-- items, skipped, career, sex, name (UTF-8), nameWide and length (fragment);
-- with GP.LINK_LOOKS also looksKeys, visibility, visibilityFromEvent and
-- features (the "f=" value or nil).
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

    if GP.LINK_LOOKS then
        info.looksKeys = true
        local visible, flags, fromEvent = visibilityValue()
        info.visibility, info.visibilityFromEvent = flags, fromEvent
        if visible then parts[#parts + 1] = "v=" .. visible end
        info.features = looksValue()
        if info.features then parts[#parts + 1] = "f=" .. info.features end
    end

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

-- The window's one status line: "9 items", plus "with your barber looks"
-- when f= is in the link.
local function countText(info)
    local text
    if info.items == 1 then
        text = "1 item"
    else
        text = info.items .. " items"
    end
    if info.features then text = text .. " with your barber looks" end
    return text
end

----------------------------------------------------------------
-- Chat
----------------------------------------------------------------

local function printLine(text)
    if type(EA_ChatWindow) == "table" and type(EA_ChatWindow.Print) == "function" then
        pcall(EA_ChatWindow.Print, towstring("Gear Preview: " .. text))
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

-- The window's vertical layout, in unscaled pixels: Count starts at 80 and
-- is at least 24 high, the link box (120 high) starts 6 below it, and 90
-- below the box hold the hint and the Close button. With a one-line count
-- the window is 320 high, as in 0.1.0.
local TEXT_X, TEXT_WIDTH, COUNT_Y, LINE_HEIGHT = 25, 470, 80, 24
local LINK_GAP, LINK_HEIGHT, FOOTER, WINDOW_WIDTH = 6, 120, 90, 520

-- Sets a wrapping label's text, sizes it to the text (the client measures
-- the wrapped height) and returns that height.
local function fitLabel(label, top, text)
    call(WindowClearAnchors, label)
    call(WindowAddAnchor, label, "topleft", GP.WINDOW, "topleft", TEXT_X, top)
    call(WindowSetDimensions, label, TEXT_WIDTH, LINE_HEIGHT)
    call(LabelSetText, label, towstring(text))
    local _, height = call(LabelGetTextDimensions, label)
    if type(height) ~= "number" or height < LINE_HEIGHT then height = LINE_HEIGHT end
    height = math.ceil(height)
    call(WindowSetDimensions, label, TEXT_WIDTH, height)
    return height
end

-- Puts the link box under Count and sizes the window to them.
local function layout(info)
    local w = GP.WINDOW
    local y = COUNT_Y + fitLabel(w .. "Count", COUNT_Y, countText(info)) + LINK_GAP
    call(WindowClearAnchors, w .. "Link")
    call(WindowAddAnchor, w .. "Link", "topleft", w, "topleft", TEXT_X, y)
    call(WindowSetDimensions, w, WINDOW_WIDTH, y + LINK_HEIGHT + FOOTER)
end

function GP.Open()
    if not ensureWindow() then return false end
    local w = GP.WINDOW
    local ok, link, info = pcall(GP.BuildLink)
    if not ok or type(link) ~= "string" then
        link, info = GP.BASE_URL, { items = 0, skipped = 0, equipmentUnreadable = true }
    end
    call(LabelSetText, w .. "Name", info.nameWide or towstring("Unknown character"))
    layout(info)
    call(TextEditBoxSetText, w .. "Link", towstring(link))
    call(WindowSetShowing, w, true)
    call(WindowAssignFocus, w .. "Link", true)
    call(TextEditBoxSelectAll, w .. "Link")
    if info.equipmentUnreadable then
        printLine("The equipment could not be read.")
    elseif info.skipped == 1 then
        printLine("1 slot left out.")
    elseif info.skipped > 1 then
        printLine(info.skipped .. " slots left out.")
    end
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
-- The buttons
----------------------------------------------------------------

-- Creates the button from the template as a child of parent, anchored with
-- the client's WindowAddAnchor(window, pointOnRelative, relativeTo,
-- pointOnWindow, x, y).
local function installButton(name, parent, point, relativeTo, relativePoint, x, y)
    if call(DoesWindowExist, name) then return true end
    if not call(DoesWindowExist, parent) or not call(DoesWindowExist, relativeTo) then return false end
    local created = call(function()
        CreateWindowFromTemplate(name, GP.BUTTON_TEMPLATE, parent)
        return true
    end)
    if not created or not call(DoesWindowExist, name) then return false end
    call(WindowClearAnchors, name)
    call(WindowAddAnchor, name, point, relativeTo, relativePoint, x, y)
    local scale = call(WindowGetScale, parent)
    if type(scale) == "number" and scale > 0 then call(WindowSetScale, name, scale) end
    call(DynamicImageSetTexture, name .. "Icon", GP.ICON, 0, 0)
    call(WindowSetShowing, name, true)
    return true
end

function GP.InstallButton()
    return installButton(GP.BUTTON, GP.PARENT, "topright", GP.TITLE_BAR, "topright", GP.BUTTON_X, 0)
end

-- The barber window is created the first time a barber opens.
function GP.InstallBarberButton()
    return installButton(GP.BARBER_BUTTON, GP.BARBER_PARENT, "topright", GP.BARBER_ANCHOR, "left", 10, 0)
end

local function setHighlight(button, showing)
    if call(DoesWindowExist, button .. "Highlight") then
        call(WindowSetShowing, button .. "Highlight", showing)
    end
end

function GP.OnButton()
    GP.Toggle()
end

function GP.OnButtonMouseOver()
    local button = get(SystemData, "ActiveWindow", "name")
    if button ~= GP.BARBER_BUTTON then button = GP.BUTTON end
    setHighlight(button, true)
    call(function()
        Tooltips.CreateTextOnlyTooltip(button, towstring("scryTome Gear Preview: a link to your gear"))
        Tooltips.AnchorTooltip(Tooltips.ANCHOR_WINDOW_TOP)
    end)
end

function GP.OnButtonMouseOverEnd()
    setHighlight(GP.BUTTON, false)
    setHighlight(GP.BARBER_BUTTON, false)
end

function GP.OnLoadingEnd()
    GP.InstallButton()
    GP.InstallBarberButton()
end

----------------------------------------------------------------
-- Helm and cloak settings, barber features
----------------------------------------------------------------

-- VISIBLE_EQUIPMENT_UPDATED: sent on login and twice on every toggle of
-- Show Helm, Show Cloak or the heraldry. The getters lag behind it.
function GP.OnVisibleEquipment(showHelm, showCloak, showCloakHeraldry)
    if type(showHelm) ~= "boolean" or type(showCloak) ~= "boolean" or type(showCloakHeraldry) ~= "boolean" then return end
    GP.visibility = { helm = showHelm, cloak = showCloak, heraldry = showCloakHeraldry }
end

function GP.OnBarberOpen()
    GP.InstallBarberButton()
end

-- INTERACT_BARBERSHOP_FEATURE_UPDATE: while a barber is open, every feature
-- in the order of pregame_features.csv for the career line and gender, each
-- with its allowed values and curValue (a zero-based index).
function GP.OnBarberFeatures(featuresData)
    GP.InstallBarberButton()
    if type(featuresData) ~= "table" then return end
    local name = playerName()
    local line = whole(get(GameData, "Player", "career", "line"))
    local gender = whole(get(GameData, "Player", "gender"))
    if not name or name == "" or not line or not gender then return end
    local values = {}
    for i = 1, #featuresData do
        local value = whole(get(featuresData, i, "curValue"))
        if not value then return end
        values[i] = value
    end
    if #values == 0 then return end
    local capture = { line = line, gender = gender, values = values }
    local record = GP.looks[name] or {}
    record.shown = capture
    -- With no changes tried, the mirror shows what the character wears.
    if call(BarbershopHaveFeaturesChanged) == false or not record.worn then record.worn = capture end
    GP.looks[name] = record
end

-- INTERACT_BARBERSHOP_RESULT: on SUCCESS the character bought the looks in
-- the mirror.
function GP.OnBarberResult(code)
    local success = get(GameData, "BarberShopMessage", "SUCCESS")
    if code == nil or code ~= success then return end
    local name = playerName()
    local record = name and GP.looks[name]
    if record and record.shown then record.worn = record.shown end
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
    local handlers = {
        LOADING_END = "GearPreview.OnLoadingEnd",
        VISIBLE_EQUIPMENT_UPDATED = "GearPreview.OnVisibleEquipment",
        INTERACT_BARBERSHOP_OPEN = "GearPreview.OnBarberOpen",
        INTERACT_BARBERSHOP_FEATURE_UPDATE = "GearPreview.OnBarberFeatures",
        INTERACT_BARBERSHOP_RESULT = "GearPreview.OnBarberResult",
    }
    for name, handler in pairs(handlers) do
        local event = get(SystemData, "Events", name)
        if event ~= nil and type(RegisterEventHandler) == "function" then
            pcall(RegisterEventHandler, event, handler)
        end
    end
end
