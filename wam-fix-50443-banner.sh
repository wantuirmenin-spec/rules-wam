#!/bin/sh
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

echo ">> 1. Configurando parâmetros da WebGUI e liberando portas 80 e 443...
";
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
    echo "   ✓ Bloqueio de RFC1918 na WAN desativado para permitir gerência remota
";
}
if (isset($config["interfaces"]["wan"]["blockbogons"])) {
    unset($config["interfaces"]["wan"]["blockbogons"]);
}

echo ">> 2. Injetando regras permanentes de firewall (Porta {$cur_port} WAN/LAN e Portas 80/443 Banner)...
";
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
    echo "   ✓ Criando regras para interface {$descr} ({$ifk})
";
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
echo "   ✓ Configurações gravadas com sucesso!
";
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
<?php
/*
 * rules_wam_block.php
 * Rules WAM - Web Access Manager para pfSense
 * Banner / Tela de Bloqueio Corporativa para Hosts Interceptados
 */

if (file_exists("/usr/local/pkg/rules_wam.inc")) {
    require_once("/usr/local/pkg/rules_wam.inc");
} elseif (file_exists(dirname(__DIR__) . "/pkg/rules_wam.inc")) {
    require_once(dirname(__DIR__) . "/pkg/rules_wam.inc");
}

