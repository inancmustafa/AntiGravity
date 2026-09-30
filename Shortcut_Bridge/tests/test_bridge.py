"""Regression checks execute actual AHK handler bodies with fake input/output.
No keyboard events are injected, no browser is opened, no bridge is started.
Run: python tests/test_bridge.py [path-to-AutoHotkey64.exe]
"""
from pathlib import Path
import re
import os
import subprocess
import sys
import tempfile

ROOT = Path(os.environ.get("BRIDGE_TEST_ROOT", Path(__file__).resolve().parents[1]))
AHK = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

def run_ahk(args):
    result = subprocess.run([AHK, "/ErrorStdOut=UTF-8", *args],
                            capture_output=True, text=True, encoding="utf-8", timeout=20)
    if result.returncode:
        raise AssertionError(f"AHK exit={result.returncode}: " + result.stdout + result.stderr)
    return result.stdout

for path in sorted(ROOT.glob("*.ahk")):
    run_ahk(["/validate", str(path)])
    print("PASS syntax:", path.name)

def handlers(filename, names):
    source = (ROOT / filename).read_text(encoding="utf-8")
    bodies = []
    for name in names:
        match = re.search(r"^" + name + r"\([^\n]*\) \{.*?^\}", source, re.M | re.S)
        assert match, name
        body = re.sub(r"\bSendEvent\b|\bSend\b", "Capture", match[0])
        for real, fake in (("GetKeyState(", "FakeKeyState("), ("WinActive(", "FakeWinActive("),
                           ("WinGetTitle(", "FakeWinGetTitle("), ("WinGetID(", "FakeWinGetID("),
                           ("WinGetProcessName(", "FakeProcessName(")):
            body = body.replace(real, fake)
        bodies.append(body)
    return "\n".join(bodies)

