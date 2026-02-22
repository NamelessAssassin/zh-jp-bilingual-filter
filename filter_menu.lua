--- 字幕过滤器控制菜单
---
--- 这是一个为 mpvacious 设计的沉浸式交互面板，用于辅助日语字幕识别。
---
--- 核心功能
---     提供可视化界面显示当前日文位置的检测状态与统计数据
---     支持通过快捷键实时切换过滤器的开关状态或重置识别逻辑
---     在当前配置不支持日语处理时，通过颜色与文案给出明确视觉提示
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

local menu = {
    active = false,
    timeout = 10,
    timer = nil,
    overlay = mp.create_osd_overlay("ass-events"),
    style = {
        -- 核心样式：第一行统一使用大字号
        main_row = "{\\b1\\fs38}",
        -- 统计行：统一使用中字号
        stat_row = "{\\b0\\fs28}",
        -- 底部提示：石墨灰
        hint = "{\\fs20\\c&HB0B0B0&}",

        -- 高级配色方案
        green = "{\\c&H98E3A1&}", -- 薄荷绿 (已锁定位置)
        yellow = "{\\c&H88D6F4&}", -- 高级琥珀黄 (自动检测中)
        red = "{\\c&H8282F4&}", -- 珊瑚红 (关闭 或 配置不支持)
        white = "{\\c&HEEEEEE&}", -- 象牙白

        -- 分割线：莫兰迪深灰
        sep = "{\\c&H666666&}"
    }
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
        end
    }, {
        key = "R",
        fn = function()
            self.callbacks.reset_history()
            self:update()
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

    -- 逻辑判断：状态文案与颜色选择
    local theme_color = self.style.red -- 默认为红色
    local status_text = ""

    -- 根据模式标识符 info.current_mode 判断
    if not info.is_profile_active then
        status_text = "当前配置不支持"
    elseif not info.enabled then
        status_text = "过滤器已关闭"
    else
        -- 当过滤器开启且配置支持时，根据是否锁定分配颜色
        status_text = info.mode_name
        -- 使用模式代码进行判断
        if info.current_mode == "AUTO" then
            theme_color = self.style.yellow -- 琥珀黄
        else
            theme_color = self.style.green -- 薄荷绿
        end
    end

    -- 初始 ASS 标签：
    -- \an7: 定位在左上角
    -- \pos(20, 80): 距离左边 20 像素，距离顶部 80 像素（让开 OSD 位置）
    local ass = "{\\an7\\pos(20, 80)}"

    -- 第一行：日文位置状态
    ass = ass .. theme_color .. self.style.main_row .. "日文位置：" .. status_text .. "{\\b0}\\N"

    -- 视觉留白
    ass = ass .. "{\\fs16} \\N"

    -- 第二行：识别统计
    ass = ass .. self.style.white .. self.style.stat_row .. "识别统计："
    ass = ass ..
              string.format("顶部 %d  底部 %d  单语 %d  (目标 %d)\\N", info.scores.JP_TOP,
            info.scores.JP_BOTTOM, info.scores.MONO, info.threshold)

    -- 分割线与提示
    ass = ass .. "{\\fs12} \\N"
    ass = ass .. self.style.sep .. "------------------------------------------------------\\N"
    ass = ass .. "{\\fs10} \\N"
    ass = ass .. self.style.hint .. "[o] 开启/关闭   [r] 重置模式   [R] 重置历史   [esc/alt+m] 关闭"    

    self.overlay.data = ass
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
