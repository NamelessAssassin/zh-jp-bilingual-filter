local AssStyler = {
    parts = {} -- 存储生成的 ASS 片段
}

-- 预设颜色常量（RRGGBB 格式）
AssStyler.colors = {
    green = "98E3A1", -- 薄荷绿
    yellow = "F4D688", -- 琥珀黄
    red = "F48282", -- 珊瑚红
    white = "EEEEEE", -- 象牙白
    sep = "666666", -- 分割线深灰
    hint = "B0B0B0" -- 提示石墨灰
}

-- 预设字号常量（像素）
AssStyler.font_sizes = {
    title = 34, -- 标题字号
    stat = 24, -- 统计信息字号
    hint = 16, -- 提示文字字号
    default = 24, -- 默认字号
    mini = 12, -- 极小字号（用于留白）
    micro = 10 -- 微字号（用于留白微调）
}

-- 对齐方式常量（ASS 标准：1=左下，2=中下，3=右下，4=左中，5=居中，6=右中，7=左上，8=中上，9=右上）
AssStyler.align = {
    bottom_left = 1,
    bottom_center = 2,
    bottom_right = 3,
    middle_left = 4,
    center = 5,
    middle_right = 6,
    top_left = 7,
    top_center = 8,
    top_right = 9
}

-- 默认样式配置（全部使用预设常量）
AssStyler.defaults = {
    font_name = "DengXian",
    font_size = AssStyler.font_sizes.default, -- 默认字体大小
    color = AssStyler.colors.white, -- 默认字体颜色
    align = AssStyler.align.top_left, -- 默认对齐方式
    pos_x = 20, -- 默认 X 坐标
    pos_y = 80 -- 默认 Y 坐标
}

-- 创建新实例
function AssStyler:new()
    local instance = {
        parts = {}
    }
    setmetatable(instance, self)
    self.__index = self

    instance:align(self.defaults.align)
    instance:pos(self.defaults.pos_x, self.defaults.pos_y)
    instance:font_name(self.defaults.font_name)
    instance:font_size(self.defaults.font_size)

    return instance
end

-- 添加纯文本（不附加任何样式）
function AssStyler:append(text)
    table.insert(self.parts, tostring(text))
    return self
end

-- 设置位置（像素坐标）
function AssStyler:pos(x, y)
    return self:append(string.format("{\\pos(%d,%d)}", x, y))
end

-- 设置对齐方式（使用 align 常量）
function AssStyler:align(mode)
    return self:append(string.format("{\\an%d}", mode))
end

-- 设置字体大小（使用 font_sizes 常量）
function AssStyler:font_size(size)
    return self:append(string.format("{\\fs%d}", size))
end

-- 设置字体名称
function AssStyler:font_name(name)
    return self:append(string.format("{\\fn%s}", name))
end

-- 设置主要颜色（使用 colors 常量，输入 RRGGBB，自动转换为 ASS 的 BGR 格式）
function AssStyler:color(hex)
    local r = hex:sub(1, 2)
    local g = hex:sub(3, 4)
    local b = hex:sub(5, 6)
    return self:append(string.format("{\\1c&H%s%s%s&}", b, g, r))
end

-- 彩色文本块：用指定颜色包裹文本，之后恢复为默认颜色
function AssStyler:colored(color_hex, text)
    self:color(color_hex)
    self:append(text)
    self:color(AssStyler.defaults.color) -- 恢复默认颜色
    return self
end

-- 指定字号的文本块
function AssStyler:with_font(size, text)
    self:font_size(size)
    self:append(text)
    self:font_size(AssStyler.defaults.font_size) -- 恢复默认字号
    return self
end

-- 粗体文本块：用粗体包裹文本，之后关闭粗体
function AssStyler:bold(text)
    self:append("{\\b700}")
    self:append(text)
    self:append("{\\b0}")
    return self
end

-- 斜体文本块
function AssStyler:italic(text)
    self:append("{\\i1}")
    self:append(text)
    self:append("{\\i0}")
    return self
end

-- 插入换行符（硬换行）
function AssStyler:newline()
    return self:append("\\N")
end

-- 插入空格（可指定数量）
function AssStyler:spaces(count)
    count = count or 4
    return self:append(string.rep("\\h", count))
end

-- 绘制水平线（基于 ASS 绘图）
-- width: 线宽（像素，默认400），thickness: 线粗（像素，默认1）
function AssStyler:hline(width, thickness)
    width = width or 400
    thickness = thickness or 1
    -- 绘图命令：从 (0,0) 到 (width,0) 到 (width, thickness) 到 (0, thickness) 闭合，形成实心矩形
    local cmd = string.format("{\\p1}m 0 0 l %d 0 l %d %d l 0 %d{\\p0}", width, width, thickness, thickness)
    return self:append(cmd)
end

-- 生成最终的 ASS 字符串
function AssStyler:build()
    return table.concat(self.parts)
end

return AssStyler
