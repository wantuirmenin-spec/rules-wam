#!/bin/sh
# ====================================================================
# Instalador / atualizador do Rules WAM para pfSense 2.7.x / 2.8.x
#
# Uso:
#   sh install.sh [--move-gui] [--gui-port=50443] [--wan-gui-sources=IP1,IP2|none]
#
#   --move-gui            Se a WebGUI estiver nas portas 80/443, move para --gui-port
#                         (padrão 50443) e desativa o redirecionamento HTTP, liberando
#                         a porta 80 para o banner. Sem esta opção a WebGUI não é alterada
#                         e o bloqueio fica no modo silencioso (0.0.0.0).
#   --wan-gui-sources=    Só para quem atualiza da 1.3: a 1.3 liberava a WebGUI na WAN para
#                         qualquer origem. Informe os IPs públicos que podem continuar
#                         acessando, ou "none" para remover o acesso pela WAN.
#
# Em terminal interativo (SSH) as perguntas são feitas na tela.
# ====================================================================

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Erro: execute como root no pfSense."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PHP=/usr/local/bin/php
INTERACTIVE=no
[ -t 0 ] && INTERACTIVE=yes

WAM_MOVE_GUI="${WAM_MOVE_GUI:-}"
WAM_GUI_PORT="${WAM_GUI_PORT:-50443}"
WAM_WAN_GUI_SOURCES="${WAM_WAN_GUI_SOURCES:-}"
for arg in "$@"; do
    case "$arg" in
        --move-gui) WAM_MOVE_GUI=yes ;;
        --gui-port=*) WAM_GUI_PORT="${arg#*=}" ;;
        --wan-gui-sources=*) WAM_WAN_GUI_SOURCES="${arg#*=}" ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "Opção desconhecida: $arg"; exit 1 ;;
    esac
done

for f in pkg/rules_wam.inc pkg/rules_wam.xml pkg/rules_wam.priv.inc pkg/register_menu.php pkg/wam_cron.php \
         pkg/wam_setup.php www/rules_wam.php www/rules_wam_status.php www/rules_wam_dashboard.php \
         www/rules_wam_block.php widgets/include/rules_wam.inc widgets/widgets/rules_wam.widget.php; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        echo "Erro: arquivo ausente no pacote: $f"
        exit 1
    fi
done

echo "======================================================"
echo " Rules WAM - instalação / atualização"
echo "======================================================"

echo "0. Verificações prévias (nada é alterado nesta etapa)..."
export WAM_WAN_GUI_SOURCES
set +e
$PHP -q "$SCRIPT_DIR/pkg/wam_setup.php" check-wan
WAN_RC=$?
set -e
if [ "$WAN_RC" -eq 2 ]; then
    echo "   Instalação interrompida sem alterações: --wan-gui-sources contém valores inválidos."
    exit 2
fi
if [ "$WAN_RC" -eq 3 ] && [ -z "$WAM_WAN_GUI_SOURCES" ]; then
    echo ""
    echo "   A versão 1.3 criou uma regra liberando a WebGUI na WAN para QUALQUER origem."
    echo "   Esta versão remove essa regra. Se você administra este firewall pela WAN,"
    echo "   informe os IPs públicos da equipe de TI para manter o acesso."
    if [ "$INTERACTIVE" = "yes" ]; then
        printf "   IPs/redes autorizados pela WAN (separados por vírgula) ou 'none': "
        read -r WAM_WAN_GUI_SOURCES
    fi
    if [ -z "$WAM_WAN_GUI_SOURCES" ]; then
        echo ""
        echo "   Instalação interrompida sem alterações na configuração."
        echo "   Rode novamente com --wan-gui-sources=IP1,IP2 ou --wan-gui-sources=none"
        exit 3
    fi
    export WAM_WAN_GUI_SOURCES
    if ! $PHP -q "$SCRIPT_DIR/pkg/wam_setup.php" check-wan; then
        echo "   Instalação interrompida sem alterações: origens WAN inválidas."
        exit 2
    fi
fi

GUI_CONFLICT=$($PHP -q "$SCRIPT_DIR/pkg/wam_setup.php" check-gui 2>/dev/null || true)
if [ -n "$GUI_CONFLICT" ] && [ -z "$WAM_MOVE_GUI" ]; then
    echo ""
    echo "   $GUI_CONFLICT"
    echo "   O banner de bloqueio precisa da porta 80 livre. Sem mover a WebGUI, os sites"
    echo "   bloqueados apenas não abrem (resposta 0.0.0.0), sem a página institucional."
    if [ "$INTERACTIVE" = "yes" ]; then
        printf "   Mover a WebGUI para a porta %s e desativar o redirecionamento HTTP? [s/N]: " "$WAM_GUI_PORT"
        read -r ans
        case "$ans" in s|S|sim|y|Y|yes) WAM_MOVE_GUI=yes ;; *) WAM_MOVE_GUI=no ;; esac
    fi
