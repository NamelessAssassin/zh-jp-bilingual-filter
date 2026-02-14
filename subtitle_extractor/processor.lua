utils = require('utils')

local M = {}

-- 动态注入的语言判定函数
local check_lang = function(line)
    return false
end

M.set_rule = function(fn)
    check_lang = fn
end

local function update_scores(lines, state, menu)
    if not state.enabled or state.current_mode ~= "AUTO" then
        return
    end

    if not lines or #lines < 1 or #lines > 2 then
        return
    end

    -- 判定位置：顶部、底部或单语
    if #lines == 1 then
        key = "MONO"
    else
        local h1 = check_lang(lines[1])
        local h2 = check_lang(lines[2])
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
        utils.notify("锁定位置：" .. state.MODES[key])
    end
    menu:maybe_refresh()
end

-- 核心提取逻辑
function M.process(text, state, menu)
    local lines = utils.split_lines(text)

    update_scores(lines, state, menu)

    if #lines <= 1 then
        return text
    end

    -- 基于语言特征提取
    local target_lines = {}
    for _, line in ipairs(lines) do
        if check_lang(line) then
            table.insert(target_lines, line)
        end
    end

    -- 回退机制：若未匹配到特征但已锁定模式，按位置提取
    if #target_lines == 0 and state.current_mode ~= "AUTO" then
        if state.current_mode == "JP_TOP" then
            table.insert(target_lines, lines[#lines - 1])
        elseif state.current_mode == "JP_BOTTOM" then
            table.insert(target_lines, lines[#lines])
        end
    end

    if #target_lines > 0 then
        return table.concat(target_lines, "\n")
    else
        return text
    end
end

return M
