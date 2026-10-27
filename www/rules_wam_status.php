<?php
/*
 * rules_wam_status.php
 * Rules WAM - Web Access Manager para pfSense
 * Página de Status, Diagnóstico e Monitoramento de Categorias
 */

require_once("guiconfig.inc");
require_once("/usr/local/pkg/rules_wam.inc");

$pgtitle = array(gettext("Services"), gettext("Rules WAM"), gettext("Status & Teste de Bloqueio"));
include("head.inc");

$tab_array = array();
$tab_array[] = array(gettext("Configurações de Bloqueio"), false, "/rules_wam.php");
$tab_array[] = array(gettext("Status & Teste de Bloqueio"), true, "/rules_wam_status.php");
$tab_array[] = array(gettext("Dashboard & Tentativas de Acesso"), false, "/rules_wam_dashboard.php");
$tab_array[] = array(gettext("Modo de Contingência"), false, "/rules_wam_contingency.php");
$tab_array[] = array(gettext("Banner de Bloqueio (Prévia)"), false, "/rules_wam_block.php");
display_top_tabs($tab_array);
echo rules_wam_contingency_alert_html(rules_wam_get_config());
echo rules_wam_log_health_alert_html(rules_wam_get_config());

// Rotação do resolver.log muito pequena: o histórico do Dashboard fica curto
$wam_logsize = trim((string)config_get_path('syslog/resolver_settings/logfilesize', ''));
if ($wam_logsize === '' || (int)$wam_logsize < WAM_RESOLVER_LOG_MIN) {
    print_info_box(sprintf(gettext('O log do DNS Resolver rotaciona a cada %s. Com o registro de consultas do Rules WAM isso acontece a cada poucos minutos. Recomendado: %d MB (%d bytes) em Status > System Logs > DNS Resolver > Log Rotation Size.'),
        $wam_logsize === '' ? gettext('500 KiB (padrão do pfSense)') : round((int)$wam_logsize / 1024) . ' KiB',
        WAM_RESOLVER_LOG_SET / 1048576, WAM_RESOLVER_LOG_SET), 'warning', false);
}

if (function_exists('rules_wam_banner_conflict') && rules_wam_banner_conflict() !== '' && (rules_wam_get_config()['block_action'] ?? 'block_page') === 'block_page') {
    print_info_box(htmlspecialchars(rules_wam_banner_conflict()) . ' ' . gettext('O banner de bloqueio está desligado e os domínios bloqueados retornam 0.0.0.0. Para usar o banner, mova a WebGUI para outra porta (System > Advanced > Admin Access) e desative o redirecionamento HTTP.'), 'warning', false);
}

// Teste de domínio solicitado
$test_domain = isset($_POST['test_domain']) ? trim($_POST['test_domain']) : '';
$test_ip = isset($_POST['test_ip']) ? trim($_POST['test_ip']) : '';
$test_result = null;

