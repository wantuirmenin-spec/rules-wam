#!/bin/sh
# ====================================================================
# Instalador Completo do Pacote Rules WAM para pfSense
# ====================================================================

set -e

echo "======================================================"
echo " 🚀 Iniciando Instalação do Pacote Rules WAM no pfSense"
echo "======================================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Erro: Este script precisa ser executado como root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "📂 1. Criando diretórios do sistema..."
mkdir -p /usr/local/pkg
mkdir -p /usr/local/www
mkdir -p /usr/local/www/widgets/include
mkdir -p /usr/local/www/widgets/widgets
mkdir -p /usr/local/share/wam/feeds
mkdir -p /var/unbound/conf.d
mkdir -p /usr/local/etc/nginx /usr/local/etc/rc.d /var/etc

echo "📦 2. Copiando arquivos do pacote, feeds e widgets..."
cp "$SCRIPT_DIR/pkg/rules_wam.xml" /usr/local/pkg/rules_wam.xml
cp "$SCRIPT_DIR/pkg/rules_wam.inc" /usr/local/pkg/rules_wam.inc
cp "$SCRIPT_DIR/pkg/rules_wam.inc" /usr/local/pkg/wam.inc
cp "$SCRIPT_DIR/pkg/rules_wam_hook.inc" /usr/local/pkg/rules_wam_hook.inc
cp "$SCRIPT_DIR/pkg/register_menu.php" /usr/local/pkg/register_menu.php
cp "$SCRIPT_DIR/pkg/wam_sync.php" /usr/local/pkg/wam_sync.php
cp "$SCRIPT_DIR/pkg/wam_cron.php" /usr/local/pkg/wam_cron.php
cp "$SCRIPT_DIR/www/rules_wam.php" /usr/local/www/rules_wam.php
cp "$SCRIPT_DIR/www/rules_wam_status.php" /usr/local/www/rules_wam_status.php
cp "$SCRIPT_DIR/www/rules_wam_dashboard.php" /usr/local/www/rules_wam_dashboard.php
cp "$SCRIPT_DIR/www/rules_wam_block.php" /usr/local/www/rules_wam_block.php
cp "$SCRIPT_DIR/widgets/include/rules_wam.inc" /usr/local/www/widgets/include/rules_wam.inc
cp "$SCRIPT_DIR/widgets/widgets/rules_wam.widget.php" /usr/local/www/widgets/widgets/rules_wam.widget.php
cp "$SCRIPT_DIR/feeds/"*.txt /usr/local/share/wam/feeds/

