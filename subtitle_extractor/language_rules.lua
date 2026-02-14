local utils = require('utils')

local M = {}

-- 菜单中相应配置所对应显示的文字
M.LANGUAGE_MAP = {
    japanese = "日文",
    korean = "韩文",
    english = "英文",
    french = "法文",
    german = "德文",
    russian = "俄文",
    spanish = "西文",
    arabic = "阿文",
    italian = "意文",
    others = "外文"
}

-- 自定义语言规则
-- 函数名与`sub2srs.conf`中`custom_subtitle_filter_mode`项的值一致
-- 函数名请使用小写字母
local rules = {
    -- 日语匹配：检查是否包含假名
    japanese = function(line)
        return utils.contains_kana(line)
    end,

    -- 韩文匹配：检查是否包含谚文
    korean = function(line)
        return utils.contains_hangul(line)
    end,

    -- 默认语言检测函数
    others = function(line)
        return not utils.contains_cjk(line)
    end
}

M.get_rule = function(profile_mode)
    local mode = nil
    if profile_mode then
        mode = profile_mode:lower()
    end

    local selected_rule = rules[mode]

    if selected_rule then
        return selected_rule
    else
        return rules["others"]
    end
end

return M
