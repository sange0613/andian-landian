function getMainWindowCloseAction(platform, isQuitting) {
  return platform === "win32" && !isQuitting ? "hide" : "close";
}

function getWindowsTrayClickAction(isVisible, status) {
  if (!isVisible) {
    return "show";
  }
  return status === "finished" ? "finish-click" : "toggle";
}

module.exports = { getMainWindowCloseAction, getWindowsTrayClickAction };
