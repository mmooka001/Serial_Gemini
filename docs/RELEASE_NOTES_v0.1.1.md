# Gemini Serial v0.1.1

## 更新内容

- 修复指令库导出失败的问题。
- 指令库默认导出名改为 `指令 yyyyMMddhhmmss.json`。
- 对话记录默认导出名改为 `对话记录 yyyyMMddhhmmss.csv`。
- 数据终端和发送框之间支持上下拖动调整大小。
- 发布版启动优化：首屏创建后再刷新串口列表，避免启动时同步枚举串口拖慢界面。
- 单配置构建默认使用 Release。

## 系统支持

- Windows 10 / Windows 11 x64。
- 当前版本基于 Qt 6，不承诺 Windows 7 兼容。

## 下载

下载 `Gemini-Serial-v0.1.1-win64.zip`，解压后运行 `GeminiSerial.exe`。