code = '#Requires AutoHotkey v2.0\n#SingleInstance Off\n#NoTrayIcon\n'
code += '#Include ' + str(ROOT / "Bridge_Config.ahk") + '\n'
code += r'''
Trace := { enabled: false }
T := { active: true, sent: [], physical: Map(), checks: 0,
       winActive: false, title: "", fgId: 0, fgExe: "" }
St := { smHwnd: 1, held: Map(), sources: Map(), pendingReset: false, tabMismatch: false,
        wasActive: false, lastKeepalive: 0 }
G := { held: Map(), lastActivity: A_TickCount, winCombo: false, winWatch: 0 }
__AUTOSTART_LINK__

try {
    rejected := false
    BRIDGE_TABLE.Push({bridge: BRIDGE_KEEPALIVE, host: ["x"], guest: "x", mode: "tap", gate: ""})
    try ValidateBridgeConfig()
    catch
        rejected := true
    BRIDGE_TABLE.Pop()
    Check(rejected, "reserved heartbeat collision rejected")
    tabEntry := BRIDGE_TABLE[2]
    winEntry := BRIDGE_TABLE[4]
    altEntry := BRIDGE_TABLE[1]
    T.physical["Ctrl"] := true
    T.physical["Tab"] := true
    HoldDown(tabEntry, "Tab")
    Check(T.sent.Length = 1 && T.sent[1] = "{Blind}{F14 down}", "Ctrl+Tab retains modifiers")
    HoldDown(tabEntry, "Tab")
    Check(T.sent.Length = 1, "repeat down is suppressed")
    HoldUp(tabEntry, "Tab")
    Check(T.sent[2] = "{Blind}{F14 up}" && !St.held.Count, "Tab up retains modifiers")

    T.sent := []
    HoldDown(winEntry, "LWin")
    HoldDown(winEntry, "RWin")
    HoldUp(winEntry, "LWin")
    Check(T.sent.Length = 1 && St.held.Has("F16"), "second Win source remains held")
    HoldUp(winEntry, "RWin")
    Check(T.sent.Length = 2 && !St.held.Count, "last Win source releases")

    T.sent := []
    shiftEntry := BRIDGE_TABLE[3]
    HoldDown(shiftEntry, "LShift")
    HoldDown(shiftEntry, "RShift")
    HoldUp(shiftEntry, "LShift")
    Check(T.sent.Length = 1 && St.held.Has("F15"), "second Shift source remains held")
    HoldUp(shiftEntry, "RShift")
    Check(T.sent.Length = 2 && !St.held.Count, "last Shift source releases")

    T.sent := []
    HoldDown(altEntry, "LAlt")
    T.active := false
    MaintainBridge()
    Check(St.pendingReset && !St.held.Count && T.sent.Length = 1, "focus loss queues reset without injecting elsewhere")
    HoldDown(tabEntry, "Tab")
    Check(T.sent.Length = 1, "no down outside target")
    T.active := true
    Check(!BridgeReady(), "pending reset blocks bridge")
    MaintainBridge()
    Check(!St.pendingReset && T.sent[2] = "{Blind}{F17}", "focus return flushes reset")

    T.active := false
    T.sent := []
    SendReset()
    Check(St.pendingReset && !T.sent.Length, "panic outside target remains pending")
    T.active := true
    MaintainBridge()

    T.sent := []
    T.physical["LAlt"] := true
    HoldDown(altEntry, "LAlt")
    St.lastKeepalive := A_TickCount - KEEPALIVE_MS - 1
    MaintainBridge()
    Check(T.sent.Length = 2 && T.sent[2] = "{Blind}{F24}", "held key emits keepalive")
    T.physical["LAlt"] := false
    MaintainBridge()
    Check(!St.held.Count && T.sent[3] = "{Blind}{F13 up}", "missing up reconciles physical key state")

    T.sent := []
    GuestHoldDown(altEntry)
    GuestHoldDown(altEntry)
    Check(T.sent.Length = 1, "guest ignores duplicate down")
    G.lastActivity := A_TickCount - HOLD_TIMEOUT_MS - 1
    GuestKeepalive()
    GuestWatchdog()
    Check(G.held.Count = 1 && T.sent.Length = 1, "keepalive preserves long hold")
    G.lastActivity := A_TickCount - HOLD_TIMEOUT_MS - 1
    GuestWatchdog()
    Check(!G.held.Count && T.sent[2] = "{Blind}{Alt up}", "missing heartbeat triggers fail-safe release")
    Check(T.sent.Length = 2, "watchdog preserves natural Ctrl")

    T.sent := []
    GuestHoldDown(altEntry)
    GuestHoldDown(tabEntry)
    GuestReset("host RESET")
    Check(T.sent[3] = "{Blind}{Tab up}" && T.sent[4] = "{Blind}{Alt up}", "reset releases Tab before Alt")
    Check(T.sent.Length = 4, "normal reset does not release native Ctrl")
    T.physical["LCtrl"] := true
    GuestReset("panik", true)
    Check(T.sent[T.sent.Length] = "{Blind}{LCtrl up}", "explicit guest panic releases native modifier")

    ; --- v5: keepalive timing -------------------------------------------------
    T.sent := []
    St.held.Clear(), St.sources.Clear(), St.pendingReset := false
    St.lastKeepalive := 0   ; stale timestamp from an earlier hold
    T.physical["LAlt"] := true
    HoldDown(altEntry, "LAlt")
    MaintainBridge()
    Check(T.sent.Length = 1, "short hold sends no immediate keepalive")
    T.physical["LAlt"] := false
    MaintainBridge()
    Check(!St.held.Count && T.sent[2] = "{Blind}{F13 up}", "short hold releases cleanly")

    ; --- v5: tab title gate -----------------------------------------------------
    Check(SMTitleMatches("VMware Horizon — Waterfox") && SMTitleMatches("Omnissa HORIZON — Waterfox"), "Horizon tab title matches")
    Check(!SMTitleMatches("GitHub — Waterfox") && !SMTitleMatches(""), "other tab title rejected")
    T.winActive := true, T.title := "VMware Horizon — Waterfox"
    Check(RealIsSM(), "target window on Horizon tab is SM")
    T.title := "Yeni Sekme — Waterfox"
    Check(!RealIsSM(), "same window on another tab is not SM")
    T.winActive := false, T.title := "VMware Horizon — Waterfox"
    Check(!RealIsSM(), "inactive target is not SM")
    savedTitle := SM_TITLE_MATCH
    SM_TITLE_MATCH := ""
    T.winActive := true, T.title := "anything"
    Check(RealIsSM(), "empty SM_TITLE_MATCH disables tab gate")
    SM_TITLE_MATCH := savedTitle
    T.winActive := false

    ; --- v5: marking and launch window filter ---------------------------------
    T.fgId := 777, T.fgExe := "Code.exe"
    MarkActiveAsSM()
    Check(St.smHwnd = 1, "non-browser window cannot be marked")
    T.fgExe := "Waterfox.EXE"
    MarkActiveAsSM()
    Check(St.smHwnd = 777 && St.pendingReset, "browser window can be marked")
    St.smHwnd := 1, St.pendingReset := false
    Check(IsAllowedSMExe("firefox.exe") && !IsAllowedSMExe("claude.exe"), "allowed browser list")
    Check(SMWindowCriteria() = "ahk_class MozillaWindowClass ahk_exe waterfox.exe", "launch watches only top-level Waterfox windows")

    ; --- v5: single Win opens Start in SM ----------------------------------------
    T.sent := []
    G.held.Clear()
    GuestHoldDown(winEntry)
    GuestHoldUp(winEntry)
    Check(T.sent.Length = 3 && T.sent[1] = "{Blind}{LWin down}" && T.sent[2] = "{Blind}{LWin up}"
        && T.sent[3] = "{Blind}{LWin}", "single Win adds clean tap for Start")
    T.sent := []
    GuestHoldDown(winEntry)
    WinComboKey(0, 0x44, 0x20)
    GuestHoldUp(winEntry)
    Check(T.sent.Length = 2, "Win+D gets no extra tap")
    T.sent := []
    GuestHoldDown(winEntry)
    GuestHoldDown(tabEntry)
    GuestHoldUp(tabEntry)
    GuestHoldUp(winEntry)
    Check(T.sent.Length = 4 && T.sent[4] = "{Blind}{LWin up}", "Win with bridged key gets no extra tap")
    T.sent := []
    WinComboKey(0, 0x44, 0x20)
    GuestHoldDown(winEntry)
    GuestHoldUp(winEntry)
    Check(T.sent.Length = 3, "combo state resets on each Win press")
    GUEST_WIN_TAP_FIX := false
    T.sent := []
    GuestHoldDown(winEntry)
    GuestHoldUp(winEntry)
    Check(T.sent.Length = 2, "Win tap fix can be disabled")
    GUEST_WIN_TAP_FIX := true
    T.sent := []
    GuestHoldDown(winEntry)
    GuestReset("host RESET")
    Check(T.sent.Length = 2 && T.sent[2] = "{Blind}{LWin up}", "reset releases Win without Start tap")
    StartWinComboWatch()
    Check(G.winWatch && G.winWatch.InProgress, "combo watcher runs as visible input hook")
    G.winWatch.Stop()

    ; --- v5: guest autostart shortcut ------------------------------------------
    folder := A_Temp "\shortcut-bridge-autostart-" A_TickCount
    DirCreate folder
    try {
        Check(SetGuestAutostart(true, folder) && FileExist(GuestAutostartPath(folder)), "autostart shortcut created")
        FileGetShortcut GuestAutostartPath(folder), &target, &dir, &args
        Check(target = GuestAutostartExe() && InStr(args, A_ScriptFullPath) && dir = A_ScriptDir, "autostart runs this receiver")
        Check(FileExist(GuestAutostartExe()), "autostart interpreter exists")
        Check(!SetGuestAutostart(false, folder) && !FileExist(GuestAutostartPath(folder)), "autostart shortcut removed")
    } finally
        DirDelete folder, true

    FileAppend "PASS " T.checks " behavioral assertions" Chr(10), "*"
    ExitApp 0
} catch as err {
    FileAppend "FAIL: " err.Message Chr(10) err.Stack Chr(10), "*"
    ExitApp 1
}

Check(ok, label) {
    if !ok
        throw Error(label)
    T.checks += 1
}
Capture(keys) {
    T.sent.Push(keys)
}
IsSM() {
    return T.active
}
FakeKeyState(key, mode := "") {
    return T.physical.Has(key) && T.physical[key]
}
TraceWrite(*) {
}
TraceModifiers(*) {
    return ""
}
FakeWinActive(*) {
    return T.winActive
}
FakeWinGetTitle(*) {
    return T.title
}
FakeWinGetID(*) {
    return T.fgId
}
FakeProcessName(*) {
    return T.fgExe
}
Notify(*) {
}
Log(*) {
}
UpdateTray(*) {
}
GuestLog(*) {
}
GuestNotify(*) {
}
UpdateGuestTray(*) {
}
'''
code += handlers("Host_PC_Bridge.ahk", [
    "HoldDown", "HoldUp", "TapSend", "SendReset", "FlushPendingReset",
    "BridgeReady", "MaintainBridge", "SourceReleaseReady", "MarkActiveAsSM", "SMWindowCriteria"])
