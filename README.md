# 🫧 Context Gauge

一个极简的 Claude Code 上下文窗口指示器——就像汽车的油表，用光环告诉你对话还剩多少空间。

<p align="center">
  <img src="docs/screenshot.png" alt="Context Gauge Screenshot" width="160">
</p>

## 设计理念

屏幕右下角一个 80×80 的半透明光环，安静地显示上下文使用情况。上下文越多，光环越短；越接近极限，颜色越红。不需要交互，余光一瞥就知道该不该 compact。

| 剩余 | 颜色 | 感觉 |
|------|------|------|
| 60–100% | `#58A6FF` 蓝 | 空间充裕，放心聊 |
| 30–60% | `#F0883E` 橙 | 过半了，留意一下 |
| 0–30% | `#F85149` 红 | 快满了，赶紧 compact |
| 压缩中 | `#9944FF` 紫 | 正在整理上下文 |

光环采用 3 层渲染（外层光晕 → 中间过渡 → 内核主线），状态切换平滑过渡。中央显示剩余百分比。

## 工作原理

```
Claude Code → statusLine Hook → %TEMP%/claude-context-gauge.json
                                ↓
                          Tauri 应用 (150ms 轮询)
                                ↓
                          Canvas 2D 渲染
```

- **statusLine Hook**: 接收 Claude Code 会话 JSON，提取 `context_window.remaining_percentage`，写入临时文件
- **事件 Hook**: 处理生命周期（compacting / stopped）
- **Tauri + Canvas**: 透明置顶窗口，动画光环渲染

## 构建

```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 安装 Tauri CLI
cargo install tauri-cli

# 构建
cd src-tauri
cargo build --release
# 输出: src-tauri/target/release/context-gauge.exe
```

## Hook 配置

在 `~/.claude/settings.json` 中注册：

| 事件 | 动作 |
|------|------|
| `statusLine` | 写入上下文百分比 |
| `SessionStart` | 启动 gauge + 设 idle |
| `PreCompact` | 设 compacting 状态 |
| `Stop` | 设 stopped 状态 |

## 技术栈

- **Tauri 2** — 轻量跨平台桌面壳
- **Canvas 2D** — 3 层光环渲染 + 平滑过渡
- **PowerShell** — Claude Code Hook 脚本
- **Rust** — 状态机 + 文件轮询

## 与 Claude Halo 共存

Context Gauge 的位置在 Halo 上方（`screen_height - 80 - 240` vs Halo 的 `screen_height - 100 - 140`），两者共享 hook 事件，互不影响。

## License

MIT