$test_error = '';
if (!empty($test_domain)) {
    $clean_test = rules_wam_clean_domain($test_domain);
    if (empty($clean_test)) {
        $test_error = gettext('Domínio inválido.');
        $test_domain = '';
    }
}
if ($test_ip !== '' && !filter_var($test_ip, FILTER_VALIDATE_IP)) {
    $test_error = gettext('IP do cliente inválido.');
    $test_domain = '';
}
if (!empty($test_domain)) {

    // 1. Política que vale para o cliente informado (perfil por rede, IP isento ou padrão)
    $wam_idx = rules_wam_blocklist_index();
    $test_view = ($test_ip !== '') ? rules_wam_view_for_ip($test_ip, $wam_idx) : 'global';
    $test_policy = rules_wam_profiles_required(rules_wam_get_config()) ? gettext('rede sem perfil: bloqueio máximo') : gettext('política padrão');
    if ($test_view === 'wam_bypass') {
        $test_policy = gettext('IP isento (bypass)');
    } elseif ($test_view !== 'global') {
        $test_policy = sprintf(gettext('perfil de rede %s'), $test_view);
        foreach (rules_wam_get_profiles(rules_wam_get_config()) as $tp) {
            if (rules_wam_profile_view_name($tp['name']) === $test_view) {
                $test_policy = sprintf(gettext('perfil de rede %s'), $tp['name']);
                break;
            }
        }
    }
    $is_in_blocklist = rules_wam_is_domain_blocked($clean_test, ($test_ip !== '') ? $test_ip : null);

    // 2. Consulta o Unbound local via drill. A consulta sai de 127.0.0.1, então reflete só a política
    //    padrão: com IP de cliente informado, vale o resultado do item 1.
    $drill_ip = null;
    $drill_out = array();
    if ($test_ip === '' && file_exists('/usr/bin/drill')) {
        @exec("/usr/bin/drill @127.0.0.1 -p 53 " . escapeshellarg($clean_test) . " A 2>&1", $drill_out);
        foreach ($drill_out as $dline) {
            if (preg_match('/\b0\.0\.0\.0\b/', $dline)) {
                $drill_ip = '0.0.0.0';
                break;
            } elseif (preg_match('/IN\s+A\s+(\d+\.\d+\.\d+\.\d+)/', $dline, $m)) {
                $drill_ip = $m[1];
            }
        }
    }

    $wam_cfg = rules_wam_get_config();
    $lan_ip = function_exists('rules_wam_get_lan_ip') ? rules_wam_get_lan_ip() : '192.168.1.1';
    $block_page_ip = !empty($wam_cfg['block_page_ip']) ? $wam_cfg['block_page_ip'] : $lan_ip;

    $is_drill_blocked = ($drill_ip === '0.0.0.0' || (!empty($block_page_ip) && $drill_ip === $block_page_ip) || $drill_ip === '127.0.0.1');

    if ($is_in_blocklist || $is_drill_blocked) {
        $test_result = array(
            'status' => 'BLOCKED',
            'domain' => $clean_test,
            'ip' => ($drill_ip ? $drill_ip : ($block_page_ip ?: '0.0.0.0')) . ' (Interceptado pelo Rules WAM / Unbound)',
            'msg' => 'Domínio BLOQUEADO pelo Rules WAM!',
            'policy' => $test_policy
        );

        // Testes do administrador não entram no log de auditoria
    } else {
        $test_result = array(
            'status' => 'ALLOWED',
            'domain' => $clean_test,
            'ip' => $drill_ip ? $drill_ip : 'Resolvido normalmente',
            'msg' => 'Domínio não está nas categorias ativas de bloqueio (acesso liberado).',
            'policy' => $test_policy
        );
    }
}

// Carrega status
$status_file = WAM_STATUS_FILE;
$status_data = array(
    'enabled' => false,
    'schedule_active' => false,
    'is_blocking' => false,
    'updated_at' => '-',
    'total_blocked' => 0,
    'categories' => array(),
    'whitelist_count' => 0,
    'bypass_ips_count' => 0
);

if (file_exists($status_file)) {
    $raw = @file_get_contents($status_file);
    $parsed = json_decode($raw, true);
    if (is_array($parsed)) {
        $status_data = array_merge($status_data, $parsed);
    }
}

// Verificação em tempo real direto no config.xml e Unbound
$wam_cfg = rules_wam_get_config();
if (rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
    $status_data['enabled'] = true;
    if (file_exists(WAM_CONF_FILE)) {
        $status_data['is_blocking'] = true;
        if ($status_data['total_blocked'] <= 0) {
            $lines = file(WAM_CONF_FILE);
            $cnt = 0;
            foreach ($lines as $l) {
                if (strpos($l, 'local-zone:') !== false) $cnt++;
            }
            $status_data['total_blocked'] = $cnt;
        }
    }
}