chmod 644 /usr/local/pkg/rules_wam.xml
chmod 644 /usr/local/pkg/rules_wam.inc
chmod 644 /usr/local/pkg/wam.inc
chmod 644 /usr/local/pkg/rules_wam_hook.inc
chmod 755 /usr/local/pkg/register_menu.php
chmod 755 /usr/local/pkg/wam_sync.php
chmod 755 /usr/local/pkg/wam_cron.php
chmod 644 /usr/local/www/rules_wam.php
chmod 644 /usr/local/www/rules_wam_status.php
chmod 644 /usr/local/www/rules_wam_dashboard.php
chmod 644 /usr/local/www/rules_wam_block.php
chmod 644 /usr/local/www/widgets/include/rules_wam.inc
chmod 644 /usr/local/www/widgets/widgets/rules_wam.widget.php
chmod 644 /usr/local/share/wam/feeds/*.txt

touch /var/log/wam_audit.log
chown www:wheel /var/log/wam_audit.log 2>/dev/null || true
chmod 640 /var/log/wam_audit.log

echo "⚙️ 3. Configurando interceptação de banner HTTP nos hosts..."
cat << 'EOF_HOOK_PHP' > /tmp/wam_hook.php
<?php
$hook = 'if (file_exists("/usr/local/pkg/rules_wam_hook.inc")) { require_once("/usr/local/pkg/rules_wam_hook.inc"); }';
foreach (array("/usr/local/www/index.php", "/usr/local/www/404.php") as $f) {
    if (file_exists($f)) {
        $c = file_get_contents($f);
        if (strpos($c, "rules_wam_hook.inc") === false) {
            $c = preg_replace("/<\\?php\\s*/i", "<?php\n" . $hook . "\n", $c, 1);
            file_put_contents($f, $c);
            echo "✓ Interceptor adicionado em $f\n";
        } else {
            echo "✓ Interceptor já presente em $f\n";
        }
    }
}
if (file_exists("/usr/local/www/404.html")) {
    $c404 = file_get_contents("/usr/local/www/404.html");
    require_once("config.inc");
    require_once("interfaces.inc");
    global $config;
    $lan_ip = function_exists("get_interface_ip") ? get_interface_ip("lan") : "";
    if (empty($lan_ip) && function_exists("get_interface_info")) { $linfo = get_interface_info("lan"); $lan_ip = $linfo["ipaddr"] ?? ""; }
    if (empty($lan_ip) && function_exists("config_get_path")) { $lan_ip = config_get_path("interfaces/lan/ipaddr", ""); }
    if (empty($lan_ip) && !empty($config["interfaces"]["lan"]["ipaddr"])) { $lan_ip = $config["interfaces"]["lan"]["ipaddr"]; }
    if (empty($lan_ip) || !filter_var($lan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) { $lan_ip = "192.168.1.1"; }
    $js_redirect = '<script>if(window.location.hostname!=="' . $lan_ip . '"&&!window.location.hostname.includes("pfsense")){window.location.replace(window.location.protocol+"//' . $lan_ip . '/rules_wam_block.php?domain="+encodeURIComponent(window.location.hostname));}</script>';
    $c404 = preg_replace('/<script>if\(window\.location\.hostname!==.*?<\/script>\s*/i', '', $c404);
    $c404 = preg_replace("/<head[^>]*>/i", "<head>\n" . $js_redirect, $c404, 1);
    file_put_contents("/usr/local/www/404.html", $c404);
    echo "✓ Redirecionador de subrotas atualizado em /usr/local/www/404.html\n";
}
EOF_HOOK_PHP
/usr/local/bin/php -q /tmp/wam_hook.php
rm -f /tmp/wam_hook.php

echo "⚙️ 4. Configurando suporte a banner em HTTPS (porta 443)..."
echo "⚙️ Liberando as portas 80 e 443 para exibição dos banners e blindando acesso na porta 50443..."
INITIAL_GUI_PORT=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["port"])) ? $config["system"]["webgui"]["port"] : "443";' 2>/dev/null)
[ -z "$INITIAL_GUI_PORT" ] && INITIAL_GUI_PORT=443

cat << 'EOF_WAM_INST_STEP4' > /tmp/wam_install_step4.php
<?php
require_once("config.inc");
require_once("filter.inc");
global $config;

init_config_arr(array("system", "webgui"));

$cur_proto = !empty($config["system"]["webgui"]["protocol"]) ? $config["system"]["webgui"]["protocol"] : "https";
$cur_port = !empty($config["system"]["webgui"]["port"]) ? $config["system"]["webgui"]["port"] : "";
if (empty($cur_port) || $cur_port == "443" || $cur_port == "80" || $cur_port == "8443") {
    $cur_port = "50443";
    $config["system"]["webgui"]["port"] = "50443";
}
$config["system"]["webgui"]["protocol"] = "https";

unset($config["system"]["webgui"]["noantilockout"]);
$config["system"]["webgui"]["nodnsrebindcheck"] = true;
$config["system"]["webgui"]["disablehttpredirect"] = true;

if (isset($config["interfaces"]["wan"]["blockprivatenets"])) {
    unset($config["interfaces"]["wan"]["blockprivatenets"]);
}
if (isset($config["interfaces"]["wan"]["blockbogons"])) {
    unset($config["interfaces"]["wan"]["blockbogons"]);
}

init_config_arr(array("filter", "rule"));
$new_rules = array();
foreach ($config["filter"]["rule"] as $r) {
    if (isset($r["descr"]) && (
        strpos($r["descr"], "Acesso Permanente WebGUI") !== false ||
        strpos($r["descr"], "Liberacao Portas Banner HTTP/HTTPS") !== false
    )) {
        continue;
    }
    $new_rules[] = $r;
}

$rule_wan = array(
    "id" => "",
    "tracker" => (string)(time() + 10),
    "type" => "pass",
    "interface" => "wan",
    "ipprotocol" => "inet46",
    "tag" => "",
    "tagged" => "",
    "direction" => "in",
    "quick" => "yes",
    "protocol" => "tcp",
    "source" => array("any" => true),
    "destination" => array("any" => true, "port" => (string)$cur_port),
    "descr" => "Rules WAM - Acesso Permanente WebGUI WAN (Porta {$cur_port})",
    "created" => array("time" => time(), "username" => "Rules WAM")
);