$client_ip = !empty($_SERVER['HTTP_X_REAL_IP']) ? $_SERVER['HTTP_X_REAL_IP'] : (!empty($_SERVER['HTTP_X_FORWARDED_FOR']) ? explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0] : (!empty($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1'));
$client_ip = trim($client_ip);
$cache_hn = array();
$client_host = function_exists('rules_wam_resolve_hostname') ? rules_wam_resolve_hostname($client_ip, $cache_hn) : 'Host ' . $client_ip;

// Identifica o domínio solicitado
$req_host = !empty($_GET['domain']) ? trim($_GET['domain']) : (!empty($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'website-bloqueado.com');
$req_host = preg_replace('/:\d+$/', '', $req_host); // remove porta se houver
$req_host = function_exists('rules_wam_clean_domain') ? rules_wam_clean_domain($req_host) : preg_replace('/[^a-zA-Z0-9\.\-_]/', '', $req_host);
if (empty($req_host) || $req_host === '127.0.0.1' || $req_host === 'localhost' || filter_var($req_host, FILTER_VALIDATE_IP)) {
    $req_host = 'website-bloqueado.com';
}

// Categoria do domínio
$category = function_exists('rules_wam_get_domain_category') ? rules_wam_get_domain_category($req_host) : 'Política de Segurança Corporativa';
if ($category === 'Regra Personalizada / Outros' || $category === 'Política de Segurança Corporativa') {
    if (strpos($req_host, 'xvideo') !== false || strpos($req_host, 'porn') !== false) {
        $category = 'Conteúdo Adulto & Pornografia';
    } elseif (strpos($req_host, 'betano') !== false || strpos($req_host, 'bet365') !== false || strpos($req_host, 'blaze') !== false || strpos($req_host, 'bet') !== false) {
        $category = 'Apostas & Bets';
    }
}

// Data e Hora
$block_time = date('d/m/Y - H:i:s');

// Registra auditoria da interceptação quando exibido a um host
$wam_cfg = function_exists('rules_wam_get_config') ? rules_wam_get_config() : array();
$lan_ip = function_exists('config_get_path') ? config_get_path('interfaces/lan/ipaddr', '') : (!empty($config['interfaces']['lan']['ipaddr']) ? $config['interfaces']['lan']['ipaddr'] : '');
$block_page_ip = !empty($wam_cfg['block_page_ip']) ? $wam_cfg['block_page_ip'] : $lan_ip;
$server_addr = $_SERVER['SERVER_ADDR'] ?? '';

$is_fw_direct = empty($_GET['domain']) && (!empty($_SERVER['HTTP_HOST']) && (
    (!empty($block_page_ip) && strpos($_SERVER['HTTP_HOST'], $block_page_ip) !== false) ||
    (!empty($server_addr) && strpos($_SERVER['HTTP_HOST'], $server_addr) !== false) ||
    strpos($_SERVER['HTTP_HOST'], 'pfsense') !== false
));

if (!empty($req_host) && $req_host !== 'website-bloqueado.com' && !$is_fw_direct) {
    $audit_line = sprintf(
        "%s|%s|%s|%s|%s\n",
        date('Y-m-d H:i:s'),
        $client_ip,
        $req_host,
        $category,
        $client_host
    );
    @file_put_contents('/var/log/wam_audit.log', $audit_line, FILE_APPEND | LOCK_EX);
}
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Acesso Bloqueado - Política de Segurança Corporativa</title>
    <style>
        :root {
            --primary-red: #c9302c;
            --dark-red: #901b17;
            --bg-page: #f0f2f5;
            --card-bg: #ffffff;
            --text-dark: #2c3e50;
            --text-muted: #667085;
            --border-color: #e4e7ec;
            --amber-warn: #f59e0b;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
            color: var(--text-dark);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .block-card {
            background: var(--card-bg);
            max-width: 720px;
            width: 100%;
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08), 0 1px 3px rgba(0, 0, 0, 0.05);
            overflow: hidden;
            border: 1px solid var(--border-color);
        }

        .card-header {
            background: linear-gradient(135deg, #d32f2f 0%, #b71c1c 100%);
            color: #ffffff;
            padding: 28px 32px;
            text-align: center;
            position: relative;
        }

        .card-header .badge-top {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            backdrop-filter: blur(4px);
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 11px;
            letter-spacing: 1px;
            font-weight: 700;
            text-transform: uppercase;
            margin-bottom: 12px;
            border: 1px solid rgba(255, 255, 255, 0.3);
        }

        .shield-icon {
            width: 64px;
            height: 64px;
            margin: 0 auto 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: rgba(255, 255, 255, 0.15);
            border-radius: 50%;
            border: 2px solid rgba(255, 255, 255, 0.4);
        }

        .shield-icon svg {
            width: 36px;
            height: 36px;
            fill: #ffffff;
        }

        .card-header h1 {
            font-size: 24px;
            font-weight: 800;
            margin-bottom: 6px;
            letter-spacing: -0.5px;
        }

        .card-header p {
            font-size: 14px;
            color: rgba(255, 255, 255, 0.9);
            max-width: 500px;
            margin: 0 auto;
        }

        .card-body {
            padding: 30px 32px;
        }

        .policy-alert-box {
            background-color: #fef2f2;
            border-left: 4px solid var(--primary-red);
            padding: 16px;
            border-radius: 6px;
            margin-bottom: 24px;
        }

        .policy-alert-box h3 {
            color: var(--dark-red);
            font-size: 15px;
            font-weight: 700;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .policy-alert-box p {
            font-size: 13.5px;
            color: #7f1d1d;
            line-height: 1.5;
        }

        .policy-categories {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 10px;
            margin-top: 14px;
        }

        .cat-item {
            background: #ffffff;
            border: 1px solid #fecaca;
            border-radius: 6px;
            padding: 10px 14px;
            font-size: 12.5px;
            color: #991b1b;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .cat-item.active-violation {
            background: #fef2f2;
            border: 2px solid #dc2626;
            box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.15);
        }

        .cat-badge-violation {
            background: #dc2626;
            color: #ffffff;
            font-size: 10px;
            padding: 2px 6px;
            border-radius: 4px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-left: auto;
            white-space: nowrap;
        }

        .cat-item span.icon {
            font-size: 18px;
        }

        /* Detalhes Técnicos */
        .tech-details {
            background-color: #f8fafc;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
            margin-bottom: 24px;
        }

        .tech-details h4 {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: var(--text-muted);
            margin-bottom: 12px;
            font-weight: 700;
        }

        .details-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            font-size: 13px;
        }

        @media (max-width: 540px) {
            .details-grid {
                grid-template-columns: 1fr;
            }
        }

        .detail-row {
            display: flex;
            flex-direction: column;
        }

        .detail-row .label {
            font-size: 11px;
            color: var(--text-muted);
            text-transform: uppercase;
            font-weight: 600;
            margin-bottom: 3px;
        }

        .detail-row .value {
            font-weight: 700;
            color: var(--text-dark);
            word-break: break-all;
        }

        .detail-row .value.blocked-domain {
            color: var(--primary-red);
            font-family: Consolas, "Courier New", monospace;
            font-size: 14px;
        }

        .legal-notice {
            font-size: 12px;
            color: var(--text-muted);
            line-height: 1.6;
            text-align: center;
            margin-bottom: 24px;
            padding: 0 10px;
        }

        .card-footer {
            background-color: #f8fafc;
            border-top: 1px solid var(--border-color);
            padding: 18px 32px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
        }

        .btn {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 9px 18px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 600;
            text-decoration: none;
            cursor: pointer;
            border: 1px solid transparent;
            transition: all 0.2s;
        }

        .btn-primary {
            background-color: #2563eb;
            color: #ffffff;
        }

        .btn-primary:hover {
            background-color: #1d4ed8;
        }

        .btn-secondary {
            background-color: #ffffff;
            color: var(--text-dark);
            border-color: var(--border-color);
        }

        .btn-secondary:hover {
            background-color: #f1f5f9;
        }

        .footer-brand {
            font-size: 12px;
            color: var(--text-muted);
        }
    </style>
</head>
<body>

<div class="block-card">
    <div class="card-header">
        <div class="badge-top">🛡️ Segurança Corporativa & Auditoria de Rede</div>
        <div class="shield-icon">
            <svg viewBox="0 0 24 24">
                <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-1 6h2v6h-2V7zm1 10.25c-.69 0-1.25-.56-1.25-1.25s.56-1.25 1.25-1.25 1.25.56 1.25 1.25-.56 1.25-1.25 1.25z"/>
            </svg>
        </div>
        <h1>ACESSO BLOQUEADO</h1>
        <p>A navegação para este destino foi restrita em conformidade com as Políticas de Segurança da Informação da instituição.</p>
    </div>

    <div class="card-body">
        <div class="policy-alert-box">
            <h3>
                <span>⚠️</span> Violação de Política de Acesso à Internet
            </h3>
            <p>
                Os recursos de rede e conectividade desta instituição são destinados estritamente às atividades profissionais e corporativas. 
                De acordo com as normas de conformidade e segurança, é expressamente <strong>proibido</strong> o acesso a páginas que contenham:
            </p>

            <?php
            $all_policy_cats = array(
                'Notícias & Portais'    => array('icon' => '📰', 'title' => 'Notícias & Portais', 'desc' => 'Portais jornalísticos, tabloides, colunas e notícias externas'),
                'Conteúdo Adulto'       => array('icon' => '🔞', 'title' => 'Conteúdo Adulto', 'desc' => 'Pornografia, acompanhantes, cams e nudez explícita'),
                'Apostas & Bets'        => array('icon' => '🎲', 'title' => 'Apostas & Bets', 'desc' => 'Jogos de azar, cassinos online, rifas e apostas esportivas'),
                'Jogos & Games'         => array('icon' => '🎮', 'title' => 'Jogos Online', 'desc' => 'Plataformas de jogos, games em rede e entretenimento lúdico'),
                'Mídias Sociais'        => array('icon' => '📱', 'title' => 'Mídias Sociais', 'desc' => 'Redes sociais, vídeos curtos, mensageria e feeds de interação'),
                'Streaming & Vídeo'     => array('icon' => '🎬', 'title' => 'Streaming & Vídeo', 'desc' => 'Plataformas de filmes, séries, vídeos sob demanda e IPTV'),
                'Compras & E-commerce'  => array('icon' => '🛍️', 'title' => 'Compras & E-commerce', 'desc' => 'Lojas virtuais, marketplaces e sites de leilão'),
                'Esportes & Placares'   => array('icon' => '⚽', 'title' => 'Esportes & Placares', 'desc' => 'Portais esportivos, transmissões de jogos e resultados'),
                'Torrents & P2P'        => array('icon' => '⚡', 'title' => 'Pirataria & Torrents', 'desc' => 'Compartilhamento P2P, downloads de mídias e cracks'),
                'Anti-Bypass DoH'       => array('icon' => '🛡️', 'title' => 'Anti-Bypass DoH', 'desc' => 'Servidores de DNS sobre HTTPS e proxies de evasão'),
                'VPN, ZTNA & Proxies'   => array('icon' => '🔒', 'title' => 'VPN, ZTNA & Proxies', 'desc' => 'Serviços de VPN comercial, túneis ZTNA, mesh VPNs e proxies anônimos'),
            );

            $ordered_cats = array();
            foreach ($all_policy_cats as $cat_k => $cat_info) {
                $matches_cat = (
                    stripos($category, $cat_k) !== false ||
                    stripos($cat_k, $category) !== false ||
                    (stripos($cat_k, 'VPN') !== false && (stripos($category, 'VPN') !== false || stripos($category, 'ZTNA') !== false))
                );
                if ($matches_cat) {
                    $ordered_cats = array($cat_k => $cat_info) + $ordered_cats;
                } else {
                    $ordered_cats[$cat_k] = $cat_info;
                }
            }
            ?>
            <div class="policy-categories">
                <?php 
                $count = 0;
                foreach ($ordered_cats as $cat_k => $cat_info): 
                    $is_match = (
                        stripos($category, $cat_k) !== false ||
                        stripos($cat_k, $category) !== false ||
                        (stripos($cat_k, 'VPN') !== false && (stripos($category, 'VPN') !== false || stripos($category, 'ZTNA') !== false))
                    );
                    if ($count >= 6 && !$is_match) continue;
                    $count++;
                ?>
                    <div class="cat-item <?=$is_match ? 'active-violation' : ''?>">
                        <span class="icon"><?=$cat_info['icon']?></span>
                        <div><strong><?=htmlspecialchars($cat_info['title'])?>:</strong> <?=htmlspecialchars($cat_info['desc'])?></div>
                        <?php if ($is_match): ?>
                            <span class="cat-badge-violation">Regra Ativa</span>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>

        <div class="tech-details">
            <h4>📋 Detalhes do Registro de Interceptação</h4>
            <div class="details-grid">
                <div class="detail-row">
                    <span class="label">Domínio Solicitado</span>
                    <span class="value blocked-domain"><?=htmlspecialchars($req_host)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Categoria Classificada</span>
                    <span class="value" style="color: #b91c1c;"><?=htmlspecialchars($category)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Seu Host / Computador</span>
                    <span class="value"><?=htmlspecialchars($client_host)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Endereço IP de Origem</span>
                    <span class="value"><code><?=htmlspecialchars($client_ip)?></code></span>
                </div>
                <div class="detail-row">
                    <span class="label">Data e Hora da Tentativa</span>
                    <span class="value"><?=htmlspecialchars($block_time)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Ação Executada</span>
                    <span class="value" style="color: #c9302c;">Conexão Bloqueada & Registrada</span>
                </div>
            </div>
        </div>

        <div class="legal-notice">
            Todas as requisições de rede são monitoradas e auditadas centralizadamente pelo firewall corporativo.<br/>
            Caso acredite que este bloqueio seja incorreto ou necessite de autorização para fins de trabalho, contate o <strong>Departamento de TI</strong> informando os dados acima.
        </div>
    </div>

    <div class="card-footer">
        <div class="footer-brand">
            <strong>Rules WAM</strong> &bull; Sistema de Proteção Web pfSense
            <?php if (file_exists('/usr/local/www/rules_wam_ca.crt')): ?>
                &bull; <a href="/rules_wam_ca.crt" style="color: #64748b; text-decoration: underline; font-size: 11px;" download title="Instalar certificado nos computadores para eliminar avisos no HTTPS">Baixar Certificado CA</a>
            <?php endif; ?>
        </div>
        <div>
            <button onclick="window.history.back();" class="btn btn-secondary">
                &larr; Voltar à página anterior
            </button>
            <a href="mailto:suporte@empresa.com.br?subject=Solicitacao%20de%20Liberacao%20de%20Acesso%20-%20<?=rawurlencode($req_host)?>&body=Ola%20Suporte%20TI,%0A%0ASolicito%20revisao%20do%20bloqueio%20do%20dominio:%20<?=rawurlencode($req_host)?>%0AHost:%20<?=rawurlencode($client_host)?>%20(IP:%20<?=rawurlencode($client_ip)?>)%0ACategoria:%20<?=rawurlencode($category)?>%0A%0AJustificativa:%20" class="btn btn-primary">
                ✉️ Contatar Suporte TI
            </a>
        </div>
    </div>
</div>

</body>
</html>

EOF_BLOCK_PHP
chmod 644 /usr/local/www/rules_wam_block.php
echo "   ✓ /usr/local/www/rules_wam_block.php instalado com sucesso"

cat << 'EOF_RULES_INC' > /usr/local/pkg/rules_wam.inc
<?php
/*
 * rules_wam.inc
 * Rules WAM - Web Access Manager para pfSense
 * Motor de aplicação de regras de bloqueio e auditoria no Unbound DNS
 */

require_once("config.inc");
require_once("util.inc");
require_once("services.inc");

define('WAM_FEEDS_DIR', '/usr/local/share/wam/feeds');
define('WAM_CONF_FILE', '/var/unbound/wam_blocklist.conf');
define('WAM_STATUS_FILE', '/var/log/wam_status.json');
define('WAM_AUDIT_LOG', '/var/log/wam_audit.log');

/**
 * Auxiliar para verificar se checkbox está marcada (aceita "yes", "on", 1, true)
 */
function rules_wam_is_checked($val) {
    if (empty($val)) return false;
    if ($val === 'yes' || $val === 'on' || $val === true || $val === '1' || $val === 1) return true;
    return false;
}

/**
 * Obtém todas as interfaces configuradas no pfSense com seus nomes amigáveis (descr) reais.
 * Suporta LAN, OPT1..OPTn, VLANs, Bridges, etc., exatamente como configurado no pfSense.
 */
function rules_wam_get_configured_interfaces($include_wan = false) {
    global $config;

    $interfaces = array();
    $ifdescrs = array();

    if (file_exists('/etc/inc/interfaces.inc')) {
        require_once("interfaces.inc");
        if (function_exists('get_configured_interface_with_descr')) {
            $ifdescrs = get_configured_interface_with_descr(false);
        }
    }

    $raw_interfaces = function_exists('config_get_path') ? config_get_path('interfaces', array()) : (!empty($config['interfaces']) ? $config['interfaces'] : array());

    if (!empty($raw_interfaces) && is_array($raw_interfaces)) {
        foreach ($raw_interfaces as $if_key => $if_cfg) {
            if (!$include_wan && $if_key === 'wan') {
                continue;
            }

            // No pfSense, interfaces OPT só estão ativas se tiverem 'enable'. LAN e WAN são ativas por padrão.
            $is_active = true;
            if (function_exists('interface_is_enabled')) {
                $is_active = interface_is_enabled($if_key);
            } else {
                $is_active = ($if_key === 'lan' || $if_key === 'wan' || isset($if_cfg['enable']));
            }
            if (!$is_active) {
                continue;
            }

            // Nome descritivo amigável configurado no pfSense (Ex: LAN_CORP, WIFI_VISITANTES, REDE_LOCAL)
            $descr = '';
            if (!empty($if_cfg['descr'])) {
                $descr = trim($if_cfg['descr']);
            } elseif (function_exists('convert_friendly_interface_to_friendly_descr')) {
                $descr = trim(convert_friendly_interface_to_friendly_descr($if_key));
            } elseif (!empty($ifdescrs[$if_key])) {
                $descr = trim($ifdescrs[$if_key]);
            } else {
                $descr = strtoupper($if_key);
            }

            // Interface física/virtual no FreeBSD (Ex: igb0, em1, vlan0.10)
            $real_if = !empty($if_cfg['if']) ? $if_cfg['if'] : '';
            if (empty($real_if) && function_exists('get_real_interface')) {
                $real_if = get_real_interface($if_key);
            }
            if (empty($real_if) && function_exists('convert_friendly_interface_to_real_interface_name')) {
                $real_if = convert_friendly_interface_to_real_interface_name($if_key);
            }

            // Endereço IPv4 da Interface
            $if_ip = '';
            $if_subnet = 24;

            if (function_exists('get_interface_ip')) {
                $g_ip = get_interface_ip($if_key);
                if (!empty($g_ip) && filter_var($g_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                    $if_ip = $g_ip;
                }
            }

            if (empty($if_ip) && function_exists('get_interface_info')) {
                $info = get_interface_info($if_key);
                if (!empty($info['ipaddr']) && filter_var($info['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                    $if_ip = $info['ipaddr'];
                }
                if (!empty($info['subnet']) && is_numeric($info['subnet'])) {
                    $if_subnet = (int)$info['subnet'];
                }
                if (empty($real_if) && !empty($info['if'])) {
                    $real_if = $info['if'];
                } elseif (empty($real_if) && !empty($info['hwif'])) {
                    $real_if = $info['hwif'];
                }
            }

            if (empty($if_ip) && !empty($if_cfg['ipaddr']) && filter_var($if_cfg['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $if_ip = $if_cfg['ipaddr'];
                if (!empty($if_cfg['subnet']) && is_numeric($if_cfg['subnet'])) {
                    $if_subnet = (int)$if_cfg['subnet'];
                }
            }

            // Fallback via ifconfig para capturar IP dinâmico/DHCP/VLAN
            if (empty($if_ip) && !empty($real_if)) {
                $raw_out = array();
                @exec("/sbin/ifconfig " . escapeshellarg($real_if) . " 2>/dev/null", $raw_out);
                foreach ($raw_out as $r_line) {
                    if (preg_match('/inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\s+netmask\s+(0x[0-9a-fA-F]+|[0-9\.]+)/i', $r_line, $im)) {
                        $if_ip = $im[1];
                        if (stripos($im[2], '0x') === 0) {
                            $if_subnet = substr_count(decbin(hexdec($im[2])), '1');
                        } elseif (filter_var($im[2], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                            $if_subnet = substr_count(decbin(ip2long($im[2])), '1');
                        }
                        break;
                    }
                }
            }

            // Calcula CIDR da sub-rede
            $has_valid_ip = (!empty($if_ip) && filter_var($if_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4));
            $cidr = '';
            $net_long = 0;
            $long_mask = 0;
            if ($has_valid_ip) {
                if ($if_subnet <= 0 || $if_subnet > 32) $if_subnet = 24;
                $long_ip = ip2long($if_ip);
                $long_mask = -1 << (32 - $if_subnet);
                $net_long = $long_ip & $long_mask;
                $cidr = long2ip($net_long) . '/' . $if_subnet;
            } else {
                $cidr = strtoupper($if_key) . ' (Sem IP)';
            }

            $interfaces[$if_key] = array(
                'key'         => $if_key,
                'logical_id'  => strtoupper($if_key),
                'descr'       => $descr,
                'name'        => $descr,
                'real_if'     => !empty($real_if) ? $real_if : $if_key,
                'ip'          => $if_ip,
                'subnet'      => $if_subnet,
                'cidr'        => $cidr,
                'net_long'    => $net_long,
                'mask_long'   => $long_mask,
                'has_ip'      => $has_valid_ip,
                'is_internal' => ($if_key !== 'wan')
            );
        }
    }

    return $interfaces;
}

/**
 * Localiza a interface do pfSense correspondente a um endereço IP de cliente
 */
function rules_wam_find_interface_for_ip($ip) {
    if (empty($ip) || !filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return null;
    }
    static $interfaces_cache = null;
    if ($interfaces_cache === null) {
        $interfaces_cache = rules_wam_get_configured_interfaces(true);
    }
    $ipl = ip2long($ip);
    foreach ($interfaces_cache as $if_key => $if_data) {
        if (!empty($if_data['has_ip']) && !empty($if_data['mask_long'])) {
            if (($ipl & $if_data['mask_long']) === $if_data['net_long']) {
                return $if_data;
            }
        }
    }
    return null;
}

/**
 * Obtém o IP IPv4 de banner/redirecionamento da rede local em tempo de execução
 */
function rules_wam_get_lan_ip() {
    global $config;

    // 1. Tenta obter IP de todas as interfaces configuradas no pfSense
    $ifaces = rules_wam_get_configured_interfaces(false);

    // Se a interface 'lan' existir e tiver IP, usa ela como prioritária
    if (!empty($ifaces['lan']['ip'])) {
        return $ifaces['lan']['ip'];
    }

    // Se a LAN foi renomeada ou não tem IP, busca a primeira interface interna com IPv4 ativo
    foreach ($ifaces as $if_data) {
        if (!empty($if_data['ip'])) {
            return $if_data['ip'];
        }
    }

    // Fallbacks legados
    if (function_exists('get_interface_ip')) {
        $lan_ip = get_interface_ip('lan');
        if (!empty($lan_ip) && filter_var($lan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            return $lan_ip;
        }
        // Se interfaces internas não tiverem IP, tenta WAN (caso de testes/laboratório em VM)
        $wan_ip = get_interface_ip('wan');
        if (!empty($wan_ip) && filter_var($wan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            return $wan_ip;
        }
    }

    $cfg_ip = function_exists('config_get_path') ? config_get_path('interfaces/lan/ipaddr', '') : ($config['interfaces']['lan']['ipaddr'] ?? '');
    if (filter_var($cfg_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return $cfg_ip;
    }

    $cfg_wan = function_exists('config_get_path') ? config_get_path('interfaces/wan/ipaddr', '') : ($config['interfaces']['wan']['ipaddr'] ?? '');
    if (filter_var($cfg_wan, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return $cfg_wan;
    }

    return '192.168.1.1';
}

/**
 * Obtém a configuração do Rules WAM de qualquer estrutura do config.xml ou $_POST
 */
function rules_wam_get_config() {
    global $config;

    $cfg = null;

    $cfg0 = config_get_path('installedpackages/rules_wam/config/0', null);
    if (is_array($cfg0) && !empty($cfg0)) {
        $cfg = $cfg0;
    } else {
        $cfga = config_get_path('installedpackages/rules_wam/config', null);
        if (is_array($cfga) && !empty($cfga)) {
            $cfg = (isset($cfga[0]) && is_array($cfga[0])) ? $cfga[0] : $cfga;
        } elseif (isset($config['installedpackages']['rules_wam']['config'][0])) {
            $cfg = $config['installedpackages']['rules_wam']['config'][0];
        } elseif (isset($config['installedpackages']['rules_wam']['config']) && is_array($config['installedpackages']['rules_wam']['config'])) {
            $cfg = $config['installedpackages']['rules_wam']['config'];
        }
    }

    if (empty($cfg) || !is_array($cfg)) {
        $cfg_w0 = config_get_path('installedpackages/wam/config/0', null);
        if (is_array($cfg_w0) && !empty($cfg_w0)) {
            $cfg = $cfg_w0;
        } else {
            $cfg_wa = config_get_path('installedpackages/wam/config', null);
            if (is_array($cfg_wa) && !empty($cfg_wa)) {
                $cfg = (isset($cfg_wa[0]) && is_array($cfg_wa[0])) ? $cfg_wa[0] : $cfg_wa;
            }
        }
    }

    if (is_array($cfg) && !empty($cfg)) {
        // Se a configuração já existe no pfSense, checkboxes ausentes no XML representam 'no'
        $checkbox_keys = array(
            'enable', 'block_adult', 'block_gambling', 'block_news', 'block_social',
            'block_sports', 'block_gaming', 'block_streaming', 'block_shopping',
            'block_p2p', 'block_doh', 'block_dns_bypass', 'block_vpn', 'block_messaging',
            'block_vpn_fortinet', 'block_vpn_cisco', 'block_vpn_paloalto',
            'block_ztna_zscaler', 'block_ztna_netskope', 'block_ztna_cloudflare',
            'block_ztna_tailscale', 'block_vpn_commercial',
            'block_msg_whatsapp', 'block_msg_telegram', 'block_msg_messenger',
            'block_msg_teams_skype', 'block_msg_discord', 'block_msg_slack',
            'block_msg_zoom_meet', 'block_msg_others',
            'schedule_enable', 'schedule_weekend',
            'corp_enable', 'corp_protect_netskope', 'corp_protect_idp', 'corp_reverse_lookup',
            'corp_protect_tools', 'corp_protect_cloudflare',
            'corp_protect_helpdesk', 'corp_protect_voip',
            'enable_upstream_forwarding'
        );
        foreach ($checkbox_keys as $chk) {
            if (!isset($cfg[$chk])) {
                // Proteções essenciais devem ser padrão ativas se não definidas
                if ($chk === 'corp_protect_tools' || $chk === 'corp_protect_cloudflare' || $chk === 'corp_protect_netskope' || $chk === 'corp_protect_idp' || $chk === 'corp_protect_helpdesk' || $chk === 'corp_protect_voip') {
                    $cfg[$chk] = 'yes';
                } else {
                    $cfg[$chk] = 'no';
                }
            }
        }
        if (empty($cfg['block_action'])) {
            $cfg['block_action'] = 'block_page';
        }
        return $cfg;
    }

    // Configuração inicial padrão (apenas se instalação virgem sem registro prévio):
    return array(
        'enable'                     => 'yes',
        'block_adult'                => 'yes',
        'block_gambling'             => 'yes',
        'block_gaming'               => 'yes',
        'block_dns_bypass'           => 'no',
        'enable_upstream_forwarding' => 'no',
        'block_action'               => 'block_page',
        'corp_protect_netskope'      => 'yes',
        'corp_protect_idp'           => 'yes',
        'corp_protect_tools'         => 'yes',
        'corp_protect_cloudflare'    => 'yes',
        'corp_protect_helpdesk'      => 'yes',
        'corp_protect_voip'          => 'yes',
        'corp_reverse_lookup'        => 'yes',
        'initialized'                => 'yes'
    );
}

/**
 * Função chamada pelo pfSense ao salvar configurações
 */
function rules_wam_resync() {
    global $config;

    $wam_cfg = rules_wam_get_config();
    log_error("[Rules WAM] Resync disparado.");

    if (!rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
        log_error("[Rules WAM] 'enable' desmarcado. Desabilitando serviço...");
        rules_wam_disable();
        return;
    }

    if (rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null)) {
        if (!rules_wam_is_in_schedule_window($wam_cfg)) {
            rules_wam_suspend_schedule();
            return;
        }
    }

    rules_wam_apply_rules($wam_cfg);
}

function wam_resync() {
    rules_wam_resync();
}

/**
 * Aplica as regras ativas no Unbound
 */
function rules_wam_apply_rules($wam_cfg = null) {
    log_error("[Rules WAM] Compilando regras de bloqueio por categoria...");

    if (empty($wam_cfg) || !is_array($wam_cfg)) {
        $wam_cfg = rules_wam_get_config();
    }

    if (!isset($wam_cfg['enable'])) {
        $wam_cfg['enable'] = 'yes';
    }

    $all_cat_keys = array(
        'block_adult', 'block_gambling', 'block_news', 'block_social',
        'block_sports', 'block_gaming', 'block_streaming', 'block_shopping',
        'block_p2p', 'block_doh', 'block_dns_bypass', 'block_vpn', 'block_messaging',
        'enable_upstream_forwarding'
    );
    foreach ($all_cat_keys as $ack) {
        if (!isset($wam_cfg[$ack])) {
            $wam_cfg[$ack] = 'no';
        }
    }

    $blocked_domains = array();
    $whitelist = array();
    $bypass_ips = array();

    if (!empty($wam_cfg['custom_whitelist'])) {
        $lines = preg_split('/\r\n|\r|\n/', $wam_cfg['custom_whitelist']);
        foreach ($lines as $line) {
            $d = rules_wam_clean_domain($line);
            if ($d) {
                $whitelist[$d] = true;
            }
        }
    }

    // Garante que o Google Meet e recursos essenciais nunca sejam bloqueados
    $whitelist['meet.google.com'] = true;
    $whitelist['apis.google.com'] = true;
    $whitelist['ssl.gstatic.com'] = true;
    $whitelist['clients6.google.com'] = true;
    $whitelist['madeiramadeira.local'] = true;
    $whitelist['madeiramadeira.com.br'] = true;

    // Proteção Essencial de Atendimento, Suporte e Helpdesk (Whitelist incondicional)
    $whitelist['zendesk.com'] = true;
    $whitelist['zdassets.com'] = true;
    $whitelist['zdstatic.com'] = true;
    $whitelist['zdusercontent.com'] = true;
    $whitelist['zopim.com'] = true;
    $whitelist['zopim.io'] = true;
    $whitelist['zopim.net'] = true;
    $whitelist['glpi-project.org'] = true;
    $whitelist['glpi-network.cloud'] = true;
    $whitelist['glpi-network.com'] = true;
    $whitelist['services.glpi-network.com'] = true;
    $whitelist['teclib.com'] = true;
    $whitelist['screenconnect.com'] = true;
    $whitelist['screenconnect.net'] = true;
    $whitelist['connectwise.com'] = true;
    $whitelist['connectwise.net'] = true;
    $whitelist['hostedrmm.com'] = true;

    // --- Integração Corporativa: Netskope, IdP, Ferramentas de TI, Cloudflare, Helpdesk e SIP/VoIP ---
    $protect_netskope = (!isset($wam_cfg['corp_protect_netskope']) || rules_wam_is_checked($wam_cfg['corp_protect_netskope']));
    $protect_idp = (!isset($wam_cfg['corp_protect_idp']) || rules_wam_is_checked($wam_cfg['corp_protect_idp']));
    $protect_tools = (!isset($wam_cfg['corp_protect_tools']) || rules_wam_is_checked($wam_cfg['corp_protect_tools']));
    $protect_cloudflare = (!isset($wam_cfg['corp_protect_cloudflare']) || rules_wam_is_checked($wam_cfg['corp_protect_cloudflare']));
    $protect_helpdesk = (!isset($wam_cfg['corp_protect_helpdesk']) || rules_wam_is_checked($wam_cfg['corp_protect_helpdesk']));
    $protect_voip = (!isset($wam_cfg['corp_protect_voip']) || rules_wam_is_checked($wam_cfg['corp_protect_voip']));
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $corp_domains = rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '');
    $corp_dns_ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');
    $corp_reverse = (!isset($wam_cfg['corp_reverse_lookup']) || rules_wam_is_checked($wam_cfg['corp_reverse_lookup']));
    $block_action = !empty($wam_cfg['block_action']) ? trim($wam_cfg['block_action']) : 'block_page';

    if ($protect_netskope) {
        $netskope_domains = array(
            'netskope.com', 'goskope.com', 'netskopedns.com', 'netskope.io',
            'addon-netskope.com', 'nsclient.netskope.com', 'npa.netskope.com',
            'gateway.goskope.com', 'ep.goskope.com', 'ca.goskope.com',
            'eu.goskope.com', 'us.goskope.com', 'app.netskope.com'
        );
        foreach ($netskope_domains as $nd) {
            $whitelist[$nd] = true;
        }
    }

    if ($protect_idp) {
        $idp_domains = array(
            'login.microsoftonline.com', 'login.microsoft.com', 'microsoft.com',
            'msftauth.net', 'msauth.net', 'windows.net', 'office.com',
            'okta.com', 'oktacdn.com', 'accounts.google.com'
        );
        foreach ($idp_domains as $idp) {
            $whitelist[$idp] = true;
        }
    }

    // Liberação e Proteção de Ferramentas de TI e Downloads Administrativos (PuTTY, WinSCP, etc.)
    if ($protect_tools) {
        $tools_domains = array(
            'putty.org', 'chiark.greenend.org.uk', 'greenend.org.uk', 'the.earth.li', 'tartarus.org',
            'winscp.net', 'filezilla-project.org', '7-zip.org', 'notepad-plus-plus.org',
            'github.com', 'githubusercontent.com', 'raw.githubusercontent.com', 'github.githubassets.com',
            'gitlab.com', 'git-scm.com', 'sourceforge.net', 'osdn.net',
            'sysinternals.com', 'live.sysinternals.com', 'download.sysinternals.com',
            'wireshark.org', 'nmap.org', 'dbeaver.io', 'postman.com', 'curl.se', 'mobatek.net',
            'python.org', 'pypi.org', 'pypi.python.org', 'files.pythonhosted.org'
        );
        foreach ($tools_domains as $td) {
            $whitelist[$td] = true;
        }
    }

    // Proteção da Infraestrutura Pública Cloudflare (CDN cdnjs, Captchas Turnstile, APIs públicas)
    if ($protect_cloudflare) {
        $cf_domains = array(
            'cloudflare.com', 'cdnjs.cloudflare.com', 'challenges.cloudflare.com',
            'static.cloudflareinsights.com', 'cloudflareinsights.com', 'cf-assets.net'
        );
        foreach ($cf_domains as $cfd) {
            $whitelist[$cfd] = true;
        }
    }

    // Liberação e Proteção de Plataformas de Helpdesk, ITSM e Suporte Remoto (Zendesk, GLPI, ScreenConnect)
    if ($protect_helpdesk) {
        $helpdesk_domains = array(
            'zendesk.com', 'zdassets.com', 'zdstatic.com', 'zdusercontent.com',
            'zopim.com', 'zopim.io', 'zopim.net',
            'glpi-project.org', 'glpi-network.cloud', 'glpi-network.com',
            'services.glpi-network.com', 'teclib.com', 'teclib-edition.com',
            'screenconnect.com', 'screenconnect.net',
            'connectwise.com', 'connectwise.net', 'hostedrmm.com'
        );
        foreach ($helpdesk_domains as $hd) {
            $whitelist[$hd] = true;
        }
    }

    // Liberação e Proteção de Telefonia IP, PABX Cloud, Protocolo SIP e Telefones IP (SIP Phones)
    if ($protect_voip) {
        $voip_domains = array(
            // Servidores STUN / TURN essenciais para travessia NAT e sinalização VoIP/WebRTC
            'stun.l.google.com', 'stun1.l.google.com', 'stun2.l.google.com', 'stun3.l.google.com', 'stun4.l.google.com',
            'stun.sipgate.net', 'stun.voipbuster.com', 'stun.ekiga.net', 'stun.counterpath.com', 'stun.counterpath.net',
            // Softphones e clientes SIP
            'zoiper.com', 'linphone.org', 'microsip.org', 'micro-sip.org', 'counterpath.com', 'bria.com', 'sip.audio',
            // Fabricantes de Telefones IP (SIP Phone) e provisionamento remoto / RPS / TR-069
            'yealink.com', 'yealinkphones.com', 'ycs.yealink.com', 'rps.yealink.com',
            'grandstream.com', 'gdms.cloud', 'gaps.grandstream.com',
            'intelbras.com.br', 'intelbras.com',
            'fanvil.com', 'fdms.fanvil.com',
            'poly.com', 'polycom.com', 'snom.com',
            // PABX em Nuvem, Troncos SIP e Operadoras VoIP
            '3cx.com', '3cx.net', '3cx.eu', '3cx.us',
            'sipgate.de', 'sipgate.com', 'sipgate.net',
            'twilio.com', 'telnyx.com', 'plivo.com',
            'ringcentral.com', 'vonage.com', 'nexmo.com', '8x8.com',
            'voip.ms', 'callcentric.com', 'didlogic.com', 'flowroute.com',
            'jive.com', 'goto.com', 'gotoconnect.com', 'dialpad.com',
            'totalvoice.com.br', 'zenvia.com', 'locaweb.com.br', 'webex.com'
        );
        foreach ($voip_domains as $vd) {
            $whitelist[$vd] = true;
        }
    }

    if ($corp_enable && !empty($corp_domains)) {
        foreach ($corp_domains as $cdom) {
            $cdom_clean = rules_wam_clean_domain($cdom);
            if ($cdom_clean) {
                $whitelist[$cdom_clean] = true;
            }
        }
    }

    if (!empty($wam_cfg['bypass_ips'])) {
        $raw_ips = preg_split('/[\r\n,;]+/', $wam_cfg['bypass_ips']);
        foreach ($raw_ips as $rip) {
            $rip = trim($rip);
            if (filter_var($rip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $bypass_ips[] = $rip . '/32';
            } elseif (filter_var($rip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
                $bypass_ips[] = $rip . '/128';
            } elseif (preg_match('#^\d+\.\d+\.\d+\.\d+/\d+$#', $rip)) {
                $bypass_ips[] = $rip;
            }
        }
    }

    $categories_active = array();

    $category_map = array(
        'block_adult'     => array('label' => 'Conteúdo Adulto',        'file' => 'adult.txt'),
        'block_gambling'  => array('label' => 'Apostas & Bets',         'file' => 'gambling.txt'),
        'block_news'      => array('label' => 'Notícias & Portais',      'file' => 'news.txt'),
        'block_social'    => array('label' => 'Mídias Sociais',         'file' => 'social-media.txt'),
        'block_sports'    => array('label' => 'Esportes & Placares',    'file' => 'sports.txt'),
        'block_gaming'    => array('label' => 'Jogos & Games',          'file' => 'gaming.txt'),
        'block_streaming' => array('label' => 'Streaming & Vídeo',      'file' => 'streaming.txt'),
        'block_shopping'  => array('label' => 'Compras & E-commerce',   'file' => 'shopping.txt'),
        'block_p2p'       => array('label' => 'Torrents & P2P',         'file' => 'p2p.txt'),
        'block_doh'       => array('label' => 'Anti-Bypass DoH',        'file' => 'doh-providers.txt'),
        'block_vpn'       => array('label' => 'VPN, ZTNA & Proxies',    'file' => 'vpn-ztna.txt'),
        'block_messaging' => array('label' => 'Mensageiros & Chat',     'file' => 'messaging.txt'),
    );

    foreach ($category_map as $cfg_key => $meta) {
        if (rules_wam_is_checked($wam_cfg[$cfg_key] ?? null)) {
            $categories_active[] = $meta['label'];
            if ($cfg_key === 'block_vpn') {
                $vpn_sub_map = array(
                    'block_vpn_fortinet'    => 'vpn-fortinet.txt',
                    'block_vpn_cisco'       => 'vpn-cisco.txt',
                    'block_vpn_paloalto'    => 'vpn-paloalto.txt',
                    'block_ztna_zscaler'    => 'ztna-zscaler.txt',
                    'block_ztna_netskope'   => 'ztna-netskope.txt',
                    'block_ztna_cloudflare' => 'ztna-cloudflare.txt',
                    'block_ztna_tailscale'  => 'ztna-tailscale.txt',
                    'block_vpn_commercial'  => 'vpn-commercial.txt',
                );
                $any_sub_specified = false;
                foreach (array_keys($vpn_sub_map) as $sub_k) {
                    if (isset($wam_cfg[$sub_k])) {
                        $any_sub_specified = true;
                        break;
                    }
                }
                foreach ($vpn_sub_map as $sub_k => $sub_f) {
                    if ($sub_k === 'block_ztna_netskope' && $protect_netskope) {
                        continue; // Netskope protegido contra bloqueio acidental
                    }
                    if ($sub_k === 'block_ztna_cloudflare' && $protect_cloudflare) {
                        // Se proteção à Cloudflare estiver ativa, só bloqueia WARP se explicitamente marcado
                        if (!rules_wam_is_checked($wam_cfg['block_ztna_cloudflare'] ?? null)) {
                            continue;
                        }
                    }
                    $is_sub_active = $any_sub_specified ? rules_wam_is_checked($wam_cfg[$sub_k] ?? null) : true;
                    if ($is_sub_active) {
                        rules_wam_load_feed_domains($sub_f, $blocked_domains, $whitelist);
                    }
                }
            } elseif ($cfg_key === 'block_messaging') {
                $msg_sub_map = array(
                    'block_msg_whatsapp'    => 'msg-whatsapp.txt',
                    'block_msg_telegram'    => 'msg-telegram.txt',
                    'block_msg_messenger'   => 'msg-messenger.txt',
                    'block_msg_teams_skype' => 'msg-teams-skype.txt',
                    'block_msg_discord'     => 'msg-discord.txt',
                    'block_msg_slack'       => 'msg-slack.txt',
                    'block_msg_zoom_meet'   => 'msg-zoom-meet.txt',
                    'block_msg_others'      => 'msg-others.txt',
                );
                $any_sub_specified = false;
                foreach (array_keys($msg_sub_map) as $sub_k) {
                    if (isset($wam_cfg[$sub_k])) {
                        $any_sub_specified = true;
                        break;
                    }
                }
                foreach ($msg_sub_map as $sub_k => $sub_f) {
                    $is_sub_active = $any_sub_specified ? rules_wam_is_checked($wam_cfg[$sub_k] ?? null) : true;
                    if ($is_sub_active) {
                        rules_wam_load_feed_domains($sub_f, $blocked_domains, $whitelist);
                    }
                }
            } else {
                rules_wam_load_feed_domains($meta['file'], $blocked_domains, $whitelist);
            }
        }
    }

    if (!empty($wam_cfg['custom_blacklist'])) {
        $lines = preg_split('/\r\n|\r|\n/', $wam_cfg['custom_blacklist']);
        foreach ($lines as $line) {
            $d = rules_wam_clean_domain($line);
            if ($d && !isset($whitelist[$d])) {
                $blocked_domains[$d] = true;
            }
        }
    }

    $total = count($blocked_domains);
    $conf_content  = "# ====================================================\n";
    $conf_content .= "# Rules WAM - Auto-gerado\n";
    $conf_content .= "# Atualizado em: " . date('Y-m-d H:i:s') . "\n";
    $conf_content .= "# Categorias ativas (" . count($categories_active) . "): " . implode(', ', $categories_active) . "\n";
    $conf_content .= "# Total de dominios bloqueados: {$total}\n";
    $conf_content .= "# ====================================================\n";
    $conf_content .= "server:\n";
    $conf_content .= "  log-local-actions: yes\n";
    $conf_content .= "  log-queries: yes\n";

    // --- Integração Corporativa: Active Directory e NPS RADIUS (Anti-Rebinding e DNSSEC Bypass) ---
    if ($corp_enable && !empty($corp_domains)) {
        $conf_content .= "  # Excecoes para Active Directory e NPS RADIUS (Anti-Rebinding e DNSSEC Bypass)\n";
        foreach ($corp_domains as $cdom) {
            $cdom = rules_wam_clean_domain($cdom);
            if (!empty($cdom)) {
                $conf_content .= "  private-domain: \"{$cdom}\"\n";
                $conf_content .= "  domain-insecure: \"{$cdom}\"\n";
            }
        }
        if ($corp_reverse) {
            $conf_content .= "  private-domain: \"in-addr.arpa\"\n";
            $conf_content .= "  domain-insecure: \"in-addr.arpa\"\n";
        }
    }

    // --- Autorização Global de Redes Corporativas no Unbound (Access Control) ---
    $corp_subnets_raw = !empty($wam_cfg['corp_allowed_subnets']) ? $wam_cfg['corp_allowed_subnets'] : "172.24.0.0/16\n192.168.0.0/16\n192.192.0.0/16\n10.0.0.0/8";
    $corp_subnets = rules_wam_parse_list($corp_subnets_raw);
    if (!empty($corp_subnets)) {
        $conf_content .= "  # Redes Corporativas Autorizadas no Unbound (18 Unidades / Matriz / Filiais)\n";
        foreach ($corp_subnets as $snet) {
            $snet = trim($snet);
            if (empty($snet)) continue;
            if (preg_match('#^(\d{1,3}\.){3}\d{1,3}(/(?:[0-9]|[12][0-9]|3[0-2]))?$#', $snet)) {
                $conf_content .= "  access-control: {$snet} allow\n";
            }
        }
    }

    $block_page_ip = !empty($wam_cfg['block_page_ip']) ? trim($wam_cfg['block_page_ip']) : '';
    $all_ifaces = rules_wam_get_configured_interfaces(false);
    $ip_found = false;
    if (!empty($block_page_ip) && filter_var($block_page_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        foreach ($all_ifaces as $if_data) {
            if (!empty($if_data['ip']) && $if_data['ip'] === $block_page_ip) {
                $ip_found = true;
                break;
            }
        }
    }
    if (!$ip_found) {
        $block_page_ip = rules_wam_get_lan_ip();
    }

    // Remove subdomínios cujo domínio pai já está na lista para evitar conflitos no Unbound
    $clean_domains = array();
    foreach ($blocked_domains as $d => $v) {
        if (rules_wam_is_whitelisted($d, $whitelist)) {
            continue;
        }
        $parts = explode('.', $d);
        $has_parent = false;
        while (count($parts) > 1) {
            array_shift($parts);
            $parent = implode('.', $parts);
            if (isset($blocked_domains[$parent])) {
                $has_parent = true;
                break;
            }
        }
        if (!$has_parent) {
            $clean_domains[$d] = true;
        }
    }

    foreach (array_keys($clean_domains) as $dom) {
        if ($block_action === 'always_null') {
            $conf_content .= "  local-zone: \"{$dom}\" always_null\n";
        } else {
            $conf_content .= "  local-zone: \"{$dom}\" redirect\n";
            $conf_content .= "  local-data: \"{$dom} 60 IN A {$block_page_ip}\"\n";
        }
    }

    // Grava o arquivo de regras do Unbound
    file_put_contents(WAM_CONF_FILE, $conf_content);
    @chmod(WAM_CONF_FILE, 0644);

    // Neutraliza qualquer arquivo antigo em conf.d para evitar duplicidade
    if (file_exists('/var/unbound/conf.d/wam_blocklist.conf')) {
        @file_put_contents('/var/unbound/conf.d/wam_blocklist.conf', "# Rules WAM - Migrado para " . WAM_CONF_FILE . "\n");
    }

    // Habilita log de consultas no pfSense
    config_set_path('unbound/log_queries', 'yes');

    // Injeta include no Unbound custom_options usando base64 (padrão pfSense)
    $raw_opts = config_get_path('unbound/custom_options', '');
    $cur_opts = '';
    if (!empty($raw_opts)) {
        $decoded = @base64_decode($raw_opts, true);
        if ($decoded !== false && base64_encode($decoded) === $raw_opts) {
            $cur_opts = $decoded;
        } else {
            $cur_opts = $raw_opts;
        }
    }

    // Limpa referências antigas e adiciona include correto
    $opt_lines = explode("\n", $cur_opts);
    $cleaned_opt_lines = array();
    foreach ($opt_lines as $oline) {
        $tline = trim($oline);
        if (empty($tline)) continue;
        if (strpos($tline, 'wam_blocklist.conf') !== false) {
            continue;
        }
        $cleaned_opt_lines[] = $tline;
    }
    $cleaned_opt_lines[] = "include: " . WAM_CONF_FILE;
    $new_custom = trim(implode("\n", $cleaned_opt_lines));
    $ub_conf = '/var/unbound/unbound.conf';
    $need_unbound_configure = ($new_custom !== trim($cur_opts));
    if (file_exists($ub_conf) && strpos(@file_get_contents($ub_conf), 'wam_blocklist.conf') === false) {
        $need_unbound_configure = true;
    }
    if ($need_unbound_configure) {
        config_set_path('unbound/custom_options', base64_encode($new_custom));
        write_config("Rules WAM ativado no Unbound com logging");
        if (function_exists('services_unbound_configure')) {
            services_unbound_configure();
        }
    }

    // Se a ação for exibir o Banner, assegura que o NGINX HTTP/HTTPS do WAM esteja ativo e sincronizado
    if ($block_action === 'block_page') {
        rules_wam_sync_banner_nginx();
    }

    $status_data = array(
        'enabled' => true,
        'schedule_active' => rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null),
        'is_blocking' => true,
        'updated_at' => date('Y-m-d H:i:s'),
        'total_blocked' => $total,
        'categories' => $categories_active,
        'whitelist_count' => count($whitelist),
        'bypass_ips_count' => count($bypass_ips),
        'dns_bypass_protection' => rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? null) ? 'Ativo (Redirecionando 8.8.8.8 / 1.1.1.1)' : 'Desativado',
        'upstream_forwarding' => rules_wam_is_checked($wam_cfg['enable_upstream_forwarding'] ?? null) ? 'Ativo (Google 8.8.8.8 & Cloudflare 1.1.1.1)' : 'Desativado',
        'corp_integration' => $corp_enable ? 'Ativo (AD & NPS via IPsec)' : 'Desativado',
        'netskope_protection' => $protect_netskope ? 'Ativo (Auto-Whitelist)' : 'Desativado',
        'helpdesk_protection' => $protect_helpdesk ? 'Ativo (Zendesk, GLPI, ScreenConnect)' : 'Desativado',
        'voip_protection' => $protect_voip ? 'Ativo (SIP & SIP Phone)' : 'Desativado'
    );
    file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));

    rules_wam_sync_domain_overrides($wam_cfg);
    rules_wam_reload_unbound();
    rules_wam_sync_firewall_rules($wam_cfg);
    log_error("[Rules WAM] Sucesso: {$total} domínios bloqueados aplicados no Unbound DNS.");
}

function rules_wam_suspend_schedule() {
    $wam_cfg = rules_wam_get_config();
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $corp_domains = rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '');
    $corp_dns_ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');
    $corp_reverse = (!isset($wam_cfg['corp_reverse_lookup']) || rules_wam_is_checked($wam_cfg['corp_reverse_lookup']));
    $upstream_enable = rules_wam_is_checked($wam_cfg['enable_upstream_forwarding'] ?? null);

    $conf = "# Rules WAM - Fora do Horario Comercial (Acesso Liberado)\nserver:\n  log-local-actions: yes\n";
    if ($corp_enable && !empty($corp_domains)) {
        foreach ($corp_domains as $cdom) {
            $cdom = rules_wam_clean_domain($cdom);
            if (!empty($cdom)) {
                $conf .= "  private-domain: \"{$cdom}\"\n";
                $conf .= "  domain-insecure: \"{$cdom}\"\n";
            }
        }
        if ($corp_reverse) {
            $conf .= "  private-domain: \"in-addr.arpa\"\n";
            $conf .= "  domain-insecure: \"in-addr.arpa\"\n";
        }
    }
    $corp_subnets_raw = !empty($wam_cfg['corp_allowed_subnets']) ? $wam_cfg['corp_allowed_subnets'] : "172.24.0.0/16\n192.168.0.0/16\n192.192.0.0/16\n10.0.0.0/8";
    $corp_subnets = rules_wam_parse_list($corp_subnets_raw);
    if (!empty($corp_subnets)) {
        foreach ($corp_subnets as $snet) {
            $snet = trim($snet);
            if (empty($snet)) continue;
            if (preg_match('#^(\d{1,3}\.){3}\d{1,3}(/(?:[0-9]|[12][0-9]|3[0-2]))?$#', $snet)) {
                $conf .= "  access-control: {$snet} allow\n";
            }
        }
    }
    file_put_contents(WAM_CONF_FILE, $conf);
    @chmod(WAM_CONF_FILE, 0644);

    $status_data = array(
        'enabled' => true,
        'schedule_active' => true,
        'is_blocking' => false,
        'updated_at' => date('Y-m-d H:i:s'),
        'total_blocked' => 0,
        'categories' => array('Horário Comercial Pausado (Acesso Liberado)'),
        'whitelist_count' => 0,
        'bypass_ips_count' => 0
    );
    file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));
    rules_wam_reload_unbound();
    log_error("[Rules WAM] Fora do horário comercial: bloqueios temporariamente liberados.");
}

function rules_wam_disable() {
    @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Desativado\nserver:\n");
    @chmod(WAM_CONF_FILE, 0644);
    if (file_exists('/var/unbound/conf.d/wam_blocklist.conf')) {
        @file_put_contents('/var/unbound/conf.d/wam_blocklist.conf', "# Desativado\nserver:\n");
    }

    $raw_opts = config_get_path('unbound/custom_options', '');
    $cur_opts = '';
    if (!empty($raw_opts)) {
        $decoded = @base64_decode($raw_opts, true);
        if ($decoded !== false && base64_encode($decoded) === $raw_opts) {
            $cur_opts = $decoded;
        } else {
            $cur_opts = $raw_opts;
        }
    }

    $lines = explode("\n", $cur_opts);
    $new_lines = array();
    foreach ($lines as $line) {
        $tline = trim($line);
        if (empty($tline)) continue;
        if (strpos($tline, 'wam_blocklist.conf') === false) {
            $new_lines[] = $tline;
        }
    }
    $new_custom = trim(implode("\n", $new_lines));
    if ($new_custom !== trim($cur_opts)) {
        config_set_path('unbound/custom_options', empty($new_custom) ? '' : base64_encode($new_custom));
        write_config("Rules WAM desativado no Unbound");
        if (function_exists('services_unbound_configure')) {
            services_unbound_configure();
        }
    }

    rules_wam_sync_domain_overrides(array('corp_enable' => 'no'));

    $status_data = array(
        'enabled' => false,
        'schedule_active' => false,
        'is_blocking' => false,
        'updated_at' => date('Y-m-d H:i:s'),
        'total_blocked' => 0,
        'categories' => array(),
        'whitelist_count' => 0,
        'bypass_ips_count' => 0
    );
    file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));
    rules_wam_reload_unbound();
    rules_wam_remove_firewall_rules();
    log_error("[Rules WAM] Serviço desabilitado.");
}

/**
 * Remove as regras automáticas de firewall do Rules WAM
 */
function rules_wam_remove_firewall_rules() {
    require_once("config.inc");
    require_once("filter.inc");
    global $config;

    init_config_arr(array("filter", "rule"));
    init_config_arr(array("nat", "rule"));
    $changed = false;
    $new_rules = array();
    foreach ($config["filter"]["rule"] as $r) {
        if (isset($r["descr"]) && strpos($r["descr"], "Rules WAM") !== false) {
            $changed = true;
        } else {
            $new_rules[] = $r;
        }
    }

    $new_nat = array();
    foreach ($config["nat"]["rule"] as $nr) {
        if (isset($nr["descr"]) && strpos($nr["descr"], "Rules WAM") !== false) {
            $changed = true;
        } else {
            $new_nat[] = $nr;
        }
    }

    if ($changed) {
        $config["filter"]["rule"] = $new_rules;
        $config["nat"]["rule"] = $new_nat;
        write_config("Rules WAM: Remocao de regras de protecao de firewall e NAT");
        filter_configure();
    }
}

/**
 * Sincroniza regras de firewall automáticas para evitar bypass em dispositivos móveis (Android/iOS)
 * e bloquear portas nativas de mensageiros como o WhatsApp (5222, 5223, etc.)
 */
function rules_wam_sync_firewall_rules($wam_cfg = null) {
    require_once("config.inc");
    require_once("filter.inc");
    global $config;

    if ($wam_cfg === null) {
        $wam_cfg = rules_wam_get_config();
    }

    if (!rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
        rules_wam_remove_firewall_rules();
        return;
    }

    init_config_arr(array("aliases", "alias"));
    init_config_arr(array("filter", "rule"));

    // 1. Alias de Portas do WhatsApp
    $alias_name = "WAM_WhatsApp_Ports";
    $alias_idx = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if ($a["name"] === $alias_name) {
            $alias_idx = $idx;
            break;
        }
    }
    $alias_data = array(
        "name" => $alias_name,
        "type" => "port",
        "address" => "5222 5223 4244",
        "descr" => "Portas de comunicacao nativa WhatsApp Mobile (Rules WAM)",
        "detail" => "5222 (XMPP)||5223 (SSL)||4244 (Media)"
    );
    if ($alias_idx !== null) {
        $config["aliases"]["alias"][$alias_idx] = $alias_data;
    } else {
        $config["aliases"]["alias"][] = $alias_data;
    }

    // 2. Alias de Redes IP do WhatsApp (AS63293 e clusters de chat Meta)
    $alias_nets_name = "WAM_WhatsApp_Nets";
    $alias_nets_idx = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if ($a["name"] === $alias_nets_name) {
            $alias_nets_idx = $idx;
            break;
        }
    }
    $wa_cidrs = array(
        "157.240.128.0/17", "129.134.128.0/17", "102.132.112.0/20", "102.221.188.0/22",
        "185.89.216.0/22", "196.49.68.0/23", "204.15.20.0/22", "31.13.64.0/18"
    );
    $alias_nets_data = array(
        "name" => $alias_nets_name,
        "type" => "network",
        "address" => implode(" ", $wa_cidrs),
        "descr" => "Redes IP WhatsApp Inc AS63293 (Rules WAM)",
        "detail" => implode("||", $wa_cidrs)
    );
    if ($alias_nets_idx !== null) {
        $config["aliases"]["alias"][$alias_nets_idx] = $alias_nets_data;
    } else {
        $config["aliases"]["alias"][] = $alias_nets_data;
    }

    // 2.1 Alias para Servidores DNS / Controladores de Dominio AD e NPS Matriz
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $corp_dns_ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');
    $valid_ad_ips = array();
    if ($corp_enable && !empty($corp_dns_ips)) {
        foreach ($corp_dns_ips as $cip) {
            if (filter_var($cip, FILTER_VALIDATE_IP)) {
                $valid_ad_ips[] = $cip;
            }
        }
    }
    $alias_corp_name = "WAM_Corp_AD_DNS";
    $alias_corp_idx = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if ($a["name"] === $alias_corp_name) {
            $alias_corp_idx = $idx;
            break;
        }
    }
    if (!empty($valid_ad_ips)) {
        $alias_corp_data = array(
            "name" => $alias_corp_name,
            "type" => "host",
            "address" => implode(" ", $valid_ad_ips),
            "descr" => "Servidores DNS/AD e NPS RADIUS Matriz (Rules WAM)",
            "detail" => implode("||", $valid_ad_ips)
        );
        if ($alias_corp_idx !== null) {
            $config["aliases"]["alias"][$alias_corp_idx] = $alias_corp_data;
        } else {
            $config["aliases"]["alias"][] = $alias_corp_data;
        }
    } elseif ($alias_corp_idx !== null) {
        unset($config["aliases"]["alias"][$alias_corp_idx]);
        $config["aliases"]["alias"] = array_values($config["aliases"]["alias"]);
    }

    // 2.2 Alias de Portas do Banner HTTP/HTTPS (Portas 80 e 443)
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

    // 3. Interfaces internas ativas configuradas no pfSense (com seus nomes amigáveis reais)
    $configured_internal = rules_wam_get_configured_interfaces(false);
    if (empty($configured_internal)) {
        $configured_internal = array(
            'lan' => array('key' => 'lan', 'descr' => 'LAN', 'is_internal' => true)
        );
    }
    $internal_ifaces = array_keys($configured_internal);
    $if_list = implode(",", $internal_ifaces);

    // 4. Filtra regras existentes que não sejam do Rules WAM
    $cleaned_rules = array();
    foreach ($config["filter"]["rule"] as $r) {
        if (!isset($r["descr"]) || strpos($r["descr"], "Rules WAM") === false) {
            $cleaned_rules[] = $r;
        }
    }

    $rules_to_add = array();

    // Identifica protocolo e porta da WebGUI (ex: 50443, 8443, 443)
    $gui_proto = !empty($config['system']['webgui']['protocol']) ? $config['system']['webgui']['protocol'] : 'https';
    $gui_port = !empty($config['system']['webgui']['port']) ? $config['system']['webgui']['port'] : ($gui_proto === 'https' ? '50443' : '80');

    // Blindagem de Acesso Administrativo (LAN e WAN):
    // 1. Anti-lockout na LAN sempre garantido
    unset($config['system']['webgui']['noantilockout']);
    // 2. Sem bloqueio por DNS Rebind
    $config['system']['webgui']['nodnsrebindcheck'] = true;
    // 3. Sem redirecionamento HTTP nativo (libera porta 80 para o Banner)
    $config['system']['webgui']['disablehttpredirect'] = true;
    // 4. Se a WAN for rede privada RFC1918 (comum em testes e laboratorios), desativa o descarte
    if (isset($config['interfaces']['wan']['blockprivatenets'])) {
        unset($config['interfaces']['wan']['blockprivatenets']);
    }
    if (isset($config['interfaces']['wan']['blockbogons'])) {
        unset($config['interfaces']['wan']['blockbogons']);
    }

    // Regra WAN Permanente: Garante acesso WebGUI na WAN (Porta $gui_port, ex: 50443)
    $rules_to_add[] = array(
        "id" => "",
        "tracker" => "1700000010",
        "type" => "pass",
        "interface" => "wan",
        "ipprotocol" => "inet46",
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "quick" => "yes",
        "protocol" => "tcp",
        "source" => array("any" => true),
        "destination" => array(
            "any" => true,
            "port" => (string)$gui_port
        ),
        "descr" => "Rules WAM - Acesso Permanente WebGUI WAN (Porta {$gui_port})",
        "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
    );

    // Regras Permanentes por Interface Interna: WebGUI e Banners HTTP/HTTPS (Portas 80 e 443)
    // Traz a descrição configurada no pfSense (Ex: LAN, LAN_CORP, WIFI_VISITANTES, etc.)
    $tracker_idx = 11;
    foreach ($configured_internal as $if_key => $if_data) {
        $if_label = !empty($if_data['descr']) ? $if_data['descr'] : strtoupper($if_key);

        // Regra de Acesso WebGUI na Interface
        $rules_to_add[] = array(
            "id" => "",
            "tracker" => (string)(1700000000 + $tracker_idx++),
            "type" => "pass",
            "interface" => $if_key,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "quick" => "yes",
            "protocol" => "tcp",
            "source" => array("any" => true),
            "destination" => array(
                "any" => true,
                "port" => (string)$gui_port
            ),
            "descr" => "Rules WAM - Acesso Permanente WebGUI {$if_label} (Porta {$gui_port})",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
        );

        // Regra de Liberação do Banner HTTP/HTTPS na Interface
        $rules_to_add[] = array(
            "id" => "",
            "tracker" => (string)(1700000000 + $tracker_idx++),
            "type" => "pass",
            "interface" => $if_key,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "quick" => "yes",
            "protocol" => "tcp",
            "source" => array("any" => true),
            "destination" => array(
                "any" => true,
                "port" => "WAM_Banner_Ports"
            ),
            "descr" => "Rules WAM - Liberacao Portas Banner HTTP/HTTPS {$if_label} (80 e 443)",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
        );
    }

    // Regra Flutuante para todas as interfaces internas ativas
    $rules_to_add[] = array(
        "id" => "",
        "tracker" => "1700000099",
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
        "destination" => array(
            "any" => true,
            "port" => "WAM_Banner_Ports"
        ),
        "descr" => "Rules WAM - Liberacao Portas Banner HTTP/HTTPS Global (80 e 443)",
        "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
    );

    // 5. Regra Anti-Bypass DoT (Porta 853) - Bloqueia DNS Privado do Android
    $rules_to_add[] = array(
        "id" => "",
        "tracker" => "1700000101",
        "type" => "reject",
        "interface" => $if_list,
        "ipprotocol" => "inet46",
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "floating" => "yes",
        "quick" => "yes",
        "protocol" => "tcp/udp",
        "source" => array("any" => true),
        "destination" => array(
            "any" => true,
            "port" => "853"
        ),
        "descr" => "Rules WAM - Anti-Bypass DNS Privado Android (DoT 853)",
        "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
    );

    // 6. Regra WhatsApp Mobile - Bloqueia portas nativas 5222/5223/4244/3478/5349 e redes IP AS63293
    $is_msg_active = rules_wam_is_checked($wam_cfg['block_messaging'] ?? null);
    $is_wa_active = !isset($wam_cfg['block_msg_whatsapp']) || rules_wam_is_checked($wam_cfg['block_msg_whatsapp']);
    if ($is_msg_active && $is_wa_active) {
        $rules_to_add[] = array(
            "id" => "",
            "tracker" => "1700000202",
            "type" => "reject",
            "interface" => $if_list,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "floating" => "yes",
            "quick" => "yes",
            "protocol" => "tcp/udp",
            "source" => array("any" => true),
            "destination" => array(
                "any" => true,
                "port" => $alias_name
            ),
            "descr" => "Rules WAM - Bloqueio de Portas App WhatsApp Mobile",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
        );

        $rules_to_add[] = array(
            "id" => "",
            "tracker" => "1700000303",
            "type" => "reject",
            "interface" => $if_list,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "floating" => "yes",
            "quick" => "yes",
            "protocol" => "tcp/udp",
            "source" => array("any" => true),
            "destination" => array(
                "address" => $alias_nets_name
            ),
            "descr" => "Rules WAM - Bloqueio de Redes IP WhatsApp Mobile (AS63293)",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => time(), "username" => "Rules WAM")
        );
    }

    // 7. Anti-Bypass DNS Porta 53 (Interceptar consultas a DNS externos como 8.8.8.8)
    $block_dns_bypass = rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? 'no');
    init_config_arr(array("nat", "rule"));
    $cleaned_nat = array();
    foreach ($config["nat"]["rule"] as $nr) {
        if (!isset($nr["descr"]) || strpos($nr["descr"], "Rules WAM") === false) {
            $cleaned_nat[] = $nr;
        }
    }

    if ($block_dns_bypass) {
        foreach ($internal_ifaces as $idx => $intf) {
            $intf_label = !empty($configured_internal[$intf]['descr']) ? $configured_internal[$intf]['descr'] : strtoupper($intf);
            if (!empty($valid_ad_ips)) {
                $cleaned_nat[] = array(
                    "id" => "",
                    "tracker" => (string)(1700004030 + $idx),
                    "interface" => $intf,
                    "nordr" => "yes",
                    "ipprotocol" => "inet",
                    "protocol" => "tcp/udp",
                    "source" => array("any" => true),
                    "destination" => array(
                        "address" => $alias_corp_name,
                        "port" => "53"
                    ),
                    "descr" => "Rules WAM - Excecao NAT Anti-Bypass AD/DNS ({$intf_label})",
                    "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
                );
            }

            $cleaned_nat[] = array(
                "id" => "",
                "tracker" => (string)(1700004040 + $idx),
                "interface" => $intf,
                "ipprotocol" => "inet",
                "protocol" => "tcp/udp",
                "source" => array("any" => true),
                "destination" => array(
                    "not" => true,
                    "network" => "{$intf}ip",
                    "port" => "53"
                ),
                "target" => "127.0.0.1",
                "local-port" => "53",
                "descr" => "Rules WAM - Anti-Bypass DNS Redirection ({$intf_label} Porta 53)",
                "associated-rule-id" => "pass",
                "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
            );
        }

        if (!empty($valid_ad_ips)) {
            $rules_to_add[] = array(
                "id" => "",
                "tracker" => "1700000504",
                "type" => "pass",
                "interface" => $if_list,
                "ipprotocol" => "inet46",
                "tag" => "",
                "tagged" => "",
                "direction" => "in",
                "floating" => "yes",
                "quick" => "yes",
                "protocol" => "tcp/udp",
                "source" => array("any" => true),
                "destination" => array(
                    "address" => $alias_corp_name,
                    "port" => "53"
                ),
                "descr" => "Rules WAM - Liberacao Direta de DNS para Controladores de Dominio AD",
                "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
            );
        }
    }

    // Adiciona as regras Rules WAM no topo
    foreach (array_reverse($rules_to_add) as $r_add) {
        array_unshift($cleaned_rules, $r_add);
    }

    $current_filter_rules = $config["filter"]["rule"] ?? array();
    $current_nat_rules = $config["nat"]["rule"] ?? array();

    $filter_changed = (serialize($cleaned_rules) !== serialize($current_filter_rules));
    $nat_changed = (serialize($cleaned_nat) !== serialize($current_nat_rules));

    if ($filter_changed || $nat_changed) {
        $config["nat"]["rule"] = $cleaned_nat;
        $config["filter"]["rule"] = $cleaned_rules;
        write_config("Rules WAM: Sincronizacao automatica de regras de protecao de rede e NAT");
        filter_configure();

        if ($is_msg_active && $is_wa_active) {
            mwexec('/sbin/pfctl -k 0.0.0.0/0 -k 157.240.0.0/16 2>/dev/null');
            mwexec('/sbin/pfctl -k 0.0.0.0/0 -k 129.134.0.0/16 2>/dev/null');
            mwexec('/sbin/pfctl -k 0.0.0.0/0 -k 31.13.64.0/18 2>/dev/null');
        }

        log_error("[Rules WAM] Regras automaticas de firewall sincronizadas com sucesso (DoT 853 e WhatsApp).");
    }
}

