# 中日双语提取日语字幕

本插件为 `mpv` 插件 `mpvacious` 的自定义脚本，专用于从 **中日双语字幕** 中提取 **日语字幕** 。

默认提取包含假名的日语行，无法识别时，可根据统计数据，提取顶部或底部的日语行，并配备交互菜单，可实时查看字幕识别状态，以及手动开关。

> **注意**：本脚本依赖 `mpvacious` 的 `custom_subtitle_filter` 扩展接口。请务必确保您安装的 `mpvacious` 为支持此功能的最新版本，否则脚本将无法加载。

---

## 核心功能

* **智能位置锁定**：自动分析字幕结构，通过分值累计逻辑自动判定日语位置（顶部、底部或单语模式）。
* **动态语言感知**：通过假名检测（Kana Detection）精准区分日语与非日语行。
* **高级交互菜单**：提供一个半透明的 ASS 叠加面板，通过琥珀黄（检测中）、薄荷绿（已就绪）、珊瑚红（停用）三种高级配色实时反馈状态。
* **配置深度集成**：完全支持 `mpvacious` 的 Profile 切换，仅在用户定义的特定模式下激活，确保多语言观影互不干扰。
* **自动状态重置**：切换字幕轨道或更换视频文件时，统计数据会自动归零重新检测，无需手动干预。

---

## 安装与使用

### 1. 获取插件

可以选择以下任意一种方式获取插件：

* **方式 一：通过 Git 安装（推荐）**
在 mpv的 `scripts` 目录下运行：
```bash
git clone https://github.com/NamelessAssassin/jp-filter-for-mpvacioius.git mpvacious_custom_subtitle_filter
```

* **方式 二：手动安装**
1. 在 GitHub 页面点击 `Code` -> `Download ZIP`。
2. 解压后，将文件夹重命名为 `mpvacious_custom_subtitle_filter`。

* **方式 三：与其他自定义脚本一起安装（折腾版）**

    <details>
    <summary>点击查看详情</summary>

    同时安装多个自定义脚本的思路在于，将本脚本作为一个模块导入`custom_subtitle_filter.lua`文件，这样便可根据喜好随意切换载入的脚本。

    > **注意**：不同的脚本可能存在按键冲突，请自行修改按键绑定，或者在相关脚本里修改相关按键，或者修改按键激活条件。

    安装方法：
    1. 在 `mpvacious_custom_subtitle_filter` 目录（而非`scripts`目录下），执行：
    ```bash
    git clone https://github.com/NamelessAssassin/jp-filter-for-mpvacioius.git jp-filter-for-mpvacioius
    ```
    2. 在 `mpvacious_custom_subtitle_filter` 目录创建空白的 `main.lua` 文件。
    3. 在 `mpvacious_custom_subtitle_filter` 目录下创建`custom_subtitle_filter.lua`文件，将以下代码写入该文件，保存：

    ```lua
    local japanese = require("jp-filter-for-mpvacioius/custom_subtitle_filter")

    local M = {}

    local get_current_mode = function()
        return nil
    end

    M.preprocess = function(text)
        if get_current_mode() == "japanese" then
            return japanese.preprocess(text)
        end

        return text
    end

    M.init = function(config)
        if type(config.get_mode) == "function" then
            get_current_mode = config.get_mode
        end

        if japanese.init then
            japanese.init(config)
        end
    end

    return M
    ```
    </details>

### 2. 放置路径

本插件文件夹 **必须** 与 `mpvacious` 存放在同一个 `scripts` 目录下，且文件夹名称 **必须** 为 `mpvacious_custom_subtitle_filter`。

| 操作系统             | 插件存放路径                                |
| ------------------- | ------------------------------------------ |
| **GNU/Linux**       | `~/.config/mpv/scripts/`                   |
| **Windows**         | `%APPDATA%/mpv/scripts/`                   |
| **Windows (便携版)** | `mpv.exe所在目录/portable_config/scripts/` |

### 3. 文件结构

本插件文件夹内包含以下文件：

```text
mpvacious_custom_subtitle_filter/
├── main.lua                   # 占位文件
├── custom_subtitle_filter.lua # 核心业务逻辑与接口实现
├── filter_menu.lua            # UI 交互菜单与按键管理
├── state.lua                  # 全局状态与分值管理
└── utils.lua                  # 假名检测等基础工具函数
```

## 配置多语言切换

`mpvacious` 支持 [**Profile（多语言配置）**](https://github.com/Ajatt-Tools/mpvacious/blob/master/README.md#profiles) 功能，允许你针对不同的学习语言（如日语、英语、德语）维护多套独立的配置。

<details>

<summary>点击查看详情</summary>

### 什么是 Profile？

如果你同时学习多种语言，你可以通过 Profile 快速切换 Deck 名称、模型字段以及本脚本的开关状态。

* **默认配置**：脚本中 `custom_subtitle_filter_mode` 的默认值即为 `japanese`。如果你只学习日语，通常无需额外修改。
* **按需开启**：对于多语种学习者，你可以设置仅在切换到日语 Profile 时才激活此过滤脚本，而在学习其他语言时保持关闭。

### 如何设置多语言 Profile？

1. **定义 Profile 列表**：在 `subs2srs.conf` 同级目录下创建 `subs2srs_profiles.conf`，定义你所需语言的配置名称：
```conf
profiles=subs2srs,english,german
active=subs2srs
```

2. **创建独立配置文件**：为每个 Profile 创建对应的 `.conf` 文件（例如 `english.conf`）。新建的配置文件中，只需填写与默认配置不同的设置项。
3. **针对性开启过滤器**：
* 在 **日语配置** (`subs2srs.conf`) 中保持默认或显式设置：
```conf
# 只有此项为 japanese 时，脚本才会激活逻辑
custom_subtitle_filter_mode=japanese
```

* 在 **英语配置** (`english.conf`) 中将其禁用：
```conf
custom_subtitle_filter_mode=none
```

### 如何切换 Profile？

* 在播放器中按下 <kbd>a</kbd> 进入高级菜单。
* 按下 <kbd>p</kbd> 循环切换不同的 Profile。
* 你可以在菜单底部的状态栏实时看到当前激活的是哪一个配置。

> **提示**：本脚本会自动监听 Profile 的切换。一旦你从 `english` 切换回 `subs2srs` (日语)，过滤器将根据 `custom_subtitle_filter_mode` 的值自动恢复工作。

</details>

---

## 交互菜单

按下快捷键即可唤起沉浸式菜单。菜单采用了极简主义设计，确保在不遮挡画面的前提下提供关键数据：

* **状态行**：显示当前判定的日文位置及工作状态。
* **统计行**：展示 `顶部`、`底部`、`单语` 三个维度的累计得分。
* **视觉反馈**：
    * 🟡 **琥珀黄**：正在自动检测位置，尚未达到锁定阈值。
    * 🟢 **薄荷绿**：识别完成，已锁定日语位置并开始过滤。
    * 🔴 **珊瑚红**：当前 Profile 不支持或过滤器已手动关闭。

---

## 快捷键

本脚本在菜单开启期间接管部分按键，关闭后自动释放。

| 快捷键      | 功能描述                      | 作用范围   |
| ----------- | ---------------------------- | --------- |
| **Alt + m** | 开启 / 关闭控制菜单           | 全局有效   |
| **o**       | 切换过滤器的开启或关闭状态     | 仅限菜单内 |
| **r**       | 重置所有统计分值并重新开始检测 | 仅限菜单内 |
| **Esc**     | 立即退出并关闭菜单界面        | 仅限菜单内 |