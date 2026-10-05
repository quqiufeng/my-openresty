#!/usr/bin/env bash
# TCP/UDP (L4) 集成测试：TCP echo / TCP 代理轮询 / UDP echo / UDP 代理 / 自定义 handler
# 依赖: bin/nginx 已构建（bin/build.sh）；python3
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

if [ ! -x "$ROOT/bin/nginx" ]; then
    echo "[SKIP] 未构建 bin/nginx，请先运行 bin/build.sh"; exit 0
fi

started=0
if ! (ss -tln 2>/dev/null | grep -q ':8080'); then
    "$ROOT/bin/start.sh" >/dev/null 2>&1 && started=1
    sleep 0.6
fi

cleanup() {
    if [ "$started" = "1" ]; then "$ROOT/bin/stop.sh" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

python3 - <<'PY'
import socket, threading, time, sys

def tcp_srv(port, tag):
    s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    s.bind(("127.0.0.1",port)); s.listen(16)
    def loop():
        while True:
            try: c,_=s.accept()
            except OSError: break
            def h(c):
                try:
                    while True:
                        d=c.recv(4096)
                        if not d: break
                        c.sendall(tag+d)
                finally: c.close()
            threading.Thread(target=h,args=(c,),daemon=True).start()
    threading.Thread(target=loop,daemon=True).start()

def udp_srv(port, tag):
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.bind(("127.0.0.1",port))
    def loop():
        while True:
            try: d,a=s.recvfrom(4096)
            except OSError: break
            s.sendto(tag+d,a)
    threading.Thread(target=loop,daemon=True).start()

tcp_srv(19011,b"[B1]"); tcp_srv(19012,b"[B2]"); udp_srv(19014,b"[U1]")
time.sleep(0.3)

def tcp(port,data):
    c=socket.create_connection(("127.0.0.1",port),timeout=3); c.sendall(data); return c.recv(4096)
def udp(port,data):
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(3)
    s.sendto(data,("127.0.0.1",port)); return s.recvfrom(4096)[0]

fails=0
def check(name, got, want):
    global fails
    if got==want: print(f"✓ PASS: {name}")
    else: print(f"✗ FAIL: {name}  got={got!r} want={want!r}"); fails+=1

check("TCP echo 19001", tcp(19001,b"hi"), b"hi")
check("TCP proxy 19002 #1", tcp(19002,b"x"), b"[B1]x")
check("TCP proxy 19002 #2", tcp(19002,b"y"), b"[B2]y")
check("TCP hello 19005", tcp(19005,b""), b"hello from MyResty tcpudp [tcp_hello]\r\n")
check("UDP echo 19003", udp(19003,b"u"), b"u")
check("UDP proxy 19004", udp(19004,b"p"), b"[U1]p")
print()
print("ALL PASSED" if fails==0 else f"{fails} FAILED")
sys.exit(1 if fails else 0)
PY
