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
