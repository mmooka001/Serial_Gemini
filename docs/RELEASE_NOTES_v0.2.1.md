# Gemini Serial v0.2.1

## 更新内容

- 修复光标停在指令名称或正文上时，鼠标滚轮无法滚动指令列表的问题：滚轮统一由外层列表处理。
- 保留指令文字编辑、拖选，以及长按排序交互。
- 更新仓库与发布页的界面截图，展示新版最大化及窗口布局。

## 新版界面

### 最大化布局

![Gemini Serial v0.2.1 最大化布局](https://raw.githubusercontent.com/mmooka001/Serial_Gemini/v0.2.1/docs/images/gemini-serial-v0.2.1-maximized.png)

### 窗口布局

![Gemini Serial v0.2.1 窗口布局](https://raw.githubusercontent.com/mmooka001/Serial_Gemini/v0.2.1/docs/images/gemini-serial-v0.2.1-windowed.png)

## 下载与运行

- Windows 10 / Windows 11 x64。
- 下载 `Gemini-Serial-v0.2.1-win64.zip`，完整解压后运行 `GeminiSerial.exe`，无需安装 Qt。
- 保持 EXE 与附带 DLL、qml、platforms 等目录在一起。
- 附件包含 ZIP、SHA-256 校验文件及上述两张原始截图。
- 指令和设置沿用系统应用数据目录，压缩包不附带个人指令、日志或测试文件。

本次完成 Release 编译与依赖打包核对，未重新执行完整功能回归。
