"""Build and test the logger-free runtime ZIP: python build_release.py."""
from pathlib import Path
import hashlib, os, re, subprocess, sys, zipfile

ROOT = Path(__file__).resolve().parent
NAME = "Shortcut_Bridge_v5_loggersiz"
PACKAGE = ROOT / "dist" / NAME

def exact(text, old, new):
    assert text.count(old) == 1, "Review changed source: " + old[:80]
    return text.replace(old, new, 1)

def pattern(text, regex, replacement=""):
    text, count = re.subn(regex, replacement, text, flags=re.M | re.S)
    assert count == 1, "Review changed source: " + regex
    return text

def runtime(name):
    text = (ROOT / name).read_text(encoding="utf-8-sig")
    text = exact(text, "#Include Bridge_Logger.ahk\n", "")
    text = "\n".join(line for line in text.splitlines()
        if "tray.Add" not in line or ("Logger ile" not in line and "TraceOpenFolder" not in line)) + "\n"
    if name.startswith("Host"):
        text = exact(text,
            'lastKeepalive: 0, wasActive: false,\n        diagnostic: A_Args.Length >= 1 && A_Args[1] = "diag" }',
            'lastKeepalive: 0, wasActive: false }')
        text = pattern(text, r'^TraceStart\("HOST".*?(?=^; SM_Baslat\.bat)')
        text = exact(text, "else if !St.diagnostic\n", "else\n")
        text = pattern(text, r'^    if Trace\.enabled \{.*?^    }\n')
        text = pattern(text, r'^Log\(msg\) \{.*?^}', 'Log(msg) {\n    ; No logging in this package.\n}')
    else:
        text = exact(text,
            'G := { held: Map(), lastActivity: A_TickCount, winCombo: false, winWatch: 0,\n       diagnostic: A_Args.Length >= 1 && A_Args[1] = "diag" }',
            'G := { held: Map(), lastActivity: A_TickCount, winCombo: false, winWatch: 0 }')
        text = pattern(text, r'^TraceStart\("GUEST"[^\n]*\n')
        text = pattern(text, r'^GuestLog\(msg\) \{.*?^}', 'GuestLog(msg) {\n    ; No logging in this package.\n}')
    assert not re.search(r"\bTrace\w*|\bdiagnostic\b|Bridge_Logger", text), name
    return text.encode("utf-8")

files = {name: runtime(name) for name in ("Host_PC_Bridge.ahk", "Guest_SM_Receiver.ahk")}
config = (ROOT / "Bridge_Config.ahk").read_text(encoding="utf-8")
files["Bridge_Config.ahk"] = re.sub(r"^DEBUG_LOG\s*:=.*\n", "", config, flags=re.M).encode("utf-8")
files["README.md"] = (ROOT / "RELEASE_README.md").read_bytes()
for name in ("SM_Baslat.bat", "Waterfox_SM/user.js", "Waterfox_SM/Apply_Waterfox_Prefs.ps1",
             "Waterfox_SM/Set_Fullscreen_UI.ps1", "Waterfox_SM/fullscreen-ui.css"):
    files[name] = (ROOT / name).read_bytes()
files["SHA256SUMS.txt"] = "".join(hashlib.sha256(data).hexdigest() + "  " + name + "\n"
    for name, data in sorted(files.items())).encode("ascii")
PACKAGE.mkdir(parents=True, exist_ok=True)
existing = {p.relative_to(PACKAGE).as_posix() for p in PACKAGE.rglob("*") if p.is_file()}
assert not existing - files.keys(), "Unexpected files in output directory"
for name, data in files.items():
    target = PACKAGE / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
subprocess.run([sys.executable, "-u", str(ROOT / "tests/test_bridge.py")],
    env=dict(os.environ, BRIDGE_TEST_ROOT=str(PACKAGE)), check=True)
output = ROOT / "releases" / (NAME + ".zip")
output.parent.mkdir(exist_ok=True)
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for name, data in sorted(files.items()):
        info = zipfile.ZipInfo(NAME + "/" + name, date_time=(2026, 9, 30, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, data)
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {NAME + "/" + name for name in files}
    for name, data in files.items():
        assert archive.read(NAME + "/" + name) == data
print("PACKAGE:", output)
print("SHA256:", hashlib.sha256(output.read_bytes()).hexdigest())
