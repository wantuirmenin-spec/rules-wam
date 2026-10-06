<?php
/*
 * wam_setup.php
 * Rotinas de instalação, atualização e desinstalação do Rules WAM.
 * Usado por install.sh, uninstall.sh e pelo instalador autônomo wam-install.sh.
 *
 *   php wam_setup.php check-gui   -> imprime o conflito de portas da WebGUI com o banner (vazio = sem conflito)
 *   php wam_setup.php check-wan   -> sai com código 3 se existir a regra antiga de WebGUI na WAN sem origens definidas
 *   php wam_setup.php install     -> aplica a configuração (variáveis: WAM_WAN_GUI_SOURCES, WAM_MOVE_GUI, WAM_GUI_PORT)
 *   php wam_setup.php uninstall   -> desfaz tudo o que o pacote alterou no config.xml
 */

require_once("config.inc");
require_once("util.inc");
require_once("filter.inc");
require_once(__DIR__ . "/rules_wam.inc");

global $config;

$action = $argv[1] ?? '';

function wam_out($msg) {
    echo "   " . $msg . "\n";
}

/** Existe a regra da versão 1.3 que liberava a WebGUI na WAN para qualquer origem? */
function wam_has_legacy_wan_rule() {
    foreach (config_get_path('filter/rule', array()) as $r) {
        if (isset($r['descr']) && strpos($r['descr'], 'Rules WAM - Acesso Permanente WebGUI WAN') === 0) {
            return true;
        }
    }
    return false;
}

/** Remove as alterações que a versão 1.3 fazia em arquivos do núcleo do pfSense */
function wam_remove_core_patches() {
    $hook = "if (file_exists(\"/usr/local/pkg/rules_wam_hook.inc\")) { require_once(\"/usr/local/pkg/rules_wam_hook.inc\"); }";
    foreach (array("/usr/local/www/index.php", "/usr/local/www/404.php") as $f) {
        if (file_exists($f)) {
            $c = file_get_contents($f);
            if (strpos($c, 'rules_wam_hook.inc') !== false) {
                $c = str_replace($hook . "\n", "", $c);
                $c = str_replace($hook, "", $c);
                file_put_contents($f, $c);
                wam_out("Hook removido de {$f}");
            }
        }
    }
    $f404 = "/usr/local/www/404.html";
    if (file_exists($f404)) {
        $c = file_get_contents($f404);
        $n = preg_replace('/<script>if\(window\.location\.hostname!==.*?<\/script>\s*/is', '', $c);
        if ($n !== null && $n !== $c) {
            file_put_contents($f404, $n);
            wam_out("Redirecionador removido de {$f404}");
        }
    }
}

/** Remove CA/certificado do banner HTTPS da versão 1.3 do Gerenciador de Certificados */
function wam_remove_legacy_certs() {
    $changed = false;
    $gui_cert = config_get_path('system/webgui/ssl-certref', '');
    $certs = config_get_path('cert', array());
    $kept = array();
    $ca_in_use = false;
    foreach ($certs as $c) {
        if (($c['descr'] ?? '') === 'Rules WAM SSL Server') {
            if (($c['refid'] ?? '') === $gui_cert) {
                $kept[] = $c; // em uso pela WebGUI: não remove
                $ca_in_use = true;
                wam_out("Aviso: o certificado 'Rules WAM SSL Server' está em uso pela WebGUI e foi mantido.");
                continue;
            }
            $changed = true;
            continue;
        }
        $kept[] = $c;
    }
    if ($changed) {
        config_set_path('cert', $kept);
    }
    if (!$ca_in_use) {
        $cas = config_get_path('ca', array());
        $kept_ca = array();
        foreach ($cas as $ca) {
            if (($ca['descr'] ?? '') === 'Rules WAM Firewall CA') {
                $changed = true;
                continue;
            }
            $kept_ca[] = $ca;
        }
        if (count($kept_ca) !== count($cas)) {
            config_set_path('ca', $kept_ca);
        }
    }
    if ($changed) {
        wam_out("CA/certificado do banner HTTPS antigo removidos do Gerenciador de Certificados");
    }
    return $changed;
}

