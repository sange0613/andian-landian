# Windows Close To Tray Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the Windows timer running when its main window is closed by hiding it to the system tray, with reliable restoration and a real Quit path.

**Architecture:** Put platform lifecycle decisions in pure functions covered by Node tests. Electron `main.js` applies those decisions to the main window and tray while retaining the existing renderer-owned timer.

**Tech Stack:** Electron, CommonJS, `node:test`, electron-builder NSIS

---

### Task 1: Lifecycle Decisions

**Files:**
- Create: `src/windowLifecycle.js`
- Create: `test/windowLifecycle.test.js`

- [ ] **Step 1: Write failing close and tray action tests**

```js
const test = require("node:test");
const assert = require("node:assert/strict");
const { getMainWindowCloseAction, getWindowsTrayClickAction } = require("../src/windowLifecycle");

test("ordinary Windows close hides the timer", () => {
  assert.equal(getMainWindowCloseAction("win32", false), "hide");
});

test("real quit and non-Windows close are allowed", () => {
  assert.equal(getMainWindowCloseAction("win32", true), "close");
  assert.equal(getMainWindowCloseAction("darwin", false), "close");
});

test("Windows tray click restores a hidden timer before other actions", () => {
  assert.equal(getWindowsTrayClickAction(false, "running"), "show");
  assert.equal(getWindowsTrayClickAction(false, "finished"), "show");
  assert.equal(getWindowsTrayClickAction(true, "running"), "toggle");
  assert.equal(getWindowsTrayClickAction(true, "finished"), "finish-click");
});
```

- [ ] **Step 2: Run `node --test test/windowLifecycle.test.js` and confirm missing-module failure**

- [ ] **Step 3: Implement the minimum pure functions**

```js
function getMainWindowCloseAction(platform, isQuitting) {
  return platform === "win32" && !isQuitting ? "hide" : "close";
}

function getWindowsTrayClickAction(isVisible, status) {
  if (!isVisible) return "show";
  return status === "finished" ? "finish-click" : "toggle";
}

module.exports = { getMainWindowCloseAction, getWindowsTrayClickAction };
```

- [ ] **Step 4: Re-run the focused test and confirm all cases pass**

### Task 2: Electron Integration

**Files:**
- Modify: `src/main.js`
- Modify: `README.md`

- [ ] **Step 1: Track `isQuitting` and set it from `app.on("before-quit")`**

- [ ] **Step 2: Add a Windows main-window `close` listener**

Use `getMainWindowCloseAction(process.platform, isQuitting)`. For `hide`, call `event.preventDefault()` and `toggleMainWindowVisibility("hide")`; otherwise allow close.

- [ ] **Step 3: Restore hidden Windows blue dots on tray click**

Before the existing finished/toggle handling, call `getWindowsTrayClickAction(mainWindow.isVisible(), latestTimerState.status)`. Apply `show`, `finish-click`, or `toggle` without changing the macOS double-click path.

- [ ] **Step 4: Document that Windows system close hides to tray and Quit exits**

- [ ] **Step 5: Run `npm test` and confirm the complete suite passes**

### Task 3: Windows Release

**Files:**
- Modify: `package.json`
- Modify: `package-lock.json`
- Generate: `dist/andian-landian-1.0.15-win-x64.exe`

- [ ] **Step 1: Run `npm version 1.0.15 --no-git-tag-version` and commit the version files**

- [ ] **Step 2: Build with `ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/ npm run dist:win`**

- [ ] **Step 3: Re-run `npm test`, confirm the unpacked app is PE32+ x86-64, and inspect the packaged version and lifecycle code from `app.asar`**

- [ ] **Step 4: Merge to `main`, copy the ASCII-named installer to the main `dist` directory, and open the directory**
