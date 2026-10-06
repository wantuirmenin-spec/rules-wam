#!/bin/sh
# ====================================================================
# Desinstalador do Rules WAM para pfSense
# Desfaz as alterações no config.xml ANTES de apagar os arquivos.
# ====================================================================

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Erro: execute como root no pfSense."
    exit 1
fi

echo "======================================================"
echo " Removendo o Rules WAM"
echo "======================================================"

echo "1. Revertendo configuração (Unbound, banner, firewall/NAT, aliases, menus, cron, WebGUI)..."
if [ -f /usr/local/pkg/wam_setup.php ] && [ -f /usr/local/pkg/rules_wam.inc ]; then
    /usr/local/bin/php -q /usr/local/pkg/wam_setup.php uninstall
else
    echo "   Aviso: wam_setup.php não encontrado (instalação antiga). Rode o install.sh desta"
    echo "   versão primeiro e depois este desinstalador, para reverter a configuração corretamente."
    exit 1
fi

echo "2. Parando o banner..."
if [ -f /usr/local/etc/rc.d/rules_wam_ssl.sh ]; then
    sh /usr/local/etc/rc.d/rules_wam_ssl.sh stop || true
fi

echo "3. Removendo arquivos..."
rm -f /usr/local/etc/nginx/rules_wam_ssl.conf /usr/local/etc/rc.d/rules_wam_ssl.sh
rm -f /var/unbound/wam_blocklist.conf /var/unbound/conf.d/wam_blocklist.conf
rm -f /usr/local/pkg/rules_wam.inc /usr/local/pkg/rules_wam.xml /usr/local/pkg/rules_wam_hook.inc
rm -f /usr/local/pkg/wam.inc /usr/local/pkg/wam.xml /usr/local/pkg/wam_sync.php /usr/local/pkg/wam_cron.php
rm -f /usr/local/pkg/register_menu.php /usr/local/pkg/wam_setup.php /etc/inc/priv/rules_wam.priv.inc
rm -f /usr/local/www/rules_wam.php /usr/local/www/rules_wam_status.php /usr/local/www/rules_wam_dashboard.php
rm -f /usr/local/www/rules_wam_block.php /usr/local/www/wam_status.php /usr/local/www/rules_wam_ca.crt
rm -f /usr/local/www/widgets/include/rules_wam.inc /usr/local/www/widgets/widgets/rules_wam.widget.php
rm -f /var/etc/rules_wam_ca.crt /var/etc/rules_wam_ca.key /var/etc/rules_wam_ca.srl /var/etc/rules_wam_ssl.crt /var/etc/rules_wam_ssl.key
rm -f /var/db/rules_wam_categories.json /var/log/wam_status.json /var/log/wam_checkconf_err.log /var/log/rules_wam_ssl.log
rm -rf /usr/local/share/wam
rm -f /tmp/config.cache /tmp/menu.cache /tmp/pkg_menu.cache

echo "4. Recarregando o Unbound..."
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf reload >/dev/null 2>&1 || true

echo ""
echo "======================================================"
echo " Rules WAM removido."
echo " O log de auditoria foi mantido em /var/log/wam_audit.log (apague se não precisar)."
echo "======================================================"