function rules_wam_is_in_schedule_window($wam_cfg) {
    $now_dow = intval(date('w'));
    $now_time = date('H:i');

    if ($now_dow === 0 || $now_dow === 6) {
        if (!rules_wam_is_checked($wam_cfg['schedule_weekend'] ?? null)) {
            return false;
        }
    }

    $start = !empty($wam_cfg['schedule_start']) ? $wam_cfg['schedule_start'] : '08:00';
    $end   = !empty($wam_cfg['schedule_end']) ? $wam_cfg['schedule_end'] : '18:00';
    $l_start = !empty($wam_cfg['schedule_lunch_start']) ? $wam_cfg['schedule_lunch_start'] : '';
    $l_end   = !empty($wam_cfg['schedule_lunch_end']) ? $wam_cfg['schedule_lunch_end'] : '';

    if (!empty($l_start) && !empty($l_end)) {
        if ($now_time >= $l_start && $now_time < $l_end) {
            return false;
        }
    }

    if ($now_time >= $start && $now_time < $end) {
        return true;
    }

    return false;
}

function rules_wam_is_whitelisted($domain, &$whitelist) {
    if (empty($domain)) return false;
    if (isset($whitelist[$domain])) return true;
    $parts = explode('.', $domain);
    while (count($parts) > 1) {
        array_shift($parts);
        $parent = implode('.', $parts);
        if (isset($whitelist[$parent])) return true;
    }
    return false;
}

