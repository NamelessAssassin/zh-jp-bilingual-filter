local state = require('state')
local utils = require('utils')
local menu = require('filter_menu')

local M = {}

local is_profile_active = function()
    return nil
end

local function update_scores(lines)
    if not state.enabled or state.current_mode ~= "AUTO" then
        return
    end

    if not is_profile_active() then
        return
    end

    if not lines or #lines < 1 or #lines > 2 then
        return
    end

    local key = nil

    if #lines == 1 then
        key = "MONO"
    elseif #lines == 2 then
        local h1, h2 = utils.contains_kana(lines[1]), utils.contains_kana(lines[2])
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
        state:reset_scores()
    end)

    -- 监听开始加载
    mp.register_event("start-file", function()
        state:reset_scores()
    end)

    -- 快捷键绑定
    mp.add_key_binding("alt+m", "jp_filter_toggle_filter_menu", function()
        menu:toggle()
    end)
end

return M