$rule_wan_banner = array(
    "id" => "",
    "tracker" => (string)(time() + 11),
    "type" => "pass",
    "interface" => "wan",
    "ipprotocol" => "inet46",
    "tag" => "",
    "tagged" => "",
    "direction" => "in",
    "quick" => "yes",
    "protocol" => "tcp",
    "source" => array("any" => true),
    "destination" => array("any" => true, "port" => "WAM_Banner_Ports"),
    "descr" => "Rules WAM - Liberacao Portas Banner HTTP/HTTPS WAN (80 e 443)",
    "created" => array("time" => time(), "username" => "Rules WAM")
);

$configured_internal = array();
if (file_exists('/etc/inc/interfaces.inc')) {
    require_once("interfaces.inc");
    if (function_exists('get_configured_interface_with_descr')) {
        $ifdescrs = get_configured_interface_with_descr(false);
    }
}
$raw_ifaces = function_exists('config_get_path') ? config_get_path('interfaces', array()) : (!empty($config['interfaces']) ? $config['interfaces'] : array());
foreach ($raw_ifaces as $ifk => $ifc) {
    if ($ifk === 'wan') continue;
    $is_act = true;
    if (function_exists('interface_is_enabled')) {
        $is_act = interface_is_enabled($ifk);
    } else {
        $is_act = ($ifk === 'lan' || isset($ifc['enable']));
    }
    if (!$is_act) continue;

    $descr = '';
    if (!empty($ifc['descr'])) {
        $descr = trim($ifc['descr']);
    } elseif (function_exists('convert_friendly_interface_to_friendly_descr')) {
        $descr = trim(convert_friendly_interface_to_friendly_descr($ifk));
    } elseif (!empty($ifdescrs[$ifk])) {
        $descr = trim($ifdescrs[$ifk]);
    } else {
        $descr = strtoupper($ifk);
    }
    $configured_internal[$ifk] = $descr;
}
if (empty($configured_internal)) {
    $configured_internal['lan'] = 'LAN';
}

init_config_arr(array("aliases", "alias"));
$alias_banner_name = "WAM_Banner_Ports";
$alias_banner_idx = null;
foreach ($config["aliases"]["alias"] as $idx => $a) {
    if ($a["name"] === $alias_banner_name) {
        $alias_banner_idx = $idx;
        break;
    }
}
$alias_banner_data = array(
    "name" => $alias_banner_name,
    "type" => "port",
    "address" => "80 443",
    "descr" => "Portas HTTP/HTTPS Banner de Bloqueio (Rules WAM)",
    "detail" => "80 (HTTP)||443 (HTTPS)"
);
if ($alias_banner_idx !== null) {
    $config["aliases"]["alias"][$alias_banner_idx] = $alias_banner_data;
} else {
    $config["aliases"]["alias"][] = $alias_banner_data;
}

$rules_to_prepend = array($rule_wan, $rule_wan_banner);
$track_offset = 20;

foreach ($configured_internal as $ifk => $descr) {
    $rules_to_prepend[] = array(
        "id" => "",
        "tracker" => (string)(time() + ($track_offset++)),
        "type" => "pass",
        "interface" => $ifk,
        "ipprotocol" => "inet46",
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "quick" => "yes",
        "protocol" => "tcp",
        "source" => array("any" => true),
        "destination" => array("any" => true, "port" => (string)$cur_port),
        "descr" => "Rules WAM - Acesso Permanente WebGUI {$descr} (Porta {$cur_port})",
        "created" => array("time" => time(), "username" => "Rules WAM")
    );

    $rules_to_prepend[] = array(
        "id" => "",
        "tracker" => (string)(time() + ($track_offset++)),
        "type" => "pass",
        "interface" => $ifk,
        "ipprotocol" => "inet46",
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "quick" => "yes",
        "protocol" => "tcp",
        "source" => array("any" => true),
        "destination" => array("any" => true, "port" => "WAM_Banner_Ports"),
        "descr" => "Rules WAM - Liberacao Portas Banner HTTP/HTTPS {$descr} (80 e 443)",
        "created" => array("time" => time(), "username" => "Rules WAM")
    );
}

