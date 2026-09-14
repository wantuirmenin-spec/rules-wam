<?php
/*
 * wam_cron.php
 * Executado periodicamente pelo cron do pfSense a cada 5 minutos
 * para manter o agendamento de Rules WAM sincronizado.
 */

require_once("config.inc");
require_once("/usr/local/pkg/rules_wam.inc");

global $config;

$wam_cfg = array();
if (isset($config['installedpackages']['rules_wam']['config'][0])) {
    $wam_cfg = $config['installedpackages']['rules_wam']['config'][0];
} elseif (isset($config['installedpackages']['wam']['config'][0])) {
    $wam_cfg = $config['installedpackages']['wam']['config'][0];
} else {
    exit(0);
}

if (!isset($wam_cfg['enable']) || $wam_cfg['enable'] !== 'yes') {
    exit(0);
}

if (!isset($wam_cfg['schedule_enable']) || $wam_cfg['schedule_enable'] !== 'yes') {
    exit(0);
}

$should_block = rules_wam_is_in_schedule_window($wam_cfg);
$conf_exists = file_exists(WAM_CONF_FILE);

if ($should_block && !$conf_exists) {
    log_error("[Rules WAM Cron] Entrando no horário de bloqueio comercial...");
    rules_wam_apply_rules($wam_cfg);
} elseif (!$should_block && $conf_exists) {
    log_error("[Rules WAM Cron] Entrando no intervalo livre (fora de horário)...");
    rules_wam_suspend_schedule();
}
?>
