local state = require('state')
local utils = require('utils')
local menu = require('menu.filter_menu')
local processor = require('subtitle_extractor.processor')

local get_lang_rule = require('subtitle_extractor.language_rules').get_rule

local M = {}

-- 在 init 中初始化
local get_current_profile_mode = function()
    return nil
end

local function check_profile_activity(profile_mode)
    return profile_mode ~= nil and profile_mode:lower() ~= "none"
end

-- 主过滤入口
M.preprocess = function(text)
    -- 基础状态检查
    if not state.enabled or text == "" then
        return text
    end

    local profile_mode = get_current_profile_mode()

    local is_profile_active = check_profile_activity(profile_mode)
    if not is_profile_active then
        return text
    end

    if state.current_mode == "MONO" then
        return text
    end

    local check_lang = get_lang_rule(profile_mode)

    -- 注入探测逻辑，并执行过滤
    processor.set_rule(check_lang)
    return processor.process(text, state, menu)
end

-- 初始化
M.init = function(config)
    if type(config.get_mode) == "function" then
        get_current_profile_mode = config.get_mode
    end

    -- 初始化菜单
    menu:setup({
        get_info = function()
            local profile_mode = get_current_profile_mode()
            if profile_mode then
                profile_mode = profile_mode:lower()
            end
            return {
                enabled = state.enabled,
                is_profile_active = check_profile_activity(profile_mode),
                current_profile_mode = profile_mode,
                current_mode = state.current_mode,
                mode_name = state.MODES[state.current_mode] or state.current_mode,
                scores = state.scores,
                threshold = state.threshold
            }
        end,
        toggle = function()
            state.enabled = not state.enabled
        end,
        reset = function()
            state:reset_scores()
        end,
        reset_all = function()
            state:reset_all()
        end
    })

    -------------------------------------------------------------------------------
    -- mpv 事件和按键绑定
    -------------------------------------------------------------------------------

    -- 监听字幕轨道切换
    mp.observe_property("sid", "string", function(_, value)
        local subtitle_track = utils.get_subtitle_fingerprint(value)
        if subtitle_track ~= state.last_subtitle_track then
            state:switch_to(subtitle_track)
            menu:maybe_refresh()
        end
    end)

    -- 监听视频加载
    mp.register_event("start-file", function()
        state:reset_all()
    end)

    -- 快捷键绑定
    mp.add_key_binding("alt+m", "bilingual_filter_toggle_filter_menu", function()
        menu:toggle()
    end)
end

return M
