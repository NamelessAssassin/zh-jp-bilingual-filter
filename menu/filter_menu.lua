--- 字幕过滤器控制菜单
---
--- 这是一个为 mpvacious 设计的沉浸式交互面板，用于辅助外语字幕识别。
---
--- 核心功能
---     提供可视化界面显示当前外文位置的检测状态与统计数据
---     支持通过快捷键实时切换过滤器的开关状态或重置识别逻辑
---     在当前配置不支持处理时，通过颜色与文案给出明确视觉提示
---
--- 交互逻辑
---     [o] 开启或关闭过滤器
---     [r] 重置所有识别统计数据
---     [esc/alt+m] 立即退出菜单界面
---
--- 设计特点
---     采用动态色彩反馈：绿色表示就绪，黄色表示自动识别中，红色表示停用或配置不支持
---     针对 mpv 快捷键特性，使用括号包装小写字母以增强符号化视觉感
---     自动注销按键绑定，确保关闭面板后不占用任何系统快捷键
---
local mp = require('mp')
local utils = require('utils')
local ass_styler = require('menu.ass_styler')

local LANGUAGE_MAP = require('subtitle_extractor.language_rules').LANGUAGE_MAP

local menu = {
    active = false,
    timeout = 10,
    timer = nil,
    overlay = mp.create_osd_overlay("ass-events")
}

-- 按键绑定表
function menu:get_bindings()
    return {{
        key = "o",
        fn = function()
            self.callbacks.toggle()
            self:update()
        end
    }, {
        key = "r",
        fn = function()
            self.callbacks.reset()
            self:update()
            utils.notify("字幕模式已重置")
        end
    }, {
        key = "R",
        fn = function()
            self.callbacks.reset_all()
            self:update()
            utils.notify("历史记录已重置")
        end
    }, {
        key = "q",
        fn = function()
            self:close()
        end
    }, {
        key = "ESC",
        fn = function()
            self:close()
        end
    }}
end

-- 获取自动生成的按键 ID 格式
function menu:get_binding_id(key)
    return "custom_filter_menu_" .. key
end

function menu:setup(callbacks)
    self.callbacks = callbacks
end

function menu:update()
    if not self.active then
        return
    end

    local info = self.callbacks.get_info()

    -- 确定状态文字和主题颜色
    local status_prefix_text = (LANGUAGE_MAP[info.current_profile_mode] or "外文") .. "位置："

    local theme_color
    local status_text = ""

    if not info.is_profile_active then
        status_text = "当前配置不支持"
        theme_color = ass_styler.colors.red
    elseif not info.enabled then
        status_text = "过滤器已关闭"
        theme_color = ass_styler.colors.red
    else
        status_text = info.mode_name
        theme_color = (info.current_mode == "AUTO") and ass_styler.colors.yellow or ass_styler.colors.green
    end

    status_text = status_prefix_text .. status_text

    -- 创建样式构建器
    local styler = ass_styler:new()

    -- 第一行：日文位置状态（整体主题色 + 粗体）
    styler:font_size(ass_styler.font_sizes.title):color(theme_color):bold(status_text):newline()

    -- 视觉留白（空行）- 使用极小字号实现紧凑留白
    styler:font_size(ass_styler.font_sizes.mini):append(" "):newline()

    -- 第二行：识别统计（默认颜色，正常字体）
    styler:font_size(ass_styler.font_sizes.stat):color(ass_styler.colors.white):append(string.format(
        "识别统计：顶部 %d  底部 %d  单语 %d  (目标 %d)", info.scores.JP_TOP, info.scores.JP_BOTTOM,
        info.scores.MONO, info.threshold)):newline()

    -- 分割线前留白
    styler:font_size(ass_styler.font_sizes.micro):append(" "):newline()

    -- 绘制分割线
    styler:font_size(ass_styler.font_sizes.hint):color(ass_styler.colors.sep):append(string.rep("—", 24)):newline()

    -- 提示行前留白
    styler:font_size(ass_styler.font_sizes.micro):append(" "):newline()

    -- 底部提示（提示色，较小字体）
    styler:font_size(ass_styler.font_sizes.hint):color(ass_styler.colors.hint):append(
        "[o] 开启/关闭   [r] 重置模式   [R] 重置历史   [q/esc] 退出")

    -- 更新 OSD
    self.overlay.data = styler:build()
    self.overlay:update()

    -- 自动关闭计时器
    if self.timer then
        self.timer:kill()
    end
    self.timer = mp.add_timeout(self.timeout, function()
        self:close()
    end)
end

function menu:maybe_refresh()
    if self.active then
        self:update()
    end
end

function menu:toggle()
    if self.active then
        self:close()
    else
        self:open()
    end
end

function menu:open()
    if self.active then
        return
    end
    self.active = true

    -- 自动化注册：使用 get_binding_id 动态生成 ID
    for _, b in ipairs(self:get_bindings()) do
        mp.add_forced_key_binding(b.key, self:get_binding_id(b.key), b.fn)
    end

    self:update()
end

function menu:close()
    if not self.active then
        return
    end
    self.active = false

    -- 自动化注销：使用同样的 get_binding_id 进行清理
    for _, b in ipairs(self:get_bindings()) do
        mp.remove_key_binding(self:get_binding_id(b.key))
    end

    self.overlay:remove()
    if self.timer then
        self.timer:kill()
    end
end

return menu
