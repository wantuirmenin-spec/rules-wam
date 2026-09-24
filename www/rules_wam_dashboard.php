<?php
/*
 * rules_wam_dashboard.php
 * Rules WAM - Web Access Manager para pfSense
 * Painel de Auditoria, Tentativas de Acesso e Exportação (CSV/JSON)
 */

require_once("guiconfig.inc");
require_once("/usr/local/pkg/rules_wam.inc");

// 1. Exportação CSV de Registros de Bloqueio (Excel) - Sem limites (Todos, Online ou Offline)
if (isset($_GET['export']) && ($_GET['export'] === 'csv' || $_GET['export'] === 'csv_all')) {
    @ini_set('memory_limit', '512M');
    @set_time_limit(300);

    $status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
    if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
        $status_filter = 'all';
    }
    // 0 = sem limites, extrai 100% dos eventos registrados
    $events = rules_wam_get_audit_events(0);

    if ($status_filter === 'online') {
        $events = array_values(array_filter($events, function($ev) {
            return !empty($ev['online']);
        }));
        $filename = "relatorio_bloqueios_online_rules_wam_" . date('Y-m-d_His') . ".csv";
    } elseif ($status_filter === 'offline') {
        $events = array_values(array_filter($events, function($ev) {
            return empty($ev['online']);
        }));
        $filename = "relatorio_bloqueios_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    } else {
        $filename = "relatorio_bloqueios_todos_online_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    }

    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    // BOM UTF-8 para o Excel abrir com acentuação correta
    echo "\xEF\xBB\xBF";

    $output = fopen('php://output', 'w');
    fputcsv($output, array('Data e Hora', 'Endereco IP', 'Hostname', 'Status na Rede', 'Interface pfSense', 'Dominio Bloqueado', 'Categoria', 'Acao Realizada'), ';');

    foreach ($events as $ev) {
        $status_txt = !empty($ev['online']) ? 'Online' : 'Offline';
        $ev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($ev['ip']) : null;
        $if_name = !empty($ev_if['descr']) ? $ev_if['descr'] : (!empty($ev_if['logical_id']) ? $ev_if['logical_id'] : 'Local');
        if (!empty($ev_if['key']) && $ev_if['key'] === 'wan') {
            if (empty($if_name) || (!empty($ev_if['real_if']) && strcasecmp($if_name, $ev_if['real_if']) === 0)) {
                $if_name = 'WAN';
            }
        }
        fputcsv($output, array(
            $ev['timestamp'],
            $ev['ip'],
            $ev['hostname'],
            $status_txt,
            $if_name,
            $ev['domain'],
            $ev['category'],
            'BLOQUEADO (0.0.0.0)'
        ), ';');
    }

    fclose($output);
    exit;
}