function rules_wam_parse_list($str) {
    if (empty($str)) return array();
    $str = str_replace(array('\r\n', '\r', '\n', "\\r\\n", "\\r", "\\n"), "\n", $str);
    $items = preg_split('/[\r\n,;\s]+/', trim($str));
    $clean = array();
    foreach ($items as $it) {
        $it = trim($it);
        if (!empty($it)) {
            $clean[] = $it;
        }
    }
    return array_values(array_unique($clean));
}

/**
 * Sincroniza Domain Overrides no DNS Resolver do pfSense para Active Directory e NPS RADIUS (via VPN IPsec)
 */
function rules_wam_sync_domain_overrides($wam_cfg) {
    if (!function_exists('config_get_path') || !function_exists('config_set_path')) {
        return;
    }

    $existing_overrides = config_get_path('unbound/domainoverrides', array());
    if (!is_array($existing_overrides)) {
        $existing_overrides = array();
    }

    // Preserva overrides manuais pré-existentes, removendo apenas os gerenciados pelo Rules WAM
    $new_overrides = array();
    foreach ($existing_overrides as $ov) {
        if (!isset($ov['descr']) || strpos($ov['descr'], 'Rules WAM') === false) {
            $new_overrides[] = $ov;
        }
    }

    if (rules_wam_is_checked($wam_cfg['corp_enable'] ?? null)) {
        $domains = rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '');
        $ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');

        foreach ($domains as $dom) {
            $dom = rules_wam_clean_domain($dom);
            if (empty($dom)) continue;
            foreach ($ips as $ip) {
                if (filter_var($ip, FILTER_VALIDATE_IP)) {
                    $new_overrides[] = array(
                        'domain' => $dom,
                        'ip' => $ip,
                        'descr' => 'Rules WAM: AD/NPS Matriz IPsec'
                    );
                }
            }
        }

        if (rules_wam_is_checked($wam_cfg['corp_reverse_lookup'] ?? 'yes')) {
            $rev_zones = array();
            foreach ($ips as $ip) {
                $p = explode('.', $ip);
                if (count($p) === 4) {
                    $rev_zones[$p[0] . '.in-addr.arpa'] = true;
                    $rev_zones[$p[1] . '.' . $p[0] . '.in-addr.arpa'] = true;
                }
            }
            foreach (array_keys($rev_zones) as $rz) {
                foreach ($ips as $ip) {
                    if (filter_var($ip, FILTER_VALIDATE_IP)) {
                        $new_overrides[] = array(
                            'domain' => $rz,
                            'ip' => $ip,
                            'descr' => 'Rules WAM: Reverso AD/NPS Matriz IPsec'
                        );
                    }
                }
            }
        }
    }

    config_set_path('unbound/domainoverrides', $new_overrides);
}

