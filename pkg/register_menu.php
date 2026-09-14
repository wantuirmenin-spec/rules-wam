<?php
/*
 * register_menu.php
 * Registra o Rules WAM no config.xml e nos menus do pfSense
 */

require_once("config.inc");
require_once("pkg-utils.inc");

// 1. Limpa relatórios de crash antigos
@unlink("/tmp/PHP_errors.log");
if (is_dir("/var/crash")) {
    $files = glob("/var/crash/*");
    if (is_array($files)) {
        foreach ($files as $f) {
            @unlink($f);
        }
    }
}

// 2. Registra pacote
$packages = config_get_path('installedpackages/package', array());
$pkg_info = array(
    "name" => "rules_wam",
    "version" => "1.3.0",
    "status" => "Stable",
    "descr" => "Rules WAM - Web Access Manager",
    "configurationfile" => "rules_wam.xml"
);

$found_pkg = false;
foreach ($packages as $idx => $p) {
    if (isset($p['name']) && ($p['name'] === 'rules_wam' || $p['name'] === 'wam')) {
        $packages[$idx] = $pkg_info;
        $found_pkg = true;
        break;
    }
}
if (!$found_pkg) {
    $packages[] = $pkg_info;
}
config_set_path('installedpackages/package', $packages);

// 3. Registra menus em Services e Firewall
$menus = config_get_path('installedpackages/menu', array());

$clean_menus = array();
if (is_array($menus)) {
    foreach ($menus as $m) {
        if (isset($m['name']) && ($m['name'] === 'Rules WAM' || $m['name'] === 'WAM - Bloqueio de Categorias' || (isset($m['url']) && strpos($m['url'], 'wam.xml') !== false))) {
            continue;
        }
        $clean_menus[] = $m;
    }
}

$clean_menus[] = array(
    "name" => "Rules WAM",
    "section" => "Services",
    "url" => "/rules_wam.php",
    "tooltiptext" => "Rules WAM - Bloqueio de Categorias de Sites"
);

$clean_menus[] = array(
    "name" => "Rules WAM",
    "section" => "Firewall",
    "url" => "/rules_wam.php",
    "tooltiptext" => "Rules WAM - Bloqueio de Categorias de Sites"
);

config_set_path('installedpackages/menu', $clean_menus);

// 4. Configura Cron a cada 5 min
$cron_items = config_get_path('cron/item', array());
$cron_cmd = "/usr/local/bin/php -q /usr/local/pkg/wam_cron.php";
$cron_found = false;
if (is_array($cron_items)) {
    foreach ($cron_items as $c) {
        if (isset($c['command']) && $c['command'] === $cron_cmd) {
            $cron_found = true;
            break;
        }
    }
}
if (!$cron_found) {
    $cron_items[] = array(
        "minute" => "*/5",
        "hour" => "*",
        "mday" => "*",
        "month" => "*",
        "wday" => "*",
        "who" => "root",
        "command" => $cron_cmd
    );
    config_set_path('cron/item', $cron_items);
}

// 5. Registra o Widget no Dashboard do pfSense (se já houver sequência configurada)
$users = config_get_path('system/user', array());
$user_changed = false;
if (is_array($users)) {
    foreach ($users as $u_idx => $u) {
        if (!empty($u['name']) && ($u['name'] === 'admin' || (!empty($u['scope']) && $u['scope'] === 'system'))) {
            $u_seq = $u['widgets']['sequence'] ?? '';
            if (!empty($u_seq) && strpos($u_seq, 'rules_wam') === false) {
                $users[$u_idx]['widgets']['sequence'] = rtrim($u_seq, ',') . ',rules_wam:col2:show:0';
                $user_changed = true;
            }
        }
    }
    if ($user_changed) {
        config_set_path('system/user', $users);
    }
}
$root_widgets = config_get_path('widgets/sequence', null);
if (!empty($root_widgets) && strpos($root_widgets, 'rules_wam') === false) {
    config_set_path('widgets/sequence', rtrim($root_widgets, ',') . ',rules_wam:col2:show:0');
}

// 6. Grava configuração e limpa caches
write_config("Rules WAM menu e widget registrados");
if (function_exists("configure_cron")) {
    configure_cron();
}

@unlink("/tmp/config.cache");
@unlink("/tmp/menu.cache");
@unlink("/tmp/pkg_menu.cache");

echo "=== SUCESSO: RULES WAM REGISTRADO ===\n";
echo "Menus ativos:\n";
foreach ($clean_menus as $m) {
    echo " -> [" . $m['section'] . "] " . $m['name'] . " (" . $m['url'] . ")\n";
}
echo "Crash reports antigos limpos!\n";
echo "=====================================\n";
?>