// 2. Exportação CSV do Resumo de Dispositivos (Online e Offline)
if (isset($_GET['export']) && $_GET['export'] === 'csv_devices') {
    @ini_set('memory_limit', '512M');
    @set_time_limit(300);

    $status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
    if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
        $status_filter = 'all';
    }
    $events = rules_wam_get_audit_events(0);

    $devices = array();
    foreach ($events as $ev) {
        $ip = $ev['ip'];
        $dom = $ev['domain'];
        $cat = $ev['category'];
        $is_online = !empty($ev['online']);

        if (!isset($devices[$ip])) {
            $devices[$ip] = array(
                'ip' => $ip,
                'hostname' => $ev['hostname'],
                'online' => $is_online,
                'status_label' => $is_online ? 'Online' : 'Offline',
                'mac' => rules_wam_get_host_mac($ip),
                'count' => 0,
                'domains' => array(),
                'categories' => array(),
                'last_time' => $ev['timestamp'],
                'last_domain' => $dom
            );
        }
        $devices[$ip]['count']++;
        $devices[$ip]['domains'][$dom] = ($devices[$ip]['domains'][$dom] ?? 0) + 1;
        $devices[$ip]['categories'][$cat] = ($devices[$ip]['categories'][$cat] ?? 0) + 1;
        $devices[$ip]['online'] = $is_online;
        $devices[$ip]['status_label'] = $is_online ? 'Online' : 'Offline';
    }

    uasort($devices, function($a, $b) {
        return $b['count'] <=> $a['count'];
    });

    if ($status_filter === 'online') {
        $devices = array_filter($devices, function($dev) { return !empty($dev['online']); });
        $filename = "relatorio_dispositivos_online_rules_wam_" . date('Y-m-d_His') . ".csv";
    } elseif ($status_filter === 'offline') {
        $devices = array_filter($devices, function($dev) { return empty($dev['online']); });
        $filename = "relatorio_dispositivos_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    } else {
        $filename = "relatorio_dispositivos_online_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    }

    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    echo "\xEF\xBB\xBF";
    $output = fopen('php://output', 'w');
    fputcsv($output, array('Endereco IP', 'Hostname', 'Status na Rede', 'Interface pfSense', 'MAC Address', 'Total de Tentativas', 'Categoria Mais Frequente', 'Ultimo Dominio Barrado', 'Data Ultima Tentativa'), ';');

    foreach ($devices as $dev) {
        arsort($dev['categories']);
        $top_c = key($dev['categories']);
        $dev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($dev['ip']) : null;
        $if_name = !empty($dev_if['descr']) ? $dev_if['descr'] : (!empty($dev_if['logical_id']) ? $dev_if['logical_id'] : 'Local');
        if (!empty($dev_if['key']) && $dev_if['key'] === 'wan') {
            if (empty($if_name) || (!empty($dev_if['real_if']) && strcasecmp($if_name, $dev_if['real_if']) === 0)) {
                $if_name = 'WAN';
            }
        }
        fputcsv($output, array(
            $dev['ip'],
            $dev['hostname'],
            $dev['status_label'],
            $if_name,
            !empty($dev['mac']) ? $dev['mac'] : 'N/A',
            $dev['count'],
            $top_c,
            $dev['last_domain'],
            $dev['last_time']
        ), ';');
    }

    fclose($output);
    exit;
}

// 3. Exportação JSON (Todos os Registros com Status)
if (isset($_GET['export']) && $_GET['export'] === 'json') {
    @ini_set('memory_limit', '512M');
    @set_time_limit(300);

    $status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
    if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
        $status_filter = 'all';
    }
    $events = rules_wam_get_audit_events(0);

    if ($status_filter === 'online') {
        $events = array_values(array_filter($events, function($ev) { return !empty($ev['online']); }));
    } elseif ($status_filter === 'offline') {
        $events = array_values(array_filter($events, function($ev) { return empty($ev['online']); }));
    }

    $online_cnt = 0;
    $offline_cnt = 0;
    foreach ($events as $ev) {
        if (!empty($ev['online'])) $online_cnt++; else $offline_cnt++;
    }

    $filename = "relatorio_bloqueios_rules_wam_" . date('Y-m-d_His') . ".json";

    header('Content-Type: application/json; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    echo json_encode(array(
        'generated_at' => date('Y-m-d H:i:s'),
        'filter' => $status_filter,
        'total_events' => count($events),
        'online_events' => $online_cnt,
        'offline_events' => $offline_cnt,
        'events' => $events
    ), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// 3. Simulação de Teste Direto na Dashboard
