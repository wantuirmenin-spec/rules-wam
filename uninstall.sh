#!/bin/sh
# ====================================================================
# Desinstalador Completo do Pacote Rules WAM do pfSense
# ====================================================================

set -e

echo "======================================================"
echo " 🗑️ Removendo Pacote Rules WAM do pfSense"
echo "======================================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Erro: Este script precisa ser executado como root."
    exit 1
fi

echo "1. Parando serviço NGINX SSL (Porta 443)..."
if [ -f /usr/local/etc/rc.d/rules_wam_ssl.sh ]; then
    sh /usr/local/etc/rc.d/rules_wam_ssl.sh stop 2>/dev/null || true
fi
if [ -f /var/run/rules_wam_ssl.pid ]; then
    kill -9 $(cat /var/run/rules_wam_ssl.pid) 2>/dev/null || true
    rm -f /var/run/rules_wam_ssl.pid
fi
rm -f /usr/local/etc/nginx/rules_wam_ssl.conf /usr/local/etc/rc.d/rules_wam_ssl.sh

echo "2. Removendo regras ativas do Unbound DNS..."
rm -f /var/unbound/conf.d/wam_blocklist.conf
rm -f /var/log/wam_status.json /var/log/rules_wam_ssl.log

echo "3. Recarregando Unbound DNS..."
if [ -f /usr/local/sbin/unbound-control ]; then
    /usr/local/sbin/unbound-control reload 2>/dev/null || true
fi

echo "4. Removendo hooks do webConfigurator..."
php -r '
foreach (array("/usr/local/www/index.php", "/usr/local/www/404.php") as $f) {
    if (file_exists($f)) {
        $c = file_get_contents($f);
        $c = str_replace("if (file_exists(\"/usr/local/pkg/rules_wam_hook.inc\")) { require_once(\"/usr/local/pkg/rules_wam_hook.inc\"); }\n", "", $c);
        file_put_contents($f, $c);
    }
}
if (file_exists("/usr/local/www/404.html")) {
    $c404 = file_get_contents("/usr/local/www/404.html");
    $c404 = preg_replace("/<script>if\(window\.location\.hostname!==.*?<\/script>\s*/i", "", $c404);
    file_put_contents("/usr/local/www/404.html", $c404);
}
'

echo "5. Removendo arquivos do pacote, páginas web, feeds e widgets..."
rm -f /usr/local/pkg/rules_wam.*
rm -f /usr/local/pkg/rules_wam_hook.inc
rm -f /usr/local/pkg/wam.*
rm -f /usr/local/pkg/wam_sync.php
rm -f /usr/local/pkg/wam_cron.php
rm -f /usr/local/pkg/register_menu.php
rm -f /usr/local/www/rules_wam*.php
rm -f /usr/local/www/rules_wam_ca.crt
rm -f /usr/local/www/wam_status.php
rm -f /usr/local/www/widgets/include/rules_wam.inc
rm -f /usr/local/www/widgets/widgets/rules_wam.widget.php
rm -f /var/etc/rules_wam_*
rm -rf /usr/local/share/wam

echo "6. Removendo pacote, menus e cron do config.xml..."
php -r '
require_once("config.inc");
global $config;

// Remover pacotes
if (isset($config["installedpackages"]["package"])) {
    foreach ($config["installedpackages"]["package"] as $idx => $p) {
        if (isset($p["name"]) && ($p["name"] === "rules_wam" || $p["name"] === "wam")) {
            unset($config["installedpackages"]["package"][$idx]);
        }
    }
    $config["installedpackages"]["package"] = array_values($config["installedpackages"]["package"]);
}

// Remover nós de configuração
unset($config["installedpackages"]["rules_wam"]);
unset($config["installedpackages"]["wam"]);

// Remover menus
if (isset($config["installedpackages"]["menu"])) {
    foreach ($config["installedpackages"]["menu"] as $idx => $m) {
        if (isset($m["name"]) && ($m["name"] === "Rules WAM" || $m["name"] === "WAM - Bloqueio de Categorias")) {
            unset($config["installedpackages"]["menu"][$idx]);
        }
    }
    $config["installedpackages"]["menu"] = array_values($config["installedpackages"]["menu"]);
}

// Remover cron
$cron_cmd = "/usr/local/bin/php -q /usr/local/pkg/wam_cron.php";
if (isset($config["cron"]["item"])) {
    foreach ($config["cron"]["item"] as $idx => $c) {
        if (isset($c["command"]) && $c["command"] === $cron_cmd) {
            unset($config["cron"]["item"][$idx]);
        }
    }
    $config["cron"]["item"] = array_values($config["cron"]["item"]);
}

// Remover widget da sequência do Dashboard
if (isset($config["system"]["user"])) {
    foreach ($config["system"]["user"] as $idx => $u) {
        if (!empty($u["widgets"]["sequence"]) && strpos($u["widgets"]["sequence"], "rules_wam") !== false) {
            $seqs = explode(",", $u["widgets"]["sequence"]);
            $seqs = array_filter($seqs, function($s) { return strpos($s, "rules_wam") === false; });
            $config["system"]["user"][$idx]["widgets"]["sequence"] = implode(",", $seqs);
        }
    }
}
if (!empty($config["widgets"]["sequence"]) && strpos($config["widgets"]["sequence"], "rules_wam") !== false) {
    $seqs = explode(",", $config["widgets"]["sequence"]);
    $seqs = array_filter($seqs, function($s) { return strpos($s, "rules_wam") === false; });
    $config["widgets"]["sequence"] = implode(",", $seqs);
}

// Remover Certificados da CA Rules WAM
if (isset($config["ca"])) {
    foreach ($config["ca"] as $idx => $ca) {
        if (isset($ca["descr"]) && $ca["descr"] === "Rules WAM Firewall CA") {
            unset($config["ca"][$idx]);
        }
    }
    $config["ca"] = array_values($config["ca"]);
}
if (isset($config["cert"])) {
    foreach ($config["cert"] as $idx => $cert) {
        if (isset($cert["descr"]) && $cert["descr"] === "Rules WAM SSL Server") {
            unset($config["cert"][$idx]);
        }
    }
    $config["cert"] = array_values($config["cert"]);
}

// Remover regras de Firewall e NAT do Rules WAM
if (isset($config["filter"]["rule"])) {
    foreach ($config["filter"]["rule"] as $idx => $r) {
        if (isset($r["descr"]) && strpos($r["descr"], "Rules WAM") !== false) {
            unset($config["filter"]["rule"][$idx]);
        }
    }
    $config["filter"]["rule"] = array_values($config["filter"]["rule"]);
}
if (isset($config["nat"]["rule"])) {
    foreach ($config["nat"]["rule"] as $idx => $r) {
        if (isset($r["descr"]) && strpos($r["descr"], "Rules WAM") !== false) {
            unset($config["nat"]["rule"][$idx]);
        }
    }
    $config["nat"]["rule"] = array_values($config["nat"]["rule"]);
}
if (isset($config["aliases"]["alias"])) {
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if (isset($a["name"]) && strpos($a["name"], "WAM_") === 0) {
            unset($config["aliases"]["alias"][$idx]);
        }
    }
    $config["aliases"]["alias"] = array_values($config["aliases"]["alias"]);
}

write_config("Rules WAM desinstalado completamente");
if (function_exists("configure_cron")) {
    configure_cron();
}
'

rm -f /tmp/config.cache /tmp/menu.cache 2>/dev/null || true

echo ""
echo "======================================================"
echo " ✅ Pacote Rules WAM removido com sucesso!"
echo "======================================================"
