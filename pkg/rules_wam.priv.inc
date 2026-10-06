<?php
/*
 * rules_wam.priv.inc
 * Privilégios da WebGUI do Rules WAM (instalado em /etc/inc/priv/)
 * Permite delegar acesso às telas sem conceder "page-all".
 */

global $priv_list;

$priv_list['page-services-ruleswam'] = array();
$priv_list['page-services-ruleswam']['name'] = "WebCfg - Services: Rules WAM (configuração)";
$priv_list['page-services-ruleswam']['descr'] = "Permite alterar a configuração do Rules WAM.";
$priv_list['page-services-ruleswam']['match'] = array();
$priv_list['page-services-ruleswam']['match'][] = "rules_wam.php*";
$priv_list['page-services-ruleswam']['match'][] = "rules_wam_status.php*";
$priv_list['page-services-ruleswam']['match'][] = "rules_wam_dashboard.php*";
$priv_list['page-services-ruleswam']['match'][] = "rules_wam_block.php*";

$priv_list['page-services-ruleswam-audit'] = array();
$priv_list['page-services-ruleswam-audit']['name'] = "WebCfg - Services: Rules WAM (auditoria)";
$priv_list['page-services-ruleswam-audit']['descr'] = "Permite ver o status e o dashboard de tentativas de acesso do Rules WAM.";
$priv_list['page-services-ruleswam-audit']['match'] = array();
$priv_list['page-services-ruleswam-audit']['match'][] = "rules_wam_status.php*";
$priv_list['page-services-ruleswam-audit']['match'][] = "rules_wam_dashboard.php*";
$priv_list['page-services-ruleswam-audit']['match'][] = "rules_wam_block.php*";