/** Remove entradas de pacote/menu/cron/widget */
function wam_remove_registration() {
    global $config;
    $pkgs = array();
    foreach (config_get_path('installedpackages/package', array()) as $p) {
        if (in_array($p['name'] ?? '', array('rules_wam', 'wam'), true)) continue;
        $pkgs[] = $p;
    }
    config_set_path('installedpackages/package', $pkgs);

    $menus = array();
    foreach (config_get_path('installedpackages/menu', array()) as $m) {
        if (in_array($m['name'] ?? '', array('Rules WAM', 'WAM - Bloqueio de Categorias'), true)) continue;
        $menus[] = $m;
    }
    config_set_path('installedpackages/menu', $menus);

    $cron = array();
    foreach (config_get_path('cron/item', array()) as $c) {
        if (strpos($c['command'] ?? '', 'wam_cron.php') !== false) continue;
        $cron[] = $c;
    }
    config_set_path('cron/item', $cron);

    if (isset($config['system']['user']) && is_array($config['system']['user'])) {
        foreach ($config['system']['user'] as $idx => $u) {
            $seq = $u['widgets']['sequence'] ?? '';
            if ($seq !== '' && strpos($seq, 'rules_wam') !== false) {
                $parts = array_filter(explode(',', $seq), function ($s) { return strpos($s, 'rules_wam') === false; });
                $config['system']['user'][$idx]['widgets']['sequence'] = implode(',', $parts);
            }
        }
    }
    $seq = config_get_path('widgets/sequence', '');
    if ($seq !== '' && strpos($seq, 'rules_wam') !== false) {
        $parts = array_filter(explode(',', $seq), function ($s) { return strpos($s, 'rules_wam') === false; });
        config_set_path('widgets/sequence', implode(',', $parts));
    }
}