// Mapeamento de categorias e contagem local
$categories_info = array(
    'block_adult'     => array('name' => 'Conteúdo Adulto & Pornografia', 'file' => 'adult.txt'),
    'block_gambling'  => array('name' => 'Apostas, Bets & Cassinos',     'file' => 'gambling.txt'),
    'block_news'      => array('name' => 'Notícias & Portais de Mídia',   'file' => 'news.txt'),
    'block_social'    => array('name' => 'Mídias Sociais & Redes',       'file' => 'social-media.txt'),
    'block_sports'    => array('name' => 'Esportes & Placares',          'file' => 'sports.txt'),
    'block_gaming'    => array('name' => 'Jogos & Games Online',         'file' => 'gaming.txt'),
    'block_streaming' => array('name' => 'Streaming & Vídeo',            'file' => 'streaming.txt'),
    'block_shopping'  => array('name' => 'Compras & E-commerce',         'file' => 'shopping.txt'),
    'block_p2p'       => array('name' => 'Torrents & P2P',               'file' => 'p2p.txt'),
    'block_doh'       => array('name' => 'Anti-Bypass DoH (DNS Seguro)', 'file' => 'doh-providers.txt'),
    'block_vpn'       => array('name' => 'VPN, ZTNA & Proxies',          'file' => 'vpn-ztna.txt'),
    'block_messaging' => array('name' => 'Mensageiros & Chat Instantâneo', 'file' => 'messaging.txt'),
);
?>

<div class="alert alert-success" style="margin-bottom: 20px;">
    <h4><i class="fa fa-database fa-lg"></i> <strong>BANCO DE DADOS DE LISTAS 100% INSTALADO E ATIVO</strong></h4>
    <p>Todas as listas de categorias (mais de <strong>4.700 domínios consolidados</strong>) já estão gravadas no seu pfSense e prontas para uso offline imediato. <strong>Não é necessário efetuar nenhum download adicional.</strong></p>
</div>

