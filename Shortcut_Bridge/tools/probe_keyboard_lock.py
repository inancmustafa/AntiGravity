"""Waterfox'un OS kisayollarini sayfaya birakip birakamayacagini olcer.

Waterfox guncellendiginde calistir: python tools/probe_keyboard_lock.py [waterfox.exe]
Gecici, bos bir profille HEADLESS acilir; gunluk profile, Horizon'a veya klavyeye
dokunmaz. Yalnizca tarayicinin hangi Keyboard Lock arayuzlerini sundugunu raporlar.

Neden: Chromium'da Horizon, navigator.keyboard.lock() ile tam ekranda Alt+Tab/Win'i
yakalayabilir. Gecko bu API'yi sunmuyor; onun yerine requestFullscreen({keyboardLock})
seçenegi var. "system" degeri gelmedikce Alt+Tab/Win tarayicida kalmaz ve kopru
gerekli olmaya devam eder.
"""
import base64, functools, http.server, json, os, shutil, socket, struct, subprocess
import sys, tempfile, threading, time

WATERFOX = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files\Waterfox\waterfox.exe"
PAGE = b"<!doctype html><title>probe</title><p>probe</p>"


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class Bidi:
    """Tek oturumluk, yalnizca stdlib kullanan WebDriver BiDi istemcisi."""

    def __init__(self, port, timeout=40):
        deadline = time.time() + timeout
        while True:
            try:
                self.sock = socket.create_connection(("127.0.0.1", port), timeout=5)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(0.5)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((f"GET /session HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\n"
                           "Upgrade: websocket\r\nConnection: Upgrade\r\n"
                           f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        data = b""
        while b"\r\n\r\n" not in data:
            data += self.sock.recv(4096)
        head, self.buf = data.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise RuntimeError(head.decode(errors="replace"))
        self.sock.settimeout(60)
        self.next_id = 1

    def _read(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("BiDi baglantisi kapandi")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def _frame(self):
        message = b""
        while True:
            b1, b2 = self._read(2)
            n = b2 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read(8))[0]
            message += self._read(n)
            if b1 & 0x80:
                return message.decode()

    def cmd(self, method, **params):
        cid, self.next_id = self.next_id, self.next_id + 1
        data = json.dumps({"id": cid, "method": method, "params": params}).encode()
        header = bytearray([0x81])
        if len(data) < 126:
            header.append(0x80 | len(data))
        else:
            header.append(0x80 | 126)
            header += struct.pack(">H", len(data))
        mask = os.urandom(4)
        self.sock.sendall(bytes(header) + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))
        while True:
            msg = json.loads(self._frame())
            if msg.get("id") == cid:
                if msg.get("type") == "error":
                    raise RuntimeError(f"{method}: {msg.get('message')}")
                return msg["result"]


PROBE = """(async () => {
    const lock = {};
    for (const v of ['none', 'browser', 'system']) {
        try { await document.body.requestFullscreen({ keyboardLock: v }); lock[v] = 'valid'; }
        catch (e) { lock[v] = /enumeration/.test(String(e)) ? 'invalid' : 'valid'; }
    }
    return JSON.stringify({ ua: navigator.userAgent,
        navigatorKeyboardLock: typeof (navigator.keyboard && navigator.keyboard.lock), lock });
})()"""


def main():
    web_port, bidi_port = free_port(), free_port()

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(PAGE)

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", web_port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    profile = tempfile.mkdtemp(prefix="shortcut-bridge-kl-probe-")
    with open(os.path.join(profile, "user.js"), "w", encoding="utf-8") as f:
        f.write('user_pref("dom.fullscreen.keyboard_lock.enabled", true);\n'
                'user_pref("browser.shell.checkDefaultBrowser", false);\n'
                'user_pref("app.update.auto", false);\n')
    proc = subprocess.Popen([WATERFOX, "--headless", "-no-remote", "-profile", profile,
                             "--remote-debugging-port", str(bidi_port)],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        bidi = Bidi(bidi_port)
        bidi.cmd("session.new", capabilities={})
        ctx = bidi.cmd("browsingContext.getTree")["contexts"][0]["context"]
        bidi.cmd("browsingContext.navigate", context=ctx,
                 url=f"http://127.0.0.1:{web_port}/", wait="complete")
        result = bidi.cmd("script.evaluate", expression=PROBE, target={"context": ctx},
                          awaitPromise=True)
        report = json.loads(result["result"]["value"])
    finally:
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
        server.shutdown()
        time.sleep(1)
        shutil.rmtree(profile, ignore_errors=True)

    print("Tarayici               :", report["ua"])
    print("navigator.keyboard.lock:", report["navigatorKeyboardLock"])
    print("requestFullscreen keyboardLock:", report["lock"])
    if report["navigatorKeyboardLock"] == "function" or report["lock"].get("system") == "valid":
        print("SONUC: Tarayici OS kisayollarini yakalayabilir olabilir. Horizon'un bunu kullanip")
        print("kullanmadigini canli oturumda kopru DURAKLATILMIS halde Alt+Tab/Win ile dene.")
    else:
        print("SONUC: Yalnizca tarayici kisayollari kilitlenebilir; Alt+Tab ve Win icin kopru gerekli.")


if __name__ == "__main__":
    main()
