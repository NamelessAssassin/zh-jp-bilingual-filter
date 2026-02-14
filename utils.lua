local this = {}

-------------------------------------------------------------------------------
-- UTF-8 Decoding Utilities
-------------------------------------------------------------------------------

--- Decodes a UTF-8 character starting at index i and returns its Unicode codepoint 
--- and the number of bytes consumed.
--- This allows us to work with logical Unicode values instead of raw bytes.
--- @param str string: The input string.
--- @param i number: The current byte index.
--- @return number, number: (codepoint, next_index)
this.get_utf8_codepoint = function(str, i)
    local b1 = string.byte(str, i)
    if not b1 then
        return nil, i + 1
    end

    -- 1-byte (ASCII): 0xxxxxxx
    if b1 < 0x80 then
        return b1, i + 1
    end

    -- Continuation byte (Invalid as start byte): 10xxxxxx
    if b1 < 0xC0 then
        return nil, i + 1
    end

    -- 2-byte: 110xxxxx
    if b1 < 0xE0 then
        local b2 = string.byte(str, i + 1)
        if not b2 then
            return nil, i + 1
        end
        -- Formula: (b1 & 0x1F) << 6 | (b2 & 0x3F)
        local cp = (b1 - 0xC0) * 0x40 + (b2 - 0x80)
        return cp, i + 2
    end

    -- 3-byte: 1110xxxx
    if b1 < 0xF0 then
        local b2 = string.byte(str, i + 1)
        local b3 = string.byte(str, i + 2)
        if not b2 or not b3 then
            return nil, i + 1
        end
        -- Formula: (b1 & 0x0F) << 12 | (b2 & 0x3F) << 6 | (b3 & 0x3F)
        local cp = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
        return cp, i + 3
    end

    -- 4-byte: 11110xxx
    if b1 < 0xF8 then
        local b2 = string.byte(str, i + 1)
        local b3 = string.byte(str, i + 2)
        local b4 = string.byte(str, i + 3)
        if not b2 or not b3 or not b4 then
            return nil, i + 1
        end
        local cp = (b1 - 0xF0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
        return cp, i + 4
    end

    -- Fallback for invalid sequences
    return nil, i + 1
end

--- Helper to get codepoint of a single character string (e.g., "あ")
--- @param char_str string
--- @return number
this.utf8_to_cp = function(char_str)
    local cp, _ = this.get_utf8_codepoint(char_str, 1)
    return cp
end

-------------------------------------------------------------------------------
-- Language Detection
-------------------------------------------------------------------------------

--- Helper to scan a string for any codepoint that satisfies a predicate function.
--- @param str string: The input string.
--- @param predicate function: A function(cp) that returns boolean.
--- @return boolean
local function contains_codepoint(str, predicate)
    if not str then
        return false
    end

    local i = 1
    local len = #str
    while i <= len do
        local cp, next_i = this.get_utf8_codepoint(str, i)
        if cp and predicate(cp) then
            return true
        end
        i = next_i
    end
    return false
end

--- Checks if a Unicode codepoint falls within the Japanese Kana range.
--- Excludes the Middle Dot (U+30FB) commonly used in Chinese text.
--- @param cp number: The Unicode codepoint.
--- @return boolean
local function is_kana_codepoint(cp)
    -- Hiragana Range: U+3041 to U+309F
    local is_hiragana = (cp >= 0x3041 and cp <= 0x309F)

    -- Katakana Range: U+30A0 to U+30FF
    -- We explicitly exclude U+30FB (Katana Middle Dot '・')
    local is_katakana = (cp >= 0x30A0 and cp <= 0x30FF) and (cp ~= 0x30FB)

    return is_hiragana or is_katakana
end

--- Checks if a Unicode codepoint falls within the Hangul Syllables range.
--- @param cp number: The Unicode codepoint.
--- @return boolean
local function is_hangul_codepoint(cp)
    local is_hangul = (cp >= 0xAC00 and cp <= 0xD7AF) -- Hangul Syllables: U+AC00 to U+D7AF
    or (cp >= 0x1100 and cp <= 0x11FF) -- Hangul Jamo (Composing characters): U+1100 to U+11FF

    return is_hangul
end

--- Checks if a Unicode codepoint falls within common CJK (Chinese, Japanese, Korean) ranges.
--- This logic specifically excludes Hiragana, Katakana, and Hangul.
--- @param cp number: The Unicode codepoint.
--- @return boolean
local function is_cjk_codepoint(cp)
    local is_cjk = (cp >= 0x4E00 and cp <= 0x9FFF) -- CJK Unified Ideographs (Common Hanzi/Kanji)
    or (cp >= 0x3400 and cp <= 0x4DBF) -- CJK Unified Ideographs Extension A

    return is_cjk
end

--- Scans a string to see if it contains any Japanese Kana.
--- @param str string
--- @return boolean
this.contains_kana = function(str)
    return contains_codepoint(str, is_kana_codepoint)
end

--- Checks if the string contains Korean Hangul.
this.contains_hangul = function(str)
    return contains_codepoint(str, is_hangul_codepoint)
end

--- Scans a string to see if it contains any CJK characters.
--- @param str string: The input string.
--- @return boolean
this.contains_cjk = function(str)
    return contains_codepoint(str, is_cjk_codepoint)
end

-------------------------------------------------------------------------------
-- OSD & UI Utilities
-------------------------------------------------------------------------------

--- Displays a temporary OSD message on the screen.
--- @param msg string: The message content to display.
this.notify = function(msg)
    if msg then
        mp.osd_message(msg, 2)
    end
end

-------------------------------------------------------------------------------
-- Others
-------------------------------------------------------------------------------

this.split_lines = function(text)
    local lines = {}
    for line in string.gmatch(text, "[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

this.join_lines = function(lines)
    return table.concat(lines, "\n")
end

this.deep_copy = function(obj)
    if type(obj) ~= 'table' then
        return obj
    end

    local res = {}
    for k, v in pairs(obj) do
        res[k] = this.deep_copy(v)
    end
    return res
end

this.get_subtitle_fingerprint = function(sid)
    if not sid or sid == "no" then
        return nil
    end

    local tracks = mp.get_property_native("track-list")
    for _, track in ipairs(tracks) do
        if track.type == "sub" and tostring(track.id) == sid then
            return (track.title or "no-title") .. "_" .. (track.lang or "und") .. "_" .. (track.id or "")
        end
    end
    return nil
end

return this