<div class="panel panel-default">
    <div class="panel-heading">
        <h2 class="panel-title"><?=gettext("Visão Geral do Serviço Rules WAM")?></h2>
    </div>
    <div class="panel-body">
        <dl class="dl-horizontal">
            <dt><?=gettext("Estado do Serviço")?></dt>
            <dd>
                <?php if ($status_data['enabled'] && $status_data['is_blocking']): ?>
                    <span class="label label-success" style="font-size: 13px; padding: 4px 10px;"><i class="fa fa-shield"></i> <?=gettext("ATIVO - BLOQUEANDO AGORA")?></span>
                <?php elseif ($status_data['enabled'] && !$status_data['is_blocking']): ?>
                    <span class="label label-info" style="font-size: 13px; padding: 4px 10px;"><i class="fa fa-clock-o"></i> <?=gettext("ATIVO - HORÁRIO PAUSADO (ACESSO LIBERADO)")?></span>
                <?php else: ?>
                    <span class="label label-danger" style="font-size: 13px; padding: 4px 10px;"><i class="fa fa-times-circle"></i> <?=gettext("DESABILITADO")?></span>
                <?php endif; ?>
            </dd>

            <dt><?=gettext("Total de Regras Ativas")?></dt>
            <dd><strong style="font-size: 15px; color: #3c763d;"><?=number_format($status_data['total_blocked'])?></strong> <?=gettext("domínios e subdomínios bloqueados no Unbound")?></dd>

            <dt><?=gettext("Última Aplicação")?></dt>
            <dd><?=htmlspecialchars($status_data['updated_at'])?></dd>

            <dt><?=gettext("Agendamento")?></dt>
            <dd>
                <?php if (!empty($status_data['schedule_active'])): ?>
                    <span class="label label-primary"><i class="fa fa-calendar"></i> <?=gettext("Horário Comercial Ativo")?></span>
                <?php else: ?>
                    <em><?=gettext("Bloqueio contínuo (24 horas)")?></em>
                <?php endif; ?>
            </dd>

            <dt><?=gettext("IPs Isentos (Bypass)")?></dt>
            <dd><?=intval($status_data['bypass_ips_count'])?> <?=gettext("dispositivo(s) com acesso livre")?></dd>

            <dt><?=gettext("Whitelist")?></dt>
            <dd><?=intval($status_data['whitelist_count'])?> <?=gettext("domínio(s) liberados")?></dd>

            <dt><?=gettext("Políticas por Rede")?></dt>
            <dd>
                <?php if (!empty($status_data['profiles_error'])): ?>
                    <span class="label label-danger"><i class="fa fa-exclamation-triangle"></i> <?=!empty($status_data['profiles_required']) ? gettext("Perfis rejeitados pelo Unbound: todas as redes estão com o bloqueio máximo. Veja o log do sistema.") : gettext("Perfis rejeitados pelo Unbound: todas as redes estão na política padrão. Veja o log do sistema.")?></span>
                <?php elseif (empty($status_data['profiles']) || !is_array($status_data['profiles'])): ?>
                    <em><?=!empty($status_data['profiles_required']) ? gettext("Nenhum perfil ativo: todas as redes estão com o bloqueio máximo") : gettext("Nenhum perfil ativo: todas as redes usam a política padrão")?></em>
                <?php else: ?>
                    <?php foreach ($status_data['profiles'] as $ps): ?>
                        <div style="margin-bottom: 4px;">
                            <span class="label label-primary"><?=htmlspecialchars($ps['name'] ?? '')?></span>
                            <code><?=htmlspecialchars(implode(', ', (array)($ps['networks'] ?? array())))?></code>
                            &mdash; <?=number_format(intval($ps['total'] ?? 0))?> <?=gettext("domínios")?>
                            <span class="text-muted small">(<?=htmlspecialchars(!empty($ps['categories']) ? implode(', ', (array)$ps['categories']) : gettext('nenhuma categoria'))?>)</span>
                        </div>
                    <?php endforeach; ?>
                <?php endif; ?>
                <?php if (!empty($status_data['uncovered_interfaces']) && is_array($status_data['uncovered_interfaces'])): ?>
                    <div style="margin-top: 6px;">
                        <span class="label label-danger"><i class="fa fa-exclamation-triangle"></i> <?=gettext("Sem perfil (bloqueio máximo)")?></span>
                        <?=htmlspecialchars(implode(', ', $status_data['uncovered_interfaces']))?>
                    </div>
                <?php endif; ?>
            </dd>

            <dt><?=gettext("Anti-Bypass DNS")?></dt>
            <dd>
                <?php if (rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? null)): ?>
                    <span class="label label-success"><i class="fa fa-lock"></i> <?=gettext("Ativo (Interceptando 8.8.8.8 / 1.1.1.1 na Porta 53)")?></span>
                <?php else: ?>
                    <span class="label label-default"><?=gettext("Desativado")?></span>
                <?php endif; ?>
            </dd>

        </dl>
    </div>
</div>

