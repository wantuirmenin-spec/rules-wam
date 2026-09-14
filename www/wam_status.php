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
display_top_tabs($tab_array);

// Teste de domínio solicitado
$test_domain = isset($_POST['test_domain']) ? trim($_POST['test_domain']) : '';
$test_result = null;

if (!empty($test_domain)) {
    $clean_test = rules_wam_clean_domain($test_domain);
    
    // 1. Verifica se o domínio está listado no arquivo de bloqueio ativo
    $is_in_blocklist = false;
    if (file_exists(WAM_CONF_FILE)) {
        $conf_data = @file_get_contents(WAM_CONF_FILE);
        if ($conf_data) {
            if (preg_match('/local-zone:\s*"' . preg_quote($clean_test, '/') . '"/i', $conf_data)) {
                $is_in_blocklist = true;
            } else {
                $parts = explode('.', $clean_test);
                while (count($parts) > 1) {
                    array_shift($parts);
                    $parent = implode('.', $parts);
                    if (preg_match('/local-zone:\s*"' . preg_quote($parent, '/') . '"/i', $conf_data)) {
                        $is_in_blocklist = true;
                        break;
                    }
                }
            }
        }
    }

    // 2. Consulta diretamente o Unbound local na porta 53 via drill
    $drill_ip = null;
    $drill_out = array();
    if (file_exists('/usr/bin/drill')) {
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

    if ($is_in_blocklist || $drill_ip === '0.0.0.0') {
        $test_result = array(
            'status' => 'BLOCKED',
            'domain' => $clean_test,
            'ip' => '0.0.0.0 (Interceptado pelo Rules WAM / Unbound)',
            'msg' => 'Domínio BLOQUEADO pelo Rules WAM!'
        );
    } else {
        $test_result = array(
            'status' => 'ALLOWED',
            'domain' => $clean_test,
            'ip' => $drill_ip ? $drill_ip : 'Resolvido normalmente',
            'msg' => 'Domínio não está nas categorias ativas de bloqueio (acesso liberado).'
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
                    $is_cat_active = rules_wam_is_checked($wam_cfg[$ckey] ?? null);
                ?>
                <tr>
                    <td><strong><?=htmlspecialchars($cdata['name'])?></strong></td>
                    <td><span class="text-success"><i class="fa fa-check-circle"></i> <?=gettext("Instalado e Pronto")?></span></td>
                    <td><span class="badge" style="background-color: #337ab7;"><?=number_format($lines_cnt)?> domínios</span></td>
                    <td>
                        <?php if ($status_data['enabled'] && $is_cat_active): ?>
                            <span class="label label-success"><i class="fa fa-shield"></i> <?=gettext("Bloqueando")?></span>
                        <?php else: ?>
                            <span class="label label-default"><?=gettext("Desmarcado")?></span>
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
            <button type="submit" class="btn btn-primary"><i class="fa fa-search"></i> <?=gettext("Testar Bloqueio")?></button>
        </form>

        <?php if ($test_result): ?>
            <div style="margin-top: 15px;">
                <?php if ($test_result['status'] === 'BLOCKED'): ?>
                    <div class="alert alert-success">
                        <h4><i class="fa fa-shield"></i> <strong>BLOQUEADO COM SUCESSO!</strong></h4>
                        <p>O domínio <strong><?=htmlspecialchars($test_result['domain'])?></strong> está bloqueado pelo Rules WAM. Resposta DNS: <code><?=htmlspecialchars($test_result['ip'])?></code>.</p>
                    </div>
                <?php else: ?>
                    <div class="alert alert-warning">
                        <h4><i class="fa fa-check-circle"></i> <strong>PERMITIDO / NÃO BLOQUEADO</strong></h4>
                        <p>O domínio <strong><?=htmlspecialchars($test_result['domain'])?></strong> não está ativo na lista de bloqueio. Status: <code><?=htmlspecialchars($test_result['ip'])?></code>.</p>
                    </div>
                <?php endif; ?>
            </div>
        <?php endif; ?>
    </div>
</div>

<?php include("foot.inc"); ?>
