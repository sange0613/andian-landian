const test = require("node:test");
const assert = require("node:assert/strict");

const {
  getMainWindowCloseAction,
  getWindowsTrayClickAction
} = require("../src/windowLifecycle");

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