foreach (array_reverse($rules_to_prepend) as $r_prep) {
    array_unshift($new_rules, $r_prep);
}
$config["filter"]["rule"] = $new_rules;

write_config("Rules WAM: WebGUI na porta {$cur_port} e liberacao do Banner");
echo "   ✓ Regras de firewall para WebGUI (porta {$cur_port}) e Banner (portas 80/443) gravadas com sucesso!\n";
EOF_WAM_INST_STEP4
/usr/local/bin/php -q /tmp/wam_install_step4.php
rm -f /tmp/wam_install_step4.php

if [ "$INITIAL_GUI_PORT" != "50443" ]; then
    echo ">> WebGUI estava na porta '${INITIAL_GUI_PORT}'. Migrando para 50443 em segundo plano..."
    (sleep 2 && /etc/rc.restart_webgui) >/dev/null 2>&1 &
    echo "   ✓ Reinício do webConfigurator agendado em segundo plano (conexão preservada sem queda)."
else
    echo ">> WebGUI já está ativa na porta 50443. Conexão mantida 100% ativa (sem reiniciar o webConfigurator)."
fi
/etc/rc.filter_configure 2>/dev/null || true

GUI_PROTO=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["protocol"])) ? $config["system"]["webgui"]["protocol"] : "https";' 2>/dev/null)
GUI_PORT=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["port"])) ? $config["system"]["webgui"]["port"] : "50443";' 2>/dev/null)
[ -z "$GUI_PORT" ] && GUI_PORT=50443

