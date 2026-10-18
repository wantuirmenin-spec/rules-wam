"""Equivalente ao build_standalone.sh: gera wam-install.sh (auto-extraível) e o .zip do pacote.
Normaliza os arquivos de texto para LF (o FreeBSD/pfSense não aceita CRLF em scripts shell)."""
import base64
import io
import os
import sys
import tarfile
import time
import zipfile

ROOT = sys.argv[1]
ZIP_OUT = sys.argv[2]
FILES = ["install.sh", "uninstall.sh", "pkg", "www", "widgets", "feeds"]
TEXT_EXT = {".sh", ".php", ".inc", ".xml", ".txt", ".md", ".html", ".json", ".css", ".js"}

HEADER = """#!/bin/sh
# Rules WAM - instalador autônomo (auto-extraível)
# Uso: sh wam-install.sh [--move-gui] [--gui-port=50443] [--wan-gui-sources=IP1,IP2|none]
# Para desinstalar depois: sh /usr/local/share/wam/uninstall.sh
set -eu
if [ "$(id -u)" -ne 0 ]; then
    echo "Erro: execute como root no pfSense."
    exit 1
fi
TMP_DIR=$(mktemp -d /tmp/wam_install.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT
LINE=$(awk '/^__PAYLOAD_BELOW__$/ { print NR + 1; exit 0 }' "$0")
tail -n +"$LINE" "$0" | /usr/bin/openssl base64 -d | tar -xzf - -C "$TMP_DIR"
sh "$TMP_DIR/install.sh" "$@"
exit $?
__PAYLOAD_BELOW__
"""


def read_lf(path):
    data = open(path, "rb").read()
    if os.path.splitext(path)[1].lower() in TEXT_EXT:
        data = data.replace(b"\r\n", b"\n")
    return data


def add(tar, rel):
    full = os.path.join(ROOT, rel)
    if os.path.isdir(full):
        ti = tarfile.TarInfo(rel.replace(os.sep, "/") + "/")
        ti.type = tarfile.DIRTYPE
        ti.mode = 0o755
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = "root"
        # Data fixa (a do arquivo mais novo da pasta): o hash do instalador só muda se o conteúdo mudar
        ti.mtime = int(max((os.path.getmtime(os.path.join(dp, n)) for dp, _, ns in os.walk(full) for n in ns), default=0))
        tar.addfile(ti)
        for name in sorted(os.listdir(full)):
            add(tar, os.path.join(rel, name))
        return
    data = read_lf(full)
    if not data:
        sys.exit(f"ERRO: {rel} está vazio")
    ti = tarfile.TarInfo(rel.replace(os.sep, "/"))
    ti.size = len(data)
    ti.mode = 0o755 if rel.endswith(".sh") else 0o644
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = "root"
    ti.mtime = int(os.path.getmtime(full))
    tar.addfile(ti, io.BytesIO(data))


import gzip
raw = io.BytesIO()
with tarfile.open(fileobj=raw, mode="w", format=tarfile.USTAR_FORMAT) as tar:
    for f in FILES:
        add(tar, f)
# gzip com mtime=0: o cabeçalho do gzip também não carrega a hora do build
buf = io.BytesIO(gzip.compress(raw.getvalue(), mtime=0))

b64 = base64.b64encode(buf.getvalue()).decode("ascii")
lines = "\n".join(b64[i:i + 64] for i in range(0, len(b64), 64)) + "\n"
out = os.path.join(ROOT, "wam-install.sh")
with open(out, "wb") as fh:
    fh.write(HEADER.encode("utf-8") + lines.encode("ascii"))
print(f"Gerado {out} ({os.path.getsize(out)} bytes)")

# Os .sh do próprio pacote também em LF
for sh in ("install.sh", "uninstall.sh", "build_standalone.sh"):
    p = os.path.join(ROOT, sh)
    data = read_lf(p)  # lê ANTES de abrir para escrita (abrir com "wb" trunca o arquivo)
    if not data:
        sys.exit(f"ERRO: {sh} está vazio")
    if data != open(p, "rb").read():
        with open(p, "wb") as fh:
            fh.write(data)

ZIP_FILES = ["README.md", "MANUAL_DE_INSTALACAO.md", "MANUAL_DO_ADMINISTRADOR.md", "CHANGELOG.md",
             "install.sh", "uninstall.sh", "build_standalone.sh", "wam-install.sh", "index.html",
             "pkg", "www", "widgets", "feeds", "captive-portal"]
with zipfile.ZipFile(ZIP_OUT, "w", zipfile.ZIP_DEFLATED) as z:
    for f in ZIP_FILES:
        full = os.path.join(ROOT, f)
        paths = [full] if os.path.isfile(full) else [
            os.path.join(d, n) for d, _, ns in os.walk(full) for n in sorted(ns)]
        for p in paths:
            rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
            zi = zipfile.ZipInfo(rel, time.localtime(os.path.getmtime(p))[:6])
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = ((0o755 if rel.endswith(".sh") else 0o644) | 0o100000) << 16
            z.writestr(zi, read_lf(p))
print(f"Gerado {ZIP_OUT}")
