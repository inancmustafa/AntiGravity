#Requires AutoHotkey v2.0
; Only Tab, modifiers, F8 and F13-F24 are observed; text keys are never stored.
; Hook callbacks enqueue fixed metadata and always call the next hook.
; Disk IO happens on a timer, not inside the keyboard callback.
Trace := { enabled: false, role: "", path: "", queue: [], dropped: 0,
           hook: 0, callback: 0, seq: 0, lastState: "" }

TraceStart(role, enabled) {
    if !enabled
        return
    Trace.role := role
    folder := A_Temp "\ShortcutBridgeLogs"
    DirCreate folder
    Trace.path := folder "\" StrLower(role) "-" A_Now "-" DllCall("GetCurrentProcessId") ".log"
    ; Surface a permissions error immediately rather than silently losing the log.
    FileAppend "Shortcut Bridge diagnostic log" Chr(10), Trace.path, "UTF-8"
    Trace.enabled := true
    TraceWrite("START", "build=diag-1 protocol=" BRIDGE_PROTOCOL_VERSION " ahk=" A_AhkVersion
        " admin=" A_IsAdmin " script=" A_ScriptFullPath)
    for e in BRIDGE_TABLE
        TraceWrite("CONFIG", e.bridge " -> " e.guest " mode=" e.mode " gate=" e.gate)
    InstallKeybdHook()
    Trace.callback := CallbackCreate(TraceKeyboard, , 3)
    Trace.hook := DllCall("SetWindowsHookExW", "Int", 13, "Ptr", Trace.callback,
        "Ptr", DllCall("GetModuleHandleW", "Ptr", 0, "Ptr"), "UInt", 0, "Ptr")
    if !Trace.hook {
        errorCode := A_LastError
        CallbackFree Trace.callback
        Trace.callback := 0
        TraceWrite("HOOK_ERROR", "win32=" errorCode)
    }
    SetTimer TraceFlush, 200
    OnExit TraceStop
    TraceFlush()
}

TraceKeyName(vk) {
    static names := Map(9, "Tab", 16, "Shift", 17, "Ctrl", 18, "Alt",
        160, "LShift", 161, "RShift", 162, "LCtrl", 163, "RCtrl",
        164, "LAlt", 165, "RAlt", 91, "LWin", 92, "RWin", 119, "F8")
    if names.Has(vk)
        return names[vk]
    if (vk >= 129 && vk <= 134)      ; F18-F23: taşıma haneleri hangi tuşa basıldığını
        return "CARRY"               ; ele verir; yalnızca türü kaydedilir
    if (vk >= 124 && vk <= 135)
        return "F" (vk - 111)
    return ""
}

TraceKeyboard(code, wParam, lParam) {
    if (code >= 0 && Trace.enabled) {
        try {
            vk := NumGet(lParam, 0, "UInt")
            key := TraceKeyName(vk)
            if (key != "") {
                flags := NumGet(lParam, 8, "UInt")
                TraceWrite("RAW", key " " ((flags & 128) ? "up" : "down")
                    " injected=" ((flags & 16) ? 1 : 0)
                    " flags=" flags " sc=" NumGet(lParam, 4, "UInt")
                    " osTick=" NumGet(lParam, 12, "UInt")
                    " hwnd=" DllCall("GetForegroundWindow", "Ptr"))
            }
        }
    }
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", code,
        "Ptr", wParam, "Ptr", lParam, "Ptr")
}

TraceWrite(stage, detail := "") {
    if !Trace.enabled
        return
    if (Trace.queue.Length >= 4096) {
        Trace.dropped += 1
        return
    }
    Trace.seq += 1
    Trace.queue.Push(Trace.seq " tick=" A_TickCount " " Trace.role " " stage " " detail)
}

TraceModifiers() {
    physical := "", logical := ""
    for key in ["LCtrl", "RCtrl", "LAlt", "RAlt", "LShift", "RShift", "LWin", "RWin", "Tab"] {
        if GetKeyState(key, "P")
            physical .= key ","
        if GetKeyState(key)
            logical .= key ","
    }
    return "physical=[" physical "] logical=[" logical "]"
}

TraceFlush() {
    if !Trace.enabled
        return
    ; Swap under Critical so events queued during disk IO are retained.
    Critical
    batch := Trace.queue
    Trace.queue := []
    lost := Trace.dropped
    Trace.dropped := 0
    Critical "Off"
    body := ""
    for line in batch
        body .= line Chr(10)
    if lost
        body .= "DROPPED " lost Chr(10)
    if (body != "") {
        try FileAppend body, Trace.path, "UTF-8"
        catch as err {
            Trace.enabled := false
            MsgBox "Logger yazamadi: " Trace.path Chr(10) err.Message
        }
    }
}

TraceStop(*) {
    if Trace.hook {
        DllCall("UnhookWindowsHookEx", "Ptr", Trace.hook)
        Trace.hook := 0
    }
    if Trace.callback {
        CallbackFree Trace.callback
        Trace.callback := 0
    }
    TraceWrite("STOP")
    TraceFlush()
    Trace.enabled := false
}

TraceOpenFolder(*) {
    Run A_Temp "\ShortcutBridgeLogs"
}
