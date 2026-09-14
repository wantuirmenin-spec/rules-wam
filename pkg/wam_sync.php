<?php
/*
 * wam_sync.php
 * Script CLI para sincronizacao e recarga das regras do WAM
 * Pode ser executado via Cron ou linha de comando:
 * php /usr/local/pkg/wam_sync.php
 */

require_once("config.inc");
require_once("/usr/local/pkg/wam.inc");

echo "[" . date('Y-m-d H:i:s') . "] Iniciando sincronizacao do WAM...\n";
wam_resync();
echo "[" . date('Y-m-d H:i:s') . "] Sincronizacao concluida!\n";
?>