fi

echo "1. Copiando arquivos..."
mkdir -p /usr/local/pkg /usr/local/www/widgets/include /usr/local/www/widgets/widgets \
         /usr/local/share/wam/feeds /usr/local/etc/nginx /usr/local/etc/rc.d /etc/inc/priv /var/db
install -m 0644 "$SCRIPT_DIR/pkg/rules_wam.xml"        /usr/local/pkg/rules_wam.xml
install -m 0644 "$SCRIPT_DIR/pkg/rules_wam.inc"        /usr/local/pkg/rules_wam.inc
install -m 0644 "$SCRIPT_DIR/pkg/register_menu.php"    /usr/local/pkg/register_menu.php
install -m 0644 "$SCRIPT_DIR/pkg/wam_cron.php"         /usr/local/pkg/wam_cron.php
install -m 0644 "$SCRIPT_DIR/pkg/wam_setup.php"        /usr/local/pkg/wam_setup.php
install -m 0644 "$SCRIPT_DIR/pkg/rules_wam.priv.inc"   /etc/inc/priv/rules_wam.priv.inc
install -m 0644 "$SCRIPT_DIR/www/rules_wam.php"            /usr/local/www/rules_wam.php
install -m 0644 "$SCRIPT_DIR/www/rules_wam_status.php"     /usr/local/www/rules_wam_status.php
install -m 0644 "$SCRIPT_DIR/www/rules_wam_dashboard.php"  /usr/local/www/rules_wam_dashboard.php
install -m 0644 "$SCRIPT_DIR/www/rules_wam_block.php"      /usr/local/www/rules_wam_block.php
install -m 0644 "$SCRIPT_DIR/widgets/include/rules_wam.inc"         /usr/local/www/widgets/include/rules_wam.inc
install -m 0644 "$SCRIPT_DIR/widgets/widgets/rules_wam.widget.php"  /usr/local/www/widgets/widgets/rules_wam.widget.php
install -m 0644 "$SCRIPT_DIR/feeds/"*.txt /usr/local/share/wam/feeds/
[ -f "$SCRIPT_DIR/uninstall.sh" ] && install -m 0755 "$SCRIPT_DIR/uninstall.sh" /usr/local/share/wam/uninstall.sh

# Sobras da versão 1.3 (cópias duplicadas, hook, CA pública, script de sync antigo)
rm -f /usr/local/pkg/wam.inc /usr/local/pkg/wam.xml /usr/local/pkg/wam_sync.php \
      /usr/local/pkg/rules_wam_hook.inc /usr/local/www/wam_status.php /usr/local/www/rules_wam_ca.crt

# A versão 1.3 deixava o socket do PHP-FPM gravável por qualquer usuário (chmod 666)
if [ -S /var/run/php-fpm.socket ] && [ -n "$(find /var/run/php-fpm.socket -perm -o+w 2>/dev/null)" ]; then
    chmod o-rwx,g-w /var/run/php-fpm.socket
    echo "   Permissões do socket do PHP-FPM restauradas (removido o acesso de outros usuários)"
fi

touch /var/log/wam_audit.log
chmod 0640 /var/log/wam_audit.log

echo "2. Registrando menu, cron e privilégios..."
$PHP -q /usr/local/pkg/register_menu.php

echo "3. Aplicando configuração..."
export WAM_MOVE_GUI WAM_GUI_PORT WAM_WAN_GUI_SOURCES
RC=0
$PHP -q /usr/local/pkg/wam_setup.php install > /tmp/wam_setup.out 2>&1 || RC=$?
grep -v '^WEBGUI_PORT=' /tmp/wam_setup.out || true
if [ "$RC" -ne 0 ]; then
    echo "Erro ao aplicar a configuração (código $RC)."
    rm -f /tmp/wam_setup.out
    exit "$RC"
fi
GUI_PORT=$(sed -n 's/^WEBGUI_PORT=//p' /tmp/wam_setup.out | tail -n 1)
rm -f /tmp/wam_setup.out /tmp/config.cache /tmp/menu.cache /tmp/pkg_menu.cache

echo ""
echo "======================================================"
echo " Rules WAM instalado."
echo "======================================================"
echo " Menu:   Services > Rules WAM"
echo " Desinstalar: sh /usr/local/share/wam/uninstall.sh"
echo " WebGUI: https://<IP-do-firewall>:${GUI_PORT:-?}"
if [ -s /var/log/wam_checkconf_err.log ]; then
    echo " ATENÇÃO: o Unbound rejeitou parte da configuração. Veja /var/log/wam_checkconf_err.log"
fi
echo "======================================================"
