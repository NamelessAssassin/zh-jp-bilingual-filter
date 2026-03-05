local this = {}

-------------------------------------------------------------------------------
-- UTF-8 解码工具
-------------------------------------------------------------------------------

--- 从字符串的指定位置解码 UTF-8 字符，返回其 Unicode 码点和消耗的字节数。
--- 这使我们可以处理逻辑上的 Unicode 值，而不是原始字节。
--- @param str string: 输入字符串
--- @param i number: 当前字节索引
--- @return number, number: (码点, 下一个索引)
this.get_utf8_codepoint = function(str, i)
    local b1 = string.byte(str, i)
    if not b1 then
        return nil, i + 1
    end

    -- 1字节 (ASCII): 0xxxxxxx
    if b1 < 0x80 then
        return b1, i + 1
    end

    -- 续字节 (作为起始字节无效): 10xxxxxx
    if b1 < 0xC0 then
        return nil, i + 1
    end

    -- 2字节: 110xxxxx
    if b1 < 0xE0 then
        local b2 = string.byte(str, i + 1)
        if not b2 then
            return nil, i + 1
        end
        -- 公式: (b1 & 0x1F) << 6 | (b2 & 0x3F)
        local cp = (b1 - 0xC0) * 0x40 + (b2 - 0x80)
        return cp, i + 2
    end

    -- 3字节: 1110xxxx
    if b1 < 0xF0 then
        local b2 = string.byte(str, i + 1)
        local b3 = string.byte(str, i + 2)
        if not b2 or not b3 then
            return nil, i + 1
        end
        -- 公式: (b1 & 0x0F) << 12 | (b2 & 0x3F) << 6 | (b3 & 0x3F)
        local cp = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
        return cp, i + 3
    end

    -- 4字节: 11110xxx
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

    -- 无效序列的回退处理
    return nil, i + 1
end

--- 获取单个字符字符串的码点（例如 "あ"）
--- @param char_str string
--- @return number
this.utf8_to_cp = function(char_str)
    local cp, _ = this.get_utf8_codepoint(char_str, 1)
    return cp
end

-------------------------------------------------------------------------------
-- 语言检测
-------------------------------------------------------------------------------

--- 辅助函数：扫描字符串中是否存在满足谓词函数的码点
--- @param str string: 输入字符串
--- @param predicate function: 接收码点并返回布尔值的函数
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

--- 检查 Unicode 码点是否在日文假名范围内。
--- 排除中文文本中常用的中点符号 (U+30FB)。
--- @param cp number: Unicode 码点
--- @return boolean
local function is_kana_codepoint(cp)
    -- 平假名范围: U+3041 到 U+309F
    local is_hiragana = (cp >= 0x3041 and cp <= 0x309F)

    -- 片假名范围: U+30A0 到 U+30FF
    -- 显式排除 U+30FB (片假名中点 '・')
    local is_katakana = (cp >= 0x30A0 and cp <= 0x30FF) and (cp ~= 0x30FB)

    return is_hiragana or is_katakana
end

--- 检查 Unicode 码点是否在韩文谚文范围内。
--- @param cp number: Unicode 码点
--- @return boolean
local function is_hangul_codepoint(cp)
    local is_hangul = (cp >= 0xAC00 and cp <= 0xD7AF) -- 韩文音节: U+AC00 到 U+D7AF
    or (cp >= 0x1100 and cp <= 0x11FF) -- 韩文字母 (组合字符): U+1100 到 U+11FF

    return is_hangul
end

--- 检查 Unicode 码点是否在常用 CJK (中日韩) 范围内。
--- 此逻辑专门排除平假名、片假名和谚文。
--- @param cp number: Unicode 码点
--- @return boolean
local function is_cjk_codepoint(cp)
    local is_cjk = (cp >= 0x4E00 and cp <= 0x9FFF) -- CJK 统一汉字 (常用汉字/日文汉字)
    or (cp >= 0x3400 and cp <= 0x4DBF) -- CJK 统一汉字扩展 A

    return is_cjk
end

--- 扫描字符串是否包含日文假名。
--- @param str string
--- @return boolean
this.contains_kana = function(str)
    return contains_codepoint(str, is_kana_codepoint)
end

--- 检查字符串是否包含韩文谚文。
this.contains_hangul = function(str)
    return contains_codepoint(str, is_hangul_codepoint)
end

--- 扫描字符串是否包含 CJK 字符。
--- @param str string: 输入字符串
--- @return boolean
this.contains_cjk = function(str)
    return contains_codepoint(str, is_cjk_codepoint)
end

-------------------------------------------------------------------------------
-- 环形缓冲区 (带大小限制的 FIFO)
-------------------------------------------------------------------------------

--- 创建一个带最大大小限制的 FIFO 环形缓冲区。
--- 当缓冲区满时，自动删除最早的条目。
--- @param max_size number: 最大条目数 (默认: 10)
--- @return table: 带 set, get, clear 方法的缓冲区对象
this.create_ring_buffer = function(max_size)
    local buffer = {
        data = {},
        order = {},
        max_size = max_size or 10
    }

    --- 设置键值对。
    --- 如果键已存在，仅更新值。如果缓冲区满，删除最早的条目。
    --- @param key string: 要设置的键
    --- @param value any: 要存储的值
    function buffer:set(key, value)
        if not key then
            return
        end

        -- 键已存在：仅更新值
        if self.data[key] then
            self.data[key] = value
            return
        end

        -- 缓冲区满：删除最早的条目 (FIFO)
        if #self.order >= self.max_size then
            local oldest_key = table.remove(self.order, 1)
            self.data[oldest_key] = nil
        end

        -- 插入新条目
        table.insert(self.order, key)
        self.data[key] = value
    end

    --- 根据键获取值。
    --- @param key string: 要查找的键
    --- @return any: 存储的值，未找到则返回 nil
    function buffer:get(key)
        return self.data[key]
    end

    --- 清空缓冲区中的所有条目。
    function buffer:clear()
        self.data = {}
        self.order = {}
    end

    return buffer
end

-------------------------------------------------------------------------------
-- OSD 和 UI 工具
-------------------------------------------------------------------------------

--- 在屏幕上显示临时的 OSD 消息。
--- @param msg string: 要显示的消息内容
this.notify = function(msg)
    if msg then
        mp.osd_message(msg, 2)
    end
end

-------------------------------------------------------------------------------
-- 其他工具
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
