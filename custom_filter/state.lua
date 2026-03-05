local utils = require('custom_filter.utils')

local state = {
    enabled = true,
    MAX_HISTORY_SIZE = 10, -- 配置：历史记录最大条目数
    MODES = {
        AUTO = "自动检测中...",
        TARGET_TOP = "顶部",
        TARGET_BOTTOM = "底部",
        MONO = "单语模式"
    },
    current_mode = "AUTO",
    threshold = 5, -- 锁定位置所需的匹配次数阈值
    scores = {
        TARGET_TOP = 0,
        TARGET_BOTTOM = 0,
        MONO = 0
    },
    last_subtitle_track = nil,
    history = nil -- 将初始化为环形缓冲区
}

-- 初始化历史记录为环形缓冲区
state.history = utils.create_ring_buffer(state.MAX_HISTORY_SIZE)

function state:toggle()
    self.enabled = not self.enabled
end

function state:get_current_mode_name()
    return self.MODES[self.current_mode] or self.current_mode
end

function state:reset_scores()
    self.current_mode = "AUTO"
    self.scores.TARGET_TOP = 0
    self.scores.TARGET_BOTTOM = 0
    self.scores.MONO = 0
end

function state:get_current_data()
    return {
        current_mode = self.current_mode,
        scores = {
            TARGET_TOP = self.scores.TARGET_TOP,
            TARGET_BOTTOM = self.scores.TARGET_BOTTOM,
            MONO = self.scores.MONO
        }
    }
end

function state:restore_data(data)
    self.current_mode = data.current_mode
    self.scores.TARGET_TOP = data.scores.TARGET_TOP
    self.scores.TARGET_BOTTOM = data.scores.TARGET_BOTTOM
    self.scores.MONO = data.scores.MONO
end

function state:save_history()
    if self.last_subtitle_track then
        self.history:set(self.last_subtitle_track, self:get_current_data())
    end
end

function state:switch_to(subtitle_track)
    self:save_history()

    local cached_data = self.history:get(subtitle_track)
    if subtitle_track and cached_data then
        self:restore_data(cached_data)
    else
        self:reset_scores()
    end

    self.last_subtitle_track = subtitle_track
end

function state:reset_all()
    self.history:clear()
    self.last_subtitle_track = nil
    self:reset_scores()
end

return state
