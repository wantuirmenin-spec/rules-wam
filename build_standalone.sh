#!/bin/sh
# ====================================================================
# Gera o instalador autônomo wam-install.sh (auto-extraível) e o pacote .zip.
# O wam-install.sh só extrai os arquivos e executa o MESMO install.sh do pacote,
# então não existe mais lógica duplicada entre os dois instaladores.
# ====================================================================
set -eu
cd "$(dirname "$0")"

OUT=wam-install.sh
FILES="install.sh uninstall.sh pkg www widgets feeds"
PAYLOAD=$(mktemp)
tar -czf "$PAYLOAD" $FILES

cat > "$OUT" <<'HEADER'
#!/bin/sh
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
HEADER
openssl base64 < "$PAYLOAD" >> "$OUT"
rm -f "$PAYLOAD"
chmod +x "$OUT"
echo "Gerado $OUT ($(wc -c < "$OUT") bytes)"

ZIP=../rules-wam-pacote.zip
rm -f "$ZIP"
zip -qr "$ZIP" README.md MANUAL_DE_INSTALACAO.md MANUAL_DO_ADMINISTRADOR.md CHANGELOG.md \
    install.sh uninstall.sh build_standalone.sh "$OUT" index.html pkg www widgets feeds
echo "Gerado $ZIP"
