#!/usr/bin/env python3
import os

with open("www/rules_wam_block.php", "r", encoding="utf-8") as f:
    block_php = f.read()

with open("pkg/rules_wam.inc", "r", encoding="utf-8") as f:
    rules_inc = f.read()

with open("widgets/widgets/rules_wam.widget.php", "r", encoding="utf-8") as f:
    widget_php = f.read()

script_template = '''#!/bin/sh
# ====================================================================
# Rules WAM - Script de Correção e Blindagem Definitiva
# Porta 50443, FastCGI NGINX, PHP-FPM e Banner de Bloqueio
# Compatível com pfSense 2.7.x / 2.8.x / Plus
# ====================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Erro: Execute este script como root no pfSense (opção 8 do console ou via SSH)."
    exit 1
fi

echo "===================================================================="
echo " 🛡️ Rules WAM: Correção e Blindagem Definitiva (FastCGI & Banner)"
echo "===================================================================="

INITIAL_GUI_PORT=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["port"])) ? $config["system"]["webgui"]["port"] : "443";' 2>/dev/null)
[ -z "$INITIAL_GUI_PORT" ] && INITIAL_GUI_PORT=443

# 1. Executa script PHP de blindagem de portas, anti-lockout e regras de firewall
cat << 'EOF_WAM_FIX_PHP' > /tmp/wam_fix_step1.php
<?php
require_once("config.inc");
require_once("filter.inc");
global $config;

echo ">> 1. Configurando parâmetros da WebGUI e liberando portas 80 e 443...\n";
init_config_arr(array("system", "webgui"));

// Garante protocolo HTTPS e porta 50443
$cur_proto = !empty($config["system"]["webgui"]["protocol"]) ? $config["system"]["webgui"]["protocol"] : "https";
$cur_port = !empty($config["system"]["webgui"]["port"]) ? $config["system"]["webgui"]["port"] : "";
if (empty($cur_port) || $cur_port == "443" || $cur_port == "8443") {
    $cur_port = "50443";
    $config["system"]["webgui"]["port"] = "50443";
}
$config["system"]["webgui"]["protocol"] = "https";

// Blindagem: anti-lockout ativo, sem DNS rebind check, sem redirecionamento HTTP nativo
unset($config["system"]["webgui"]["noantilockout"]);
$config["system"]["webgui"]["nodnsrebindcheck"] = true;
$config["system"]["webgui"]["disablehttpredirect"] = true;

// Desbloqueia redes privadas na WAN se aplicavel (evita bloqueio em redes de teste/laboratorio)
if (isset($config["interfaces"]["wan"]["blockprivatenets"])) {
    unset($config["interfaces"]["wan"]["blockprivatenets"]);
    echo "   ✓ Bloqueio de RFC1918 na WAN desativado para permitir gerência remota\n";
}
if (isset($config["interfaces"]["wan"]["blockbogons"])) {
    unset($config["interfaces"]["wan"]["blockbogons"]);
}

echo ">> 2. Injetando regras permanentes de firewall (Porta {$cur_port} WAN/LAN e Portas 80/443 Banner)...\n";
init_config_arr(array("filter", "rule"));

// Remove regras antigas duplicadas do fix
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

// 2.1 Regra WAN para WebGUI
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
    "created" => array("time" => time(), "username" => "Rules WAM Fix")
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
    "created" => array("time" => time(), "username" => "Rules WAM Fix")
);

// 2.2 Detecta todas as interfaces internas configuradas no pfSense com seus nomes amigáveis oficiais
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

// 2.3 Alias de Portas de Banner (Portas 80 e 443)
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

// Cria regras permanentes de WebGUI e Banner para cada interface interna usando seu nome oficial
foreach ($configured_internal as $ifk => $descr) {
    echo "   ✓ Criando regras para interface {$descr} ({$ifk})\n";
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
        "created" => array("time" => time(), "username" => "Rules WAM Fix")
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
        "created" => array("time" => time(), "username" => "Rules WAM Fix")
    );
}

// Regra flutuante global para todas as interfaces internas
$if_list = implode(",", array_keys($configured_internal));
$rules_to_prepend[] = array(
    "id" => "",
    "tracker" => (string)(time() + ($track_offset++)),
    "type" => "pass",
    "interface" => $if_list,
    "ipprotocol" => "inet46",
    "tag" => "",
    "tagged" => "",
    "direction" => "in",
    "floating" => "yes",
    "quick" => "yes",
    "protocol" => "tcp",
    "source" => array("any" => true),
    "destination" => array("any" => true, "port" => "WAM_Banner_Ports"),
    "descr" => "Rules WAM - Liberacao Portas Banner HTTP/HTTPS Global (80 e 443)",
    "created" => array("time" => time(), "username" => "Rules WAM Fix")
);

// Adiciona regras com prioridade máxima (no topo)
foreach (array_reverse($rules_to_prepend) as $r_prep) {
    array_unshift($new_rules, $r_prep);
}
$config["filter"]["rule"] = $new_rules;

write_config("Rules WAM Fix: Blindagem de acesso porta {$cur_port} e liberacao do Banner");
echo "   ✓ Configurações gravadas com sucesso!\n";
EOF_WAM_FIX_PHP
/usr/local/bin/php -q /tmp/wam_fix_step1.php
rm -f /tmp/wam_fix_step1.php

# 2. Reinicia o webConfigurator para aplicar protocolo HTTPS e porta 50443 somente se a porta tiver mudado
if [ "$INITIAL_GUI_PORT" != "50443" ]; then
    echo ">> 3. WebGUI migrada de porta '${INITIAL_GUI_PORT}' para 50443. Agendando reinício em segundo plano..."
    (sleep 2 && /etc/rc.restart_webgui) >/dev/null 2>&1 &
    echo "   ✓ Reinício do webConfigurator agendado para segundo plano (conexão preservada sem queda)."
else
    echo ">> 3. WebGUI já está ativa na porta 50443. Conexão mantida 100% ativa (sem reiniciar o webConfigurator)."
fi
echo ">> Recarregando regras do filtro de pacotes..."
/etc/rc.filter_configure 2>/dev/null || true

# 3. Detecta porta e protocolo ativos
GUI_PROTO=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["protocol"])) ? $config["system"]["webgui"]["protocol"] : "https";' 2>/dev/null)
GUI_PORT=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["port"])) ? $config["system"]["webgui"]["port"] : "50443";' 2>/dev/null)
[ -z "$GUI_PORT" ] && GUI_PORT=50443

echo "   ✓ WebGUI ativa em: ${GUI_PROTO}://127.0.0.1:${GUI_PORT}"

# 4. Instala / Atualiza os arquivos centrais do Rules WAM
echo ">> 4. Instalando arquivos da aplicação e banner corporativo..."
mkdir -p /usr/local/www /usr/local/pkg /usr/local/etc/nginx /usr/local/etc/rc.d /var/etc

cat << 'EOF_BLOCK_PHP' > /usr/local/www/rules_wam_block.php
##BLOCK_PHP##
EOF_BLOCK_PHP
chmod 644 /usr/local/www/rules_wam_block.php
echo "   ✓ /usr/local/www/rules_wam_block.php instalado com sucesso"

cat << 'EOF_RULES_INC' > /usr/local/pkg/rules_wam.inc
##RULES_INC##
EOF_RULES_INC
chmod 644 /usr/local/pkg/rules_wam.inc
cp -f /usr/local/pkg/rules_wam.inc /usr/local/pkg/wam.inc
chmod 644 /usr/local/pkg/wam.inc
echo "   ✓ /usr/local/pkg/rules_wam.inc e wam.inc sincronizados com FastCGI nativo"

mkdir -p /usr/local/www/widgets/widgets
cat << 'EOF_WIDGET_PHP' > /usr/local/www/widgets/widgets/rules_wam.widget.php
##WIDGET_PHP##
EOF_WIDGET_PHP
chmod 644 /usr/local/www/widgets/widgets/rules_wam.widget.php
echo "   ✓ /usr/local/www/widgets/widgets/rules_wam.widget.php atualizado com nomes reais de interfaces"

# 5. Garante permissões adequadas no socket do PHP-FPM
echo ">> 5. Configurando permissões do socket PHP-FPM..."
chmod 666 /var/run/php-fpm.socket 2>/dev/null || true

# 6. Atualiza a configuração do NGINX do Banner
echo ">> 6. Sincronizando NGINX do Banner com FastCGI nativo (PHP-FPM)..."

cat << 'EOF_NGINX' > /usr/local/etc/nginx/rules_wam_ssl.conf
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

    # Servidor HTTP na porta 80 (Intercepção direta)
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

    # Servidor HTTPS na porta 443 (Intercepção SSL)
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
EOF_NGINX

# 7. Assegura certificados SSL válidos para o Banner
echo ">> 7. Verificando certificados SSL do Banner..."
/usr/local/bin/php -r 'require_once("/usr/local/pkg/rules_wam.inc"); rules_wam_ensure_banner_certs();' 2>/dev/null || true
if [ -f /var/etc/rules_wam_ca.crt ]; then
    cp -f /var/etc/rules_wam_ca.crt /usr/local/www/rules_wam_ca.crt 2>/dev/null || true
    chmod 644 /usr/local/www/rules_wam_ca.crt 2>/dev/null || true
fi

# 8. Cria script do serviço rc.d
cat << 'EOF_RC' > /usr/local/etc/rc.d/rules_wam_ssl.sh
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
EOF_RC
chmod +x /usr/local/etc/rc.d/rules_wam_ssl.sh

# 9. Reinicia servicos garantindo liberação das portas 80 e 443
echo ">> 8. Liberando portas 80 e 443 e iniciando NGINX do Banner..."
sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart 2>/dev/null || true
sleep 2

echo ">> 9. Sincronizando regras do Rules WAM e Unbound..."
/usr/local/bin/php -r '
require_once("config.inc");
require_once("/usr/local/pkg/rules_wam.inc");
global $config;
if (function_exists("rules_wam_sync_all")) {
    rules_wam_sync_all();
    echo "   ✓ Rules WAM e Unbound sincronizados com sucesso\n";
}
' 2>/dev/null || true

/etc/rc.filter_configure 2>/dev/null || true
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf reload 2>/dev/null || true

echo ""
echo "===================================================================="
echo " 📊 DIAGNÓSTICO E STATUS DOS SERVIÇOS"
echo "===================================================================="

echo ">> Portas ativas de Banner (80 e 443):"
sockstat -4 -l -p 80,443 | grep nginx || echo "⚠️ Aviso: Verifique /var/log/rules_wam_ssl.log"

echo ">> Porta ativa da WebGUI (${GUI_PORT}):"
sockstat -4 -l -p "${GUI_PORT}" | grep nginx || echo "⚠️ Aviso: WebGUI não detectada na porta ${GUI_PORT}"

echo ">> Socket PHP-FPM:"
if [ -S /var/run/php-fpm.socket ]; then
    echo "   ✓ /var/run/php-fpm.socket ativo"
else
    echo "   ⚠️ /var/run/php-fpm.socket não encontrado!"
fi

echo ""
echo ">> Teste de Banner Local:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: betano.com" http://127.0.0.1/ 2>/dev/null || echo "000")
HTTPS_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: betano.com" https://127.0.0.1/ 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ HTTP (Porta 80):  HTTP 200 OK (Banner servido com sucesso)"
else
    echo "   ⚠️ HTTP (Porta 80):  HTTP ${HTTP_CODE}"
fi

if [ "$HTTPS_CODE" = "200" ]; then
    echo "   ✓ HTTPS (Porta 443): HTTP 200 OK (Banner servido com sucesso)"
else
    echo "   ⚠️ HTTPS (Porta 443): HTTP ${HTTPS_CODE}"
fi

if [ "$HTTP_CODE" != "200" ] || [ "$HTTPS_CODE" != "200" ]; then
    echo ""
    echo ">> Diagnóstico detalhado do log NGINX (/var/log/rules_wam_ssl.log):"
    tail -n 25 /var/log/rules_wam_ssl.log 2>/dev/null || true
fi

BANNER_IP=$(/usr/local/bin/php -r 'require_once("/usr/local/pkg/rules_wam.inc"); echo rules_wam_get_lan_ip();' 2>/dev/null)
[ -z "$BANNER_IP" ] && BANNER_IP="127.0.0.1"

echo ""
echo "===================================================================="
echo " 🎉 CORREÇÃO APLICADA COM SUCESSO!"
echo "===================================================================="
echo "👉 Acesse a WebGUI em: ${GUI_PROTO}://<IP_DO_PFSENSE>:${GUI_PORT}"
echo "👉 IP do Banner ativo: ${BANNER_IP}"
echo "👉 Teste o Banner em:  http://${BANNER_IP}/ ou https://${BANNER_IP}/"
echo "👉 Teste de Domínio:   http://betano.com/ (com DNS do cliente apontando para o pfSense)"
echo "===================================================================="
'''

script_content = script_template.replace("##BLOCK_PHP##", block_php).replace("##RULES_INC##", rules_inc).replace("##WIDGET_PHP##", widget_php)

with open("wam-fix-50443-banner.sh", "w", encoding="utf-8") as f:
    f.write(script_content)

print("wam-fix-50443-banner.sh generated successfully!")
print(f"Size: {len(script_content)} bytes")