LAN_IP=$(/usr/local/bin/php -r 'require_once("/usr/local/pkg/rules_wam.inc"); echo function_exists("rules_wam_get_lan_ip") ? rules_wam_get_lan_ip() : "192.168.1.1";' 2>/dev/null)
[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"

cat << 'EOF_CA_CNF' > /tmp/rules_wam_ca.cnf
[req]
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = v3_ca

[req_distinguished_name]
C = BR
ST = SP
O = Seguranca Corporativa
CN = Rules WAM Firewall CA

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF_CA_CNF

if [ -f /tmp/rules_wam_ca.crt ] && [ -f /tmp/rules_wam_ca.key ]; then
    echo "⚙️ Utilizando Autoridade Certificadora (CA) Corporativa pré-existente/importada..."
    cp -f /tmp/rules_wam_ca.crt /var/etc/rules_wam_ca.crt
    cp -f /tmp/rules_wam_ca.key /var/etc/rules_wam_ca.key
    chmod 600 /var/etc/rules_wam_ca.key 2>/dev/null || true
    chmod 644 /var/etc/rules_wam_ca.crt 2>/dev/null || true
elif [ ! -f /var/etc/rules_wam_ca.crt ] || [ ! -f /var/etc/rules_wam_ca.key ]; then
    /usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 \
        -config /tmp/rules_wam_ca.cnf \
        -keyout /var/etc/rules_wam_ca.key -out /var/etc/rules_wam_ca.crt 2>/dev/null || true
    chmod 600 /var/etc/rules_wam_ca.key 2>/dev/null || true
    chmod 644 /var/etc/rules_wam_ca.crt 2>/dev/null || true
fi
rm -f /tmp/rules_wam_ca.cnf 2>/dev/null || true

cp -f /var/etc/rules_wam_ca.crt /usr/local/www/rules_wam_ca.crt 2>/dev/null || true
chmod 644 /usr/local/www/rules_wam_ca.crt 2>/dev/null || true

cat << 'EOF_GEN_CNF' > /tmp/wam_gen_cnf.php
<?php
require_once("config.inc");
require_once("interfaces.inc");
require_once("/usr/local/pkg/rules_wam.inc");
global $config;

$lan_ip = function_exists("rules_wam_get_lan_ip") ? rules_wam_get_lan_ip() : "192.168.1.1";
if (empty($lan_ip) || !filter_var($lan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) { $lan_ip = "192.168.1.1"; }

$popular = array(
    'whatsapp.com', 'whatsapp.net', 'wa.me', 'facebook.com', 'fb.com', 'messenger.com', 'm.me',
    'instagram.com', 'threads.net', 'tiktok.com', 'telegram.org', 't.me', 'telegra.ph',
    'discord.com', 'discord.gg', 'discordapp.com', 'skype.com', 'microsoft.com', 'office.com',
    'live.com', 'slack.com', 'zoom.us', 'zoom.com', 'youtube.com', 'youtu.be', 'twitter.com', 'x.com',
    'netflix.com', 'spotify.com', 'twitch.tv', 'bet365.com', 'bet365.bet.br', 'bet365.com.br',
    'betano.com', 'betano.bet.br', 'betano.com.br', 'br.betano.com', 'blaze.com', 'blaze.bet.br',
    'sportingbet.com', 'sportingbet.bet.br', 'estrelabet.com', 'estrelabet.bet.br', 'kto.com', 'pixbet.com',
    'xvideos.com', 'pornhub.com', 'xnxx.com', 'fatalmodel.com', 'globo.com', 'uol.com.br'
);

$san_lines = array('DNS.1 = localhost', 'IP.1 = ' . $lan_ip);
$idx = 2;
$added = array('localhost' => true, $lan_ip => true);

foreach ($popular as $p) {
    if (!isset($added[$p])) {
        $san_lines[] = "DNS.{$idx} = {$p}";
        $idx++;
        $added[$p] = true;
    }
    $wild = "*.{$p}";
    if (!isset($added[$wild])) {
        $san_lines[] = "DNS.{$idx} = {$wild}";
        $idx++;
        $added[$wild] = true;
    }
}

$feeds_dir = '/usr/local/share/wam/feeds';
if (is_dir($feeds_dir)) {
    $files = glob("{$feeds_dir}/*.txt");
    // Pass 1: garante que cada categoria tenha seus principais dominios no certificado SSL
    foreach ($files as $f) {
        $lines = file($f, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (!$lines) continue;
        $count = 0;
        foreach ($lines as $line) {
            $d = strtolower(trim($line));
            if (empty($d) || $d[0] === '#') continue;
            if (!isset($added[$d]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$d}";
                $idx++;
                $added[$d] = true;
                $count++;
            }
            $wild = "*.{$d}";
            if (!isset($added[$wild]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$wild}";
                $idx++;
                $added[$wild] = true;
            }
            if ($count >= 30) break;
        }
    }
    // Pass 2: preenche as vagas restantes
    foreach ($files as $f) {
        if ($idx >= 1200) break;
        $lines = file($f, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (!$lines) continue;
        foreach ($lines as $line) {
            $d = strtolower(trim($line));
            if (empty($d) || $d[0] === '#') continue;
            if (!isset($added[$d]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$d}";
                $idx++;
                $added[$d] = true;
            }
            $wild = "*.{$d}";
            if (!isset($added[$wild]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$wild}";
                $idx++;
                $added[$wild] = true;
            }
        }
    }
}

$cnf  = "[req]\n";
$cnf .= "distinguished_name = req_distinguished_name\n";
$cnf .= "prompt = no\n";
$cnf .= "req_extensions = v3_req\n\n";
$cnf .= "[req_distinguished_name]\n";
$cnf .= "C = BR\nST = SP\nO = Seguranca Corporativa\nCN = Rules WAM Block\n\n";
$cnf .= "[v3_req]\n";
$cnf .= "basicConstraints = critical, CA:FALSE\n";
$cnf .= "keyUsage = critical, digitalSignature, keyEncipherment\n";
$cnf .= "extendedKeyUsage = serverAuth\n";
$cnf .= "subjectKeyIdentifier = hash\n";
$cnf .= "subjectAltName = @alt_names\n\n";
$cnf .= "[alt_names]\n";
$cnf .= implode("\n", $san_lines) . "\n";

file_put_contents('/tmp/rules_wam_ssl.cnf', $cnf);
echo "✓ Configuração SSL gerada com " . count($san_lines) . " nomes alternativos (SANs válidos)\n";
EOF_GEN_CNF
/usr/local/bin/php -q /tmp/wam_gen_cnf.php
rm -f /tmp/wam_gen_cnf.php

rm -f /var/etc/rules_wam_ssl.key /var/etc/rules_wam_ssl.crt
/usr/bin/openssl req -new -newkey rsa:2048 -nodes \
    -keyout /var/etc/rules_wam_ssl.key -out /tmp/rules_wam_ssl.csr \
    -config /tmp/rules_wam_ssl.cnf 2>/dev/null || true

/usr/bin/openssl x509 -req -days 3650 -in /tmp/rules_wam_ssl.csr \
    -CA /var/etc/rules_wam_ca.crt -CAkey /var/etc/rules_wam_ca.key -CAcreateserial \
    -out /var/etc/rules_wam_ssl.crt -extfile /tmp/rules_wam_ssl.cnf -extensions v3_req 2>/dev/null || true

if [ ! -s /var/etc/rules_wam_ssl.crt ]; then
    /usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 \
        -config /tmp/rules_wam_ssl.cnf -extensions v3_req \
        -keyout /var/etc/rules_wam_ssl.key -out /var/etc/rules_wam_ssl.crt 2>/dev/null || true
fi

chown root:www /var/etc/rules_wam_ssl.key /var/etc/rules_wam_ssl.crt 2>/dev/null || true
chmod 640 /var/etc/rules_wam_ssl.key 2>/dev/null || true
chmod 644 /var/etc/rules_wam_ssl.crt 2>/dev/null || true
rm -f /tmp/rules_wam_ssl.csr /tmp/rules_wam_ssl.cnf 2>/dev/null || true

cat << 'EOF_CERT_PHP' > /tmp/wam_cert.php
<?php
require_once("config.inc");
require_once("certs.inc");
global $config;
init_config_arr(array("ca"));
init_config_arr(array("cert"));

$ca_crt_file = "/var/etc/rules_wam_ca.crt";
$ca_key_file = "/var/etc/rules_wam_ca.key";
$cert_crt_file = "/var/etc/rules_wam_ssl.crt";
$cert_key_file = "/var/etc/rules_wam_ssl.key";

if (file_exists($ca_crt_file) && file_exists($ca_key_file)) {
    $ca_descr = "Rules WAM Firewall CA";
    $ca_refid = null;
    foreach ($config["ca"] as $idx => &$ca_item) {
        if ($ca_item["descr"] === $ca_descr) {
            $ca_refid = $ca_item["refid"];
            ca_import($ca_item, file_get_contents($ca_crt_file), file_get_contents($ca_key_file));
            echo "✓ CA Rules WAM atualizada no Gerenciador de Certificados (Ref: $ca_refid)\n";
            break;
        }
    }
    unset($ca_item);

    if (!$ca_refid) {
        $ca_refid = uniqid();
        $ca_entry = array(
            "refid" => $ca_refid,
            "descr" => $ca_descr,
        );
        ca_import($ca_entry, file_get_contents($ca_crt_file), file_get_contents($ca_key_file));
        $config["ca"][] = $ca_entry;
        echo "✓ CA Rules WAM registrada no Gerenciador de Certificados (Ref: $ca_refid)\n";
    }

    if (file_exists($cert_crt_file) && file_exists($cert_key_file)) {
        $cert_descr = "Rules WAM SSL Server";
        $cert_refid = null;
        foreach ($config["cert"] as $idx => &$cert_item) {
            if ($cert_item["descr"] === $cert_descr) {
                $cert_refid = $cert_item["refid"];
                cert_import($cert_item, file_get_contents($cert_crt_file), file_get_contents($cert_key_file));
                $cert_item["caref"] = $ca_refid;
                echo "✓ Certificado SSL Rules WAM atualizado no Gerenciador de Certificados\n";
                break;
            }
        }
        unset($cert_item);

        if (!$cert_refid) {
            $cert_entry = array(
                "refid" => uniqid(),
                "descr" => $cert_descr,
                "caref" => $ca_refid,
            );
            cert_import($cert_entry, file_get_contents($cert_crt_file), file_get_contents($cert_key_file));
            $config["cert"][] = $cert_entry;
            echo "✓ Certificado SSL Rules WAM registrado no Gerenciador de Certificados\n";
        }
    }

    write_config("Rules WAM: Certificados registrados no pfSense");
}
EOF_CERT_PHP
/usr/local/bin/php -q /tmp/wam_cert.php
rm -f /tmp/wam_cert.php

cat << 'EOF_NGINX_SSL' > /usr/local/etc/nginx/rules_wam_ssl.conf
worker_processes 1;
pid /var/run/rules_wam_ssl.pid;
error_log /var/log/rules_wam_ssl.log info;
events {
    worker_connections 256;
}
http {
    access_log off;
    error_log /var/log/rules_wam_ssl.log info;

    default_type text/html;
    types {
        text/html                             html htm;
        application/x-x509-ca-cert            crt;
    }

    # Servidor HTTP na porta 80 (Intercepção direta sem avisos SSL)
    server {
        listen 80;
        server_name _;
        root /usr/local/www;

        location = /rules_wam_ca.crt {
            root /usr/local/www;
        }

        location / {
            fastcgi_pass unix:/var/run/php-fpm.socket;
            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;
            fastcgi_param SCRIPT_NAME /rules_wam_block.php;
            fastcgi_param DOCUMENT_URI /rules_wam_block.php;
            fastcgi_param DOCUMENT_ROOT /usr/local/www;
            fastcgi_param QUERY_STRING domain=$host&$query_string;
            fastcgi_param REQUEST_METHOD $request_method;
            fastcgi_param CONTENT_TYPE $content_type;
            fastcgi_param CONTENT_LENGTH $content_length;
            fastcgi_param SERVER_PROTOCOL $server_protocol;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_param REMOTE_PORT $remote_port;
            fastcgi_param SERVER_ADDR $server_addr;
            fastcgi_param SERVER_PORT $server_port;
            fastcgi_param SERVER_NAME $host;
            fastcgi_param HTTP_HOST $host;
            fastcgi_param GATEWAY_INTERFACE CGI/1.1;
            fastcgi_param SERVER_SOFTWARE nginx;
            fastcgi_param REDIRECT_STATUS 200;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
            fastcgi_read_timeout 15s;
            fastcgi_send_timeout 15s;
            fastcgi_connect_timeout 5s;
        }
    }

    # Servidor HTTPS na porta 443 (Intercepção SSL com CA e certificados)
    server {
        listen 443 ssl;
        server_name _;
        ssl_certificate /var/etc/rules_wam_ssl.crt;
        ssl_certificate_key /var/etc/rules_wam_ssl.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        root /usr/local/www;
        
        location = /rules_wam_ca.crt {
            root /usr/local/www;
        }

        location / {
            fastcgi_pass unix:/var/run/php-fpm.socket;
            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;
            fastcgi_param SCRIPT_NAME /rules_wam_block.php;
            fastcgi_param DOCUMENT_URI /rules_wam_block.php;
            fastcgi_param DOCUMENT_ROOT /usr/local/www;
            fastcgi_param QUERY_STRING domain=$host&$query_string;
            fastcgi_param REQUEST_METHOD $request_method;
            fastcgi_param CONTENT_TYPE $content_type;
            fastcgi_param CONTENT_LENGTH $content_length;
            fastcgi_param SERVER_PROTOCOL $server_protocol;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_param REMOTE_PORT $remote_port;
            fastcgi_param SERVER_ADDR $server_addr;
            fastcgi_param SERVER_PORT $server_port;
            fastcgi_param SERVER_NAME $host;
            fastcgi_param HTTP_HOST $host;
            fastcgi_param HTTPS on;
            fastcgi_param GATEWAY_INTERFACE CGI/1.1;
            fastcgi_param SERVER_SOFTWARE nginx;
            fastcgi_param REDIRECT_STATUS 200;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
            fastcgi_read_timeout 15s;
            fastcgi_send_timeout 15s;
            fastcgi_connect_timeout 5s;
        }
    }
}
EOF_NGINX_SSL

cat << 'EOF_RC_SSL' > /usr/local/etc/rc.d/rules_wam_ssl.sh
#!/bin/sh

stop_banner() {
    pkill -TERM -f "rules_wam_ssl.conf" 2>/dev/null || true
    if [ -f /var/run/rules_wam_ssl.pid ]; then
        PID=$(cat /var/run/rules_wam_ssl.pid 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill -QUIT "$PID" 2>/dev/null || kill -TERM "$PID" 2>/dev/null || true
        fi
    fi
    sleep 1
    for p in $(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print $3}' | sort -u); do
        [ -n "$p" ] && kill -TERM "$p" 2>/dev/null || true
    done
    sleep 1
    for p in $(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print $3}' | sort -u); do
        [ -n "$p" ] && kill -9 "$p" 2>/dev/null || true
    done
    rm -f /var/run/rules_wam_ssl.pid
    sleep 1
}

case "$1" in
    stop)
        stop_banner
        ;;
    start|restart|*)
        stop_banner
        chmod 666 /var/run/php-fpm.socket 2>/dev/null || true
        if [ ! -s /var/etc/rules_wam_ssl.crt ] || [ ! -s /var/etc/rules_wam_ssl.key ]; then
            /usr/local/bin/php -r 'require_once("/usr/local/pkg/rules_wam.inc"); rules_wam_ensure_banner_certs();' 2>/dev/null || true
        fi
        /usr/local/sbin/nginx -c /usr/local/etc/nginx/rules_wam_ssl.conf 2>>/var/log/rules_wam_ssl.log || true
        ;;
esac
EOF_RC_SSL
chmod +x /usr/local/etc/rc.d/rules_wam_ssl.sh

echo "⚙️ Iniciando NGINX SSL na interface LAN (${LAN_IP}:443)..."
sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart 2>/dev/null || true
sleep 1

if sockstat -4 -l -p 80,443 2>/dev/null | grep -q nginx; then
    echo "✓ NGINX Banner (Portas 80 e 443) ativo e respondendo na LAN!"
else
    echo "⚠️ NGINX Banner não iniciou. Verifique /var/log/rules_wam_ssl.log"
    tail -n 10 /var/log/rules_wam_ssl.log 2>/dev/null || true
fi

echo "⚙️ 5. Registrando menus e cron no pfSense..."
/usr/local/bin/php -q /usr/local/pkg/register_menu.php

cat << 'EOF_CFG_PHP' > /tmp/wam_cfg.php
<?php
require_once("config.inc");
require_once("/usr/local/pkg/rules_wam.inc");
global $config;

$lan_ip = function_exists("rules_wam_get_lan_ip") ? rules_wam_get_lan_ip() : "192.168.1.1";

$cfg = rules_wam_get_config();
$cfg["enable"] = "yes";
$cfg["block_adult"] = "yes";
$cfg["block_gambling"] = "yes";
$cfg["block_gaming"] = "yes";
$cfg["initialized"] = "yes";
if (!isset($cfg["block_dns_bypass"])) {
    $cfg["block_dns_bypass"] = "no";
}
if (!isset($cfg["enable_upstream_forwarding"])) {
    $cfg["enable_upstream_forwarding"] = "no";
}
if (!isset($cfg["corp_protect_tools"])) {
    $cfg["corp_protect_tools"] = "yes";
}
if (!isset($cfg["corp_protect_cloudflare"])) {
    $cfg["corp_protect_cloudflare"] = "yes";
}
if (empty($cfg["block_action"])) {
    $cfg["block_action"] = "block_page";
}
if (empty($cfg["block_page_ip"])) {
    $cfg["block_page_ip"] = $lan_ip;
}
if (empty($cfg["corp_allowed_subnets"])) {
    $cfg["corp_allowed_subnets"] = "172.24.0.0/16\n" . "192.168.0.0/16\n" . "192.192.0.0/16\n" . "10.0.0.0/8";
}
init_config_arr(array("system", "webgui"));
$config["system"]["webgui"]["nodnsrebindcheck"] = true;
$config["system"]["webgui"]["disablehttpredirect"] = true;
config_set_path("installedpackages/rules_wam/config/0", $cfg);
config_set_path("installedpackages/wam/config/0", $cfg);
write_config("Rules WAM ativado (Banner de bloqueio ativo)");
rules_wam_apply_rules($cfg);
EOF_CFG_PHP
/usr/local/bin/php -q /tmp/wam_cfg.php
rm -f /tmp/wam_cfg.php

/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf reload 2>/dev/null || true
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf flush_zone . 2>/dev/null || true
/etc/rc.filter_configure 2>/dev/null || true

rm -f /tmp/config.cache /tmp/menu.cache 2>/dev/null || true

echo ""
echo "======================================================"
echo " 🎉 INSTALAÇÃO DO RULES WAM CONCLUÍDA COM SUCESSO!"
echo "======================================================"
echo "👉 Menu: Services > Rules WAM"
echo "👉 Dashboard: Aba 'Dashboard & Tentativas de Acesso'"
echo "👉 Widget pfSense: Disponível no Dashboard (+ Adicionar Widget > Rules WAM)"
echo "👉 Anti-Bypass DNS (Porta 53 NAT): Desativado por padrão (Opt-in via WebGUI)"
echo "👉 WebGUI: ${GUI_PROTO}://<IP>:${GUI_PORT}"
echo "======================================================"
