const { app, BrowserWindow, Menu, Tray, ipcMain, shell } = require("electron");
const path = require("node:path");
const { getMenuBarTitle } = require("./menuBar");
const { PRESET_DURATIONS } = require("./durations");
const { getDraggedWindowPosition } = require("./windowDrag");
const { getWindowVisibilityMenuItem } = require("./windowVisibility");
const { resizeBoundsAroundCenter } = require("./alertWindow");
const {
  getMainWindowCloseAction,
  getWindowsTrayClickAction
} = require("./windowLifecycle");

const NORMAL_WINDOW_SIZE = 112;
const ALERT_WINDOW_SIZE = NORMAL_WINDOW_SIZE * 3;

let mainWindow;
let settingsWindow;
let tray;
let latestTimerState = { remainingText: "25", status: "idle", dismissClicks: 0 };
let alertSoundPlayed = false;
let blinkVisible = true;
let blinkTimer;
let trayClickTimer;
let windowDrag;
let isQuitting = false;

function sendCommand(command, value) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("menu-command", { command, value });
  }
}

function sendTimerState(state) {
  const wasFinished = latestTimerState.status === "finished";
  const isFinished = state.status === "finished";
  latestTimerState = state;
  if (isFinished !== wasFinished) {
    setAlertWindowSize(isFinished);
  }
  if (isFinished && !wasFinished) {
    playFinishSound();
    startMenuBarBlink();
  }
  if (state.status !== "finished") {
    alertSoundPlayed = false;
    stopMenuBarBlink();
  }
  updateTrayTitle(state);
  if (settingsWindow && !settingsWindow.isDestroyed()) {
    settingsWindow.webContents.send("timer-state", state);
  }
}

function setAlertWindowSize(isAlerting) {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return;
  }

  const targetSize = isAlerting ? ALERT_WINDOW_SIZE : NORMAL_WINDOW_SIZE;
  const bounds = mainWindow.getBounds();
  if (bounds.width === targetSize && bounds.height === targetSize) {
    return;
  }

  mainWindow.setBounds(
    resizeBoundsAroundCenter(bounds, targetSize, targetSize),
    false
  );
}

function updateTrayTitle(state) {
  if (!tray) {
    return;
  }

  tray.setTitle(getMenuBarTitle(state, blinkVisible));
  tray.setToolTip(`暗淡蓝点 ${state.remainingText}`);
}

function playFinishSound() {
  if (alertSoundPlayed) {
    return;
  }

  alertSoundPlayed = true;
  shell.beep();
}

function startMenuBarBlink() {
  if (blinkTimer || !tray) {
    return;
  }

  blinkTimer = setInterval(() => {
    blinkVisible = !blinkVisible;
    updateTrayTitle(latestTimerState);
  }, 600);
}

function stopMenuBarBlink() {
  if (blinkTimer) {
    clearInterval(blinkTimer);
    blinkTimer = undefined;
  }
  blinkVisible = true;
}

function toggleMainWindowVisibility(action) {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return;
  }

  if (action === "hide") {
    mainWindow.hide();
  }
  if (action === "show") {
    mainWindow.show();
    mainWindow.focus();
  }

  if (tray && process.platform !== "darwin") {
    tray.setContextMenu(buildContextMenu());
  }
}

function buildContextMenu() {
  const visibilityItem = getWindowVisibilityMenuItem(
    Boolean(mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible())
  );

  return Menu.buildFromTemplate([
    {
      label: visibilityItem.label,
      click: () => toggleMainWindowVisibility(visibilityItem.action)
    },
    { type: "separator" },
    { label: "Settings", click: () => createSettingsWindow() },
    { type: "separator" },
    ...PRESET_DURATIONS.map((minutes) => ({
      label: `${minutes} minutes`,
      click: () => sendCommand("duration", minutes)
    })),
    { type: "separator" },
    { label: "Start / Pause", click: () => sendCommand("toggle") },
    { label: "Reset", click: () => sendCommand("reset") },
    { type: "separator" },
    { label: "Quit", click: () => app.quit() }
  ]);
}