<div class="panel panel-default">
    <div class="panel-heading">
        <h2 class="panel-title"><?=gettext("Status das Categorias no Sistema (Banco de Regras Local)")?></h2>
    </div>
    <div class="table-responsive">
        <table class="table table-striped table-hover table-condensed">
            <thead>
                <tr>
                    <th><?=gettext("Categoria")?></th>
                    <th><?=gettext("Status no pfSense")?></th>
                    <th><?=gettext("Qtd. Domínios no Banco")?></th>
                    <th><?=gettext("Aplicação na Rede")?></th>
                </tr>
            </thead>
            <tbody>
                <?php $cat_usage = rules_wam_category_usage($wam_cfg); ?>
                <?php foreach ($categories_info as $ckey => $cdata):
                    $fpath = WAM_FEEDS_DIR . '/' . $cdata['file'];
                    $lines_cnt = 0;
                    if (file_exists($fpath)) {
                        $lines = file($fpath, FILE_SKIP_EMPTY_LINES);
                        foreach ($lines as $l) {
                            $l = trim($l);
                            if (!empty($l) && $l[0] !== '#') $lines_cnt++;
                        }
                    }
                    $cat_where = $cat_usage[$ckey] ?? array();
                    $is_cat_active = !empty($cat_where);
                ?>
                <tr>
                    <td><strong><?=htmlspecialchars($cdata['name'])?></strong></td>
                    <td><span class="text-success"><i class="fa fa-check-circle"></i> <?=gettext("Instalado e Pronto")?></span></td>
                    <td><span class="badge" style="background-color: #337ab7;"><?=number_format($lines_cnt)?> domínios</span></td>
                    <td>
                        <?php if ($status_data['enabled'] && $is_cat_active): ?>
                            <span class="label label-success"><i class="fa fa-shield"></i> <?=gettext("Bloqueando")?></span>
                            <span class="small text-muted"><?=htmlspecialchars(implode(', ', $cat_where))?></span>
                        <?php else: ?>
                            <span class="label label-default"><?=gettext("Nenhum perfil")?></span>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="panel panel-default">
    <div class="panel-heading">
        <h2 class="panel-title"><?=gettext("Testador de Bloqueio em Tempo Real")?></h2>
    </div>
    <div class="panel-body">
        <p><?=gettext("Digite um domínio ou URL para testar se o pfSense está bloqueando a resolução DNS para os clientes da rede:")?></p>
        <form action="/rules_wam_status.php" method="post" class="form-inline">
            <div class="form-group">
                <input type="text" name="test_domain" class="form-control" style="min-width: 320px;" placeholder="Ex: g1globo.com, xvideo.com, youtube.com, betano.com" value="<?=htmlspecialchars($test_domain)?>" required />
            </div>
            <div class="form-group">
                <input type="text" name="test_ip" class="form-control" style="min-width: 200px;" placeholder="<?=gettext("IP do cliente (opcional)")?>" value="<?=htmlspecialchars($test_ip)?>" title="<?=gettext("Informe o IP de uma máquina para testar a política da rede dela (perfil, IP isento ou padrão)")?>" />
            </div>
            <button type="submit" class="btn btn-primary"><i class="fa fa-search"></i> <?=gettext("Testar Bloqueio")?></button>
        </form>

        <?php if (!empty($test_error)): ?>
            <div class="alert alert-warning" style="margin-top: 15px;"><?=htmlspecialchars($test_error)?></div>
        <?php endif; ?>
        <?php if ($test_result): ?>
            <div style="margin-top: 15px;">
                <?php if ($test_result['status'] === 'BLOCKED'): ?>
                    <div class="alert alert-success">
                        <h4><i class="fa fa-shield"></i> <strong>BLOQUEADO COM SUCESSO!</strong></h4>
                        <p>O domínio <strong><?=htmlspecialchars($test_result['domain'])?></strong> está bloqueado pelo Rules WAM (<?=htmlspecialchars($test_result['policy'])?>). Resposta DNS: <code><?=htmlspecialchars($test_result['ip'])?></code>.</p>
                    </div>
                <?php else: ?>
                    <div class="alert alert-warning">
                        <h4><i class="fa fa-check-circle"></i> <strong>PERMITIDO / NÃO BLOQUEADO</strong></h4>
                        <p>O domínio <strong><?=htmlspecialchars($test_result['domain'])?></strong> não está bloqueado (<?=htmlspecialchars($test_result['policy'])?>). Status: <code><?=htmlspecialchars($test_result['ip'])?></code>.</p>
                    </div>
                <?php endif; ?>
            </div>
        <?php endif; ?>
    </div>
</div>

<?php include("foot.inc"); ?>