function rules_wam_load_feed_domains($feed_file, &$blocked_domains, &$whitelist) {
    $path = WAM_FEEDS_DIR . '/' . $feed_file;
    if (!file_exists($path)) {
        return;
    }
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if (empty($line) || $line[0] === '#') {
            continue;
        }
        $d = rules_wam_clean_domain($line);
        if ($d && !rules_wam_is_whitelisted($d, $whitelist)) {
            $blocked_domains[$d] = true;
        }
    }
}

function rules_wam_clean_domain($domain) {
    $domain = trim($domain);
    $domain = rtrim($domain, '.');
    $domain = preg_replace('#^https?://#i', '', $domain);
    $domain = preg_replace('#/.*$#', '', $domain);
    $domain = preg_replace('#:\d+$#', '', $domain);
    $domain = strtolower($domain);
    $domain = rtrim($domain, '.');
    if (empty($domain)) return null;
    if (strpos($domain, 'www.') === 0) {
        $domain = substr($domain, 4);
    }
    // Filtro rigoroso de caracteres para impedir quebra ou injeção na sintaxe do Unbound
    // Permite apenas caracteres RFC válidos para hostnames e subdomínios (letras, dígitos, hífens, pontos e sublinhados para SRV)
    if (!preg_match('/^(\*\.)?[a-z0-9_\-\.]+$/', $domain)) {
        return null;
    }
    // Impede pontos consecutivos e comprimentos acima do limite RFC
    if (strpos($domain, '..') !== false || strlen($domain) > 253) {
        return null;
    }
    return $domain;
}

function rules_wam_reload_unbound() {
    $ub_conf = '/var/unbound/unbound.conf';

    // 1. Garante que o arquivo de blocklist exista e tenha permissão de leitura pelo Unbound
    if (!file_exists(WAM_CONF_FILE)) {
        @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Inicial\nserver:\n");
    }
    @chmod(WAM_CONF_FILE, 0644);

    // 2. Validação estrita de sintaxe com unbound-checkconf
    if (file_exists('/usr/local/sbin/unbound-checkconf') && file_exists($ub_conf)) {
        $check_out = array();
        $check_rc = 0;
        exec("/usr/local/sbin/unbound-checkconf " . escapeshellarg($ub_conf) . " 2>&1", $check_out, $check_rc);
        if ($check_rc !== 0) {
            $err_str = implode("\n", $check_out);
            @file_put_contents('/var/log/wam_checkconf_err.log', $err_str);
            log_error("[Rules WAM] Falha na validação do Unbound ({$err_str}). Neutralizando regras para proteger a rede.");
            @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Protecao contra falha de sintaxe\nserver:\n");
        } else {
            @unlink('/var/log/wam_checkconf_err.log');
        }
    }

    // 3. Verifica se o Unbound está ativo e escutando na porta 53
    $is_running = false;
    $sock_out = array();
    exec("/usr/bin/sockstat -4 -l -p 53 2>/dev/null | grep unbound", $sock_out);
    if (!empty($sock_out)) {
        $is_running = true;
    }

    // 4. Se o serviço já está rodando, efetua recarga em memória com ZERO DOWNTIME (sem parar o DNS)
    if ($is_running && file_exists('/usr/local/sbin/unbound-control') && file_exists($ub_conf)) {
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} reload 2>/dev/null");
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} flush_zone . 2>/dev/null");
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} flush_negative 2>/dev/null");
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} flush_bogus 2>/dev/null");
        return true;
    }

    // 5. Se o serviço estiver parado, inicializa oficialmente pelo pfSense
    if (function_exists('services_unbound_configure')) {
        services_unbound_configure();
    } elseif (file_exists('/usr/local/sbin/pfSsh.php')) {
        mwexec("/usr/local/sbin/pfSsh.php playback svc restart unbound 2>/dev/null");
    }

    return true;
}

/**
 * Identifica o Hostname a partir do IP (via Mapeamento Manual, DHCP leases do pfSense, Unbound ou DNS Reverso)
 */
function rules_wam_resolve_hostname($ip, &$cache) {
    if (isset($cache[$ip])) return $cache[$ip];
    $hostname = '';

    global $config;

    // 0. Prioridade Máxima: Mapeamento Manual no Rules WAM (custom_hosts)
    $wam_cfg = rules_wam_get_config();
    if (!empty($wam_cfg['custom_hosts'])) {
        $lines = preg_split('/[\r\n]+/', $wam_cfg['custom_hosts']);
        foreach ($lines as $line) {
            $line = trim($line);
            if (empty($line) || strpos($line, '#') === 0) continue;
            if (strpos($line, '=') !== false) {
                list($hip, $hname) = explode('=', $line, 2);
                if (trim($hip) === $ip && !empty(trim($hname))) {
                    $cache[$ip] = trim($hname);
                    return $cache[$ip];
                }
            }
        }
    }

    // Padrões conhecidos de equipamentos de infraestrutura (antenas, APs, switches, rádios)
    $infra_patterns = '/(antena|antenna|ubnt|unifi|nanostation|litebeam|airmax|mikrotik|cpe|station|wlan|torre|setor|radio|enlace|ptp|pmp|ap[-_]|switch)/i';
    $infra_fallback = '';

    // 1. Leitura direta e reversa do arquivo de leases (/var/dhcpd/var/db/dhcpd.leases)
    // O ISC-DHCP faz append a cada concessão. O final do arquivo contém a concessão mais recente enviada pelo host.
    if (file_exists('/var/dhcpd/var/db/dhcpd.leases')) {
        $l_data = @file_get_contents('/var/dhcpd/var/db/dhcpd.leases');
        if (!empty($l_data) && preg_match_all('/lease\s+' . preg_quote($ip, '/') . '\s*\{([^}]+)\}/s', $l_data, $m_blocks)) {
            for ($i = count($m_blocks[1]) - 1; $i >= 0; $i--) {
                $block_content = $m_blocks[1][$i];
                if (preg_match('/client-hostname\s+"([^"]+)";/', $block_content, $m_hn)) {
                    $cand = trim($m_hn[1]);
                    if (!empty($cand)) {
                        if (!preg_match($infra_patterns, $cand)) {
                            $hostname = $cand;
                            break;
                        } else {
                            if (empty($infra_fallback)) $infra_fallback = $cand;
                        }
                    }
                }
            }
        }
    }

    // 2. Consulta tabela de concessões DHCP do pfSense (system_get_dhcpleases) em ordem reversa
    if (empty($hostname) && function_exists('system_get_dhcpleases')) {
        $leases = system_get_dhcpleases();
        if (!empty($leases['lease'])) {
            $rev_leases = array_reverse($leases['lease']);
            foreach ($rev_leases as $l) {
                if (isset($l['ip']) && $l['ip'] === $ip) {
                    $cand = !empty($l['hostname']) ? trim($l['hostname']) : (!empty($l['descr']) ? trim($l['descr']) : '');
                    if (!empty($cand)) {
                        $is_infra = preg_match($infra_patterns, $cand);
                        if (!$is_infra) {
                            $hostname = $cand;
                            break;
                        } else {
                            if (empty($infra_fallback)) $infra_fallback = $cand;
                        }
                    }
                }
            }
        }
    }

    // 3. Consulta Host Overrides no DNS Resolver (Unbound) do config.xml
    if (empty($hostname) && !empty($config['unbound']['hosts'])) {
        foreach ($config['unbound']['hosts'] as $h) {
            if (isset($h['ip']) && $h['ip'] === $ip && !empty($h['host'])) {
                $cand = $h['host'] . (!empty($h['domain']) ? '.' . $h['domain'] : '');
                if (!preg_match($infra_patterns, $cand)) {
                    $hostname = $cand;
                    break;
                }
            }
        }
    }

    // 4. Consulta mapeamentos estáticos de DHCP no config.xml (ignora se for antena)
    if (empty($hostname) && !empty($config['dhcpd']) && is_array($config['dhcpd'])) {
        foreach ($config['dhcpd'] as $if_dhcp) {
            if (!empty($if_dhcp['staticmap']) && is_array($if_dhcp['staticmap'])) {
                foreach ($if_dhcp['staticmap'] as $sm) {
                    if (isset($sm['ipaddr']) && $sm['ipaddr'] === $ip) {
                        $cand = !empty($sm['hostname']) ? $sm['hostname'] : (!empty($sm['descr']) ? $sm['descr'] : '');
                        if (!empty($cand) && !preg_match($infra_patterns, $cand)) {
                            $hostname = $cand;
                            break 2;
                        } elseif (!empty($cand) && empty($infra_fallback)) {
                            $infra_fallback = $cand;
                        }
                    }
                }
            }
        }
    }

    // 6. Se só encontrou nome da antena/equipamento de rede, informa com clareza
    if (empty($hostname)) {
        if (!empty($infra_fallback)) {
            $hostname = "Host {$ip} (via {$infra_fallback})";
        } else {
            $hostname = "Host {$ip}";
        }
    }

    $cache[$ip] = $hostname;
    return $cache[$ip];
}

/**
 * Identifica a categoria a que um domínio pertence
 */
function rules_wam_get_domain_category($domain) {
    static $cat_index = null;
    if ($cat_index === null) {
        $cat_index = array();
        $map = array(
            'adult.txt'        => 'Conteúdo Adulto',
            'gambling.txt'     => 'Apostas & Bets',
            'news.txt'         => 'Notícias & Portais',
            'social-media.txt' => 'Mídias Sociais',
            'sports.txt'       => 'Esportes & Placares',
            'streaming.txt'    => 'Streaming & Vídeo',
            'gaming.txt'       => 'Jogos & Games',
            'shopping.txt'     => 'Compras & E-commerce',
            'p2p.txt'              => 'Torrents & P2P',
            'doh-providers.txt'    => 'Anti-Bypass DoH',
            'vpn-fortinet.txt'     => 'VPN Fortinet / FortiGate',
            'vpn-cisco.txt'        => 'VPN Cisco AnyConnect',
            'vpn-paloalto.txt'     => 'VPN Palo Alto GlobalProtect',
            'ztna-zscaler.txt'     => 'ZTNA Zscaler',
            'ztna-netskope.txt'    => 'ZTNA Netskope',
            'ztna-cloudflare.txt'  => 'ZTNA Cloudflare WARP',
            'ztna-tailscale.txt'   => 'ZTNA & Mesh VPN',
            'vpn-commercial.txt'   => 'VPN Comercial & Proxies',
            'vpn-ztna.txt'         => 'VPN, ZTNA & Proxies',
            'msg-whatsapp.txt'     => 'WhatsApp',
            'msg-telegram.txt'     => 'Telegram',
            'msg-messenger.txt'    => 'Facebook Messenger',
            'msg-teams-skype.txt'  => 'Microsoft Teams / Skype / MSN',
            'msg-discord.txt'      => 'Discord',
            'msg-slack.txt'        => 'Slack',
            'msg-zoom-meet.txt'    => 'Zoom & Google Meet',
            'msg-others.txt'       => 'Mensageiros Instantâneos',
            'messaging.txt'        => 'Mensageiros & Chat'
        );
        foreach ($map as $f => $label) {
            $path = WAM_FEEDS_DIR . '/' . $f;
            if (file_exists($path)) {
                $lines = file($path, FILE_SKIP_EMPTY_LINES);
                foreach ($lines as $l) {
                    $l = trim($l);
                    if (!empty($l) && $l[0] !== '#') {
                        $cat_index[$l] = $label;
                    }
                }
            }
        }
    }

    $d = rules_wam_clean_domain($domain);
    if (isset($cat_index[$d])) return $cat_index[$d];

    // Checa domínio pai
    $parts = explode('.', $d);
    while (count($parts) > 1) {
        array_shift($parts);
        $p = implode('.', $parts);
        if (isset($cat_index[$p])) return $cat_index[$p];
    }

    return 'Regra Personalizada / Outros';
}

/**
 * Verifica se um domínio está na lista ativa de bloqueio do Unbound
 */
function rules_wam_is_domain_blocked($domain) {
    static $blocked_cache = null;
    if ($blocked_cache === null) {
        $blocked_cache = array();
        $candidates = array(
            WAM_CONF_FILE,
            '/var/unbound/conf.d/wam_blocklist.conf',
            '/var/unbound/wam_blocklist.conf'
        );
        foreach ($candidates as $cfile) {
            if (file_exists($cfile)) {
                $lines = @file($cfile, FILE_SKIP_EMPTY_LINES);
                if (!empty($lines)) {
                    foreach ($lines as $line) {
                        if (preg_match('/local-zone:\s*"([^"]+)"/i', $line, $m)) {
                            $blocked_cache[strtolower(trim($m[1]))] = true;
                        }
                    }
                }
                if (!empty($blocked_cache)) break;
            }
        }
    }

    $d = strtolower(rules_wam_clean_domain($domain));
    if (empty($d)) return false;
    if (isset($blocked_cache[$d])) return true;

    $parts = explode('.', $d);
    while (count($parts) > 1) {
        array_shift($parts);
        $p = implode('.', $parts);
        if (isset($blocked_cache[$p])) return true;
    }

    return false;
}

/**
 * Obtém a lista e status de hosts Online na rede local via tabelas ARP (IPv4) e NDP (IPv6)
 */
function rules_wam_get_online_hosts() {
    static $online_hosts = null;
    if ($online_hosts !== null) {
        return $online_hosts;
    }

    $online_hosts = array();

    // 1. pfSense native system_get_arp_table()
    if (function_exists('system_get_arp_table')) {
        $arp_data = system_get_arp_table(false);
        if (is_array($arp_data)) {
            foreach ($arp_data as $entry) {
                $ip = $entry['ip-address'] ?? ($entry['ip'] ?? '');
                $mac = $entry['mac-address'] ?? ($entry['mac'] ?? '');
                if (!empty($ip) && !empty($mac) && stripos($mac, 'incomplete') === false && $mac !== '(incomplete)') {
                    $online_hosts[$ip] = array(
                        'online' => true,
                        'mac' => $mac,
                        'interface' => $entry['interface'] ?? '',
                        'status' => 'online'
                    );
                }
            }
        }
    }

    // 2. Leitura direta de /usr/sbin/arp -an (garantia máxima no FreeBSD/pfSense)
    $raw_arp = array();
    @exec('/usr/sbin/arp -an 2>/dev/null', $raw_arp);
    if (empty($raw_arp)) {
        @exec('arp -an 2>/dev/null', $raw_arp);
    }
    if (!empty($raw_arp)) {
        foreach ($raw_arp as $line) {
            // Formato FreeBSD: ? (172.24.60.10) at 00:11:22:33:44:55 on em0 expires in 1198 seconds [ethernet]
            if (preg_match('/\(([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\)\s+at\s+([0-9a-fA-F:]{11,17}|[0-9a-fA-F]{1,2}(?::[0-9a-fA-F]{1,2}){5})/i', $line, $m)) {
                $ip = $m[1];
                $mac = strtolower($m[2]);
                if (stripos($mac, 'incomplete') === false && !isset($online_hosts[$ip])) {
                    $online_hosts[$ip] = array(
                        'online' => true,
                        'mac' => $mac,
                        'interface' => '',
                        'status' => 'online'
                    );
                }
            }
        }
    }

    // 3. Suporte a IPv6 via ndp -an
    $raw_ndp = array();
    @exec('/usr/sbin/ndp -an 2>/dev/null', $raw_ndp);
    if (!empty($raw_ndp)) {
        foreach ($raw_ndp as $line) {
            $parts = preg_split('/\s+/', trim($line));
            if (count($parts) >= 2) {
                $ip6 = $parts[0];
                $mac6 = strtolower($parts[1]);
                if (strpos($ip6, ':') !== false && stripos($mac6, 'incomplete') === false && preg_match('/^[0-9a-f:]+$/i', $mac6)) {
                    if (!isset($online_hosts[$ip6])) {
                        $online_hosts[$ip6] = array(
                            'online' => true,
                            'mac' => $mac6,
                            'interface' => $parts[2] ?? '',
                            'status' => 'online'
                        );
                    }
                }
            }
        }
    }

    // 4. Sessão web atual e loopback são sempre Online
    $online_hosts['127.0.0.1'] = array('online' => true, 'mac' => 'loopback', 'interface' => 'lo0', 'status' => 'online');
    $online_hosts['::1'] = array('online' => true, 'mac' => 'loopback', 'interface' => 'lo0', 'status' => 'online');
    if (!empty($_SERVER['REMOTE_ADDR'])) {
        $online_hosts[$_SERVER['REMOTE_ADDR']] = array('online' => true, 'mac' => 'current_session', 'interface' => 'lan', 'status' => 'online');
    }

    return $online_hosts;
}

/**
 * Retorna se um endereço IP específico está online no momento
 */
function rules_wam_is_host_online($ip) {
    if (empty($ip)) return false;
    $online = rules_wam_get_online_hosts();
    return isset($online[$ip]) && !empty($online[$ip]['online']);
}

/**
 * Retorna o MAC address conhecido do host se disponível
 */
function rules_wam_get_host_mac($ip) {
    if (empty($ip)) return '';
    $online = rules_wam_get_online_hosts();
    if (isset($online[$ip]['mac']) && $online[$ip]['mac'] !== 'loopback' && $online[$ip]['mac'] !== 'current_session') {
        return $online[$ip]['mac'];
    }
    return '';
}

/**
 * Extrai os registros de tentativas de bloqueio dos logs do sistema
 * Se $limit <= 0, retorna todos os registros sem limitação
 */
