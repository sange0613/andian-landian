# 暗淡蓝点 Windows 原生版

这是使用 C++17、Win32 和 Windows 自带 GDI+ 的轻量版，无需 Electron、.NET 或额外运行库。
支持 Windows 10 / 11 x64，保留蓝点、剩余分钟数、拖动、双击开始/暂停/继续、托盘、简洁设置、5/25/45 分钟、自定义 1-180 分钟、重置、隐藏/显示、关闭缩到托盘、到点声音与 3 倍放大、三次点击取消，以及设置中的作者“戌無营造”。

详细操作见 [使用说明](使用说明.txt)。菜单使用英文，产品名称和作者保留原名称。

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
`DimBlueDot-1.1.0-Win10-x64-Setup.exe` 是安装包。
构建中间文件和测试程序不随安装包分发。
`build-report.json` 记录准确大小、SHA-256、导入的系统 DLL；
构建检查会拒绝额外运行库，且限制程序在 5MB 内、安装包在 2MB 内。

本地 MinGW 首轮实测：主程序 91,136 字节，安装包 114,233 字节。
最终产物的准确数值以构建报告为准。MSVC 产物大小可能不同。

## 验证

`tests/logic_test.cpp` 可在 Mac / Windows 编译运行，覆盖计时截止时间、
睡眠后到期、暂停续计、时间校验、三次点击、双击与拖动。
`tests/window_test.cpp` 使用真实 Win32 窗口、设置控件和消息验证交互，
包括自定义输入不被定时刷新覆盖、关窗不退出、到期放大和快速三击。
`tests/install-test.ps1` 实际安装、启动、关闭缩到托盘、退出和卸载。
GitHub Actions 使用 Windows runner 执行上述验证，上传安装包，
不会自动创建 Release。
