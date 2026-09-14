<?php
/*
 * rules_wam_hook.inc
 * Interceptor de requisições HTTP para exibição do Banner de Bloqueio
 */

if (!empty($_SERVER['HTTP_HOST'])) {
    $fwd_port  = $_SERVER['HTTP_X_FORWARDED_PORT'] ?? '';
    $fwd_proto = $_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '';
    $srv_port  = $_SERVER['SERVER_PORT'] ?? '';
    $is_proxied = (!empty($_SERVER['REMOTE_ADDR']) && $_SERVER['REMOTE_ADDR'] === '127.0.0.1' && (!empty($_SERVER['HTTP_X_REAL_IP']) || !empty($fwd_proto) || !empty($fwd_port)));
    $is_banner_port = ($srv_port == '80' || $srv_port == '443' || $fwd_port == '80' || $fwd_port == '443');

    // Se a requisição veio diretamente na porta administrativa WebGUI sem proxy WAM, não interceptar
    if (!$is_proxied && !$is_banner_port && !empty($srv_port)) {
        return;
    }

    $req_h = strtolower(trim($_SERVER['HTTP_HOST']));
    $req_h = preg_replace('/:\d+$/', '', $req_h); // remove porta

    // Lista de identificadores locais do firewall
    $fw_ips = array('127.0.0.1', '::1', 'localhost');
    if (!empty($_SERVER['SERVER_ADDR'])) {
        $fw_ips[] = $_SERVER['SERVER_ADDR'];
    }

    if (!isset($config) && file_exists('/etc/inc/config.inc')) {
        require_once('/etc/inc/config.inc');
    }

    global $config;
    if (!empty($config['interfaces'])) {
        foreach ($config['interfaces'] as $if_cfg) {
            if (!empty($if_cfg['ipaddr'])) {
                $fw_ips[] = $if_cfg['ipaddr'];
            }
        }
    }
    if (!empty($config['system']['hostname'])) {
        $fw_ips[] = strtolower($config['system']['hostname']);
        if (!empty($config['system']['domain'])) {
            $fw_ips[] = strtolower($config['system']['hostname'] . '.' . $config['system']['domain']);
        }
    }

    $is_fw = in_array($req_h, $fw_ips) || strpos($req_h, 'pfsense') !== false;

    // Se o host solicitado NÃO for o próprio firewall, é um domínio interceptado pelo Rules WAM!
    if (!$is_fw) {
        if (file_exists('/usr/local/www/rules_wam_block.php')) {
            require('/usr/local/www/rules_wam_block.php');
            exit;
        }
    }
}