code += "\n" + handlers("Host_PC_Bridge.ahk", ["IsSM"]).replace("IsSM()", "RealIsSM()", 1)
code += "\n" + handlers("Guest_SM_Receiver.ahk", [
    "GuestHoldDown", "GuestHoldUp", "GuestTap", "GuestReset", "GuestKeepalive", "GuestWatchdog",
    "StartWinComboWatch", "WinComboKey", "GuestAutostartPath", "GuestAutostartExe", "SetGuestAutostart"])
autostart = re.search(r"^AUTOSTART_LINK := .*$", (ROOT / "Guest_SM_Receiver.ahk").read_text(encoding="utf-8"), re.M)
assert autostart, "AUTOSTART_LINK"
code = code.replace("__AUTOSTART_LINK__", autostart[0], 1)

with tempfile.TemporaryDirectory(prefix="shortcut-bridge-tests-") as folder:
    harness = Path(folder) / "regression.ahk"
    harness.write_text(code, encoding="utf-8")
    print(run_ahk([str(harness)]), end="")


# Register the real dynamic hotkey variants while every target gate is false.
# No real bridge instance is started or replaced; callbacks still use fake IO.
registration = code.replace('try {\n', 'try {\n    T.active := false\n    RegisterBridges()\n    FileAppend "PASS dynamic hotkey registration" Chr(10), "*"\n    ExitApp 0\n', 1)
registration += "\n" + handlers("Host_PC_Bridge.ahk", ["RegisterBridges"])
with tempfile.TemporaryDirectory(prefix="shortcut-bridge-registration-") as folder:
    harness = Path(folder) / "registration.ahk"
    harness.write_text(registration, encoding="utf-8")
    print(run_ahk([str(harness)]), end="")

