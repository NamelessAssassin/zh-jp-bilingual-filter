local state = require('state')
local utils = require('utils')
local menu = require('filter_menu')

local M = {}

local state_history = {}
local last_subtitle_track = nil

local is_profile_active = function()
    return nil
end

-- 将当前状态存入历史记录
local function save_current_state()
    if last_subtitle_track then
        state_history[last_subtitle_track] = state:get_current_data()
    end
end

-- 根据新的字幕指纹加载状态
local function load_subtitle_state(subtitle_track)
    if subtitle_track and state_history[subtitle_track] then
        state:restore_data(state_history[subtitle_track])
    else
        state:reset_scores()
    end
    -- 无论读档还是重置，都更新菜单显示
    menu:maybe_refresh()
end

local function reset_state_history()
    state_history = {}
    last_subtitle_track = nil
end

local function update_scores(lines)
    if not state.enabled or state.current_mode ~= "AUTO" then
        return
    end

    if not lines or #lines < 1 or #lines > 2 then
        return
    end

    local key = nil

    if #lines == 1 then
        key = "MONO"
    elseif #lines == 2 then
        local h1 = utils.contains_kana(lines[1])
        local h2 = utils.contains_kana(lines[2])
        if h1 and not h2 then
            key = "JP_TOP"
        elseif not h1 and h2 then
            key = "JP_BOTTOM"
        else
            key = "MONO"
        end
    end

    state.scores[key] = state.scores[key] + 1
    if state.scores[key] >= state.threshold then
        state.current_mode = key
        menu:maybe_refresh()
        utils.notify("锁定日文位置：" .. state.MODES[key])
    else
        menu:maybe_refresh()
    end
end

M.preprocess = function(text)
    if not state.enabled or text == "" then
        return text
    end

    if not is_profile_active() then
        return text
    end

    if state.current_mode == "MONO" then
        return text
    end

    local lines = {}
    for line in string.gmatch(text, "[^\r\n]+") do
        table.insert(lines, line)
    end

    update_scores(lines)

    if #lines <= 1 then
        return text
    end

    local jp_lines = {}
    for _, line in ipairs(lines) do
        if utils.contains_kana(line) then
            table.insert(jp_lines, line)
        end
    end

    -- 日语在上提取倒数第二行，在下提取最后一行
    if #jp_lines == 0 and state.current_mode ~= "AUTO" then
        if state.current_mode == "JP_TOP" then
            table.insert(jp_lines, lines[#lines - 1])
        elseif state.current_mode == "JP_BOTTOM" then
            table.insert(jp_lines, lines[#lines])
        end
    end

    if #jp_lines > 0 then
        return table.concat(jp_lines, "\n")
    end

    return text
end

M.init = function(config)
    if type(config.get_mode) == "function" then
        is_profile_active = function()
            return config.get_mode() == "japanese"
        end
    end

    menu:setup({
        get_info = function()
            return {
                enabled = state.enabled,
                is_profile_active = is_profile_active(),
                current_mode = state.current_mode,
                mode_name = state.MODES[state.current_mode],
                scores = state.scores,
                threshold = state.threshold
            }
        end,
        toggle = function()
            state.enabled = not state.enabled
        end,
        reset = function()
            state:reset_scores();
        end
    })

    -- 监听字幕轨道切换
    mp.observe_property("sid", "string", function(_, value)
        local current_subtitle_track = utils.get_subtitle_fingerprint(value)

        -- 如果指纹没变（可能是 mpv 内部属性震荡），不做任何操作
        if current_subtitle_track == last_subtitle_track then
            return
        end

        -- 存档旧字幕状态
        save_current_state()

        -- 加载或重置新字幕状态
        load_subtitle_state(current_subtitle_track)

        -- 更新当前追踪的字幕
        last_subtitle_track = current_subtitle_track
    end)

    -- 监听视频加载
    mp.register_event("start-file", function()
        state:reset_scores()
        reset_state_history()
    end)

    -- 快捷键绑定
    mp.add_key_binding("alt+m", "jp_filter_toggle_filter_menu", function()
        menu:toggle()
    end)
end

return M
