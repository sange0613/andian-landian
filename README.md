# 暗淡蓝点

暗淡蓝点是一个极简桌面番茄钟，当前发布版支持 macOS Apple Silicon。

## 下载

前往 Releases 下载最新版：

https://github.com/sange1022/andian-landian/releases

当前 macOS 安装包：`andian-landian-1.0.11-arm64.dmg`

## 安装

1. 下载 `.dmg` 文件。
2. 打开 `.dmg`，把 `暗淡蓝点.app` 拖到 `Applications`。
3. 如果 macOS 提示无法验证开发者，右键点击 App 选择“打开”，或到系统设置的安全性里允许打开。

## 使用说明

- 启动后，状态栏会显示蓝点和剩余分钟数。
- 桌面上会出现一个克莱因蓝圆点。
- 左键按住桌面圆点可以拖动位置。
- 双击桌面圆点可以开始或暂停。
- 状态栏左键双击也可以开始或暂停。
- 状态栏右键打开菜单。
- 桌面圆点右键打开菜单。
- 右键菜单可隐藏桌面蓝点；隐藏后倒计时继续，可从状态栏右键恢复。
- Windows 上关闭主窗口会隐藏到右下角系统托盘，倒计时继续；单击托盘图标可恢复。
- 需要完全退出时，使用右键菜单中的 `Quit`。
- 设置里有 `5 / 25 / 45` 分钟快捷按钮。
- 设置里也可以输入自定义时间，范围是 `1-180` 分钟。
- 开始计时后，蓝点会变成半透明。
- 时间到后，状态栏会闪烁，系统会响一声，桌面圆点会放大提醒。
- 时间到后，需要连续点击圆点 3 下才会取消提醒。

## 注意

- 当前 release 是 `arm64`，适合 M 系列 Mac。
- 当前版本未做 Apple Developer ID 签名，所以第一次打开可能需要手动允许。
- GitHub release 提供 Windows 10 x64 和 Mac ARM64 安装包。

## Development

```bash
npm install
npm test
npm start
```

If Electron download is slow in China, install with:

```bash
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm install
```

## Build Installers

```bash
npm run make:icon
npm run dist:win
npm run dist:mac
```

The installers are written to `dist/`.