switch ($action) {

case 'check-wan':
    // 2 = origens informadas inválidas; 3 = falta informar as origens (regra antiga da 1.3 na WAN)
    $wan_env = trim((string)getenv('WAM_WAN_GUI_SOURCES'));
    if ($wan_env !== '' && strtolower($wan_env) !== 'none') {
        $parts = rules_wam_parse_list($wan_env);
        $valid = rules_wam_parse_sources($wan_env);
        if (empty($valid) || count($valid) !== count(array_unique($parts))) {
            fwrite(STDERR, "   Origens WAN inválidas: {$wan_env}\n");
            exit(2);
        }
        exit(0);
    }
    $cfg = rules_wam_get_config();
    if ($wan_env === '' && wam_has_legacy_wan_rule() && trim($cfg['gui_wan_sources'] ?? '') === '') {
        exit(3);
    }
    exit(0);

case 'check-gui':
    echo rules_wam_banner_conflict();
    exit(0);

case 'install':
    $is_upgrade = (config_get_path('installedpackages/rules_wam/config', null) !== null)
        || (config_get_path('installedpackages/wam/config', null) !== null);

    // 1. Migra a configuração do caminho legado "wam" e remove a cópia duplicada
    $cfg = rules_wam_get_config();
    if (config_get_path('installedpackages/wam', null) !== null) {
        config_del_path('installedpackages/wam');
        wam_out("Configuração duplicada 'installedpackages/wam' removida (migrada para rules_wam)");
    }

    // 2. Regra antiga de WebGUI na WAN -> converte para origens explícitas (ou nenhuma)
    $wan_env = trim((string)getenv('WAM_WAN_GUI_SOURCES'));
    if ($wan_env !== '' && strtolower($wan_env) !== 'none') {
        $valid = rules_wam_parse_sources($wan_env);
        if (empty($valid)) {
            fwrite(STDERR, "WAM_WAN_GUI_SOURCES sem nenhum IP/rede válido.\n");
            exit(2);
        }
        $cfg['gui_wan_sources'] = implode(' ', $valid);
        wam_out("WebGUI pela WAN restrita a: " . implode(', ', $valid));
    } elseif (wam_has_legacy_wan_rule() && trim($cfg['gui_wan_sources'] ?? '') === '') {
        if (strtolower($wan_env) !== 'none') {
            fwrite(STDERR, "Existe a regra antiga de WebGUI na WAN. Defina WAM_WAN_GUI_SOURCES (lista de IPs) ou WAM_WAN_GUI_SOURCES=none.\n");
            exit(3);
        }
        wam_out("Regra de WebGUI na WAN será removida (sem acesso pela WAN)");
    }

    // 3. Ajustes de upgrade da 1.3
    if ($is_upgrade && empty($cfg['migrated_v14'])) {
        $cfg['migrated_v14'] = 'yes';
        // A versão 1.3 já tinha alterado porta/redirecionamento da WebGUI: valores originais desconhecidos
        rules_wam_state_set_once('orig_gui_unknown', 'yes');
        wam_out("Upgrade da 1.3 detectado: revise os campos de lista em Services > Rules WAM e salve novamente");
    }
    if (!$is_upgrade) {
        $cfg['initialized'] = 'yes';
        $cfg['migrated_v14'] = 'yes';
    }

    // 4. Portas 80/443: o banner precisa delas livres. Só mexe na WebGUI com autorização explícita.
    $orig_port = config_get_path('system/webgui/port', '');
    $orig_redirect = (config_get_path('system/webgui/disablehttpredirect') !== null) ? 'yes' : 'no';
    rules_wam_state_set_once('orig_gui_port', $orig_port);
    rules_wam_state_set_once('orig_gui_disablehttpredirect', $orig_redirect);
    $restart_gui = false;
    $conflict = rules_wam_banner_conflict();
    if ($conflict !== '' && ($cfg['block_action'] ?? 'block_page') === 'block_page') {
        if (strtolower((string)getenv('WAM_MOVE_GUI')) === 'yes') {
            $new_port = trim((string)getenv('WAM_GUI_PORT')) ?: '50443';
            if (!ctype_digit($new_port) || (int)$new_port < 1 || (int)$new_port > 65535 || in_array($new_port, array('80', '443'), true)) {
                fwrite(STDERR, "WAM_GUI_PORT inválida: {$new_port}\n");
                exit(2);
            }
            init_config_arr(array('system', 'webgui'));
            if (in_array(config_get_path('system/webgui/port', ''), array('', '80', '443'), true)) {
                config_set_path('system/webgui/port', $new_port);
                config_set_path('installedpackages/rules_wam/state/gui_port_set_by_wam', $new_port);
                $restart_gui = true;
            }
            if (config_get_path('system/webgui/protocol', 'https') === 'https' && config_get_path('system/webgui/disablehttpredirect') === null) {
                config_set_path('system/webgui/disablehttpredirect', true);
                config_set_path('installedpackages/rules_wam/state/redirect_set_by_wam', 'yes');
                $restart_gui = true;
            }
            wam_out("WebGUI movida para a porta " . config_get_path('system/webgui/port', '') . " e redirecionamento HTTP desativado");
        } else {
            wam_out("Atenção: {$conflict} O banner ficará desligado (bloqueio silencioso 0.0.0.0) até a porta ser liberada.");
        }
    }

    // 5. Limpeza de sobras da 1.3
    wam_remove_core_patches();
    wam_remove_legacy_certs();

    config_set_path('installedpackages/rules_wam/config/0', $cfg);
    write_config("Rules WAM " . RULES_WAM_VERSION . ": instalacao/atualizacao");

    // 6. Aplica (gera regras do Unbound, banner e firewall)
    rules_wam_resync();

    if ($restart_gui) {
        wam_out("Reiniciando a WebGUI em segundo plano (a sessão atual pode cair; acesse a nova porta)...");
        mwexec_bg('/etc/rc.restart_webgui');
    }
    $p = config_get_path('system/webgui/port', '') ?: (config_get_path('system/webgui/protocol', 'https') === 'https' ? '443' : '80');
    echo "WEBGUI_PORT=" . $p . "\n";
    exit(0);

case 'uninstall':
    // 1. Remove include do Unbound, domain overrides, banner, regras e aliases
    rules_wam_disable(true);

    // 2. Restaura porta/redirecionamento da WebGUI se fomos nós que mudamos
    $restart_gui = false;
    $set_port = rules_wam_state_get('gui_port_set_by_wam');
    if (rules_wam_state_get('orig_gui_unknown') !== 'yes' && $set_port !== null
        && config_get_path('system/webgui/port', '') === $set_port) {
        $orig_port = rules_wam_state_get('orig_gui_port', '');
        if ($orig_port === '') {
            config_del_path('system/webgui/port');
        } else {
            config_set_path('system/webgui/port', $orig_port);
        }
        $restart_gui = true;
        wam_out("Porta original da WebGUI restaurada (" . ($orig_port === '' ? 'padrão' : $orig_port) . ")");
    }
    if (rules_wam_state_get('orig_gui_unknown') !== 'yes' && rules_wam_state_get('redirect_set_by_wam') === 'yes'
        && config_get_path('system/webgui/disablehttpredirect') !== null) {
        config_del_path('system/webgui/disablehttpredirect');
        $restart_gui = true;
        wam_out("Redirecionamento HTTP da WebGUI reativado");
    }
    if (rules_wam_state_get('orig_gui_unknown') === 'yes') {
        wam_out("Aviso: a porta da WebGUI foi alterada pela versão 1.3 e não é restaurada automaticamente.");
        wam_out("        Revise em System > Advanced > Admin Access (porta, redirecionamento HTTP e DNS rebind).");
    }

    // 3. Remove registro do pacote, menus, cron, widget, certificados da 1.3 e configuração
    wam_remove_registration();
    wam_remove_legacy_certs();
    wam_remove_core_patches();
    config_del_path('installedpackages/rules_wam');
    config_del_path('installedpackages/wam');
    write_config("Rules WAM desinstalado");
    if (function_exists('configure_cron')) {
        configure_cron();
    }
    filter_configure();
    if ($restart_gui) {
        mwexec_bg('/etc/rc.restart_webgui');
    }
    exit(0);

default:
    fwrite(STDERR, "Uso: php wam_setup.php check-wan|install|uninstall\n");
    exit(1);
}