function rules_wam_get_audit_events($limit = 1000) {
    $events = array();
    $cache_hn = array();
    $seen = array();
    $limit = intval($limit);

    // 1. Lê wam_audit.log direto
    if (file_exists(WAM_AUDIT_LOG)) {
        $lines = @file(WAM_AUDIT_LOG, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($lines) {
            for ($i = count($lines) - 1; $i >= 0; $i--) {
                $line = trim($lines[$i]);
                if (empty($line)) continue;

                $ts = '';
                $ip = '';
                $dom = '';
                $cat = '';
                $hn = '';

                if (strpos($line, '|') !== false) {
                    $parts = explode('|', $line);
                    if (count($parts) >= 3) {
                        $ts = trim($parts[0]);
                        $ip = trim($parts[1]);
                        $dom = rules_wam_clean_domain(trim($parts[2]));
                        $cat = isset($parts[3]) ? trim($parts[3]) : '';
                        $hn = isset($parts[4]) ? trim($parts[4]) : '';
                    }
                } elseif (preg_match('/\[(.*?)\]\s+CLIENT=([^\s]+)(?:\s+HOSTNAME=([^\s]+))?\s+DOMAIN=([^\s]+)(?:\s+CATEGORY="(.*?)")?/i', $line, $am)) {
                    $ts = trim($am[1]);
                    $ip = trim($am[2]);
                    $hn = !empty($am[3]) ? trim($am[3]) : '';
                    $dom = rules_wam_clean_domain(trim($am[4]));
                    $cat = !empty($am[5]) ? trim($am[5]) : '';
                }

                if (!empty($dom) && !empty($ip)) {
                    $key = "$ts|$ip|$dom";
                    if (!isset($seen[$key])) {
                        $seen[$key] = true;
                        $is_online = rules_wam_is_host_online($ip);
                        $events[] = array(
                            'timestamp' => $ts,
                            'ip' => $ip,
                            'hostname' => !empty($hn) ? $hn : rules_wam_resolve_hostname($ip, $cache_hn),
                            'online' => $is_online,
                            'status_label' => $is_online ? 'Online' : 'Offline',
                            'domain' => $dom,
                            'category' => !empty($cat) ? $cat : rules_wam_get_domain_category($dom)
                        );
                        if ($limit > 0 && count($events) >= $limit) return $events;
                    }
                }
            }
        }
    }

    // 2. Lê /var/log/resolver.log e /var/log/system.log do pfSense (consultas reais de rede de qualquer cliente)
    $log_lines = array();
    $log_files = array('/var/log/resolver.log', '/var/log/system.log');
    $tail_count = ($limit > 0) ? intval($limit * 3) : 100000;

    foreach ($log_files as $lfile) {
        if (!file_exists($lfile)) continue;

        // Se for circular clog (FreeBSD/pfSense)
        if (file_exists('/usr/local/sbin/clog')) {
            $clog_out = array();
            @exec('/usr/local/sbin/clog -f ' . escapeshellarg($lfile) . ' 2>/dev/null | tail -n ' . $tail_count, $clog_out);
            if (!empty($clog_out)) {
                $log_lines = array_merge($log_lines, $clog_out);
                continue;
            }
        }

        // Tenta tail nativo do shell
        $tail_out = array();
        @exec('tail -n ' . $tail_count . ' ' . escapeshellarg($lfile) . ' 2>/dev/null', $tail_out);
        if (!empty($tail_out)) {
            $log_lines = array_merge($log_lines, $tail_out);
            continue;
        }

        // Fallback PHP file()
        $f_lines = @file($lfile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($f_lines) {
            $log_lines = array_merge($log_lines, array_slice($f_lines, -$tail_count));
        }
    }

    if (!empty($log_lines)) {
        // Regex robusto:
        // - Datas ISO 8601 (2026-09-04T13:08:31... ou 2026-09-04 13:08:31)
        // - Datas BSD clássicas (Sep  4 13:08:31)
        // - info: ou query: com ou sem PID e porta
        $regex = '/(?:(\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:?\d{2}|Z)?)|([A-Za-z]{3}\s+\d+\s+\d{2}:\d{2}:\d{2})).*?(?:info|query):\s+(?:query\s+(?:from\s+)?)?([0-9a-fA-F.:]+)(?:@\d+|\s+\d+)?\s+([a-zA-Z0-9_.-]+)\.?/i';

        for ($i = count($log_lines) - 1; $i >= 0; $i--) {
            $line = trim($log_lines[$i]);
            if (empty($line)) continue;

            if (preg_match($regex, $line, $m)) {
                $ts = !empty($m[1]) ? $m[1] : $m[2];
                $ip = $m[3];
                $raw_dom = $m[4];
                $dom = rules_wam_clean_domain($raw_dom);
                $lan_ip = function_exists('config_get_path') ? config_get_path('interfaces/lan/ipaddr', '') : (!empty($config['interfaces']['lan']['ipaddr']) ? $config['interfaces']['lan']['ipaddr'] : '');
                $cfg_ip = !empty($wam_cfg['block_page_ip']) ? $wam_cfg['block_page_ip'] : '';
                if (empty($dom) || $ip === '127.0.0.1' || $ip === '::1' || (!empty($lan_ip) && $ip === $lan_ip) || (!empty($cfg_ip) && $ip === $cfg_ip)) continue;

                // Checa se o domínio acessado pertence à nossa lista de bloqueio ativa
                if (rules_wam_is_domain_blocked($dom)) {
                    $key = "$ts|$ip|$dom";
                    if (!isset($seen[$key])) {
                        $seen[$key] = true;
                        $is_online = rules_wam_is_host_online($ip);
                        $events[] = array(
                            'timestamp' => $ts,
                            'ip' => $ip,
                            'hostname' => rules_wam_resolve_hostname($ip, $cache_hn),
                            'online' => $is_online,
                            'status_label' => $is_online ? 'Online' : 'Offline',
                            'domain' => $dom,
                            'category' => rules_wam_get_domain_category($dom)
                        );
                        if ($limit > 0 && count($events) >= $limit) return $events;
                    }
                }
            }
        }
    }

    return $events;
}

/**
 * Garante a existência dos certificados SSL e CA para o Banner de Bloqueio
 */
function rules_wam_ensure_banner_certs($block_page_ip = null) {
    if (empty($block_page_ip)) {
        $block_page_ip = rules_wam_get_lan_ip();
    }
    $ca_crt = '/var/etc/rules_wam_ca.crt';
    $ca_key = '/var/etc/rules_wam_ca.key';
    $ssl_crt = '/var/etc/rules_wam_ssl.crt';
    $ssl_key = '/var/etc/rules_wam_ssl.key';
    $pub_ca = '/usr/local/www/rules_wam_ca.crt';

    @mkdir('/var/etc', 0755, true);

    $need_gen = (!file_exists($ssl_crt) || !file_exists($ssl_key) || @filesize($ssl_crt) === 0 || @filesize($ssl_key) === 0);

    if (!$need_gen) {
        if (!file_exists($pub_ca) && file_exists($ca_crt)) {
            @copy($ca_crt, $pub_ca);
            @chmod($pub_ca, 0644);
        }
        return false;
    }

    // 1. Gera Autoridade Certificadora (CA) se ausente
    if (!file_exists($ca_crt) || !file_exists($ca_key) || @filesize($ca_crt) === 0) {
        $ca_cnf = "[req]\n"
            . "distinguished_name = req_distinguished_name\n"
            . "prompt = no\n"
            . "x509_extensions = v3_ca\n\n"
            . "[req_distinguished_name]\n"
            . "C = BR\nST = SP\nO = Seguranca Corporativa\nCN = Rules WAM Firewall CA\n\n"
            . "[v3_ca]\n"
            . "basicConstraints = critical, CA:TRUE\n"
            . "keyUsage = critical, digitalSignature, cRLSign, keyCertSign\n"
            . "subjectKeyIdentifier = hash\n"
            . "authorityKeyIdentifier = keyid:always,issuer\n";
        @file_put_contents('/tmp/rules_wam_ca.cnf', $ca_cnf);
        @exec("/usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 -config /tmp/rules_wam_ca.cnf -keyout {$ca_key} -out {$ca_crt} 2>/dev/null");
        @unlink('/tmp/rules_wam_ca.cnf');
        @chmod($ca_key, 0600);
        @chmod($ca_crt, 0644);
    }

    if (file_exists($ca_crt)) {
        @copy($ca_crt, $pub_ca);
        @chmod($pub_ca, 0644);
    }

    // 2. Monta configuração com SANs para o Banner
    $san_lines = array('DNS.1 = localhost', 'IP.1 = 127.0.0.1');
    $ip_idx = 2;
    $added = array('localhost' => true, '127.0.0.1' => true);

    if (!empty($block_page_ip) && !isset($added[$block_page_ip])) {
        $san_lines[] = "IP.{$ip_idx} = {$block_page_ip}";
        $added[$block_page_ip] = true;
        $ip_idx++;
    }

    // Inclui todos os IPs de interfaces internas configuradas no pfSense no certificado SAN
    $internal_ifaces = rules_wam_get_configured_interfaces(false);
    foreach ($internal_ifaces as $i_data) {
        if (!empty($i_data['ip']) && !isset($added[$i_data['ip']])) {
            $san_lines[] = "IP.{$ip_idx} = " . $i_data['ip'];
            $added[$i_data['ip']] = true;
            $ip_idx++;
        }
    }

    $idx = 2;
    $popular = array(
        'whatsapp.com', 'facebook.com', 'instagram.com', 'tiktok.com', 'twitter.com', 'x.com',
        'discord.com', 'telegram.org', 'bet365.com', 'betano.com', 'blaze.com', 'sportingbet.com',
        'xvideos.com', 'pornhub.com', 'xnxx.com', 'globo.com', 'uol.com.br'
    );
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

    $cnf = "[req]\n"
        . "distinguished_name = req_distinguished_name\n"
        . "prompt = no\n"
        . "req_extensions = v3_req\n\n"
        . "[req_distinguished_name]\n"
        . "C = BR\nST = SP\nO = Seguranca Corporativa\nCN = Rules WAM Block\n\n"
        . "[v3_req]\n"
        . "basicConstraints = critical, CA:FALSE\n"
        . "keyUsage = critical, digitalSignature, keyEncipherment\n"
        . "extendedKeyUsage = serverAuth\n"
        . "subjectKeyIdentifier = hash\n"
        . "subjectAltName = @alt_names\n\n"
        . "[alt_names]\n"
        . implode("\n", $san_lines) . "\n";

    @file_put_contents('/tmp/rules_wam_ssl.cnf', $cnf);
    @unlink($ssl_key);
    @unlink($ssl_crt);
    @exec("/usr/bin/openssl req -new -newkey rsa:2048 -nodes -keyout {$ssl_key} -out /tmp/rules_wam_ssl.csr -config /tmp/rules_wam_ssl.cnf 2>/dev/null");
    @exec("/usr/bin/openssl x509 -req -days 3650 -in /tmp/rules_wam_ssl.csr -CA {$ca_crt} -CAkey {$ca_key} -CAcreateserial -out {$ssl_crt} -extfile /tmp/rules_wam_ssl.cnf -extensions v3_req 2>/dev/null");

    if (!file_exists($ssl_crt) || @filesize($ssl_crt) === 0) {
        @exec("/usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 -config /tmp/rules_wam_ssl.cnf -extensions v3_req -keyout {$ssl_key} -out {$ssl_crt} 2>/dev/null");
    }

    @unlink('/tmp/rules_wam_ssl.csr');
    @unlink('/tmp/rules_wam_ssl.cnf');
    @chmod($ssl_key, 0640);
    @chmod($ssl_crt, 0644);

    return true;
}

/**
 * Sincroniza o servico NGINX do Banner de Bloqueio com a porta ativa da WebGUI
 */
function rules_wam_sync_banner_nginx() {
    global $config;
    require_once("config.inc");
    init_config_arr(array('system', 'webgui'));

    $sys_changed = false;
    // Assegura parâmetros de DNS Rebind e HTTP Redirect se ausentes
    if (!isset($config['system']['webgui']['nodnsrebindcheck'])) {
        $config['system']['webgui']['nodnsrebindcheck'] = true;
        $sys_changed = true;
    }
    if (!isset($config['system']['webgui']['disablehttpredirect'])) {
        $config['system']['webgui']['disablehttpredirect'] = true;
        $sys_changed = true;
    }

    // Libera porta 443 e 80 migrando WebGUI para 50443 caso esteja em conflito
    $cur_port = !empty($config['system']['webgui']['port']) ? $config['system']['webgui']['port'] : '';
    $cur_proto = !empty($config['system']['webgui']['protocol']) ? $config['system']['webgui']['protocol'] : 'https';
    $port_changed = false;
    if ($cur_port === '443' || $cur_port === '80' || (empty($cur_port) && $cur_proto === 'https') || $cur_port === '8443') {
        $config['system']['webgui']['port'] = '50443';
        $config['system']['webgui']['protocol'] = 'https';
        $port_changed = true;
        $sys_changed = true;
    }

    if ($sys_changed) {
        write_config("Rules WAM: Portas 80 e 443 liberadas para Banner (WebGUI ajustada para 50443)");
        if ($port_changed && file_exists('/etc/rc.restart_webgui')) {
            // Executa em segundo plano com delay para não encerrar a sessão HTTP atual do usuário
            if (function_exists('mwexec_bg')) {
                @mwexec_bg('/bin/sh -c "(sleep 2 && /etc/rc.restart_webgui) >/dev/null 2>&1 &"');
            } else {
                @mwexec('/bin/sh -c "(sleep 2 && /etc/rc.restart_webgui) >/dev/null 2>&1 &"');
            }
        }
        if (file_exists('/etc/rc.filter_configure')) {
            @mwexec('/etc/rc.filter_configure 2>/dev/null');
        } elseif (function_exists('filter_configure')) {
            filter_configure();
        }
    }

    // Assegura certificados SSL válidos para o Banner NGINX
    $cert_generated = rules_wam_ensure_banner_certs();

    $nginx_conf = '/usr/local/etc/nginx/rules_wam_ssl.conf';
    $conf_changed = false;

    // FastCGI direto para o PHP-FPM nativo do pfSense
    // Elimina completamente 502 Bad Gateway e dependência de porta/protocolo da WebGUI
    $conf_tpl = "worker_processes 1;\n"
        . "pid /var/run/rules_wam_ssl.pid;\n"
        . "error_log /var/log/rules_wam_ssl.log info;\n"
        . "events {\n    worker_connections 256;\n}\n"
        . "http {\n"
        . "    access_log off;\n"
        . "    error_log /var/log/rules_wam_ssl.log info;\n"
        . "    default_type text/html;\n"
        . "    types {\n"
        . "        text/html                             html htm;\n"
        . "        application/x-x509-ca-cert            crt;\n"
        . "    }\n\n"
        . "    server {\n"
        . "        listen 80;\n"
        . "        server_name _;\n"
        . "        root /usr/local/www;\n\n"
        . "        location = /rules_wam_ca.crt {\n"
        . "            root /usr/local/www;\n"
        . "        }\n\n"
        . "        location / {\n"
        . "            fastcgi_pass unix:/var/run/php-fpm.socket;\n"
        . "            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;\n"
        . "            fastcgi_param SCRIPT_NAME /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_URI /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_ROOT /usr/local/www;\n"
        . "            fastcgi_param QUERY_STRING domain=\$host&\$query_string;\n"
        . "            fastcgi_param REQUEST_METHOD \$request_method;\n"
        . "            fastcgi_param CONTENT_TYPE \$content_type;\n"
        . "            fastcgi_param CONTENT_LENGTH \$content_length;\n"
        . "            fastcgi_param SERVER_PROTOCOL \$server_protocol;\n"
        . "            fastcgi_param REMOTE_ADDR \$remote_addr;\n"
        . "            fastcgi_param REMOTE_PORT \$remote_port;\n"
        . "            fastcgi_param SERVER_ADDR \$server_addr;\n"
        . "            fastcgi_param SERVER_PORT \$server_port;\n"
        . "            fastcgi_param SERVER_NAME \$host;\n"
        . "            fastcgi_param HTTP_HOST \$host;\n"
        . "            fastcgi_param GATEWAY_INTERFACE CGI/1.1;\n"
        . "            fastcgi_param SERVER_SOFTWARE nginx;\n"
        . "            fastcgi_param REDIRECT_STATUS 200;\n"
        . "            fastcgi_buffers 16 16k;\n"
        . "            fastcgi_buffer_size 32k;\n"
        . "            fastcgi_read_timeout 15s;\n"
        . "            fastcgi_send_timeout 15s;\n"
        . "            fastcgi_connect_timeout 5s;\n"
        . "        }\n"
        . "    }\n\n"
        . "    server {\n"
        . "        listen 443 ssl;\n"
        . "        server_name _;\n"
        . "        ssl_certificate /var/etc/rules_wam_ssl.crt;\n"
        . "        ssl_certificate_key /var/etc/rules_wam_ssl.key;\n"
        . "        ssl_protocols TLSv1.2 TLSv1.3;\n"
        . "        ssl_ciphers HIGH:!aNULL:!MD5;\n"
        . "        root /usr/local/www;\n\n"
        . "        location = /rules_wam_ca.crt {\n"
        . "            root /usr/local/www;\n"
        . "        }\n\n"
        . "        location / {\n"
        . "            fastcgi_pass unix:/var/run/php-fpm.socket;\n"
        . "            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;\n"
        . "            fastcgi_param SCRIPT_NAME /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_URI /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_ROOT /usr/local/www;\n"
        . "            fastcgi_param QUERY_STRING domain=\$host&\$query_string;\n"
        . "            fastcgi_param REQUEST_METHOD \$request_method;\n"
        . "            fastcgi_param CONTENT_TYPE \$content_type;\n"
        . "            fastcgi_param CONTENT_LENGTH \$content_length;\n"
        . "            fastcgi_param SERVER_PROTOCOL \$server_protocol;\n"
        . "            fastcgi_param REMOTE_ADDR \$remote_addr;\n"
        . "            fastcgi_param REMOTE_PORT \$remote_port;\n"
        . "            fastcgi_param SERVER_ADDR \$server_addr;\n"
        . "            fastcgi_param SERVER_PORT \$server_port;\n"
        . "            fastcgi_param SERVER_NAME \$host;\n"
        . "            fastcgi_param HTTP_HOST \$host;\n"
        . "            fastcgi_param HTTPS on;\n"
        . "            fastcgi_param GATEWAY_INTERFACE CGI/1.1;\n"
        . "            fastcgi_param SERVER_SOFTWARE nginx;\n"
        . "            fastcgi_param REDIRECT_STATUS 200;\n"
        . "            fastcgi_buffers 16 16k;\n"
        . "            fastcgi_buffer_size 32k;\n"
        . "            fastcgi_read_timeout 15s;\n"
        . "            fastcgi_send_timeout 15s;\n"
        . "            fastcgi_connect_timeout 5s;\n"
        . "        }\n"
        . "    }\n"
        . "}\n";

    if (!file_exists($nginx_conf) || @file_get_contents($nginx_conf) !== $conf_tpl) {
        @mkdir('/usr/local/etc/nginx', 0755, true);
        file_put_contents($nginx_conf, $conf_tpl);
        $conf_changed = true;
    }

    $rc_script = '/usr/local/etc/rc.d/rules_wam_ssl.sh';
    $rc_content = "#!/bin/sh\n"
        . "stop_banner() {\n"
        . "    pkill -TERM -f \"rules_wam_ssl.conf\" 2>/dev/null || true\n"
        . "    if [ -f /var/run/rules_wam_ssl.pid ]; then\n"
        . "        PID=\$(cat /var/run/rules_wam_ssl.pid 2>/dev/null)\n"
        . "        if [ -n \"\$PID\" ] && kill -0 \"\$PID\" 2>/dev/null; then\n"
        . "            kill -QUIT \"\$PID\" 2>/dev/null || kill -TERM \"\$PID\" 2>/dev/null || true\n"
        . "        fi\n"
        . "    fi\n"
        . "    sleep 1\n"
        . "    for p in \$(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print \$3}' | sort -u); do\n"
        . "        [ -n \"\$p\" ] && kill -TERM \"\$p\" 2>/dev/null || true\n"
        . "    done\n"
        . "    sleep 1\n"
        . "    for p in \$(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print \$3}' | sort -u); do\n"
        . "        [ -n \"\$p\" ] && kill -9 \"\$p\" 2>/dev/null || true\n"
        . "    done\n"
        . "    rm -f /var/run/rules_wam_ssl.pid\n"
        . "    sleep 1\n"
        . "}\n\n"
        . "case \"\$1\" in\n"
        . "    stop)\n"
        . "        stop_banner\n"
        . "        ;;\n"
        . "    start|restart|*)\n"
        . "        stop_banner\n"
        . "        chmod 666 /var/run/php-fpm.socket 2>/dev/null || true\n"
        . "        if [ ! -s /var/etc/rules_wam_ssl.crt ] || [ ! -s /var/etc/rules_wam_ssl.key ]; then\n"
        . "            /usr/local/bin/php -r 'require_once(\"/usr/local/pkg/rules_wam.inc\"); rules_wam_ensure_banner_certs();' 2>/dev/null || true\n"
        . "        fi\n"
        . "        /usr/local/sbin/nginx -c /usr/local/etc/nginx/rules_wam_ssl.conf 2>>/var/log/rules_wam_ssl.log || true\n"
        . "        ;;\nesac\n";

    if (!file_exists($rc_script) || @file_get_contents($rc_script) !== $rc_content) {
        @mkdir('/usr/local/etc/rc.d', 0755, true);
        file_put_contents($rc_script, $rc_content);
        @chmod($rc_script, 0755);
        $conf_changed = true;
    }

    // Verifica se o NGINX do banner já está em execução
    $is_banner_running = false;
    if (file_exists('/var/run/rules_wam_ssl.pid')) {
        $npid = trim(@file_get_contents('/var/run/rules_wam_ssl.pid'));
        if (!empty($npid) && function_exists('posix_kill') && @posix_kill($npid, 0)) {
            $is_banner_running = true;
        }
    }
    if (!$is_banner_running) {
        $p_out = array();
        @exec("/usr/bin/pgrep -f 'rules_wam_ssl.conf'", $p_out);
        $is_banner_running = !empty($p_out);
    }

    // Reinicia o Banner NGINX se a configuração mudou, certificados foram gerados ou serviço está parado
    if (file_exists($rc_script) && ($conf_changed || $cert_generated || !$is_banner_running)) {
        mwexec('/bin/sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart 2>/dev/null');
    }
}
?>
EOF_RULES_INC
chmod 644 /usr/local/pkg/rules_wam.inc
cp -f /usr/local/pkg/rules_wam.inc /usr/local/pkg/wam.inc
chmod 644 /usr/local/pkg/wam.inc
echo "   ✓ /usr/local/pkg/rules_wam.inc e wam.inc sincronizados com FastCGI nativo"

mkdir -p /usr/local/www/widgets/widgets
cat << 'EOF_WIDGET_PHP' > /usr/local/www/widgets/widgets/rules_wam.widget.php
<?php
/*
 * rules_wam.widget.php
 * Rules WAM - Web Access Manager para pfSense
 * Dashboard Widget: Status do Serviço, Categorias Ativas e Resumo Macro de Hosts por Rede
 */

require_once("guiconfig.inc");
require_once("pfsense-utils.inc");
require_once("functions.inc");
require_once("interfaces.inc");
if (file_exists("/usr/local/pkg/rules_wam.inc")) {
    require_once("/usr/local/pkg/rules_wam.inc");
}

if (empty($widgetkey)) {
    $widgetkey = isset($_REQUEST['widgetkey']) ? htmlspecialchars($_REQUEST['widgetkey']) : 'rules_wam-0';
}

$wam_cfg = function_exists('rules_wam_get_config') ? rules_wam_get_config() : array();
$is_enabled = function_exists('rules_wam_is_checked') ? rules_wam_is_checked($wam_cfg['enable'] ?? null) : false;

// 1. Status Geral e Unbound
$status_file = defined('WAM_STATUS_FILE') ? WAM_STATUS_FILE : '/var/log/wam_status.json';
$status_data = array(
    'enabled' => $is_enabled,
    'schedule_active' => false,
    'is_blocking' => false,
    'updated_at' => '-',
    'total_blocked' => 0,
    'categories' => array(),
    'whitelist_count' => 0,
    'bypass_ips_count' => 0
);
if (file_exists($status_file)) {
    $raw_st = @file_get_contents($status_file);
    $parsed_st = json_decode($raw_st, true);
    if (is_array($parsed_st)) {
        $status_data = array_merge($status_data, $parsed_st);
    }
}

// Unbound running check
$unbound_running = false;
if (function_exists('is_service_running')) {
    $unbound_running = is_service_running('unbound');
} else {
    $unbound_pid = @file_get_contents('/var/run/unbound.pid');
    $unbound_running = (!empty($unbound_pid) && function_exists('posix_kill') && @posix_kill(trim($unbound_pid), 0));
}

// NGINX SSL Banner running check
$nginx_banner_running = false;
if (file_exists('/var/run/rules_wam_ssl.pid')) {
    $npid = trim(@file_get_contents('/var/run/rules_wam_ssl.pid'));
    $nginx_banner_running = (!empty($npid) && function_exists('posix_kill') && @posix_kill($npid, 0));
} else {
    $n_out = array();
    @exec("/usr/bin/pgrep -f 'rules_wam_ssl.conf'", $n_out);
    $nginx_banner_running = !empty($n_out);
}

// Schedule check
$schedule_enabled = function_exists('rules_wam_is_checked') ? rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null) : false;
$in_schedule = true;
if ($is_enabled && $schedule_enabled && function_exists('rules_wam_is_in_schedule_window')) {
    $in_schedule = rules_wam_is_in_schedule_window($wam_cfg);
}

// Block action
$block_action = !empty($wam_cfg['block_action']) ? $wam_cfg['block_action'] : 'block_page';

// Contagem real de domínios bloqueados
$total_blocked_domains = $status_data['total_blocked'] ?? 0;
$conf_file = defined('WAM_CONF_FILE') ? WAM_CONF_FILE : '/var/unbound/wam_blocklist.conf';
if ($is_enabled && file_exists($conf_file)) {
    if ($total_blocked_domains <= 0) {
        $conf_lines = @file($conf_file);
        if (is_array($conf_lines)) {
            $c_cnt = 0;
            foreach ($conf_lines as $cline) {
                if (strpos($cline, 'local-zone:') !== false) $c_cnt++;
            }
            $total_blocked_domains = $c_cnt;
        }
    }
}

// 2. Mapeamento das 12 Categorias
$categories_def = array(
    'block_adult'     => array('name' => 'Adulto',         'full' => 'Conteúdo Adulto & Pornografia', 'icon' => 'fa-ban',           'color' => '#d9534f'),
    'block_gambling'  => array('name' => 'Apostas/Bets',   'full' => 'Apostas, Bets & Cassinos',     'icon' => 'fa-money',         'color' => '#f0ad4e'),
    'block_streaming' => array('name' => 'Streaming',      'full' => 'Streaming de Vídeo & Música',  'icon' => 'fa-play-circle',   'color' => '#5bc0de'),
    'block_social'    => array('name' => 'Redes Sociais',  'full' => 'Mídias Sociais & Redes',       'icon' => 'fa-share-alt',     'color' => '#337ab7'),
    'block_messaging' => array('name' => 'Mensageiros',    'full' => 'WhatsApp, Teams, Telegram',    'icon' => 'fa-comments',      'color' => '#5cb85c'),
    'block_gaming'    => array('name' => 'Jogos Online',   'full' => 'Jogos & Plataformas Games',    'icon' => 'fa-gamepad',       'color' => '#8e44ad'),
    'block_vpn'       => array('name' => 'VPN / Proxies',  'full' => 'VPN, ZTNA & Proxies',          'icon' => 'fa-user-secret',   'color' => '#e83e8c'),
    'block_shopping'  => array('name' => 'Compras',        'full' => 'E-commerce & Compras',         'icon' => 'fa-shopping-cart', 'color' => '#fd7e14'),
    'block_p2p'       => array('name' => 'Torrents / P2P', 'full' => 'Torrents & Redes P2P',         'icon' => 'fa-download',      'color' => '#20c997'),
    'block_news'      => array('name' => 'Notícias',       'full' => 'Notícias & Portais de Mídia',  'icon' => 'fa-newspaper-o',   'color' => '#17a2b8'),
    'block_sports'    => array('name' => 'Esportes',       'full' => 'Esportes & Placares ao Vivo',  'icon' => 'fa-trophy',        'color' => '#28a745'),
    'block_doh'       => array('name' => 'Anti-DoH',       'full' => 'Anti-Bypass DNS-over-HTTPS',   'icon' => 'fa-shield',        'color' => '#6c757d')
);

$active_categories = array();
foreach ($categories_def as $cat_key => $cat_info) {
    if (function_exists('rules_wam_is_checked') && rules_wam_is_checked($wam_cfg[$cat_key] ?? null)) {
        $active_categories[$cat_key] = $cat_info;
    }
}

// 3. Mapeamento e Agrupamento Macro por Rede (Descoberta Direta e Abrangente no pfSense)
global $config;
$network_summary = array();

// Função auxiliar para converter qualquer formato de máscara (CIDR, decimal com pontos ou hex) em número CIDR
$to_cidr = function($val) {
    if (empty($val)) return 24;
    $val_str = trim((string)$val);
    if (is_numeric($val_str) && (int)$val_str >= 1 && (int)$val_str <= 32) {
        return (int)$val_str;
    }
    if (stripos($val_str, '0x') === 0) {
        $val_str = long2ip(hexdec($val_str));
    }
    if (filter_var($val_str, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return substr_count(decbin(ip2long($val_str)), '1');
    }
    return 24;
};

// 3.1 Obtém interfaces usando rules_wam_get_configured_interfaces()
$all_configured_ifaces = function_exists('rules_wam_get_configured_interfaces') ? rules_wam_get_configured_interfaces(false) : array();

// Fallback robusto caso rules_wam.inc ainda não tenha a função carregada
if (empty($all_configured_ifaces)) {
    $pfsense_interfaces = function_exists('config_get_path') ? config_get_path('interfaces', array()) : (!empty($config['interfaces']) ? $config['interfaces'] : array());
    $ifdescrs = array();
    if (function_exists('get_configured_interface_with_descr')) {
        $ifdescrs = get_configured_interface_with_descr(false);
    }
    foreach ($pfsense_interfaces as $if_key => $if_cfg) {
        $is_if_enabled = true;
        if (function_exists('interface_is_enabled')) {
            $is_if_enabled = interface_is_enabled($if_key);
        } else {
            $is_if_enabled = ($if_key === 'lan' || $if_key === 'wan' || isset($if_cfg['enable']));
        }
        if (!$is_if_enabled) continue;

        $descr_configured = '';
        if (!empty($if_cfg['descr'])) {
            $descr_configured = trim($if_cfg['descr']);
        } elseif (function_exists('convert_friendly_interface_to_friendly_descr')) {
            $descr_configured = trim(convert_friendly_interface_to_friendly_descr($if_key));
        } elseif (!empty($ifdescrs[$if_key])) {
            $descr_configured = trim($ifdescrs[$if_key]);
        } else {
            $descr_configured = strtoupper($if_key);
        }

        $real_if = !empty($if_cfg['if']) ? $if_cfg['if'] : '';
        if (empty($real_if) && function_exists('get_real_interface')) {
            $real_if = get_real_interface($if_key);
        }
        if (empty($real_if) && function_exists('convert_friendly_interface_to_real_interface_name')) {
            $real_if = convert_friendly_interface_to_real_interface_name($if_key);
        }

        $if_ip = '';
        $if_subnet = 24;
        if (function_exists('get_interface_ip')) {
            $g_ip = get_interface_ip($if_key);
            if (!empty($g_ip) && filter_var($g_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $if_ip = $g_ip;
            }
        }
        if (empty($if_ip) && function_exists('get_interface_info')) {
            $ifinfo = get_interface_info($if_key);
            if (!empty($ifinfo['ipaddr']) && filter_var($ifinfo['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $if_ip = $ifinfo['ipaddr'];
            }
            if (!empty($ifinfo['subnet'])) {
                $if_subnet = $to_cidr($ifinfo['subnet']);
            }
            if (empty($real_if) && !empty($ifinfo['if'])) {
                $real_if = $ifinfo['if'];
            }
        }
        if (empty($if_ip) && !empty($if_cfg['ipaddr']) && filter_var($if_cfg['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            $if_ip = $if_cfg['ipaddr'];
            if (!empty($if_cfg['subnet'])) $if_subnet = $to_cidr($if_cfg['subnet']);
        }

        $has_valid_ip = (!empty($if_ip) && filter_var($if_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4));
        $cidr = '';
        $net_long = 0;
        $long_mask = 0;
        if ($has_valid_ip) {
            $long_ip = ip2long($if_ip);
            $long_mask = -1 << (32 - $if_subnet);
            $net_long = $long_ip & $long_mask;
            $cidr = long2ip($net_long) . '/' . $if_subnet;
        } else {
            $cidr = strtoupper($if_key) . ' (Sem IP)';
        }

        $all_configured_ifaces[$if_key] = array(
            'key' => $if_key,
            'logical_id' => strtoupper($if_key),
            'descr' => $descr_configured,
            'name' => $descr_configured,
            'real_if' => !empty($real_if) ? $real_if : $if_key,
            'ip' => $if_ip,
            'subnet' => $if_subnet,
            'cidr' => $cidr,
            'net_long' => $net_long,
            'mask_long' => $long_mask,
            'has_ip' => $has_valid_ip,
            'is_internal' => ($if_key !== 'wan')
        );
    }
}

// 3.2 Constrói o array $network_summary com o nome exato configurado no pfSense
foreach ($all_configured_ifaces as $if_key => $if_data) {
    $network_summary[$if_key] = array(
        'if_key' => $if_key,
        'logical_id' => $if_data['logical_id'] ?? strtoupper($if_key),
        'descr' => !empty($if_data['descr']) ? $if_data['descr'] : strtoupper($if_key),
        'name' => !empty($if_data['descr']) ? $if_data['descr'] : strtoupper($if_key),
        'real_if' => !empty($if_data['real_if']) ? $if_data['real_if'] : $if_key,
        'ip' => $if_data['ip'] ?? '',
        'cidr' => $if_data['cidr'] ?? '',
        'has_ip' => !empty($if_data['has_ip']),
        'net_long' => $if_data['net_long'] ?? 0,
        'mask_long' => $if_data['mask_long'] ?? 0,
        'online_hosts' => array(),
        'blocked_hosts' => array(),
        'block_count' => 0,
        'bypass_hosts' => array()
    );
}

// 3.3 Adiciona Servidores OpenVPN configurados no pfSense
$ovpn_servers = array();
if (function_exists('config_get_path')) {
    $ovpn_servers = config_get_path('openvpn/openvpn-server', array());
} elseif (!empty($config['openvpn']['openvpn-server']) && is_array($config['openvpn']['openvpn-server'])) {
    $ovpn_servers = $config['openvpn']['openvpn-server'];
}
if (!empty($ovpn_servers) && is_array($ovpn_servers)) {
    foreach ($ovpn_servers as $ovpn) {
        if (!empty($ovpn['tunnel_network']) && strpos($ovpn['tunnel_network'], '/') !== false) {
            $ovpn_cidr = trim($ovpn['tunnel_network']);
            list($o_net, $o_sub) = explode('/', $ovpn_cidr, 2);
            $o_sub_int = (int)$o_sub;
            if ($o_sub_int >= 8 && $o_sub_int <= 32 && filter_var($o_net, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $o_net_long = ip2long($o_net) & (-1 << (32 - $o_sub_int));
                $norm_cidr = long2ip($o_net_long) . '/' . $o_sub_int;
                $ovpn_id = !empty($ovpn['vpnid']) ? $ovpn['vpnid'] : '1';
                $ovpn_key = 'ovpn_' . $ovpn_id;
                $ovpn_descr = !empty($ovpn['description']) ? $ovpn['description'] : 'Acesso Remoto (VPN)';
                $ovpn_dev = 'ovpns' . $ovpn_id;
                $network_summary[$ovpn_key] = array(
                    'if_key' => 'openvpn',
                    'logical_id' => 'OPENVPN',
                    'descr' => $ovpn_descr,
                    'name' => $ovpn_descr,
                    'real_if' => $ovpn_dev,
                    'ip' => long2ip($o_net_long + 1),
                    'cidr' => $norm_cidr,
                    'has_ip' => true,
                    'net_long' => $o_net_long,
                    'mask_long' => -1 << (32 - $o_sub_int),
                    'online_hosts' => array(),
                    'blocked_hosts' => array(),
                    'block_count' => 0,
                    'bypass_hosts' => array()
                );
            }
        }
    }
}

// 3.4 Fallback para ifconfig do FreeBSD cruzando interfaces ativas
$raw_if = array();
@exec("/sbin/ifconfig -a 2>/dev/null", $raw_if);
if (!empty($raw_if)) {
    $cur_dev = '';
    foreach ($raw_if as $line) {
        if (preg_match('/^([a-zA-Z0-9_\.\-]+):/i', $line, $dm)) {
            $cur_dev = $dm[1];
        }
        if (preg_match('/inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\s+netmask\s+(0x[0-9a-fA-F]+|[0-9\.]+)/i', $line, $im)) {
            $s_ip = $im[1];
            $s_mask_raw = $im[2];
            if ($s_ip === '127.0.0.1' || $cur_dev === 'lo0' || strpos($cur_dev, 'pflog') === 0) continue;

            $s_sub = $to_cidr($s_mask_raw);
            $s_long_ip = ip2long($s_ip);
            $s_long_mask = -1 << (32 - $s_sub);
            $s_net_long = $s_long_ip & $s_long_mask;
            $s_cidr = long2ip($s_net_long) . '/' . $s_sub;

            // Tenta casar com interface existente por real_if
            $found_match = false;
            foreach ($network_summary as $nk => &$nentry) {
                if ($nentry['real_if'] === $cur_dev) {
                    if (empty($nentry['ip'])) {
                        $nentry['ip'] = $s_ip;
                        $nentry['has_ip'] = true;
                        $nentry['net_long'] = $s_net_long;
                        $nentry['mask_long'] = $s_long_mask;
                        $nentry['cidr'] = $s_cidr;
                    }
                    $found_match = true;
                    break;
                }
            }
            unset($nentry);

            if (!$found_match) {
                $network_summary[$cur_dev] = array(
                    'if_key' => $cur_dev,
                    'logical_id' => strtoupper($cur_dev),
                    'descr' => strtoupper($cur_dev),
                    'name' => strtoupper($cur_dev),
                    'real_if' => $cur_dev,
                    'ip' => $s_ip,
                    'cidr' => $s_cidr,
                    'has_ip' => true,
                    'net_long' => $s_net_long,
                    'mask_long' => $s_long_mask,
                    'online_hosts' => array(),
                    'blocked_hosts' => array(),
                    'block_count' => 0,
                    'bypass_hosts' => array()
                );
            }
        }
    }
}

// 3.5 Ordenação: LAN primeiro, depois OPTs, depois WAN, depois VPNs, depois Remoto
if (!empty($network_summary)) {
    uksort($network_summary, function($a, $b) use ($network_summary) {
        $order_type = function($entry) {
            $k = strtolower((string)($entry['if_key'] ?? ''));
            if ($k === 'lan') return 1;
            if (strpos($k, 'opt') === 0) return 2;
            if ($k === 'wan') return 3;
            if (strpos($k, 'openvpn') === 0 || strpos($k, 'ovpn') === 0) return 4;
            if (strpos($k, 'ipsec') === 0) return 5;
            if ($k === 'remote') return 99;
            return 10;
        };
        $val_a = $order_type($network_summary[$a] ?? array());
        $val_b = $order_type($network_summary[$b] ?? array());
        if ($val_a !== $val_b) return $val_a - $val_b;
        return strcmp((string)$a, (string)$b);
    });
}

// 3.6 Classifica IP em interface existente ou cria entrada remota
$assign_ip_to_network = function($ip, &$net_summary) {
    if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) return null;
    if ($ip === '127.0.0.1') return null;

    $ipl = ip2long($ip);
    foreach ($net_summary as $if_key => &$net) {
        if (!empty($net['has_ip']) && !empty($net['mask_long'])) {
            if (($ipl & $net['mask_long']) === $net['net_long']) {
                return $if_key;
            }
        }
    }
    unset($net);

    $remote_net_long = $ipl & (-1 << (32 - 24));
    $remote_cidr = long2ip($remote_net_long) . '/24';
    $remote_key = 'remote_' . md5($remote_cidr);
    if (!isset($net_summary[$remote_key])) {
        $net_summary[$remote_key] = array(
            'if_key' => 'remote',
            'logical_id' => 'REMOTO',
            'descr' => 'Rede Remota / VPN Externa',
            'name' => 'Rede Remota / VPN Externa',
            'real_if' => 'remoto',
            'ip' => '',
            'cidr' => $remote_cidr,
            'has_ip' => true,
            'net_long' => $remote_net_long,
            'mask_long' => -1 << (32 - 24),
            'online_hosts' => array(),
            'blocked_hosts' => array(),
            'block_count' => 0,
            'bypass_hosts' => array()
        );
    }
    return $remote_key;
};

// 3.7 Hosts Online
$online_hosts = function_exists('rules_wam_get_online_hosts') ? rules_wam_get_online_hosts() : array();
$total_online_all = array();
if (is_array($online_hosts)) {
    foreach ($online_hosts as $o_ip => $o_info) {
        $net_k = $assign_ip_to_network($o_ip, $network_summary);
        if ($net_k !== null && isset($network_summary[$net_k])) {
            $network_summary[$net_k]['online_hosts'][$o_ip] = true;
            $total_online_all[$o_ip] = true;
        }
    }
}

// 3.8 Tentativas de Bloqueio nos Logs
$audit_file = defined('WAM_AUDIT_LOG') ? WAM_AUDIT_LOG : '/var/log/wam_audit.log';
$total_blocked_hosts_all = array();
$total_block_events_all = 0;

if (file_exists($audit_file)) {
    $audit_lines = @file($audit_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($audit_lines) {
        $max_lines = 5000;
        $total_lines = count($audit_lines);
        $start_idx = max(0, $total_lines - $max_lines);

        for ($i = $start_idx; $i < $total_lines; $i++) {
            $line = trim($audit_lines[$i]);
            if (empty($line)) continue;

            $a_ip = '';
            if (strpos($line, '|') !== false) {
                $parts = explode('|', $line);
                if (count($parts) >= 2) {
                    $a_ip = trim($parts[1]);
                }
            } elseif (preg_match('/CLIENT=([^\s]+)/i', $line, $cm)) {
                $a_ip = trim($cm[1]);
            }

            if (!empty($a_ip)) {
                $net_k = $assign_ip_to_network($a_ip, $network_summary);
                if ($net_k !== null && isset($network_summary[$net_k])) {
                    $network_summary[$net_k]['blocked_hosts'][$a_ip] = true;
                    $network_summary[$net_k]['block_count']++;
                    $total_blocked_hosts_all[$a_ip] = true;
                    $total_block_events_all++;
                }
            }
        }
    }
}

// 3.9 Bypass IPs
$total_bypass_all = array();
if (!empty($wam_cfg['bypass_ips'])) {
    $raw_bypass = preg_split('/[\r\n,;]+/', $wam_cfg['bypass_ips']);
    foreach ($raw_bypass as $b_ip) {
        $b_ip = trim($b_ip);
        if (!empty($b_ip) && filter_var($b_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            $net_k = $assign_ip_to_network($b_ip, $network_summary);
            if ($net_k !== null && isset($network_summary[$net_k])) {
                $network_summary[$net_k]['bypass_hosts'][$b_ip] = true;
                $total_bypass_all[$b_ip] = true;
            }
        }
    }
}

// Se for requisição direta AJAX de atualização rápida do widget
$is_ajax = isset($_GET['ajax']) && $_GET['ajax'] === 'rules_wam';
if ($is_ajax) {
    ob_clean();
}
?>

<div id="rules_wam_widget_container" style="font-family: inherit;">

    <!-- 1. Linha de Status dos Serviços -->
    <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 6px; margin-bottom: 10px; padding-bottom: 8px; border-bottom: 1px solid #e5e5e5;">
        <div style="display: flex; flex-wrap: wrap; gap: 5px; align-items: center;">
            <?php if (!$is_enabled): ?>
                <span class="label label-danger" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Filtragem do Rules WAM está desligada')?>">
                    <i class="fa fa-ban"></i> <?=gettext('Desativado')?>
                </span>
            <?php elseif ($schedule_enabled && !$in_schedule): ?>
                <span class="label label-warning" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Filtro pausado temporariamente pelo agendador de horário comercial / almoço')?>">
                    <i class="fa fa-clock-o"></i> <?=gettext('Pausado (Horário)')?>
                </span>
            <?php else: ?>
                <span class="label label-success" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Rules WAM está ativo e filtrando domínios em tempo real')?>">
                    <i class="fa fa-shield"></i> <?=gettext('Ativo & Filtrando')?>
                </span>
            <?php endif; ?>

            <span class="label <?=$unbound_running ? 'label-success' : 'label-danger'?>" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Status do Unbound DNS Resolver')?>">
                <i class="fa fa-server"></i> DNS: <?=$unbound_running ? gettext('Online') : gettext('Parado')?>
            </span>

            <?php if ($is_enabled && $block_action === 'block_page'): ?>
                <span class="label <?=$nginx_banner_running ? 'label-info' : 'label-warning'?>" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Instância NGINX nas portas 80 e 443 para banner institucional')?>">
                    <i class="fa fa-desktop"></i> Banner: <?=$nginx_banner_running ? '80/443 OK' : gettext('Alerta')?>
                </span>
            <?php elseif ($is_enabled): ?>
                <span class="label label-default" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Respostas DNS retornam 0.0.0.0 sem exibição de tela de bloqueio')?>">
                    <i class="fa fa-volume-off"></i> <?=gettext('Modo Silencioso')?>
                </span>
            <?php endif; ?>
        </div>

        <div style="display: flex; align-items: center; gap: 6px;">
            <span class="badge" style="background-color: #337ab7; font-size: 11px; padding: 4px 8px;" title="<?=gettext('Total de domínios configurados para bloqueio imediato no Unbound')?>">
                <i class="fa fa-database"></i> <?=number_format($total_blocked_domains, 0, ',', '.')?> <?=gettext('domínios')?>
            </span>
            <button type="button" class="btn btn-xs btn-default" onclick="rules_wam_widget_refresh();" title="<?=gettext('Atualizar dados do widget agora')?>" style="padding: 2px 7px;">
                <i class="fa fa-refresh" id="rules_wam_refresh_icon"></i>
            </button>
        </div>
    </div>

    <!-- 2. Categorias Sendo Bloqueadas -->
    <div style="background-color: #f9f9f9; border: 1px solid #e1e4e8; border-radius: 4px; padding: 8px 10px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
            <span style="font-weight: 600; font-size: 11px; text-transform: uppercase; color: #444;">
                <i class="fa fa-tags text-primary"></i> <?=gettext('Categorias Bloqueadas')?> (<?=count($active_categories)?> de <?=count($categories_def)?>)
            </span>
            <small><a href="/rules_wam.php" style="font-size: 11px; font-weight: bold;"><?=gettext('Gerenciar Regras')?> &raquo;</a></small>
        </div>

        <div style="display: flex; flex-wrap: wrap; gap: 4px;">
            <?php if (empty($active_categories)): ?>
                <span class="text-muted" style="font-size: 11px; font-style: italic;">
                    <i class="fa fa-info-circle"></i> <?=gettext('Nenhuma categoria de bloqueio está ativada no momento.')?>
                </span>
            <?php else: ?>
                <?php foreach ($active_categories as $cat_k => $cat_v): ?>
                    <span class="label" style="background-color: <?=$cat_v['color']?>; font-size: 10px; font-weight: normal; padding: 3px 6px; display: inline-flex; align-items: center; gap: 3px;" title="<?=$cat_v['full']?>">
                        <i class="fa <?=$cat_v['icon']?>"></i> <?=$cat_v['name']?>
                    </span>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>

    <!-- 3. Resumo Macro dos Hosts por Rede -->
    <div style="margin-bottom: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
            <span style="font-weight: 600; font-size: 11px; text-transform: uppercase; color: #444;">
                <i class="fa fa-sitemap text-primary"></i> <?=gettext('Resumo Macro dos Hosts por Rede')?>
            </span>
            <small><a href="/rules_wam_dashboard.php" style="font-size: 11px; font-weight: bold;"><?=gettext('Auditoria de Acesso')?> &raquo;</a></small>
        </div>

        <div class="table-responsive" style="margin-bottom: 0;">
            <table class="table table-striped table-condensed table-hover" style="font-size: 11px; margin-bottom: 0; border: 1px solid #ddd;">
                <thead>
                    <tr class="active" style="border-bottom: 2px solid #ddd;">
                        <th style="vertical-align: middle;"><?=gettext('Rede / Interface')?></th>
                        <th class="text-center" style="vertical-align: middle;"><?=gettext('Sub-rede')?></th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Dispositivos ativos detectados na tabela ARP / Rede')?>">
                            <i class="fa fa-circle text-success"></i> <?=gettext('Online')?>
                        </th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Hosts distintos que registraram tentativas de acesso bloqueadas')?>">
                            <i class="fa fa-exclamation-triangle text-danger"></i> <?=gettext('Barrados')?>
                        </th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Total acumulado de requisições de sites bloqueados')?>">
                            <i class="fa fa-ban text-danger"></i> <?=gettext('Tentativas')?>
                        </th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Dispositivos com isenção de filtro (Bypass IP)')?>">
                            <i class="fa fa-unlock text-primary"></i> <?=gettext('Bypass')?>
                        </th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($network_summary)): ?>
                        <tr>
                            <td colspan="6" class="text-center text-muted" style="font-style: italic; padding: 12px;">
                                <i class="fa fa-info-circle"></i> <?=gettext('Nenhuma interface de rede IPv4 ativa detectada no momento.')?>
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($network_summary as $net): ?>
                            <tr>
                                <td style="vertical-align: middle;">
                                    <?php if ($net['if_key'] === 'wan'): ?>
                                        <i class="fa fa-globe text-primary" title="<?=gettext('Interface WAN (Internet)')?>"></i>
                                    <?php elseif ($net['if_key'] === 'lan'): ?>
                                        <i class="fa fa-sitemap text-success" title="<?=gettext('Interface LAN (Rede Local)')?>"></i>
                                    <?php elseif ($net['if_key'] === 'openvpn'): ?>
                                        <i class="fa fa-shield text-warning" title="<?=gettext('Servidor OpenVPN')?>"></i>
                                    <?php elseif ($net['if_key'] === 'remote'): ?>
                                        <i class="fa fa-laptop text-muted" title="<?=gettext('Rede Remota / VPN Externa')?>"></i>
                                    <?php else: ?>
                                        <i class="fa fa-exchange text-info" title="<?=gettext('Interface Adicional / VLAN')?>"></i>
                                    <?php endif; ?>
                                    &nbsp;<strong><?=htmlspecialchars($net['name'])?></strong>
                                    <?php
                                    $port_details = array();
                                    if (!empty($net['logical_id']) && strcasecmp($net['logical_id'], $net['name']) !== 0) {
                                        $port_details[] = $net['logical_id'];
                                    }
                                    if (!empty($net['real_if']) && $net['real_if'] !== 'remoto' && strcasecmp($net['real_if'], $net['name']) !== 0 && (!isset($port_details[0]) || strcasecmp($net['real_if'], $port_details[0]) !== 0)) {
                                        $port_details[] = $net['real_if'];
                                    }
                                    if (!empty($port_details)):
                                    ?>
                                        <small class="text-muted" style="font-size: 10px;">(<?=htmlspecialchars(implode(' / ', $port_details))?>)</small>
                                    <?php endif; ?>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php if (!empty($net['has_ip'])): ?>
                                        <code style="font-size: 10px;" title="<?=!empty($net['ip']) ? 'IP: ' . htmlspecialchars($net['ip']) : ''?>"><?=htmlspecialchars($net['cidr'])?></code>
                                    <?php else: ?>
                                        <span class="label label-default" style="font-size: 9px;"><?=gettext('Sem IPv4 / DHCP')?></span>
                                    <?php endif; ?>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php $on_c = count($net['online_hosts']); ?>
                                    <span class="badge" style="background-color: <?=$on_c > 0 ? '#5cb85c' : '#bbb'?>; font-size: 10px; font-weight: bold;">
                                        <?=$on_c?>
                                    </span>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php $blk_c = count($net['blocked_hosts']); ?>
                                    <span class="badge" style="background-color: <?=$blk_c > 0 ? '#d9534f' : '#bbb'?>; font-size: 10px; font-weight: bold;">
                                        <?=$blk_c?>
                                    </span>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php if ($net['block_count'] > 0): ?>
                                        <span class="label label-danger" style="font-size: 10px; font-weight: bold;">
                                            <?=number_format($net['block_count'], 0, ',', '.')?>
                                        </span>
                                    <?php else: ?>
                                        <span class="text-muted" style="font-size: 10px;">0</span>
                                    <?php endif; ?>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php $byp_c = count($net['bypass_hosts']); ?>
                                    <?php if ($byp_c > 0): ?>
                                        <span class="badge" style="background-color: #337ab7; font-size: 10px; font-weight: bold;">
                                            <?=$byp_c?>
                                        </span>
                                    <?php else: ?>
                                        <span class="text-muted" style="font-size: 10px;">-</span>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
                <tfoot>
                    <tr class="info" style="font-weight: bold; border-top: 2px solid #ddd;">
                        <td style="vertical-align: middle;"><?=gettext('Total Consolidado')?></td>
                        <td class="text-center" style="vertical-align: middle; font-size: 10px;">
                            <?=count($network_summary)?> <?=gettext('redes')?>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="badge" style="background-color: #449d44; font-size: 10px; font-weight: bold;">
                                <?=count($total_online_all)?>
                            </span>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="badge" style="background-color: #c9302c; font-size: 10px; font-weight: bold;">
                                <?=count($total_blocked_hosts_all)?>
                            </span>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="label label-danger" style="font-size: 10px; font-weight: bold;">
                                <?=number_format($total_block_events_all, 0, ',', '.')?>
                            </span>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="badge" style="background-color: #286090; font-size: 10px; font-weight: bold;">
                                <?=count($total_bypass_all)?>
                            </span>
                        </td>
                    </tr>
                </tfoot>
            </table>
        </div>
    </div>

    <!-- 4. Rodapé e Atalhos Rápidos -->
    <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; border-top: 1px solid #e5e5e5; padding-top: 8px; font-size: 11px;">
        <div style="display: flex; align-items: center; gap: 4px;">
            <i class="fa fa-lock text-muted"></i>
            <span class="text-muted"><?=gettext('Anti-Bypass DNS (Porta 53):')?></span>
            <strong>
                <?=function_exists('rules_wam_is_checked') && rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? null) 
                    ? '<span class="text-success"><i class="fa fa-check"></i> ' . gettext('Ativo') . '</span>' 
                    : '<span class="text-muted">' . gettext('Desativado') . '</span>'?>
            </strong>
        </div>

        <div style="display: flex; gap: 4px;">
            <a href="/rules_wam.php" class="btn btn-xs btn-default" title="<?=gettext('Configurações de Bloqueio, Horários e Bypass')?>">
                <i class="fa fa-cog"></i> <?=gettext('Configurações')?>
            </a>
            <a href="/rules_wam_status.php" class="btn btn-xs btn-default" title="<?=gettext('Testar domínios e diagnosticar Unbound')?>">
                <i class="fa fa-heartbeat"></i> <?=gettext('Status')?>
            </a>
            <a href="/rules_wam_dashboard.php" class="btn btn-xs btn-primary" title="<?=gettext('Ver tentativas detalhadas e exportar relatórios CSV/JSON')?>">
                <i class="fa fa-bar-chart"></i> <?=gettext('Auditoria')?>
            </a>
        </div>
    </div>

</div>

<?php
if ($is_ajax) {
    exit;
}
?>

<script type="text/javascript">
//<![CDATA[
function rules_wam_widget_refresh() {
    var icon = document.getElementById('rules_wam_refresh_icon');
    if (icon) {
        icon.className = 'fa fa-refresh fa-spin';
    }

    if (typeof $ !== 'undefined') {
        $.ajax({
            url: '/widgets/widgets/rules_wam.widget.php?ajax=rules_wam&widgetkey=<?=urlencode($widgetkey)?>',
            type: 'GET',
            cache: false,
            success: function(response) {
                var container = $('#rules_wam_widget_container');
                if (container.length && response) {
                    container.replaceWith(response);
                }
            },
            complete: function() {
                var iconDone = document.getElementById('rules_wam_refresh_icon');
                if (iconDone) {
                    iconDone.className = 'fa fa-refresh';
                }
            }
        });
    }
}

// Auto-atualização periódica a cada 60 segundos
if (typeof rules_wam_auto_timer !== 'undefined') {
    clearInterval(rules_wam_auto_timer);
}
var rules_wam_auto_timer = setInterval(function() {
    if (document.getElementById('rules_wam_widget_container')) {
        rules_wam_widget_refresh();
    } else {
        clearInterval(rules_wam_auto_timer);
    }
}, 60000);
//]]>
</script>

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
    echo "   ✓ Rules WAM e Unbound sincronizados com sucesso
";
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