$alert_msg = null;
if (isset($_POST['simulate_test_domain'])) {
    $s_dom = rules_wam_clean_domain($_POST['simulate_test_domain'] ?? '');
    if (!empty($s_dom)) {
        $client_ip = !empty($_POST['simulate_ip']) ? trim($_POST['simulate_ip']) : (!empty($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1');
        $cat = rules_wam_get_domain_category($s_dom);
        $entry = date('M d H:i:s') . '|' . $client_ip . '|' . $s_dom . '|' . $cat . "\n";
        @file_put_contents(WAM_AUDIT_LOG, $entry, FILE_APPEND);
        $alert_msg = "Tentativa de acesso a '{$s_dom}' registrada no log para o IP {$client_ip}!";
    }
}

// 4. Limpeza de Logs
if (isset($_POST['clear_audit_logs'])) {
    if (file_exists(WAM_AUDIT_LOG)) {
        @file_put_contents(WAM_AUDIT_LOG, '');
    }
    $alert_msg = "Histórico de auditoria do Rules WAM foi limpo com sucesso!";
}

$pgtitle = array(gettext("Services"), gettext("Rules WAM"), gettext("Dashboard & Auditoria"));
include("head.inc");

$tab_array = array();
$tab_array[] = array(gettext("Configurações de Bloqueio"), false, "/rules_wam.php");
$tab_array[] = array(gettext("Status & Teste de Bloqueio"), false, "/rules_wam_status.php");
$tab_array[] = array(gettext("Dashboard & Tentativas de Acesso"), true, "/rules_wam_dashboard.php");
$tab_array[] = array(gettext("Banner de Bloqueio (Prévia)"), false, "/rules_wam_block.php");
display_top_tabs($tab_array);

// Carrega eventos auditados recentes para visualização na tela
$all_events = rules_wam_get_audit_events(2000);

// Informações do Host Atual conectado à WebGUI
$current_client_ip = !empty($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1';
$cache_hn = array();
$current_client_hostname = rules_wam_resolve_hostname($current_client_ip, $cache_hn);
$wam_cfg = rules_wam_get_config();

$is_current_in_bypass = false;
if (!empty($wam_cfg['bypass_ips'])) {
    $raw_ips = preg_split('/[\r\n,;]+/', $wam_cfg['bypass_ips']);
    foreach ($raw_ips as $rip) {
        $rip = trim($rip);
        if ($rip === $current_client_ip || strpos($rip, $current_client_ip) !== false) {
            $is_current_in_bypass = true;
            break;
        }
    }
}

// Agrupamento geral por IP/Dispositivo
$by_device = array();
$by_domain = array();

foreach ($all_events as $ev) {
    $ip = $ev['ip'];
    $dom = $ev['domain'];
    $cat = $ev['category'];
    $is_online = !empty($ev['online']);

    if (!isset($by_device[$ip])) {
        $by_device[$ip] = array(
            'ip' => $ip,
            'hostname' => $ev['hostname'],
            'online' => $is_online,
            'status_label' => $is_online ? 'Online' : 'Offline',
            'mac' => rules_wam_get_host_mac($ip),
            'count' => 0,
            'domains' => array(),
            'categories' => array(),
            'last_time' => $ev['timestamp'],
            'last_domain' => $dom
        );
    }
    $by_device[$ip]['count']++;
    $by_device[$ip]['domains'][$dom] = ($by_device[$ip]['domains'][$dom] ?? 0) + 1;
    $by_device[$ip]['categories'][$cat] = ($by_device[$ip]['categories'][$cat] ?? 0) + 1;
    $by_device[$ip]['online'] = $is_online;
    $by_device[$ip]['status_label'] = $is_online ? 'Online' : 'Offline';

    if (!isset($by_domain[$dom])) {
        $by_domain[$dom] = array(
            'domain' => $dom,
            'category' => $cat,
            'count' => 0,
            'last_time' => $ev['timestamp']
        );
    }
    $by_domain[$dom]['count']++;
}

// Ordena dispositivos por mais tentativas (Top Offender)
uasort($by_device, function($a, $b) {
    return $b['count'] <=> $a['count'];
});

// Ordena domínios mais tentados
uasort($by_domain, function($a, $b) {
    return $b['count'] <=> $a['count'];
});

// Estatísticas globais
$total_blocks = count($all_events);
$total_devices = count($by_device);

$count_online_devices = 0;
$count_offline_devices = 0;
foreach ($by_device as $dev) {
    if (!empty($dev['online'])) $count_online_devices++; else $count_offline_devices++;
}

$count_online_events = 0;
$count_offline_events = 0;
foreach ($all_events as $ev) {
    if (!empty($ev['online'])) $count_online_events++; else $count_offline_events++;
}

$top_domain_item = !empty($by_domain) ? reset($by_domain) : null;
$top_device_item = !empty($by_device) ? reset($by_device) : null;

$current_host_stats = $by_device[$current_client_ip] ?? null;
$current_host_blocks = $current_host_stats ? $current_host_stats['count'] : 0;

// Filtro selecionado na interface
$status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
    $status_filter = 'all';
}

if ($status_filter === 'online') {
    $display_events = array_values(array_filter($all_events, function($ev) { return !empty($ev['online']); }));
    $display_devices = array_filter($by_device, function($dev) { return !empty($dev['online']); });
} elseif ($status_filter === 'offline') {
    $display_events = array_values(array_filter($all_events, function($ev) { return empty($ev['online']); }));
    $display_devices = array_filter($by_device, function($dev) { return empty($dev['online']); });
} else {
    $display_events = $all_events;
    $display_devices = $by_device;
}
?>

<?php if ($alert_msg): ?>
    <div class="alert alert-success alert-dismissible" role="alert">
        <button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span></button>
        <i class="fa fa-check-circle"></i> <strong><?=htmlspecialchars($alert_msg)?></strong>
    </div>
<?php endif; ?>

<!-- Barra de Ações e Exportação Completa -->
<div style="margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
    <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
        <!-- Grupo de Exportação CSV Geral (Sem Limites) -->
        <div class="btn-group">
            <a href="/rules_wam_dashboard.php?export=csv&status=all" class="btn btn-success" title="<?=gettext("Exporta todos os registros (online e offline) em CSV/Excel sem limite de linhas")?>">
                <i class="fa fa-file-excel-o"></i> <strong><?=gettext("Exportar Todos os Registros (CSV)")?></strong>
            </a>
            <button type="button" class="btn btn-success dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                <span class="caret"></span>
                <span class="sr-only">Opções de Exportação</span>
            </button>
            <ul class="dropdown-menu">
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv&status=all">
                        <i class="fa fa-database text-primary"></i> <strong><?=gettext("Todos os Registros (Online & Offline)")?></strong>
                    </a>
                </li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv&status=online">
                        <i class="fa fa-circle text-success"></i> <?=gettext("Apenas Registros de Hosts Online (CSV)")?>
                    </a>
                </li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv&status=offline">
                        <i class="fa fa-circle-o text-muted"></i> <?=gettext("Apenas Registros de Hosts Offline (CSV)")?>
                    </a>
                </li>
                <li role="separator" class="divider"></li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv_devices">
                        <i class="fa fa-desktop text-info"></i> <?=gettext("Exportar Lista de Dispositivos (Online & Offline)")?>
                    </a>
                </li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=json">
                        <i class="fa fa-code text-warning"></i> <?=gettext("Exportar Todos os Registros (JSON)")?>
                    </a>
                </li>
            </ul>
        </div>

        <a href="/rules_wam_dashboard.php?export=csv_devices" class="btn btn-primary" title="<?=gettext("Exporta resumo consolidado de dispositivos e seu status na rede")?>">
            <i class="fa fa-desktop"></i> <?=gettext("Exportar Dispositivos (CSV)")?>
        </a>

        <a href="/rules_wam_block.php" target="_blank" class="btn btn-warning">
            <i class="fa fa-shield"></i> <?=gettext("Ver Banner de Bloqueio")?>
        </a>
        <a href="/rules_wam_dashboard.php" class="btn btn-info">
            <i class="fa fa-refresh"></i> <?=gettext("Atualizar")?>
        </a>
    </div>

    <div>
        <form action="/rules_wam_dashboard.php" method="post" style="display: inline;" onsubmit="return confirm('Deseja realmente limpar o histórico de tentativas gravado?');">
            <input type="hidden" name="clear_audit_logs" value="1" />
            <button type="submit" class="btn btn-danger btn-sm">
                <i class="fa fa-trash"></i> <?=gettext("Limpar Histórico")?>
            </button>
        </form>
    </div>
</div>

<!-- Informações do Host Atual Conectado -->
<div class="panel panel-default" style="border-left: 5px solid #337ab7; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
    <div class="panel-body" style="padding: 15px 20px;">
        <div class="row" style="display: flex; align-items: center; flex-wrap: wrap; gap: 15px 0;">
            <div class="col-sm-4">
                <h4 style="margin: 0 0 5px 0; color: #337ab7; font-size: 15px;">
                    <i class="fa fa-laptop"></i> <strong><?=gettext("Seu Host Atual (Sessão Conectada)")?></strong>
                </h4>
                <div style="font-size: 14px; margin-top: 4px;">
                    <strong>IP:</strong> <span class="label label-primary" style="font-size: 13px;"><?=htmlspecialchars($current_client_ip)?></span>
                    &nbsp;&nbsp;
                    <strong>Host:</strong> <code style="font-size: 13px;"><?=htmlspecialchars($current_client_hostname)?></code>
                    &nbsp;&nbsp;
                    <span class="label label-success" style="font-size: 11px;"><i class="fa fa-circle"></i> Online</span>
                </div>
            </div>

            <div class="col-sm-4 text-center">
                <span class="text-muted" style="font-size: 12px; text-transform: uppercase; font-weight: 600; display: block; margin-bottom: 4px;">
                    <?=gettext("Status de Filtragem")?>
                </span>
                <?php if ($is_current_in_bypass): ?>
                    <span class="label label-warning" style="font-size: 13px; padding: 5px 10px;">
                        <i class="fa fa-unlock"></i> <?=gettext("Isento de Bloqueios (Bypass IP Ativo)")?>
                    </span>
                <?php else: ?>
                    <span class="label label-success" style="font-size: 13px; padding: 5px 10px;">
                        <i class="fa fa-shield"></i> <?=gettext("Proteção Ativa (Sujeito às Regras)")?>
                    </span>
                <?php endif; ?>
            </div>

            <div class="col-sm-4 text-right">
                <span class="text-muted" style="font-size: 12px; text-transform: uppercase; font-weight: 600; display: block; margin-bottom: 4px;">
                    <?=gettext("Tentativas Registradas Deste Host")?>
                </span>
                <span class="badge" style="font-size: 14px; background-color: <?=$current_host_blocks > 0 ? '#d9534f' : '#5cb85c'?>; padding: 5px 10px;">
                    <?=number_format($current_host_blocks)?> <?=gettext("bloqueios")?>
                </span>
                <?php if ($current_host_stats): ?>
                    <div style="font-size: 11.5px; color: #777; margin-top: 3px;">
                        <?=gettext("Último:")?> <strong class="text-danger"><?=htmlspecialchars($current_host_stats['last_domain'])?></strong> (<?=htmlspecialchars($current_host_stats['last_time'])?>)
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>

<!-- KPIs / Cartões no Topo -->
<div class="row">
    <div class="col-sm-3">
        <div class="panel panel-danger text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-shield"></i> <?=gettext("TENTATIVAS BLOQUEADAS")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 32px; font-weight: bold; color: #a94442;"><?=number_format($total_blocks)?></span>
                <div style="font-size: 12px; margin-top: 5px;">
                    <span class="text-success" style="font-weight: 600;"><i class="fa fa-circle"></i> <?=$count_online_events?> Online</span>
                    &nbsp;|&nbsp;
                    <span class="text-muted" style="font-weight: 600;"><i class="fa fa-circle-o"></i> <?=$count_offline_events?> Offline</span>
                </div>
            </div>
        </div>
    </div>

    <div class="col-sm-3">
        <div class="panel panel-primary text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-desktop"></i> <?=gettext("MÁQUINAS / DISPOSITIVOS")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 32px; font-weight: bold; color: #337ab7;"><?=number_format($total_devices)?></span>
                <div style="font-size: 12px; margin-top: 5px;">
                    <span class="text-success" style="font-weight: 600;"><i class="fa fa-circle"></i> <?=$count_online_devices?> Online</span>
                    &nbsp;|&nbsp;
                    <span class="text-muted" style="font-weight: 600;"><i class="fa fa-circle-o"></i> <?=$count_offline_devices?> Offline</span>
                </div>
            </div>
        </div>
    </div>

    <div class="col-sm-3">
        <div class="panel panel-warning text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-globe"></i> <?=gettext("TOP SITE BLOQUEADO")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 18px; font-weight: bold; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    <?=$top_domain_item ? htmlspecialchars($top_domain_item['domain']) : 'Nenhum'?>
                </span>
                <p class="text-muted" style="margin: 0;">
                    <?=$top_domain_item ? number_format($top_domain_item['count']) . ' tentativas' : 'Aguardando tráfego'?>
                </p>
            </div>
        </div>
    </div>

    <div class="col-sm-3">
        <div class="panel panel-info text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-user"></i> <?=gettext("TOP DISPOSITIVO INFRATOR")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 18px; font-weight: bold; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    <?=$top_device_item ? htmlspecialchars($top_device_item['hostname']) : 'Nenhum'?>
                </span>
                <p class="text-muted" style="margin: 0;">
                    <?=$top_device_item ? htmlspecialchars($top_device_item['ip']) . ' (' . $top_device_item['count'] . 'x)' : 'Sem bloqueios'?>
                </p>
            </div>
        </div>
    </div>
</div>

<!-- Barra de Simulação Rápida / Teste -->
<div class="panel panel-default" style="margin-bottom: 20px;">
    <div class="panel-body" style="padding: 12px;">
        <form action="/rules_wam_dashboard.php" method="post" class="form-inline" style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
            <span style="font-weight: bold;"><i class="fa fa-crosshairs"></i> <?=gettext("Simular/Testar Registro de Tentativa:")?></span>
            <input type="text" name="simulate_ip" class="form-control" style="width: 150px;" placeholder="IP (ex: 172.24.60.111)" value="<?=htmlspecialchars($current_client_ip)?>" title="IP do host a registrar" />
            <input type="text" name="simulate_test_domain" class="form-control" style="min-width: 250px;" placeholder="Domínio (ex: betano.com, xvideo.com)" required />
            <button type="submit" class="btn btn-warning"><i class="fa fa-bolt"></i> <?=gettext("Registrar Tentativa Agora")?></button>
            <span class="text-muted" style="font-size: 12px;"><?=gettext("(Grava imediatamente no log com o IP informado e atualiza a auditoria)")?></span>
        </form>
    </div>
</div>

<!-- Filtro de Visualização: Todos / Online / Offline -->
<div style="margin-bottom: 15px;">
    <ul class="nav nav-pills" style="font-weight: bold;">
        <li role="presentation" class="<?=$status_filter === 'all' ? 'active' : ''?>">
            <a href="/rules_wam_dashboard.php?status=all"><i class="fa fa-list"></i> <?=gettext("Todos os Registros")?> <span class="badge"><?=$total_blocks?></span></a>
        </li>
        <li role="presentation" class="<?=$status_filter === 'online' ? 'active' : ''?>">
            <a href="/rules_wam_dashboard.php?status=online" style="<?=$status_filter !== 'online' ? 'color: #3c763d;' : ''?>"><i class="fa fa-circle text-success"></i> <?=gettext("Apenas Hosts Online")?> <span class="badge"><?=$count_online_events?></span></a>
        </li>
        <li role="presentation" class="<?=$status_filter === 'offline' ? 'active' : ''?>">
            <a href="/rules_wam_dashboard.php?status=offline" style="<?=$status_filter !== 'offline' ? 'color: #777;' : ''?>"><i class="fa fa-circle-o text-muted"></i> <?=gettext("Apenas Hosts Offline")?> <span class="badge"><?=$count_offline_events?></span></a>
        </li>
    </ul>
</div>

<!-- Tabela 1: Resumo Agrupado por Dispositivo -->
<div class="panel panel-default">
    <div class="panel-heading" style="display: flex; justify-content: space-between; align-items: center;">
        <h2 class="panel-title"><i class="fa fa-users"></i> <?=gettext("Tentativas de Acesso por Dispositivo (Auditoria por IP, Hostname & Presença na Rede)")?></h2>
        <div>
            <a href="/rules_wam_dashboard.php?export=csv_devices&amp;status=<?=htmlspecialchars($status_filter, ENT_QUOTES, 'UTF-8')?>" class="btn btn-default btn-xs" title="<?=gettext("Exportar lista de dispositivos para CSV")?>">
                <i class="fa fa-download"></i> <?=gettext("Exportar Dispositivos (CSV)")?>
            </a>
        </div>
    </div>
    <div class="table-responsive">
        <table class="table table-striped table-hover table-condensed">
            <thead>
                <tr>
                    <th style="width: 110px;"><?=gettext("Status na Rede")?></th>
                    <th><?=gettext("Endereço IP")?></th>
                    <th><?=gettext("Interface / Rede")?></th>
                    <th><?=gettext("Hostname / Nome da Máquina")?></th>
                    <th><?=gettext("MAC Address")?></th>
                    <th class="text-center"><?=gettext("Total de Tentativas")?></th>
                    <th><?=gettext("Categoria Mais Tentada")?></th>
                    <th><?=gettext("Último Domínio Barrado")?></th>
                    <th><?=gettext("Última Tentativa")?></th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($display_devices)): ?>
                    <tr>
                        <td colspan="9" class="text-center text-muted" style="padding: 30px;">
                            <i class="fa fa-info-circle fa-2x"></i><br />
                            <?=gettext("Nenhum dispositivo encontrado para o filtro selecionado.")?>
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($display_devices as $dev): 
                        arsort($dev['categories']);
                        $top_cat = key($dev['categories']);
                        $is_me = ($dev['ip'] === $current_client_ip);
                        $is_on = !empty($dev['online']);
                        $dev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($dev['ip']) : null;
                        $dev_if_name = !empty($dev_if['descr']) ? $dev_if['descr'] : (!empty($dev_if['logical_id']) ? $dev_if['logical_id'] : 'Rede Local');
                        if (!empty($dev_if['key']) && $dev_if['key'] === 'wan') {
                            if (empty($dev_if_name) || (!empty($dev_if['real_if']) && strcasecmp($dev_if_name, $dev_if['real_if']) === 0)) {
                                $dev_if_name = 'WAN';
                            }
                        }
                    ?>
                    <tr <?=$is_me ? 'class="info" style="background-color: #eef7fe;"' : ''?>>
                        <td>
                            <?php if ($is_on): ?>
                                <span class="label label-success" style="font-size: 11px; padding: 4px 7px;"><i class="fa fa-circle"></i> Online</span>
                            <?php else: ?>
                                <span class="label label-default" style="font-size: 11px; padding: 4px 7px; color: #666;"><i class="fa fa-circle-o"></i> Offline</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <code><?=htmlspecialchars($dev['ip'])?></code>
                            <?php if ($is_me): ?>
                                <span class="label label-primary" style="margin-left: 5px;"><i class="fa fa-user"></i> <?=gettext("Seu Host")?></span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <span class="label label-primary" style="font-size: 11px;" title="<?=!empty($dev_if['real_if']) ? htmlspecialchars($dev_if['logical_id'] . ' / ' . $dev_if['real_if']) : ''?>">
                                <i class="fa fa-sitemap"></i> <?=htmlspecialchars($dev_if_name)?>
                            </span>
                        </td>
                        <td><strong><i class="fa fa-laptop"></i> <?=htmlspecialchars($dev['hostname'])?></strong></td>
                        <td><code style="font-size: 11px;"><?=!empty($dev['mac']) ? htmlspecialchars($dev['mac']) : '—'?></code></td>
                        <td class="text-center">
                            <span class="badge" style="background-color: #d9534f; font-size: 13px;">
                                <?=number_format($dev['count'])?> vezes
                            </span>
                        </td>
                        <td><span class="label label-warning"><?=htmlspecialchars($top_cat)?></span></td>
                        <td><code><?=htmlspecialchars($dev['last_domain'])?></code></td>
                        <td><i class="fa fa-clock-o text-muted"></i> <?=htmlspecialchars($dev['last_time'])?></td>
                    </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<!-- Tabela 2: Registro Detalhado dos Últimos Bloqueios -->
<div class="panel panel-default">
    <div class="panel-heading" style="display: flex; justify-content: space-between; align-items: center;">
        <h2 class="panel-title"><i class="fa fa-list"></i> <?=gettext("Registro Detalhado dos Últimos Bloqueios (Tempo Real)")?></h2>
        <div>
            <a href="/rules_wam_dashboard.php?export=csv&amp;status=<?=htmlspecialchars($status_filter, ENT_QUOTES, 'UTF-8')?>" class="btn btn-default btn-xs" title="<?=gettext("Exportar registros para CSV")?>">
                <i class="fa fa-download"></i> <?=gettext("Exportar Registros (CSV)")?>
            </a>
        </div>
    </div>
    <div class="table-responsive">
        <table class="table table-striped table-hover table-condensed">
            <thead>
                <tr>
                    <th><?=gettext("Data / Hora")?></th>
                    <th><?=gettext("Endereço IP")?></th>
                    <th><?=gettext("Interface")?></th>
                    <th><?=gettext("Hostname")?></th>
                    <th style="width: 100px;"><?=gettext("Status")?></th>
                    <th><?=gettext("Domínio Bloqueado")?></th>
                    <th><?=gettext("Categoria")?></th>
                    <th><?=gettext("Ação do Firewall")?></th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($display_events)): ?>
                    <tr>
                        <td colspan="8" class="text-center text-muted" style="padding: 20px;">
                            <?=gettext("Nenhum registro encontrado para o filtro selecionado.")?>
                        </td>
                    </tr>
                <?php else: ?>
                    <?php 
                    $slice = array_slice($display_events, 0, 150);
                    foreach ($slice as $ev): 
                        $is_me = ($ev['ip'] === $current_client_ip);
                        $is_on = !empty($ev['online']);
                        $ev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($ev['ip']) : null;
                        $ev_if_name = !empty($ev_if['descr']) ? $ev_if['descr'] : (!empty($ev_if['logical_id']) ? $ev_if['logical_id'] : 'Local');
                        if (!empty($ev_if['key']) && $ev_if['key'] === 'wan') {
                            if (empty($ev_if_name) || (!empty($ev_if['real_if']) && strcasecmp($ev_if_name, $ev_if['real_if']) === 0)) {
                                $ev_if_name = 'WAN';
                            }
                        }
                    ?>
                    <tr <?=$is_me ? 'style="background-color: #eef7fe;"' : ''?>>
                        <td><i class="fa fa-clock-o text-muted"></i> <?=htmlspecialchars($ev['timestamp'])?></td>
                        <td>
                            <code><?=htmlspecialchars($ev['ip'])?></code>
                            <?php if ($is_me): ?>
                                <span class="label label-info" style="font-size: 10px; margin-left: 3px;"><?=gettext("Você")?></span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <span class="label label-default" style="font-size: 10px;" title="<?=!empty($ev_if['real_if']) ? htmlspecialchars($ev_if['logical_id'] . ' / ' . $ev_if['real_if']) : ''?>">
                                <?=htmlspecialchars($ev_if_name)?>
                            </span>
                        </td>
                        <td><strong><?=htmlspecialchars($ev['hostname'])?></strong></td>
                        <td>
                            <?php if ($is_on): ?>
                                <span class="label label-success" style="font-size: 10px;"><i class="fa fa-circle"></i> Online</span>
                            <?php else: ?>
                                <span class="label label-default" style="font-size: 10px; color: #666;"><i class="fa fa-circle-o"></i> Offline</span>
                            <?php endif; ?>
                        </td>
                        <td><strong class="text-danger"><?=htmlspecialchars($ev['domain'])?></strong></td>
                        <td><span class="label label-default"><?=htmlspecialchars($ev['category'])?></span></td>
                        <td><span class="label label-danger"><i class="fa fa-ban"></i> <?=gettext("BLOQUEADO")?></span></td>
                    </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php include("foot.inc"); ?>