if not (ROOT / "Bridge_Logger.ahk").exists():
    print("PASS logger-free runtime: no logger module")
    sys.exit(0)

# Exercise the actual observer hook and buffered file writer without sending keys.
logger_smoke = (
    '#Requires AutoHotkey v2.0\n#SingleInstance Off\n#NoTrayIcon\n'
    '#Include ' + str(ROOT / "Bridge_Config.ahk") + '\n'
    '#Include ' + str(ROOT / "Bridge_Logger.ahk") + '\n'
    + r'''
try {
    if (TraceKeyName(65) != "" || TraceKeyName(49) != "")
        throw Error("Text keys must not be logged")
    if (TraceKeyName(125) != "F14" || TraceKeyName(9) != "Tab")
        throw Error("Key mapping failed")
    TraceStart("TEST", true)
    if !Trace.hook
        throw Error("Observer hook installation failed")
    TraceWrite("TEST_MARKER", "buffered-write")
    Sleep 250
    TraceStop()
    contents := FileRead(Trace.path, "UTF-8")
    if (!InStr(contents, "TEST_MARKER buffered-write") || !InStr(contents, "STOP"))
        throw Error("Buffered log missing")
    FileDelete Trace.path
    FileAppend "PASS logger whitelist, native hook, buffer flush and cleanup" Chr(10), "*"
    ExitApp 0
} catch as err {
    FileAppend "FAIL logger: " err.Message Chr(10), "*"
    ExitApp 1
}
''')
with tempfile.TemporaryDirectory(prefix="shortcut-bridge-logger-") as folder:
    harness = Path(folder) / "logger.ahk"
    harness.write_text(logger_smoke, encoding="utf-8")
    print(run_ahk([str(harness)]), end="")