function createSettingsWindow() {
  if (settingsWindow && !settingsWindow.isDestroyed()) {
    settingsWindow.show();
    settingsWindow.focus();
    return;
  }

  settingsWindow = new BrowserWindow({
    width: 280,
    height: 310,
    resizable: false,
    minimizable: false,
    maximizable: false,
    title: "暗淡蓝点",
    backgroundColor: "#f6f6f6",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  settingsWindow.setMenu(null);
  settingsWindow.loadFile(path.join(__dirname, "settings.html"));
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: NORMAL_WINDOW_SIZE,
    height: NORMAL_WINDOW_SIZE,
    minWidth: 88,
    minHeight: 88,
    frame: false,
    transparent: true,
    resizable: false,
    alwaysOnTop: true,
    skipTaskbar: false,
    hasShadow: false,
    backgroundColor: "#00000000",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.setAlwaysOnTop(true, "screen-saver");
  mainWindow.loadFile(path.join(__dirname, "index.html"));
  mainWindow.once("ready-to-show", () => {
    mainWindow.show();
    mainWindow.focus();
  });
  mainWindow.on("close", (event) => {
    if (getMainWindowCloseAction(process.platform, isQuitting) !== "hide") {
      return;
    }
    event.preventDefault();
    toggleMainWindowVisibility("hide");
  });

  ipcMain.on("show-context-menu", () => {
    buildContextMenu().popup({ window: mainWindow });
  });
}

function createTray() {
  const iconPath = process.platform === "darwin"
    ? path.join(__dirname, "..", "build", "iconTemplate.png")
    : path.join(__dirname, "..", "build", "icon.ico");
  tray = new Tray(iconPath);
  tray.setToolTip("暗淡蓝点");
  if (process.platform === "darwin") {
    tray.setTitle("25");
    tray.on("right-click", () => {
      buildContextMenu().popup();
    });
  } else {
    tray.setContextMenu(buildContextMenu());
  }
  tray.on("click", () => {
    if (process.platform === "win32") {
      const action = getWindowsTrayClickAction(
        Boolean(mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()),
        latestTimerState.status
      );
      if (action === "show") {
        toggleMainWindowVisibility("show");
      } else {
        sendCommand(action);
      }
      return;
    }

    if (latestTimerState.status === "finished") {
      sendCommand("finish-click");
      return;
    }

    if (process.platform === "darwin") {
      if (trayClickTimer) {
        clearTimeout(trayClickTimer);
        trayClickTimer = undefined;
        sendCommand("toggle");
        return;
      }

      trayClickTimer = setTimeout(() => {
        trayClickTimer = undefined;
      }, 300);
      return;
    }

    sendCommand("toggle");
  });
}

app.whenReady().then(() => {
  app.setAppUserModelId("com.codex.minimalpomodoro");
  if (process.platform === "darwin") {
    app.dock.hide();
  }
  createWindow();
  createTray();

  ipcMain.on("settings-command", (_event, payload) => {
    if (payload.command === "quit") {
      app.quit();
      return;
    }
    sendCommand(payload.command, payload.value);
  });

  ipcMain.on("timer-state", (_event, state) => {
    sendTimerState(state);
  });

  ipcMain.on("start-window-drag", (_event, point) => {
    if (!mainWindow || mainWindow.isDestroyed()) {
      return;
    }

    windowDrag = {
      startPointer: point,
      startWindowPosition: mainWindow.getPosition()
    };
  });

  ipcMain.on("move-window-drag", (_event, point) => {
    if (!mainWindow || mainWindow.isDestroyed() || !windowDrag) {
      return;
    }

    mainWindow.setPosition(
      ...getDraggedWindowPosition(windowDrag.startWindowPosition, windowDrag.startPointer, point),
      false
    );
  });

  ipcMain.on("end-window-drag", () => {
    windowDrag = undefined;
  });

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("before-quit", () => {
  isQuitting = true;
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
