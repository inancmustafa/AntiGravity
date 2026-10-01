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

# Validate through a wrapper: warnings go to stdout instead of a blocking dialog,
# and include-only files (the logger) are checked together with the config.
with tempfile.TemporaryDirectory(prefix="shortcut-bridge-validate-") as folder:
    for path in sorted(ROOT.glob("*.ahk")):
        wrapper = Path(folder) / ("validate_" + path.name)
        lines = ["#Requires AutoHotkey v2.0", "#Warn VarUnset, StdOut", "#Include " + str(ROOT)]
        if path.name == "Bridge_Logger.ahk":
            lines.append("#Include Bridge_Config.ahk")
        lines.append("#Include " + str(path))
        wrapper.write_text("\n".join(lines) + "\n", encoding="utf-8")
        output = run_ahk(["/validate", str(wrapper)])
        assert "Warning" not in output, path.name + ": " + output
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
                           ("WinGetProcessName(", "FakeProcessName("), ("WinExist(", "FakeWinExist("),
                           ("WinMinimize(", "FakeWinMinimize("), ("WinActivate(", "FakeWinActivate("),
                           ("KeyWait(", "FakeKeyWait(")):
            body = body.replace(real, fake)
        bodies.append(body)
    return "\n".join(bodies)

code = '#Requires AutoHotkey v2.0\n#SingleInstance Off\n#NoTrayIcon\n'
code += '#Include ' + str(ROOT / "Bridge_Config.ahk") + '\n'
code += r'''
Trace := { enabled: false }
T := { active: true, sent: [], physical: Map(), checks: 0,
       winActive: false, title: "", fgId: 0, fgExe: "", exists: true, windowOps: [] }
St := { smHwnd: 1, held: Map(), sources: Map(), pendingReset: false, tabMismatch: false,
        wasActive: false, lastKeepalive: 0, diagnostic: false }
G := { held: Map(), lastActivity: A_TickCount, winCombo: false, winWatch: 0, carry: [], carryTick: 0 }
__CONTROL_ACTIONS__
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

    ; --- v5: Ctrl+Alt+Shift+H toggles between SM and host -------------------------
    T.sent := [], T.windowOps := []
    T.winActive := true, T.active := true
    ToggleSMFocus()
    Check(T.windowOps.Length = 5 && T.windowOps[5] = "minimize ahk_id 1", "leave minimizes SM window after keys are released")
    Check(T.sent.Length = 1 && T.sent[1] = "{Blind}{F17}", "leave resets SM before switching")
    T.sent := [], T.windowOps := []
    T.winActive := false, T.active := false
    ToggleSMFocus()
    Check(T.windowOps[T.windowOps.Length] = "activate ahk_id 1" && !T.sent.Length, "second press returns to SM")
    T.windowOps := [], T.exists := false
    ToggleSMFocus()
    Check(!T.windowOps.Length, "no SM window means no switching")
    T.exists := true, T.active := true
    St.pendingReset := false

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

    ; --- v6: Waterfox shortcuts are carried to SM ---------------------------------
    for k in ["Ctrl", "Alt", "Shift", "RAlt", "LAlt", "Tab", "LCtrl"]
        T.physical[k] := false
    St.held.Clear(), St.sources.Clear(), St.pendingReset := false
    T.active := true
    Check(!CarryReady("vk54"), "plain T is typed normally")
    T.physical["Ctrl"] := true
    Check(CarryReady("vk54") && CarryReady("PgDn") && CarryReady("vk4E"), "Ctrl+T, Ctrl+PgDn, Ctrl+N are carried")
    Check(!CarryReady("vk43") && !CarryReady("vk56") && !CarryReady("vk58"), "Ctrl+C/V/X stay natural for Horizon clipboard")
    St.held[ALT_BRIDGE] := A_TickCount
    Check(CarryReady("vk43") && CarryReady("vk54"), "Ctrl+Alt+C and Ctrl+Alt+T are carried")
    St.held.Clear()
    T.physical["Ctrl"] := false
    Check(CarryReady("F5") && CarryReady("F11") && CarryReady("F12"), "F keys are carried without modifiers")
    St.held[WIN_BRIDGE] := A_TickCount
    Check(CarryReady("vk44") && CarryReady("Left"), "Win+D and Win+Left are carried")
    Check(ModGateReady(), "Win+Tab is bridged through the Tab gate")
    St.held.Clear()
    Check(!ModGateReady(), "plain Tab is not bridged")
    T.physical["Ctrl"] := true, T.physical["RAlt"] := true
    Check(!CarryReady("vk51"), "AltGr characters are never carried")
    T.physical["RAlt"] := false
    T.physical["Alt"] := true, T.physical["Shift"] := true
    Check(ControlReady() && !CarryReady("vk53") && CarryReady("vk54"), "Ctrl+Alt+Shift+S stays a bridge control, Ctrl+Alt+Shift+T is carried")
    T.physical["Alt"] := false, T.physical["Shift"] := false
    Check(!ControlReady(), "control variant needs Ctrl+Alt+Shift")
    T.physical["Ctrl"] := true
    Check(FullscreenReady() && !CarryReady("F11") && CarryReady("F5"), "Ctrl+F11 stays in Waterfox, Ctrl+F5 is carried")
    T.sent := []
    FullscreenToggle()
    Check(T.sent.Length = 1 && T.sent[1] = "{F11}", "Ctrl+F11 sends plain F11 to Waterfox")
    St.held[ALT_BRIDGE] := A_TickCount, T.physical["Alt"] := true
    Check(!FullscreenReady() && CarryReady("F11"), "Ctrl+Alt+F11 is carried to SM")
    St.held.Clear(), T.physical["Alt"] := false
    T.physical["Ctrl"] := false
    Check(!FullscreenReady() && CarryReady("F11"), "plain F11 is carried to SM")
    T.active := false
    Check(!CarryReady("vk54") && !CarryReady("F5"), "nothing is carried outside the SM tab")
    T.physical["Ctrl"] := true
    Check(!FullscreenReady(), "Ctrl+F11 is left alone outside the SM tab")
    T.physical["Ctrl"] := false
    T.active := true
    T.physical["Ctrl"] := false

    ; host -> guest round trip for every carried key
    G.held.Clear(), G.carry := [], G.carryTick := 0
    for k in CARRY_KEYS {
        T.sent := []
        CarrySend(k)
        seq := T.sent[1]
        T.sent := []
        FeedCarry(seq)
        if (T.sent.Length != 1 || T.sent[1] != "{Blind}{" k "}")
            throw Error("carry round trip failed for " k)
    }
    Check(CARRY_KEYS.Length >= 70, "all " CARRY_KEYS.Length " carried keys round-trip host->guest")

    good := CarrySequence("vk54")
    bad := SubStr(good, 1, StrLen(good) - 5) "{" CARRY_DIGITS[Mod(CarryCheckDigit(good) + 1, 5) + 1] "}"
    T.sent := []
    FeedCarry(bad)
    Check(!T.sent.Length, "corrupted or other-version sequence is rejected")
    FeedCarry(StrReplace(good, "{" CARRY_START "}", ""))
    Check(!T.sent.Length, "digits without start marker are ignored")
    GuestCarryStart()
    G.carryTick := A_TickCount - CARRY_TIMEOUT_MS - 1
    FeedCarry(StrReplace(good, "{" CARRY_START "}", ""))
    Check(!T.sent.Length, "stale sequence times out")
    FeedCarry(good)
    Check(T.sent.Length = 1 && T.sent[1] = "{Blind}{vk54}", "decoder recovers after rejected input")

    T.sent := []
    G.held.Clear()
    GuestHoldDown(winEntry)
    FeedCarry(CarrySequence("vk44"))
    GuestHoldUp(winEntry)
    Check(T.sent.Length = 3 && T.sent[2] = "{Blind}{vk44}" && T.sent[3] = "{Blind}{LWin up}", "Win+D is produced in guest without Start tap")
    T.sent := []
    GuestCarryStart()
    GuestReset("host RESET")
    Check(!G.carryTick && !G.carry.Length, "reset clears a pending carry sequence")

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
FeedCarry(seq) {
    pos := 1
    while RegExMatch(seq, "\{(F\d+)\}", &m, pos) {
        pos := m.Pos + m.Len
        if (m[1] = CARRY_START) {
            GuestCarryStart()
            continue
        }
        for i, d in CARRY_DIGITS
            if (m[1] = d)
                GuestCarryDigit(i - 1)
    }
}
CarryCheckDigit(seq) {
    RegExMatch(seq, "\{(F\d+)\}$", &m)
    for i, d in CARRY_DIGITS
        if (m[1] = d)
            return i - 1
}
FakeWinExist(*) {
    return T.exists
}
FakeWinMinimize(target) {
    T.windowOps.Push("minimize " target)
}
FakeWinActivate(target) {
    T.windowOps.Push("activate " target)
}
FakeKeyWait(key, *) {
    T.windowOps.Push("wait " key)
    return 1
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
    "BridgeReady", "MaintainBridge", "SourceReleaseReady", "MarkActiveAsSM", "SMWindowCriteria",
    "ToggleSMFocus", "ModGateReady", "ControlReady", "ControlHotkey", "CarryReady", "CarrySend",
    "FullscreenReady", "FullscreenToggle"])
code += "\n" + handlers("Host_PC_Bridge.ahk", ["IsSM"]).replace("IsSM()", "RealIsSM()", 1)
code += "\n" + handlers("Guest_SM_Receiver.ahk", [
    "GuestHoldDown", "GuestHoldUp", "GuestTap", "GuestReset", "GuestKeepalive", "GuestWatchdog",
    "StartWinComboWatch", "WinComboKey", "GuestAutostartPath", "GuestAutostartExe", "SetGuestAutostart",
    "GuestCarryStart", "GuestCarryDigit"])
autostart = re.search(r"^AUTOSTART_LINK := .*$", (ROOT / "Guest_SM_Receiver.ahk").read_text(encoding="utf-8"), re.M)
assert autostart, "AUTOSTART_LINK"
code = code.replace("__AUTOSTART_LINK__", autostart[0], 1)
# Same control keys as the host; the actions themselves are not exercised here.
control_keys = re.findall(r'^\s+"(vk[0-9A-F]{2})", \w+', (ROOT / "Host_PC_Bridge.ahk").read_text(encoding="utf-8"), re.M)
assert len(control_keys) == 5, control_keys
code = code.replace("__CONTROL_ACTIONS__", "CONTROL_ACTIONS := Map(" + ", ".join(f'"{k}", (*) => 0' for k in control_keys) + ")", 1)

with tempfile.TemporaryDirectory(prefix="shortcut-bridge-tests-") as folder:
    harness = Path(folder) / "regression.ahk"
    harness.write_text(code, encoding="utf-8")
    print(run_ahk([str(harness)]), end="")


# Register the real dynamic hotkey variants while every target gate is false.
# No real bridge instance is started or replaced; callbacks still use fake IO.
registration = code.replace('try {\n', 'try {\n    T.active := false\n    RegisterBridges()\n    RegisterReceivers()\n    FileAppend "PASS dynamic hotkey registration (host and receiver)" Chr(10), "*"\n    ExitApp 0\n', 1)
registration += "\n" + handlers("Host_PC_Bridge.ahk", ["RegisterBridges"])
registration += "\n" + handlers("Guest_SM_Receiver.ahk", ["RegisterReceivers"])

# Other AHK scripts in the VM (e.g. a ^3:: hotkey) must see the receiver's keys
# like a real keyboard: SendLevel above their default #InputLevel 0, while the
# receiver's own hotkeys sit at input level 1 so its own sends never trigger them.
guest_source = (ROOT / "Guest_SM_Receiver.ahk").read_text(encoding="utf-8")
assert re.search(r"^SendLevel 1$", guest_source, re.M), "receiver must send at SendLevel 1"
assert guest_source.index("#InputLevel 1") < guest_source.index("^!+r::"), "panic hotkey input level"
receiver = re.search(r"^RegisterReceivers\(\) \{.*?^\}", guest_source, re.M | re.S)[0]
hotkey_lines = [l for l in receiver.splitlines() if l.strip().startswith('Hotkey "*"')]
assert hotkey_lines and all(l.rstrip().endswith('"I1"') for l in hotkey_lines), "receiver hotkeys need input level 1"
assert 'InputHook("V I2 L0")' in guest_source, "combo watcher must ignore the receiver's own SendLevel 1 output"
print("PASS receiver input levels: SendLevel 1, own hotkeys at #InputLevel 1")
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
    if (TraceKeyName(129) != "CARRY" || TraceKeyName(134) != "CARRY" || TraceKeyName(135) != "F24")
        throw Error("Carry digits must not reveal the carried key")
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
