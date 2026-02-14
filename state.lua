local state = {
    enabled = true,
    MODES = {
        AUTO = "自动检测中...",
        JP_TOP = "顶部",
        JP_BOTTOM = "底部",
        MONO = "单语模式"
    },
    current_mode = "AUTO",
    threshold = 5,
    scores = {
        JP_TOP = 0,
        JP_BOTTOM = 0,
        MONO = 0
    }
}

function state:reset_scores()
    self.current_mode = "AUTO"
    self.scores.JP_TOP = 0
    self.scores.JP_BOTTOM = 0
    self.scores.MONO = 0
end

return state
