# 暗淡蓝点 Windows 原生版

这是使用 C++17、Win32 和 Windows 自带 GDI+ 的轻量版，无需 Electron、.NET 或额外运行库。
支持 Windows 10 / 11 x64，保留蓝点、剩余分钟数、拖动、双击开始/暂停/继续、托盘、简洁设置、5/25/45 分钟、自定义 1-180 分钟、重置、隐藏/显示、关闭缩到托盘、到点声音与 3 倍放大、三次点击取消，以及设置中的作者“戌無营造”。

详细操作见 [使用说明](使用说明.txt)。1.1.1 版的菜单、设置、通知及安装卸载界面均为简体中文。
设置底部显示“作者：戌無营造”，程序和安装包属性也使用这一署名。

中文版 1.1.1 的 Windows 验证产物在 `dist/暗淡蓝点-Win10-中文轻量版-1.1.1/`。
安装包 161,068 字节（约 157KB），安装目录共 271,500 字节（约 265KB）。
中文作者控件、程序属性署名、计时交互、安装、启动和卸载检查均通过。
[Windows 验证记录](https://github.com/sange1022/andian-landian/actions/runs/38335176786)。

## 构建

Mac 上安装 MinGW-w64 和 NSIS 后，可本地交叉编译：

```sh
brew install mingw-w64 nsis
sh native-win/build.sh
```

Windows 上安装 Visual Studio C++ 工具、Node.js、NSIS，在 Developer PowerShell 中运行：

```powershell
./native-win/build.ps1
./native-win/tests/install-test.ps1
```

输出在 `dist/native-win/`：`DimBlueDot.exe` 是免安装程序，
`DimBlueDot-1.1.1-Win10-x64-Setup.exe` 是安装包。
构建中间文件和测试程序不随安装包分发。
`build-report.json` 记录准确大小、SHA-256、导入的系统 DLL；
构建检查会拒绝额外运行库，且限制程序在 5MB 内、安装包在 2MB 内。

本地 MinGW 首轮实测：主程序 91,136 字节，安装包 114,233 字节。
最终产物的准确数值以构建报告为准。MSVC 产物大小可能不同。

1.1.0 版的 Windows 验证记录：安装包 160,964 字节（约 157KB），
程序 198,656 字节（约 194KB），安装目录包含卸载程序共 271,516 字节（约 265KB）。
对应 Windows 构建与验证：[run 38097249105](https://github.com/sange1022/andian-landian/actions/runs/38097249105)。
这份验证后的安装包与免安装程序在 `dist/暗淡蓝点-Win10-轻量版/`，
附有 `build-report.json` 大小及校验报告。验证平台是 Windows NT 10.0.26100.0，
尚未在 Windows 10 真机验证。

## 验证

`tests/logic_test.cpp` 可在 Mac / Windows 编译运行，覆盖计时截止时间、
睡眠后到期、暂停续计、时间校验、三次点击、双击与拖动。
`tests/window_test.cpp` 使用真实 Win32 窗口、设置控件和消息验证交互，
包括自定义输入不被定时刷新覆盖、关窗不退出、到期放大和快速三击。
`tests/install-test.ps1` 实际安装、启动、关闭缩到托盘、退出和卸载。
GitHub Actions 使用 Windows runner 执行上述验证，上传安装包，
不会自动创建 Release。
