<?php
/*
 * wam_cron.php
 * Executado pelo cron do pfSense a cada 5 minutos para manter o agendamento sincronizado.
 * Com --boot (chamado pelo rc.d na inicialização) regenera as regras, já que /var pode ser RAM disk.
 */

$is_boot = in_array('--boot', $argv ?? array(), true);
if ($is_boot) {
    define('RULES_WAM_BOOT', true);
}

require_once("config.inc");
require_once("/usr/local/pkg/rules_wam.inc");

$wam_cfg = rules_wam_get_config();
$enabled = rules_wam_is_checked($wam_cfg['enable'] ?? null);

if ($is_boot) {
    if ($enabled) {
        rules_wam_resync();
    }
    exit(0);
}

if (!$enabled || !rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null)) {
    exit(0);
}

// Decide pelo estado gravado na última aplicação (e não pela existência do arquivo,
// que também existe durante a pausa - era isso que impedia o bloqueio de voltar)
$status = rules_wam_read_status();
$currently_blocking = isset($status['is_blocking']) ? (bool)$status['is_blocking'] : null;
$should_block = rules_wam_is_in_schedule_window($wam_cfg);

if ($should_block && $currently_blocking !== true) {
    log_error("[Rules WAM Cron] Entrando no horario de bloqueio...");
    rules_wam_apply_rules($wam_cfg);
} elseif (!$should_block && $currently_blocking !== false) {
    log_error("[Rules WAM Cron] Entrando no intervalo livre (fora do horario)...");
    rules_wam_suspend_schedule($wam_cfg);
}
