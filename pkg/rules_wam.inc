<?php
/*
 * rules_wam.inc
 * Rules WAM - Web Access Manager para pfSense
 * Motor de aplicação de regras de bloqueio e auditoria no Unbound DNS
 */

require_once("config.inc");
require_once("util.inc");
require_once("services.inc");

define('WAM_FEEDS_DIR', '/usr/local/share/wam/feeds');
define('WAM_CONF_FILE', '/var/unbound/wam_blocklist.conf');
define('WAM_STATUS_FILE', '/var/log/wam_status.json');
define('WAM_AUDIT_LOG', '/var/log/wam_audit.log');

/**
 * Auxiliar para verificar se checkbox está marcada (aceita "yes", "on", 1, true)
 */
function rules_wam_is_checked($val) {
    if (empty($val)) return false;
    if ($val === 'yes' || $val === 'on' || $val === true || $val === '1' || $val === 1) return true;
    return false;
}

/**
 * Obtém todas as interfaces configuradas no pfSense com seus nomes amigáveis (descr) reais.
 * Suporta LAN, OPT1..OPTn, VLANs, Bridges, etc., exatamente como configurado no pfSense.
 */
function rules_wam_get_configured_interfaces($include_wan = false) {
    global $config;

    $interfaces = array();
    $ifdescrs = array();

    if (file_exists('/etc/inc/interfaces.inc')) {
        require_once("interfaces.inc");
        if (function_exists('get_configured_interface_with_descr')) {
            $ifdescrs = get_configured_interface_with_descr(false);
        }
    }

    $raw_interfaces = function_exists('config_get_path') ? config_get_path('interfaces', array()) : (!empty($config['interfaces']) ? $config['interfaces'] : array());

    if (!empty($raw_interfaces) && is_array($raw_interfaces)) {
        foreach ($raw_interfaces as $if_key => $if_cfg) {
            if (!$include_wan && $if_key === 'wan') {
                continue;
            }

            // No pfSense, interfaces OPT só estão ativas se tiverem 'enable'. LAN e WAN são ativas por padrão.
            $is_active = true;
            if (function_exists('interface_is_enabled')) {
                $is_active = interface_is_enabled($if_key);
            } else {
                $is_active = ($if_key === 'lan' || $if_key === 'wan' || isset($if_cfg['enable']));
            }
            if (!$is_active) {
                continue;
            }

            // Nome descritivo amigável configurado no pfSense (Ex: LAN_CORP, WIFI_VISITANTES, REDE_LOCAL)
            $descr = '';
            if (!empty($if_cfg['descr'])) {
                $descr = trim($if_cfg['descr']);
            } elseif (function_exists('convert_friendly_interface_to_friendly_descr')) {
                $descr = trim(convert_friendly_interface_to_friendly_descr($if_key));
            } elseif (!empty($ifdescrs[$if_key])) {
                $descr = trim($ifdescrs[$if_key]);
            } else {
                $descr = strtoupper($if_key);
            }

            // Interface física/virtual no FreeBSD (Ex: igb0, em1, vlan0.10, vtnet1)
            $real_if = !empty($if_cfg['if']) ? $if_cfg['if'] : '';
            if (empty($real_if) && function_exists('get_real_interface')) {
                $real_if = get_real_interface($if_key);
            }
            if (empty($real_if) && function_exists('convert_friendly_interface_to_real_interface_name')) {
                $real_if = convert_friendly_interface_to_real_interface_name($if_key);
            }

            // Normaliza nomes padrão: garante que 'wan' seja 'WAN' e 'lan' seja 'LAN'
            // se a descrição estiver vazia ou com o nome do dispositivo físico (ex: vtnet1, vtnet0)
            if ($if_key === 'wan' && (empty($descr) || (!empty($real_if) && strcasecmp($descr, $real_if) === 0))) {
                $descr = 'WAN';
            }
            if ($if_key === 'lan' && (empty($descr) || (!empty($real_if) && strcasecmp($descr, $real_if) === 0))) {
                $descr = 'LAN';
            }

            // Endereço IPv4 da Interface
            $if_ip = '';
            $if_subnet = 24;

            if (function_exists('get_interface_ip')) {
                $g_ip = get_interface_ip($if_key);
                if (!empty($g_ip) && filter_var($g_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                    $if_ip = $g_ip;
                }
            }

            if (empty($if_ip) && function_exists('get_interface_info')) {
                $info = get_interface_info($if_key);
                if (!empty($info['ipaddr']) && filter_var($info['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                    $if_ip = $info['ipaddr'];
                }
                if (!empty($info['subnet']) && is_numeric($info['subnet'])) {
                    $if_subnet = (int)$info['subnet'];
                }
                if (empty($real_if) && !empty($info['if'])) {
                    $real_if = $info['if'];
                } elseif (empty($real_if) && !empty($info['hwif'])) {
                    $real_if = $info['hwif'];
                }
            }

            if (empty($if_ip) && !empty($if_cfg['ipaddr']) && filter_var($if_cfg['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $if_ip = $if_cfg['ipaddr'];
                if (!empty($if_cfg['subnet']) && is_numeric($if_cfg['subnet'])) {
                    $if_subnet = (int)$if_cfg['subnet'];
                }
            }

            // Fallback via ifconfig para capturar IP dinâmico/DHCP/VLAN
            if (empty($if_ip) && !empty($real_if)) {
                $raw_out = array();
                @exec("/sbin/ifconfig " . escapeshellarg($real_if) . " 2>/dev/null", $raw_out);
                foreach ($raw_out as $r_line) {
                    if (preg_match('/inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\s+netmask\s+(0x[0-9a-fA-F]+|[0-9\.]+)/i', $r_line, $im)) {
                        $if_ip = $im[1];
                        if (stripos($im[2], '0x') === 0) {
                            $if_subnet = substr_count(decbin(hexdec($im[2])), '1');
                        } elseif (filter_var($im[2], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                            $if_subnet = substr_count(decbin(ip2long($im[2])), '1');
                        }
                        break;
                    }
                }
            }

            // Calcula CIDR da sub-rede
            $has_valid_ip = (!empty($if_ip) && filter_var($if_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4));
            $cidr = '';
            $net_long = 0;
            $long_mask = 0;
            if ($has_valid_ip) {
                if ($if_subnet <= 0 || $if_subnet > 32) $if_subnet = 24;
                $long_ip = ip2long($if_ip);
                $long_mask = -1 << (32 - $if_subnet);
                $net_long = $long_ip & $long_mask;
                $cidr = long2ip($net_long) . '/' . $if_subnet;
            } else {
                $cidr = strtoupper($if_key) . ' (Sem IP)';
            }

            $interfaces[$if_key] = array(
                'key'         => $if_key,
                'logical_id'  => strtoupper($if_key),
                'descr'       => $descr,
                'name'        => $descr,
                'real_if'     => !empty($real_if) ? $real_if : $if_key,
                'ip'          => $if_ip,
                'subnet'      => $if_subnet,
                'cidr'        => $cidr,
                'net_long'    => $net_long,
                'mask_long'   => $long_mask,
                'has_ip'      => $has_valid_ip,
                'is_internal' => ($if_key !== 'wan')
            );
        }
    }

    return $interfaces;
}

/**
 * Localiza a interface do pfSense correspondente a um endereço IP de cliente
 */
function rules_wam_find_interface_for_ip($ip) {
    if (empty($ip) || !filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return null;
    }
    static $interfaces_cache = null;
    if ($interfaces_cache === null) {
        $interfaces_cache = rules_wam_get_configured_interfaces(true);
    }
    $ipl = ip2long($ip);
    foreach ($interfaces_cache as $if_key => $if_data) {
        if (!empty($if_data['has_ip']) && !empty($if_data['mask_long'])) {
            if (($ipl & $if_data['mask_long']) === $if_data['net_long']) {
                return $if_data;
            }
        }
    }
    return null;
}

/**
 * Obtém o IP IPv4 de banner/redirecionamento da rede local em tempo de execução
 */
function rules_wam_get_lan_ip() {
    global $config;

    // 1. Tenta obter IP de todas as interfaces configuradas no pfSense
    $ifaces = rules_wam_get_configured_interfaces(false);

    // Se a interface 'lan' existir e tiver IP, usa ela como prioritária
    if (!empty($ifaces['lan']['ip'])) {
        return $ifaces['lan']['ip'];
    }

    // Se a LAN foi renomeada ou não tem IP, busca a primeira interface interna com IPv4 ativo
    foreach ($ifaces as $if_data) {
        if (!empty($if_data['ip'])) {
            return $if_data['ip'];
        }
    }

    // Fallbacks legados
    if (function_exists('get_interface_ip')) {
        $lan_ip = get_interface_ip('lan');
        if (!empty($lan_ip) && filter_var($lan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            return $lan_ip;
        }
        // Se interfaces internas não tiverem IP, tenta WAN (caso de testes/laboratório em VM)
        $wan_ip = get_interface_ip('wan');
        if (!empty($wan_ip) && filter_var($wan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            return $wan_ip;
        }
    }

    $cfg_ip = function_exists('config_get_path') ? config_get_path('interfaces/lan/ipaddr', '') : ($config['interfaces']['lan']['ipaddr'] ?? '');
    if (filter_var($cfg_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return $cfg_ip;
    }

    $cfg_wan = function_exists('config_get_path') ? config_get_path('interfaces/wan/ipaddr', '') : ($config['interfaces']['wan']['ipaddr'] ?? '');
    if (filter_var($cfg_wan, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return $cfg_wan;
    }

    return '192.168.1.1';
}

/**
 * Obtém a configuração do Rules WAM de qualquer estrutura do config.xml ou $_POST
 */
function rules_wam_get_config() {
    global $config;

    $cfg = null;

    $cfg0 = config_get_path('installedpackages/rules_wam/config/0', null);
    if (is_array($cfg0) && !empty($cfg0)) {
        $cfg = $cfg0;
    } else {
        $cfga = config_get_path('installedpackages/rules_wam/config', null);
        if (is_array($cfga) && !empty($cfga)) {
            $cfg = (isset($cfga[0]) && is_array($cfga[0])) ? $cfga[0] : $cfga;
        } elseif (isset($config['installedpackages']['rules_wam']['config'][0])) {
            $cfg = $config['installedpackages']['rules_wam']['config'][0];
        } elseif (isset($config['installedpackages']['rules_wam']['config']) && is_array($config['installedpackages']['rules_wam']['config'])) {
            $cfg = $config['installedpackages']['rules_wam']['config'];
        }
    }

    if (empty($cfg) || !is_array($cfg)) {
        $cfg_w0 = config_get_path('installedpackages/wam/config/0', null);
        if (is_array($cfg_w0) && !empty($cfg_w0)) {
            $cfg = $cfg_w0;
        } else {
            $cfg_wa = config_get_path('installedpackages/wam/config', null);
            if (is_array($cfg_wa) && !empty($cfg_wa)) {
                $cfg = (isset($cfg_wa[0]) && is_array($cfg_wa[0])) ? $cfg_wa[0] : $cfg_wa;
            }
        }
    }

    if (is_array($cfg) && !empty($cfg)) {
        // Se a configuração já existe no pfSense, checkboxes ausentes no XML representam 'no'
        $checkbox_keys = array(
            'enable', 'block_adult', 'block_gambling', 'block_news', 'block_social',
            'block_sports', 'block_gaming', 'block_streaming', 'block_shopping',
            'block_p2p', 'block_doh', 'block_dns_bypass', 'block_vpn', 'block_messaging',
            'block_vpn_fortinet', 'block_vpn_cisco', 'block_vpn_paloalto',
            'block_ztna_zscaler', 'block_ztna_netskope', 'block_ztna_cloudflare',
            'block_ztna_tailscale', 'block_vpn_commercial',
            'block_msg_whatsapp', 'block_msg_telegram', 'block_msg_messenger',
            'block_msg_teams_skype', 'block_msg_discord', 'block_msg_slack',
            'block_msg_zoom_meet', 'block_msg_others',
            'schedule_enable', 'schedule_weekend',
            'corp_enable', 'corp_protect_netskope', 'corp_protect_idp', 'corp_reverse_lookup',
            'corp_protect_tools', 'corp_protect_cloudflare',
            'corp_protect_helpdesk', 'corp_protect_voip',
            'enable_upstream_forwarding'
        );
        foreach ($checkbox_keys as $chk) {
            if (!isset($cfg[$chk])) {
                // Proteções essenciais devem ser padrão ativas se não definidas
                if ($chk === 'corp_protect_tools' || $chk === 'corp_protect_cloudflare' || $chk === 'corp_protect_netskope' || $chk === 'corp_protect_idp' || $chk === 'corp_protect_helpdesk' || $chk === 'corp_protect_voip') {
                    $cfg[$chk] = 'yes';
                } else {
                    $cfg[$chk] = 'no';
                }
            }
        }
        if (empty($cfg['block_action'])) {
            $cfg['block_action'] = 'block_page';
        }
        return $cfg;
    }

    // Configuração inicial padrão (apenas se instalação virgem sem registro prévio):
    return array(
        'enable'                     => 'yes',
        'block_adult'                => 'yes',
        'block_gambling'             => 'yes',
        'block_gaming'               => 'yes',
        'block_dns_bypass'           => 'no',
        'enable_upstream_forwarding' => 'no',
        'block_action'               => 'block_page',
        'corp_protect_netskope'      => 'yes',
        'corp_protect_idp'           => 'yes',
        'corp_protect_tools'         => 'yes',
        'corp_protect_cloudflare'    => 'yes',
        'corp_protect_helpdesk'      => 'yes',
        'corp_protect_voip'          => 'yes',
        'corp_reverse_lookup'        => 'yes',
        'initialized'                => 'yes'
    );
}

/**
 * Função chamada pelo pfSense ao salvar configurações
 */
function rules_wam_resync() {
    global $config;

    $wam_cfg = rules_wam_get_config();
    log_error("[Rules WAM] Resync disparado.");

    if (!rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
        log_error("[Rules WAM] 'enable' desmarcado. Desabilitando serviço...");
        rules_wam_disable();
        return;
    }

    if (rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null)) {
        if (!rules_wam_is_in_schedule_window($wam_cfg)) {
            rules_wam_suspend_schedule();
            return;
        }
    }

    rules_wam_apply_rules($wam_cfg);
}

function wam_resync() {
    rules_wam_resync();
}

/**
 * Aplica as regras ativas no Unbound
 */
function rules_wam_apply_rules($wam_cfg = null) {
    log_error("[Rules WAM] Compilando regras de bloqueio por categoria...");

    if (empty($wam_cfg) || !is_array($wam_cfg)) {
        $wam_cfg = rules_wam_get_config();
    }

    if (!isset($wam_cfg['enable'])) {
        $wam_cfg['enable'] = 'yes';
    }

    $all_cat_keys = array(
        'block_adult', 'block_gambling', 'block_news', 'block_social',
        'block_sports', 'block_gaming', 'block_streaming', 'block_shopping',
        'block_p2p', 'block_doh', 'block_dns_bypass', 'block_vpn', 'block_messaging',
        'enable_upstream_forwarding'
    );
    foreach ($all_cat_keys as $ack) {
        if (!isset($wam_cfg[$ack])) {
            $wam_cfg[$ack] = 'no';
        }
    }

    $blocked_domains = array();
    $whitelist = array();
    $bypass_ips = array();

    if (!empty($wam_cfg['custom_whitelist'])) {
        $lines = preg_split('/\r\n|\r|\n/', $wam_cfg['custom_whitelist']);
        foreach ($lines as $line) {
            $d = rules_wam_clean_domain($line);
            if ($d) {
                $whitelist[$d] = true;
            }
        }
    }

    // Garante que o Google Meet e recursos essenciais nunca sejam bloqueados
    $whitelist['meet.google.com'] = true;
    $whitelist['apis.google.com'] = true;
    $whitelist['ssl.gstatic.com'] = true;
    $whitelist['clients6.google.com'] = true;
    $whitelist['madeiramadeira.local'] = true;
    $whitelist['madeiramadeira.com.br'] = true;

    // Proteção Essencial de Atendimento, Suporte e Helpdesk (Whitelist incondicional)
    $whitelist['zendesk.com'] = true;
    $whitelist['zdassets.com'] = true;
    $whitelist['zdstatic.com'] = true;
    $whitelist['zdusercontent.com'] = true;
    $whitelist['zopim.com'] = true;
    $whitelist['zopim.io'] = true;
    $whitelist['zopim.net'] = true;
    $whitelist['glpi-project.org'] = true;
    $whitelist['glpi-network.cloud'] = true;
    $whitelist['glpi-network.com'] = true;
    $whitelist['services.glpi-network.com'] = true;
    $whitelist['teclib.com'] = true;
    $whitelist['screenconnect.com'] = true;
    $whitelist['screenconnect.net'] = true;
    $whitelist['connectwise.com'] = true;
    $whitelist['connectwise.net'] = true;
    $whitelist['hostedrmm.com'] = true;

    // --- Integração Corporativa: Netskope, IdP, Ferramentas de TI, Cloudflare, Helpdesk e SIP/VoIP ---
    $protect_netskope = (!isset($wam_cfg['corp_protect_netskope']) || rules_wam_is_checked($wam_cfg['corp_protect_netskope']));
    $protect_idp = (!isset($wam_cfg['corp_protect_idp']) || rules_wam_is_checked($wam_cfg['corp_protect_idp']));
    $protect_tools = (!isset($wam_cfg['corp_protect_tools']) || rules_wam_is_checked($wam_cfg['corp_protect_tools']));
    $protect_cloudflare = (!isset($wam_cfg['corp_protect_cloudflare']) || rules_wam_is_checked($wam_cfg['corp_protect_cloudflare']));
    $protect_helpdesk = (!isset($wam_cfg['corp_protect_helpdesk']) || rules_wam_is_checked($wam_cfg['corp_protect_helpdesk']));
    $protect_voip = (!isset($wam_cfg['corp_protect_voip']) || rules_wam_is_checked($wam_cfg['corp_protect_voip']));
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $corp_domains = rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '');
    $corp_dns_ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');
    $corp_reverse = (!isset($wam_cfg['corp_reverse_lookup']) || rules_wam_is_checked($wam_cfg['corp_reverse_lookup']));
    $block_action = !empty($wam_cfg['block_action']) ? trim($wam_cfg['block_action']) : 'block_page';

    if ($protect_netskope) {
        $netskope_domains = array(
            'netskope.com', 'goskope.com', 'netskopedns.com', 'netskope.io',
            'addon-netskope.com', 'nsclient.netskope.com', 'npa.netskope.com',
            'gateway.goskope.com', 'ep.goskope.com', 'ca.goskope.com',
            'eu.goskope.com', 'us.goskope.com', 'app.netskope.com'
        );
        foreach ($netskope_domains as $nd) {
            $whitelist[$nd] = true;
        }
    }

    if ($protect_idp) {
        $idp_domains = array(
            'login.microsoftonline.com', 'login.microsoft.com', 'microsoft.com',
            'msftauth.net', 'msauth.net', 'windows.net', 'office.com',
            'okta.com', 'oktacdn.com', 'accounts.google.com'
        );
        foreach ($idp_domains as $idp) {
            $whitelist[$idp] = true;
        }
    }

    // Liberação e Proteção de Ferramentas de TI e Downloads Administrativos (PuTTY, WinSCP, etc.)
    if ($protect_tools) {
        $tools_domains = array(
            'putty.org', 'chiark.greenend.org.uk', 'greenend.org.uk', 'the.earth.li', 'tartarus.org',
            'winscp.net', 'filezilla-project.org', '7-zip.org', 'notepad-plus-plus.org',
            'github.com', 'githubusercontent.com', 'raw.githubusercontent.com', 'github.githubassets.com',
            'gitlab.com', 'git-scm.com', 'sourceforge.net', 'osdn.net',
            'sysinternals.com', 'live.sysinternals.com', 'download.sysinternals.com',
            'wireshark.org', 'nmap.org', 'dbeaver.io', 'postman.com', 'curl.se', 'mobatek.net',
            'python.org', 'pypi.org', 'pypi.python.org', 'files.pythonhosted.org'
        );
        foreach ($tools_domains as $td) {
            $whitelist[$td] = true;
        }
    }

    // Proteção da Infraestrutura Pública Cloudflare (CDN cdnjs, Captchas Turnstile, APIs públicas)
    if ($protect_cloudflare) {
        $cf_domains = array(
            'cloudflare.com', 'cdnjs.cloudflare.com', 'challenges.cloudflare.com',
            'static.cloudflareinsights.com', 'cloudflareinsights.com', 'cf-assets.net'
        );
        foreach ($cf_domains as $cfd) {
            $whitelist[$cfd] = true;
        }
    }

    // Liberação e Proteção de Plataformas de Helpdesk, ITSM e Suporte Remoto (Zendesk, GLPI, ScreenConnect)
    if ($protect_helpdesk) {
        $helpdesk_domains = array(
            'zendesk.com', 'zdassets.com', 'zdstatic.com', 'zdusercontent.com',
            'zopim.com', 'zopim.io', 'zopim.net',
            'glpi-project.org', 'glpi-network.cloud', 'glpi-network.com',
            'services.glpi-network.com', 'teclib.com', 'teclib-edition.com',
            'screenconnect.com', 'screenconnect.net',
            'connectwise.com', 'connectwise.net', 'hostedrmm.com'
        );
        foreach ($helpdesk_domains as $hd) {
            $whitelist[$hd] = true;
        }
    }

    // Liberação e Proteção de Telefonia IP, PABX Cloud, Protocolo SIP e Telefones IP (SIP Phones)
    if ($protect_voip) {
        $voip_domains = array(
            // Servidores STUN / TURN essenciais para travessia NAT e sinalização VoIP/WebRTC
            'stun.l.google.com', 'stun1.l.google.com', 'stun2.l.google.com', 'stun3.l.google.com', 'stun4.l.google.com',
            'stun.sipgate.net', 'stun.voipbuster.com', 'stun.ekiga.net', 'stun.counterpath.com', 'stun.counterpath.net',
            // Softphones e clientes SIP
            'zoiper.com', 'linphone.org', 'microsip.org', 'micro-sip.org', 'counterpath.com', 'bria.com', 'sip.audio',
            // Fabricantes de Telefones IP (SIP Phone) e provisionamento remoto / RPS / TR-069
            'yealink.com', 'yealinkphones.com', 'ycs.yealink.com', 'rps.yealink.com',
            'grandstream.com', 'gdms.cloud', 'gaps.grandstream.com',
            'intelbras.com.br', 'intelbras.com',
            'fanvil.com', 'fdms.fanvil.com',
            'poly.com', 'polycom.com', 'snom.com',
            // PABX em Nuvem, Troncos SIP e Operadoras VoIP
            '3cx.com', '3cx.net', '3cx.eu', '3cx.us',
            'sipgate.de', 'sipgate.com', 'sipgate.net',
            'twilio.com', 'telnyx.com', 'plivo.com',
            'ringcentral.com', 'vonage.com', 'nexmo.com', '8x8.com',
            'voip.ms', 'callcentric.com', 'didlogic.com', 'flowroute.com',
            'jive.com', 'goto.com', 'gotoconnect.com', 'dialpad.com',
            'totalvoice.com.br', 'zenvia.com', 'locaweb.com.br', 'webex.com'
        );
        foreach ($voip_domains as $vd) {
            $whitelist[$vd] = true;
        }
    }

    if ($corp_enable && !empty($corp_domains)) {
        foreach ($corp_domains as $cdom) {
            $cdom_clean = rules_wam_clean_domain($cdom);
            if ($cdom_clean) {
                $whitelist[$cdom_clean] = true;
            }
        }
    }

    if (!empty($wam_cfg['bypass_ips'])) {
        $raw_ips = preg_split('/[\r\n,;]+/', $wam_cfg['bypass_ips']);
        foreach ($raw_ips as $rip) {
            $rip = trim($rip);
            if (filter_var($rip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $bypass_ips[] = $rip . '/32';
            } elseif (filter_var($rip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
                $bypass_ips[] = $rip . '/128';
            } elseif (preg_match('#^\d+\.\d+\.\d+\.\d+/\d+$#', $rip)) {
                $bypass_ips[] = $rip;
            }
        }
    }

    $categories_active = array();

    $category_map = array(
        'block_adult'     => array('label' => 'Conteúdo Adulto',        'file' => 'adult.txt'),
        'block_gambling'  => array('label' => 'Apostas & Bets',         'file' => 'gambling.txt'),
        'block_news'      => array('label' => 'Notícias & Portais',      'file' => 'news.txt'),
        'block_social'    => array('label' => 'Mídias Sociais',         'file' => 'social-media.txt'),
        'block_sports'    => array('label' => 'Esportes & Placares',    'file' => 'sports.txt'),
        'block_gaming'    => array('label' => 'Jogos & Games',          'file' => 'gaming.txt'),
        'block_streaming' => array('label' => 'Streaming & Vídeo',      'file' => 'streaming.txt'),
        'block_shopping'  => array('label' => 'Compras & E-commerce',   'file' => 'shopping.txt'),
        'block_p2p'       => array('label' => 'Torrents & P2P',         'file' => 'p2p.txt'),
        'block_doh'       => array('label' => 'Anti-Bypass DoH',        'file' => 'doh-providers.txt'),
        'block_vpn'       => array('label' => 'VPN, ZTNA & Proxies',    'file' => 'vpn-ztna.txt'),
        'block_messaging' => array('label' => 'Mensageiros & Chat',     'file' => 'messaging.txt'),
    );

    foreach ($category_map as $cfg_key => $meta) {
        if (rules_wam_is_checked($wam_cfg[$cfg_key] ?? null)) {
            $categories_active[] = $meta['label'];
            if ($cfg_key === 'block_vpn') {
                $vpn_sub_map = array(
                    'block_vpn_fortinet'    => 'vpn-fortinet.txt',
                    'block_vpn_cisco'       => 'vpn-cisco.txt',
                    'block_vpn_paloalto'    => 'vpn-paloalto.txt',
                    'block_ztna_zscaler'    => 'ztna-zscaler.txt',
                    'block_ztna_netskope'   => 'ztna-netskope.txt',
                    'block_ztna_cloudflare' => 'ztna-cloudflare.txt',
                    'block_ztna_tailscale'  => 'ztna-tailscale.txt',
                    'block_vpn_commercial'  => 'vpn-commercial.txt',
                );
                $any_sub_specified = false;
                foreach (array_keys($vpn_sub_map) as $sub_k) {
                    if (isset($wam_cfg[$sub_k])) {
                        $any_sub_specified = true;
                        break;
                    }
                }
                foreach ($vpn_sub_map as $sub_k => $sub_f) {
                    if ($sub_k === 'block_ztna_netskope' && $protect_netskope) {
                        continue; // Netskope protegido contra bloqueio acidental
                    }
                    if ($sub_k === 'block_ztna_cloudflare' && $protect_cloudflare) {
                        // Se proteção à Cloudflare estiver ativa, só bloqueia WARP se explicitamente marcado
                        if (!rules_wam_is_checked($wam_cfg['block_ztna_cloudflare'] ?? null)) {
                            continue;
                        }
                    }
                    $is_sub_active = $any_sub_specified ? rules_wam_is_checked($wam_cfg[$sub_k] ?? null) : true;
                    if ($is_sub_active) {
                        rules_wam_load_feed_domains($sub_f, $blocked_domains, $whitelist);
                    }
                }
            } elseif ($cfg_key === 'block_messaging') {
                $msg_sub_map = array(
                    'block_msg_whatsapp'    => 'msg-whatsapp.txt',
                    'block_msg_telegram'    => 'msg-telegram.txt',
                    'block_msg_messenger'   => 'msg-messenger.txt',
                    'block_msg_teams_skype' => 'msg-teams-skype.txt',
                    'block_msg_discord'     => 'msg-discord.txt',
                    'block_msg_slack'       => 'msg-slack.txt',
                    'block_msg_zoom_meet'   => 'msg-zoom-meet.txt',
                    'block_msg_others'      => 'msg-others.txt',
                );
                $any_sub_specified = false;
                foreach (array_keys($msg_sub_map) as $sub_k) {
                    if (isset($wam_cfg[$sub_k])) {
                        $any_sub_specified = true;
                        break;
                    }
                }
                foreach ($msg_sub_map as $sub_k => $sub_f) {
                    $is_sub_active = $any_sub_specified ? rules_wam_is_checked($wam_cfg[$sub_k] ?? null) : true;
                    if ($is_sub_active) {
                        rules_wam_load_feed_domains($sub_f, $blocked_domains, $whitelist);
                    }
                }
            } else {
                rules_wam_load_feed_domains($meta['file'], $blocked_domains, $whitelist);
            }
        }
    }

    if (!empty($wam_cfg['custom_blacklist'])) {
        $lines = preg_split('/\r\n|\r|\n/', $wam_cfg['custom_blacklist']);
        foreach ($lines as $line) {
            $d = rules_wam_clean_domain($line);
            if ($d && !isset($whitelist[$d])) {
                $blocked_domains[$d] = true;
            }
        }
    }

    $total = count($blocked_domains);
    $conf_content  = "# ====================================================\n";
    $conf_content .= "# Rules WAM - Auto-gerado\n";
    $conf_content .= "# Atualizado em: " . date('Y-m-d H:i:s') . "\n";
    $conf_content .= "# Categorias ativas (" . count($categories_active) . "): " . implode(', ', $categories_active) . "\n";
    $conf_content .= "# Total de dominios bloqueados: {$total}\n";
    $conf_content .= "# ====================================================\n";
    $conf_content .= "server:\n";
    $conf_content .= "  log-local-actions: yes\n";
    $conf_content .= "  log-queries: yes\n";

    // --- Integração Corporativa: Active Directory e NPS RADIUS (Anti-Rebinding e DNSSEC Bypass) ---
    if ($corp_enable && !empty($corp_domains)) {
        $conf_content .= "  # Excecoes para Active Directory e NPS RADIUS (Anti-Rebinding e DNSSEC Bypass)\n";
        foreach ($corp_domains as $cdom) {
            $cdom = rules_wam_clean_domain($cdom);
            if (!empty($cdom)) {
                $conf_content .= "  private-domain: \"{$cdom}\"\n";
                $conf_content .= "  domain-insecure: \"{$cdom}\"\n";
            }
        }
        if ($corp_reverse) {
            $conf_content .= "  private-domain: \"in-addr.arpa\"\n";
            $conf_content .= "  domain-insecure: \"in-addr.arpa\"\n";
        }
    }

    // --- Autorização Global de Redes Corporativas no Unbound (Access Control) ---
    $corp_subnets_raw = !empty($wam_cfg['corp_allowed_subnets']) ? $wam_cfg['corp_allowed_subnets'] : "172.24.0.0/16\n192.168.0.0/16\n192.192.0.0/16\n10.0.0.0/8";
    $corp_subnets = rules_wam_parse_list($corp_subnets_raw);
    if (!empty($corp_subnets)) {
        $conf_content .= "  # Redes Corporativas Autorizadas no Unbound (18 Unidades / Matriz / Filiais)\n";
        foreach ($corp_subnets as $snet) {
            $snet = trim($snet);
            if (empty($snet)) continue;
            if (preg_match('#^(\d{1,3}\.){3}\d{1,3}(/(?:[0-9]|[12][0-9]|3[0-2]))?$#', $snet)) {
                $conf_content .= "  access-control: {$snet} allow\n";
            }
        }
    }

    $block_page_ip = !empty($wam_cfg['block_page_ip']) ? trim($wam_cfg['block_page_ip']) : '';
    $all_ifaces = rules_wam_get_configured_interfaces(false);
    $ip_found = false;
    if (!empty($block_page_ip) && filter_var($block_page_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        foreach ($all_ifaces as $if_data) {
            if (!empty($if_data['ip']) && $if_data['ip'] === $block_page_ip) {
                $ip_found = true;
                break;
            }
        }
    }
    if (!$ip_found) {
        $block_page_ip = rules_wam_get_lan_ip();
    }

    // Remove subdomínios cujo domínio pai já está na lista para evitar conflitos no Unbound
    $clean_domains = array();
    foreach ($blocked_domains as $d => $v) {
        if (rules_wam_is_whitelisted($d, $whitelist)) {
            continue;
        }
        $parts = explode('.', $d);
        $has_parent = false;
        while (count($parts) > 1) {
            array_shift($parts);
            $parent = implode('.', $parts);
            if (isset($blocked_domains[$parent])) {
                $has_parent = true;
                break;
            }
        }
        if (!$has_parent) {
            $clean_domains[$d] = true;
        }
    }

    foreach (array_keys($clean_domains) as $dom) {
        if ($block_action === 'always_null') {
            $conf_content .= "  local-zone: \"{$dom}\" always_null\n";
        } else {
            $conf_content .= "  local-zone: \"{$dom}\" redirect\n";
            $conf_content .= "  local-data: \"{$dom} 60 IN A {$block_page_ip}\"\n";
        }
    }

    // Grava o arquivo de regras do Unbound
    file_put_contents(WAM_CONF_FILE, $conf_content);
    @chmod(WAM_CONF_FILE, 0644);

    // Neutraliza qualquer arquivo antigo em conf.d para evitar duplicidade
    if (file_exists('/var/unbound/conf.d/wam_blocklist.conf')) {
        @file_put_contents('/var/unbound/conf.d/wam_blocklist.conf', "# Rules WAM - Migrado para " . WAM_CONF_FILE . "\n");
    }

    // Habilita log de consultas no pfSense
    config_set_path('unbound/log_queries', 'yes');

    // Injeta include no Unbound custom_options usando base64 (padrão pfSense)
    $raw_opts = config_get_path('unbound/custom_options', '');
    $cur_opts = '';
    if (!empty($raw_opts)) {
        $decoded = @base64_decode($raw_opts, true);
        if ($decoded !== false && base64_encode($decoded) === $raw_opts) {
            $cur_opts = $decoded;
        } else {
            $cur_opts = $raw_opts;
        }
    }

    // Limpa referências antigas e adiciona include correto
    $opt_lines = explode("\n", $cur_opts);
    $cleaned_opt_lines = array();
    foreach ($opt_lines as $oline) {
        $tline = trim($oline);
        if (empty($tline)) continue;
        if (strpos($tline, 'wam_blocklist.conf') !== false) {
            continue;
        }
        $cleaned_opt_lines[] = $tline;
    }
    $cleaned_opt_lines[] = "include: " . WAM_CONF_FILE;
    $new_custom = trim(implode("\n", $cleaned_opt_lines));
    $ub_conf = '/var/unbound/unbound.conf';
    $need_unbound_configure = ($new_custom !== trim($cur_opts));
    if (file_exists($ub_conf) && strpos(@file_get_contents($ub_conf), 'wam_blocklist.conf') === false) {
        $need_unbound_configure = true;
    }
    if ($need_unbound_configure) {
        config_set_path('unbound/custom_options', base64_encode($new_custom));
        write_config("Rules WAM ativado no Unbound com logging");
        if (function_exists('services_unbound_configure')) {
            services_unbound_configure();
        }
    }

    // Se a ação for exibir o Banner, assegura que o NGINX HTTP/HTTPS do WAM esteja ativo e sincronizado
    if ($block_action === 'block_page') {
        rules_wam_sync_banner_nginx();
    }

    $status_data = array(
        'enabled' => true,
        'schedule_active' => rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null),
        'is_blocking' => true,
        'updated_at' => date('Y-m-d H:i:s'),
        'total_blocked' => $total,
        'categories' => $categories_active,
        'whitelist_count' => count($whitelist),
        'bypass_ips_count' => count($bypass_ips),
        'dns_bypass_protection' => rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? null) ? 'Ativo (Redirecionando 8.8.8.8 / 1.1.1.1)' : 'Desativado',
        'upstream_forwarding' => rules_wam_is_checked($wam_cfg['enable_upstream_forwarding'] ?? null) ? 'Ativo (Google 8.8.8.8 & Cloudflare 1.1.1.1)' : 'Desativado',
        'corp_integration' => $corp_enable ? 'Ativo (AD & NPS via IPsec)' : 'Desativado',
        'netskope_protection' => $protect_netskope ? 'Ativo (Auto-Whitelist)' : 'Desativado',
        'helpdesk_protection' => $protect_helpdesk ? 'Ativo (Zendesk, GLPI, ScreenConnect)' : 'Desativado',
        'voip_protection' => $protect_voip ? 'Ativo (SIP & SIP Phone)' : 'Desativado'
    );
    file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));

    rules_wam_sync_domain_overrides($wam_cfg);
    rules_wam_reload_unbound();
    rules_wam_sync_firewall_rules($wam_cfg);
    log_error("[Rules WAM] Sucesso: {$total} domínios bloqueados aplicados no Unbound DNS.");
}

function rules_wam_suspend_schedule() {
    $wam_cfg = rules_wam_get_config();
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $corp_domains = rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '');
    $corp_dns_ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');
    $corp_reverse = (!isset($wam_cfg['corp_reverse_lookup']) || rules_wam_is_checked($wam_cfg['corp_reverse_lookup']));
    $upstream_enable = rules_wam_is_checked($wam_cfg['enable_upstream_forwarding'] ?? null);

    $conf = "# Rules WAM - Fora do Horario Comercial (Acesso Liberado)\nserver:\n  log-local-actions: yes\n";
    if ($corp_enable && !empty($corp_domains)) {
        foreach ($corp_domains as $cdom) {
            $cdom = rules_wam_clean_domain($cdom);
            if (!empty($cdom)) {
                $conf .= "  private-domain: \"{$cdom}\"\n";
                $conf .= "  domain-insecure: \"{$cdom}\"\n";
            }
        }
        if ($corp_reverse) {
            $conf .= "  private-domain: \"in-addr.arpa\"\n";
            $conf .= "  domain-insecure: \"in-addr.arpa\"\n";
        }
    }
    $corp_subnets_raw = !empty($wam_cfg['corp_allowed_subnets']) ? $wam_cfg['corp_allowed_subnets'] : "172.24.0.0/16\n192.168.0.0/16\n192.192.0.0/16\n10.0.0.0/8";
    $corp_subnets = rules_wam_parse_list($corp_subnets_raw);
    if (!empty($corp_subnets)) {
        foreach ($corp_subnets as $snet) {
            $snet = trim($snet);
            if (empty($snet)) continue;
            if (preg_match('#^(\d{1,3}\.){3}\d{1,3}(/(?:[0-9]|[12][0-9]|3[0-2]))?$#', $snet)) {
                $conf .= "  access-control: {$snet} allow\n";
            }
        }
    }
    file_put_contents(WAM_CONF_FILE, $conf);
    @chmod(WAM_CONF_FILE, 0644);

    $status_data = array(
        'enabled' => true,
        'schedule_active' => true,
        'is_blocking' => false,
        'updated_at' => date('Y-m-d H:i:s'),
        'total_blocked' => 0,
        'categories' => array('Horário Comercial Pausado (Acesso Liberado)'),
        'whitelist_count' => 0,
        'bypass_ips_count' => 0
    );
    file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));
    rules_wam_reload_unbound();
    log_error("[Rules WAM] Fora do horário comercial: bloqueios temporariamente liberados.");
}

function rules_wam_disable() {
    @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Desativado\nserver:\n");
    @chmod(WAM_CONF_FILE, 0644);
    if (file_exists('/var/unbound/conf.d/wam_blocklist.conf')) {
        @file_put_contents('/var/unbound/conf.d/wam_blocklist.conf', "# Desativado\nserver:\n");
    }

    $raw_opts = config_get_path('unbound/custom_options', '');
    $cur_opts = '';
    if (!empty($raw_opts)) {
        $decoded = @base64_decode($raw_opts, true);
        if ($decoded !== false && base64_encode($decoded) === $raw_opts) {
            $cur_opts = $decoded;
        } else {
            $cur_opts = $raw_opts;
        }
    }

    $lines = explode("\n", $cur_opts);
    $new_lines = array();
    foreach ($lines as $line) {
        $tline = trim($line);
        if (empty($tline)) continue;
        if (strpos($tline, 'wam_blocklist.conf') === false) {
            $new_lines[] = $tline;
        }
    }
    $new_custom = trim(implode("\n", $new_lines));
    if ($new_custom !== trim($cur_opts)) {
        config_set_path('unbound/custom_options', empty($new_custom) ? '' : base64_encode($new_custom));
        write_config("Rules WAM desativado no Unbound");
        if (function_exists('services_unbound_configure')) {
            services_unbound_configure();
        }
    }

    rules_wam_sync_domain_overrides(array('corp_enable' => 'no'));

    $status_data = array(
        'enabled' => false,
        'schedule_active' => false,
        'is_blocking' => false,
        'updated_at' => date('Y-m-d H:i:s'),
        'total_blocked' => 0,
        'categories' => array(),
        'whitelist_count' => 0,
        'bypass_ips_count' => 0
    );
    file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));
    rules_wam_reload_unbound();
    rules_wam_remove_firewall_rules();
    log_error("[Rules WAM] Serviço desabilitado.");
}

/**
 * Remove as regras automáticas de firewall do Rules WAM
 */
function rules_wam_remove_firewall_rules() {
    require_once("config.inc");
    require_once("filter.inc");
    global $config;

    init_config_arr(array("filter", "rule"));
    init_config_arr(array("nat", "rule"));
    $changed = false;
    $new_rules = array();
    foreach ($config["filter"]["rule"] as $r) {
        if (isset($r["descr"]) && strpos($r["descr"], "Rules WAM") !== false) {
            $changed = true;
        } else {
            $new_rules[] = $r;
        }
    }

    $new_nat = array();
    foreach ($config["nat"]["rule"] as $nr) {
        if (isset($nr["descr"]) && strpos($nr["descr"], "Rules WAM") !== false) {
            $changed = true;
        } else {
            $new_nat[] = $nr;
        }
    }

    if ($changed) {
        $config["filter"]["rule"] = $new_rules;
        $config["nat"]["rule"] = $new_nat;
        write_config("Rules WAM: Remocao de regras de protecao de firewall e NAT");
        filter_configure();
    }
}

/**
 * Sincroniza regras de firewall automáticas para evitar bypass em dispositivos móveis (Android/iOS)
 * e bloquear portas nativas de mensageiros como o WhatsApp (5222, 5223, etc.)
 */
function rules_wam_sync_firewall_rules($wam_cfg = null) {
    require_once("config.inc");
    require_once("filter.inc");
    global $config;

    if ($wam_cfg === null) {
        $wam_cfg = rules_wam_get_config();
    }

    if (!rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
        rules_wam_remove_firewall_rules();
        return;
    }

    init_config_arr(array("aliases", "alias"));
    init_config_arr(array("filter", "rule"));

    // 1. Alias de Portas do WhatsApp
    $alias_name = "WAM_WhatsApp_Ports";
    $alias_idx = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if ($a["name"] === $alias_name) {
            $alias_idx = $idx;
            break;
        }
    }
    $alias_data = array(
        "name" => $alias_name,
        "type" => "port",
        "address" => "5222 5223 4244",
        "descr" => "Portas de comunicacao nativa WhatsApp Mobile (Rules WAM)",
        "detail" => "5222 (XMPP)||5223 (SSL)||4244 (Media)"
    );
    if ($alias_idx !== null) {
        $config["aliases"]["alias"][$alias_idx] = $alias_data;
    } else {
        $config["aliases"]["alias"][] = $alias_data;
    }

    // 2. Alias de Redes IP do WhatsApp (AS63293 e clusters de chat Meta)
    $alias_nets_name = "WAM_WhatsApp_Nets";
    $alias_nets_idx = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if ($a["name"] === $alias_nets_name) {
            $alias_nets_idx = $idx;
            break;
        }
    }
    $wa_cidrs = array(
        "157.240.128.0/17", "129.134.128.0/17", "102.132.112.0/20", "102.221.188.0/22",
        "185.89.216.0/22", "196.49.68.0/23", "204.15.20.0/22", "31.13.64.0/18"
    );
    $alias_nets_data = array(
        "name" => $alias_nets_name,
        "type" => "network",
        "address" => implode(" ", $wa_cidrs),
        "descr" => "Redes IP WhatsApp Inc AS63293 (Rules WAM)",
        "detail" => implode("||", $wa_cidrs)
    );
    if ($alias_nets_idx !== null) {
        $config["aliases"]["alias"][$alias_nets_idx] = $alias_nets_data;
    } else {
        $config["aliases"]["alias"][] = $alias_nets_data;
    }

    // 2.1 Alias para Servidores DNS / Controladores de Dominio AD e NPS Matriz
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $corp_dns_ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');
    $valid_ad_ips = array();
    if ($corp_enable && !empty($corp_dns_ips)) {
        foreach ($corp_dns_ips as $cip) {
            if (filter_var($cip, FILTER_VALIDATE_IP)) {
                $valid_ad_ips[] = $cip;
            }
        }
    }
    $alias_corp_name = "WAM_Corp_AD_DNS";
    $alias_corp_idx = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if ($a["name"] === $alias_corp_name) {
            $alias_corp_idx = $idx;
            break;
        }
    }
    if (!empty($valid_ad_ips)) {
        $alias_corp_data = array(
            "name" => $alias_corp_name,
            "type" => "host",
            "address" => implode(" ", $valid_ad_ips),
            "descr" => "Servidores DNS/AD e NPS RADIUS Matriz (Rules WAM)",
            "detail" => implode("||", $valid_ad_ips)
        );
        if ($alias_corp_idx !== null) {
            $config["aliases"]["alias"][$alias_corp_idx] = $alias_corp_data;
        } else {
            $config["aliases"]["alias"][] = $alias_corp_data;
        }
    } elseif ($alias_corp_idx !== null) {
        unset($config["aliases"]["alias"][$alias_corp_idx]);
        $config["aliases"]["alias"] = array_values($config["aliases"]["alias"]);
    }

    // 2.2 Alias de Portas do Banner HTTP/HTTPS (Portas 80 e 443)
    $alias_banner_name = "WAM_Banner_Ports";
    $alias_banner_idx = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if ($a["name"] === $alias_banner_name) {
            $alias_banner_idx = $idx;
            break;
        }
    }
    $alias_banner_data = array(
        "name" => $alias_banner_name,
        "type" => "port",
        "address" => "80 443",
        "descr" => "Portas HTTP/HTTPS Banner de Bloqueio (Rules WAM)",
        "detail" => "80 (HTTP)||443 (HTTPS)"
    );
    if ($alias_banner_idx !== null) {
        $config["aliases"]["alias"][$alias_banner_idx] = $alias_banner_data;
    } else {
        $config["aliases"]["alias"][] = $alias_banner_data;
    }

    // 3. Interfaces internas ativas configuradas no pfSense (com seus nomes amigáveis reais)
    $configured_internal = rules_wam_get_configured_interfaces(false);
    if (empty($configured_internal)) {
        $configured_internal = array(
            'lan' => array('key' => 'lan', 'descr' => 'LAN', 'is_internal' => true)
        );
    }
    $internal_ifaces = array_keys($configured_internal);
    $if_list = implode(",", $internal_ifaces);

    // 4. Filtra regras existentes que não sejam do Rules WAM
    $cleaned_rules = array();
    foreach ($config["filter"]["rule"] as $r) {
        if (!isset($r["descr"]) || strpos($r["descr"], "Rules WAM") === false) {
            $cleaned_rules[] = $r;
        }
    }

    $rules_to_add = array();

    // Identifica protocolo e porta da WebGUI (ex: 50443, 8443, 443)
    $gui_proto = !empty($config['system']['webgui']['protocol']) ? $config['system']['webgui']['protocol'] : 'https';
    $gui_port = !empty($config['system']['webgui']['port']) ? $config['system']['webgui']['port'] : ($gui_proto === 'https' ? '50443' : '80');

    // Blindagem de Acesso Administrativo (LAN e WAN):
    // 1. Anti-lockout na LAN sempre garantido
    unset($config['system']['webgui']['noantilockout']);
    // 2. Sem bloqueio por DNS Rebind
    $config['system']['webgui']['nodnsrebindcheck'] = true;
    // 3. Sem redirecionamento HTTP nativo (libera porta 80 para o Banner)
    $config['system']['webgui']['disablehttpredirect'] = true;
    // 4. Se a WAN for rede privada RFC1918 (comum em testes e laboratorios), desativa o descarte
    if (isset($config['interfaces']['wan']['blockprivatenets'])) {
        unset($config['interfaces']['wan']['blockprivatenets']);
    }
    if (isset($config['interfaces']['wan']['blockbogons'])) {
        unset($config['interfaces']['wan']['blockbogons']);
    }

    // Regra WAN Permanente: Garante acesso WebGUI na WAN (Porta $gui_port, ex: 50443)
    $rules_to_add[] = array(
        "id" => "",
        "tracker" => "1700000010",
        "type" => "pass",
        "interface" => "wan",
        "ipprotocol" => "inet46",
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "quick" => "yes",
        "protocol" => "tcp",
        "source" => array("any" => true),
        "destination" => array(
            "any" => true,
            "port" => (string)$gui_port
        ),
        "descr" => "Rules WAM - Acesso Permanente WebGUI WAN (Porta {$gui_port})",
        "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
    );

    // Regras Permanentes por Interface Interna: WebGUI e Banners HTTP/HTTPS (Portas 80 e 443)
    // Traz a descrição configurada no pfSense (Ex: LAN, LAN_CORP, WIFI_VISITANTES, etc.)
    $tracker_idx = 11;
    foreach ($configured_internal as $if_key => $if_data) {
        $if_label = !empty($if_data['descr']) ? $if_data['descr'] : strtoupper($if_key);

        // Regra de Acesso WebGUI na Interface
        $rules_to_add[] = array(
            "id" => "",
            "tracker" => (string)(1700000000 + $tracker_idx++),
            "type" => "pass",
            "interface" => $if_key,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "quick" => "yes",
            "protocol" => "tcp",
            "source" => array("any" => true),
            "destination" => array(
                "any" => true,
                "port" => (string)$gui_port
            ),
            "descr" => "Rules WAM - Acesso Permanente WebGUI {$if_label} (Porta {$gui_port})",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
        );

        // Regra de Liberação do Banner HTTP/HTTPS na Interface
        $rules_to_add[] = array(
            "id" => "",
            "tracker" => (string)(1700000000 + $tracker_idx++),
            "type" => "pass",
            "interface" => $if_key,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "quick" => "yes",
            "protocol" => "tcp",
            "source" => array("any" => true),
            "destination" => array(
                "any" => true,
                "port" => "WAM_Banner_Ports"
            ),
            "descr" => "Rules WAM - Liberacao Portas Banner HTTP/HTTPS {$if_label} (80 e 443)",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
        );
    }

    // Regra Flutuante para todas as interfaces internas ativas
    $rules_to_add[] = array(
        "id" => "",
        "tracker" => "1700000099",
        "type" => "pass",
        "interface" => $if_list,
        "ipprotocol" => "inet46",
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "floating" => "yes",
        "quick" => "yes",
        "protocol" => "tcp",
        "source" => array("any" => true),
        "destination" => array(
            "any" => true,
            "port" => "WAM_Banner_Ports"
        ),
        "descr" => "Rules WAM - Liberacao Portas Banner HTTP/HTTPS Global (80 e 443)",
        "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
    );

    // 5. Regra Anti-Bypass DoT (Porta 853) - Bloqueia DNS Privado do Android
    $rules_to_add[] = array(
        "id" => "",
        "tracker" => "1700000101",
        "type" => "reject",
        "interface" => $if_list,
        "ipprotocol" => "inet46",
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "floating" => "yes",
        "quick" => "yes",
        "protocol" => "tcp/udp",
        "source" => array("any" => true),
        "destination" => array(
            "any" => true,
            "port" => "853"
        ),
        "descr" => "Rules WAM - Anti-Bypass DNS Privado Android (DoT 853)",
        "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
    );

    // 6. Regra WhatsApp Mobile - Bloqueia portas nativas 5222/5223/4244/3478/5349 e redes IP AS63293
    $is_msg_active = rules_wam_is_checked($wam_cfg['block_messaging'] ?? null);
    $is_wa_active = !isset($wam_cfg['block_msg_whatsapp']) || rules_wam_is_checked($wam_cfg['block_msg_whatsapp']);
    if ($is_msg_active && $is_wa_active) {
        $rules_to_add[] = array(
            "id" => "",
            "tracker" => "1700000202",
            "type" => "reject",
            "interface" => $if_list,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "floating" => "yes",
            "quick" => "yes",
            "protocol" => "tcp/udp",
            "source" => array("any" => true),
            "destination" => array(
                "any" => true,
                "port" => $alias_name
            ),
            "descr" => "Rules WAM - Bloqueio de Portas App WhatsApp Mobile",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
        );

        $rules_to_add[] = array(
            "id" => "",
            "tracker" => "1700000303",
            "type" => "reject",
            "interface" => $if_list,
            "ipprotocol" => "inet46",
            "tag" => "",
            "tagged" => "",
            "direction" => "in",
            "floating" => "yes",
            "quick" => "yes",
            "protocol" => "tcp/udp",
            "source" => array("any" => true),
            "destination" => array(
                "address" => $alias_nets_name
            ),
            "descr" => "Rules WAM - Bloqueio de Redes IP WhatsApp Mobile (AS63293)",
            "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => time(), "username" => "Rules WAM")
        );
    }

    // 7. Anti-Bypass DNS Porta 53 (Interceptar consultas a DNS externos como 8.8.8.8)
    $block_dns_bypass = rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? 'no');
    init_config_arr(array("nat", "rule"));
    $cleaned_nat = array();
    foreach ($config["nat"]["rule"] as $nr) {
        if (!isset($nr["descr"]) || strpos($nr["descr"], "Rules WAM") === false) {
            $cleaned_nat[] = $nr;
        }
    }

    if ($block_dns_bypass) {
        foreach ($internal_ifaces as $idx => $intf) {
            $intf_label = !empty($configured_internal[$intf]['descr']) ? $configured_internal[$intf]['descr'] : strtoupper($intf);
            if (!empty($valid_ad_ips)) {
                $cleaned_nat[] = array(
                    "id" => "",
                    "tracker" => (string)(1700004030 + $idx),
                    "interface" => $intf,
                    "nordr" => "yes",
                    "ipprotocol" => "inet",
                    "protocol" => "tcp/udp",
                    "source" => array("any" => true),
                    "destination" => array(
                        "address" => $alias_corp_name,
                        "port" => "53"
                    ),
                    "descr" => "Rules WAM - Excecao NAT Anti-Bypass AD/DNS ({$intf_label})",
                    "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
                );
            }

            $cleaned_nat[] = array(
                "id" => "",
                "tracker" => (string)(1700004040 + $idx),
                "interface" => $intf,
                "ipprotocol" => "inet",
                "protocol" => "tcp/udp",
                "source" => array("any" => true),
                "destination" => array(
                    "not" => true,
                    "network" => "{$intf}ip",
                    "port" => "53"
                ),
                "target" => "127.0.0.1",
                "local-port" => "53",
                "descr" => "Rules WAM - Anti-Bypass DNS Redirection ({$intf_label} Porta 53)",
                "associated-rule-id" => "pass",
                "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
            );
        }

        if (!empty($valid_ad_ips)) {
            $rules_to_add[] = array(
                "id" => "",
                "tracker" => "1700000504",
                "type" => "pass",
                "interface" => $if_list,
                "ipprotocol" => "inet46",
                "tag" => "",
                "tagged" => "",
                "direction" => "in",
                "floating" => "yes",
                "quick" => "yes",
                "protocol" => "tcp/udp",
                "source" => array("any" => true),
                "destination" => array(
                    "address" => $alias_corp_name,
                    "port" => "53"
                ),
                "descr" => "Rules WAM - Liberacao Direta de DNS para Controladores de Dominio AD",
                "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => 1700000000, "username" => "Rules WAM")
            );
        }
    }

    // Adiciona as regras Rules WAM no topo
    foreach (array_reverse($rules_to_add) as $r_add) {
        array_unshift($cleaned_rules, $r_add);
    }

    $current_filter_rules = $config["filter"]["rule"] ?? array();
    $current_nat_rules = $config["nat"]["rule"] ?? array();

    $filter_changed = (serialize($cleaned_rules) !== serialize($current_filter_rules));
    $nat_changed = (serialize($cleaned_nat) !== serialize($current_nat_rules));

    if ($filter_changed || $nat_changed) {
        $config["nat"]["rule"] = $cleaned_nat;
        $config["filter"]["rule"] = $cleaned_rules;
        write_config("Rules WAM: Sincronizacao automatica de regras de protecao de rede e NAT");
        filter_configure();

        if ($is_msg_active && $is_wa_active) {
            mwexec('/sbin/pfctl -k 0.0.0.0/0 -k 157.240.0.0/16 2>/dev/null');
            mwexec('/sbin/pfctl -k 0.0.0.0/0 -k 129.134.0.0/16 2>/dev/null');
            mwexec('/sbin/pfctl -k 0.0.0.0/0 -k 31.13.64.0/18 2>/dev/null');
        }

        log_error("[Rules WAM] Regras automaticas de firewall sincronizadas com sucesso (DoT 853 e WhatsApp).");
    }
}

function rules_wam_is_in_schedule_window($wam_cfg) {
    $now_dow = intval(date('w'));
    $now_time = date('H:i');

    if ($now_dow === 0 || $now_dow === 6) {
        if (!rules_wam_is_checked($wam_cfg['schedule_weekend'] ?? null)) {
            return false;
        }
    }

    $start = !empty($wam_cfg['schedule_start']) ? $wam_cfg['schedule_start'] : '08:00';
    $end   = !empty($wam_cfg['schedule_end']) ? $wam_cfg['schedule_end'] : '18:00';
    $l_start = !empty($wam_cfg['schedule_lunch_start']) ? $wam_cfg['schedule_lunch_start'] : '';
    $l_end   = !empty($wam_cfg['schedule_lunch_end']) ? $wam_cfg['schedule_lunch_end'] : '';

    if (!empty($l_start) && !empty($l_end)) {
        if ($now_time >= $l_start && $now_time < $l_end) {
            return false;
        }
    }

    if ($now_time >= $start && $now_time < $end) {
        return true;
    }

    return false;
}

function rules_wam_is_whitelisted($domain, &$whitelist) {
    if (empty($domain)) return false;
    if (isset($whitelist[$domain])) return true;
    $parts = explode('.', $domain);
    while (count($parts) > 1) {
        array_shift($parts);
        $parent = implode('.', $parts);
        if (isset($whitelist[$parent])) return true;
    }
    return false;
}

function rules_wam_parse_list($str) {
    if (empty($str)) return array();
    $str = str_replace(array('\r\n', '\r', '\n', "\\r\\n", "\\r", "\\n"), "\n", $str);
    $items = preg_split('/[\r\n,;\s]+/', trim($str));
    $clean = array();
    foreach ($items as $it) {
        $it = trim($it);
        if (!empty($it)) {
            $clean[] = $it;
        }
    }
    return array_values(array_unique($clean));
}

/**
 * Sincroniza Domain Overrides no DNS Resolver do pfSense para Active Directory e NPS RADIUS (via VPN IPsec)
 */
function rules_wam_sync_domain_overrides($wam_cfg) {
    if (!function_exists('config_get_path') || !function_exists('config_set_path')) {
        return;
    }

    $existing_overrides = config_get_path('unbound/domainoverrides', array());
    if (!is_array($existing_overrides)) {
        $existing_overrides = array();
    }

    // Preserva overrides manuais pré-existentes, removendo apenas os gerenciados pelo Rules WAM
    $new_overrides = array();
    foreach ($existing_overrides as $ov) {
        if (!isset($ov['descr']) || strpos($ov['descr'], 'Rules WAM') === false) {
            $new_overrides[] = $ov;
        }
    }

    if (rules_wam_is_checked($wam_cfg['corp_enable'] ?? null)) {
        $domains = rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '');
        $ips = rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '');

        foreach ($domains as $dom) {
            $dom = rules_wam_clean_domain($dom);
            if (empty($dom)) continue;
            foreach ($ips as $ip) {
                if (filter_var($ip, FILTER_VALIDATE_IP)) {
                    $new_overrides[] = array(
                        'domain' => $dom,
                        'ip' => $ip,
                        'descr' => 'Rules WAM: AD/NPS Matriz IPsec'
                    );
                }
            }
        }

        if (rules_wam_is_checked($wam_cfg['corp_reverse_lookup'] ?? 'yes')) {
            $rev_zones = array();
            foreach ($ips as $ip) {
                $p = explode('.', $ip);
                if (count($p) === 4) {
                    $rev_zones[$p[0] . '.in-addr.arpa'] = true;
                    $rev_zones[$p[1] . '.' . $p[0] . '.in-addr.arpa'] = true;
                }
            }
            foreach (array_keys($rev_zones) as $rz) {
                foreach ($ips as $ip) {
                    if (filter_var($ip, FILTER_VALIDATE_IP)) {
                        $new_overrides[] = array(
                            'domain' => $rz,
                            'ip' => $ip,
                            'descr' => 'Rules WAM: Reverso AD/NPS Matriz IPsec'
                        );
                    }
                }
            }
        }
    }

    config_set_path('unbound/domainoverrides', $new_overrides);
}

function rules_wam_load_feed_domains($feed_file, &$blocked_domains, &$whitelist) {
    $path = WAM_FEEDS_DIR . '/' . $feed_file;
    if (!file_exists($path)) {
        return;
    }
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if (empty($line) || $line[0] === '#') {
            continue;
        }
        $d = rules_wam_clean_domain($line);
        if ($d && !rules_wam_is_whitelisted($d, $whitelist)) {
            $blocked_domains[$d] = true;
        }
    }
}

function rules_wam_clean_domain($domain) {
    $domain = trim($domain);
    $domain = rtrim($domain, '.');
    $domain = preg_replace('#^https?://#i', '', $domain);
    $domain = preg_replace('#/.*$#', '', $domain);
    $domain = preg_replace('#:\d+$#', '', $domain);
    $domain = strtolower($domain);
    $domain = rtrim($domain, '.');
    if (empty($domain)) return null;
    if (strpos($domain, 'www.') === 0) {
        $domain = substr($domain, 4);
    }
    // Filtro rigoroso de caracteres para impedir quebra ou injeção na sintaxe do Unbound
    // Permite apenas caracteres RFC válidos para hostnames e subdomínios (letras, dígitos, hífens, pontos e sublinhados para SRV)
    if (!preg_match('/^(\*\.)?[a-z0-9_\-\.]+$/', $domain)) {
        return null;
    }
    // Impede pontos consecutivos e comprimentos acima do limite RFC
    if (strpos($domain, '..') !== false || strlen($domain) > 253) {
        return null;
    }
    return $domain;
}

function rules_wam_reload_unbound() {
    $ub_conf = '/var/unbound/unbound.conf';

    // 1. Garante que o arquivo de blocklist exista e tenha permissão de leitura pelo Unbound
    if (!file_exists(WAM_CONF_FILE)) {
        @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Inicial\nserver:\n");
    }
    @chmod(WAM_CONF_FILE, 0644);

    // 2. Validação estrita de sintaxe com unbound-checkconf
    if (file_exists('/usr/local/sbin/unbound-checkconf') && file_exists($ub_conf)) {
        $check_out = array();
        $check_rc = 0;
        exec("/usr/local/sbin/unbound-checkconf " . escapeshellarg($ub_conf) . " 2>&1", $check_out, $check_rc);
        if ($check_rc !== 0) {
            $err_str = implode("\n", $check_out);
            @file_put_contents('/var/log/wam_checkconf_err.log', $err_str);
            log_error("[Rules WAM] Falha na validação do Unbound ({$err_str}). Neutralizando regras para proteger a rede.");
            @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Protecao contra falha de sintaxe\nserver:\n");
        } else {
            @unlink('/var/log/wam_checkconf_err.log');
        }
    }

    // 3. Verifica se o Unbound está ativo e escutando na porta 53
    $is_running = false;
    $sock_out = array();
    exec("/usr/bin/sockstat -4 -l -p 53 2>/dev/null | grep unbound", $sock_out);
    if (!empty($sock_out)) {
        $is_running = true;
    }

    // 4. Se o serviço já está rodando, efetua recarga em memória com ZERO DOWNTIME (sem parar o DNS)
    if ($is_running && file_exists('/usr/local/sbin/unbound-control') && file_exists($ub_conf)) {
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} reload 2>/dev/null");
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} flush_zone . 2>/dev/null");
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} flush_negative 2>/dev/null");
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} flush_bogus 2>/dev/null");
        return true;
    }

    // 5. Se o serviço estiver parado, inicializa oficialmente pelo pfSense
    if (function_exists('services_unbound_configure')) {
        services_unbound_configure();
    } elseif (file_exists('/usr/local/sbin/pfSsh.php')) {
        mwexec("/usr/local/sbin/pfSsh.php playback svc restart unbound 2>/dev/null");
    }

    return true;
}

/**
 * Identifica o Hostname a partir do IP (via Mapeamento Manual, DHCP leases do pfSense, Unbound ou DNS Reverso)
 */
function rules_wam_resolve_hostname($ip, &$cache) {
    if (isset($cache[$ip])) return $cache[$ip];
    $hostname = '';

    global $config;

    // 0. Prioridade Máxima: Mapeamento Manual no Rules WAM (custom_hosts)
    $wam_cfg = rules_wam_get_config();
    if (!empty($wam_cfg['custom_hosts'])) {
        $lines = preg_split('/[\r\n]+/', $wam_cfg['custom_hosts']);
        foreach ($lines as $line) {
            $line = trim($line);
            if (empty($line) || strpos($line, '#') === 0) continue;
            if (strpos($line, '=') !== false) {
                list($hip, $hname) = explode('=', $line, 2);
                if (trim($hip) === $ip && !empty(trim($hname))) {
                    $cache[$ip] = trim($hname);
                    return $cache[$ip];
                }
            }
        }
    }

    // Padrões conhecidos de equipamentos de infraestrutura (antenas, APs, switches, rádios)
    $infra_patterns = '/(antena|antenna|ubnt|unifi|nanostation|litebeam|airmax|mikrotik|cpe|station|wlan|torre|setor|radio|enlace|ptp|pmp|ap[-_]|switch)/i';
    $infra_fallback = '';

    // 1. Leitura direta e reversa do arquivo de leases (/var/dhcpd/var/db/dhcpd.leases)
    // O ISC-DHCP faz append a cada concessão. O final do arquivo contém a concessão mais recente enviada pelo host.
    if (file_exists('/var/dhcpd/var/db/dhcpd.leases')) {
        $l_data = @file_get_contents('/var/dhcpd/var/db/dhcpd.leases');
        if (!empty($l_data) && preg_match_all('/lease\s+' . preg_quote($ip, '/') . '\s*\{([^}]+)\}/s', $l_data, $m_blocks)) {
            for ($i = count($m_blocks[1]) - 1; $i >= 0; $i--) {
                $block_content = $m_blocks[1][$i];
                if (preg_match('/client-hostname\s+"([^"]+)";/', $block_content, $m_hn)) {
                    $cand = trim($m_hn[1]);
                    if (!empty($cand)) {
                        if (!preg_match($infra_patterns, $cand)) {
                            $hostname = $cand;
                            break;
                        } else {
                            if (empty($infra_fallback)) $infra_fallback = $cand;
                        }
                    }
                }
            }
        }
    }

    // 2. Consulta tabela de concessões DHCP do pfSense (system_get_dhcpleases) em ordem reversa
    if (empty($hostname) && function_exists('system_get_dhcpleases')) {
        $leases = system_get_dhcpleases();
        if (!empty($leases['lease'])) {
            $rev_leases = array_reverse($leases['lease']);
            foreach ($rev_leases as $l) {
                if (isset($l['ip']) && $l['ip'] === $ip) {
                    $cand = !empty($l['hostname']) ? trim($l['hostname']) : (!empty($l['descr']) ? trim($l['descr']) : '');
                    if (!empty($cand)) {
                        $is_infra = preg_match($infra_patterns, $cand);
                        if (!$is_infra) {
                            $hostname = $cand;
                            break;
                        } else {
                            if (empty($infra_fallback)) $infra_fallback = $cand;
                        }
                    }
                }
            }
        }
    }

    // 3. Consulta Host Overrides no DNS Resolver (Unbound) do config.xml
    if (empty($hostname) && !empty($config['unbound']['hosts'])) {
        foreach ($config['unbound']['hosts'] as $h) {
            if (isset($h['ip']) && $h['ip'] === $ip && !empty($h['host'])) {
                $cand = $h['host'] . (!empty($h['domain']) ? '.' . $h['domain'] : '');
                if (!preg_match($infra_patterns, $cand)) {
                    $hostname = $cand;
                    break;
                }
            }
        }
    }

    // 4. Consulta mapeamentos estáticos de DHCP no config.xml (ignora se for antena)
    if (empty($hostname) && !empty($config['dhcpd']) && is_array($config['dhcpd'])) {
        foreach ($config['dhcpd'] as $if_dhcp) {
            if (!empty($if_dhcp['staticmap']) && is_array($if_dhcp['staticmap'])) {
                foreach ($if_dhcp['staticmap'] as $sm) {
                    if (isset($sm['ipaddr']) && $sm['ipaddr'] === $ip) {
                        $cand = !empty($sm['hostname']) ? $sm['hostname'] : (!empty($sm['descr']) ? $sm['descr'] : '');
                        if (!empty($cand) && !preg_match($infra_patterns, $cand)) {
                            $hostname = $cand;
                            break 2;
                        } elseif (!empty($cand) && empty($infra_fallback)) {
                            $infra_fallback = $cand;
                        }
                    }
                }
            }
        }
    }

    // 6. Se só encontrou nome da antena/equipamento de rede, informa com clareza
    if (empty($hostname)) {
        if (!empty($infra_fallback)) {
            $hostname = "Host {$ip} (via {$infra_fallback})";
        } else {
            $hostname = "Host {$ip}";
        }
    }

    $cache[$ip] = $hostname;
    return $cache[$ip];
}

/**
 * Identifica a categoria a que um domínio pertence
 */
function rules_wam_get_domain_category($domain) {
    static $cat_index = null;
    if ($cat_index === null) {
        $cat_index = array();
        $map = array(
            'adult.txt'        => 'Conteúdo Adulto',
            'gambling.txt'     => 'Apostas & Bets',
            'news.txt'         => 'Notícias & Portais',
            'social-media.txt' => 'Mídias Sociais',
            'sports.txt'       => 'Esportes & Placares',
            'streaming.txt'    => 'Streaming & Vídeo',
            'gaming.txt'       => 'Jogos & Games',
            'shopping.txt'     => 'Compras & E-commerce',
            'p2p.txt'              => 'Torrents & P2P',
            'doh-providers.txt'    => 'Anti-Bypass DoH',
            'vpn-fortinet.txt'     => 'VPN Fortinet / FortiGate',
            'vpn-cisco.txt'        => 'VPN Cisco AnyConnect',
            'vpn-paloalto.txt'     => 'VPN Palo Alto GlobalProtect',
            'ztna-zscaler.txt'     => 'ZTNA Zscaler',
            'ztna-netskope.txt'    => 'ZTNA Netskope',
            'ztna-cloudflare.txt'  => 'ZTNA Cloudflare WARP',
            'ztna-tailscale.txt'   => 'ZTNA & Mesh VPN',
            'vpn-commercial.txt'   => 'VPN Comercial & Proxies',
            'vpn-ztna.txt'         => 'VPN, ZTNA & Proxies',
            'msg-whatsapp.txt'     => 'WhatsApp',
            'msg-telegram.txt'     => 'Telegram',
            'msg-messenger.txt'    => 'Facebook Messenger',
            'msg-teams-skype.txt'  => 'Microsoft Teams / Skype / MSN',
            'msg-discord.txt'      => 'Discord',
            'msg-slack.txt'        => 'Slack',
            'msg-zoom-meet.txt'    => 'Zoom & Google Meet',
            'msg-others.txt'       => 'Mensageiros Instantâneos',
            'messaging.txt'        => 'Mensageiros & Chat'
        );
        foreach ($map as $f => $label) {
            $path = WAM_FEEDS_DIR . '/' . $f;
            if (file_exists($path)) {
                $lines = file($path, FILE_SKIP_EMPTY_LINES);
                foreach ($lines as $l) {
                    $l = trim($l);
                    if (!empty($l) && $l[0] !== '#') {
                        $cat_index[$l] = $label;
                    }
                }
            }
        }
    }

    $d = rules_wam_clean_domain($domain);
    if (isset($cat_index[$d])) return $cat_index[$d];

    // Checa domínio pai
    $parts = explode('.', $d);
    while (count($parts) > 1) {
        array_shift($parts);
        $p = implode('.', $parts);
        if (isset($cat_index[$p])) return $cat_index[$p];
    }

    return 'Regra Personalizada / Outros';
}

/**
 * Verifica se um domínio está na lista ativa de bloqueio do Unbound
 */
function rules_wam_is_domain_blocked($domain) {
    static $blocked_cache = null;
    if ($blocked_cache === null) {
        $blocked_cache = array();
        $candidates = array(
            WAM_CONF_FILE,
            '/var/unbound/conf.d/wam_blocklist.conf',
            '/var/unbound/wam_blocklist.conf'
        );
        foreach ($candidates as $cfile) {
            if (file_exists($cfile)) {
                $lines = @file($cfile, FILE_SKIP_EMPTY_LINES);
                if (!empty($lines)) {
                    foreach ($lines as $line) {
                        if (preg_match('/local-zone:\s*"([^"]+)"/i', $line, $m)) {
                            $blocked_cache[strtolower(trim($m[1]))] = true;
                        }
                    }
                }
                if (!empty($blocked_cache)) break;
            }
        }
    }

    $d = strtolower(rules_wam_clean_domain($domain));
    if (empty($d)) return false;
    if (isset($blocked_cache[$d])) return true;

    $parts = explode('.', $d);
    while (count($parts) > 1) {
        array_shift($parts);
        $p = implode('.', $parts);
        if (isset($blocked_cache[$p])) return true;
    }

    return false;
}

/**
 * Obtém a lista e status de hosts Online na rede local via tabelas ARP (IPv4) e NDP (IPv6)
 */
function rules_wam_get_online_hosts() {
    static $online_hosts = null;
    if ($online_hosts !== null) {
        return $online_hosts;
    }

    $online_hosts = array();

    // 1. pfSense native system_get_arp_table()
    if (function_exists('system_get_arp_table')) {
        $arp_data = system_get_arp_table(false);
        if (is_array($arp_data)) {
            foreach ($arp_data as $entry) {
                $ip = $entry['ip-address'] ?? ($entry['ip'] ?? '');
                $mac = $entry['mac-address'] ?? ($entry['mac'] ?? '');
                if (!empty($ip) && !empty($mac) && stripos($mac, 'incomplete') === false && $mac !== '(incomplete)') {
                    $online_hosts[$ip] = array(
                        'online' => true,
                        'mac' => $mac,
                        'interface' => $entry['interface'] ?? '',
                        'status' => 'online'
                    );
                }
            }
        }
    }

    // 2. Leitura direta de /usr/sbin/arp -an (garantia máxima no FreeBSD/pfSense)
    $raw_arp = array();
    @exec('/usr/sbin/arp -an 2>/dev/null', $raw_arp);
    if (empty($raw_arp)) {
        @exec('arp -an 2>/dev/null', $raw_arp);
    }
    if (!empty($raw_arp)) {
        foreach ($raw_arp as $line) {
            // Formato FreeBSD: ? (172.24.60.10) at 00:11:22:33:44:55 on em0 expires in 1198 seconds [ethernet]
            if (preg_match('/\(([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\)\s+at\s+([0-9a-fA-F:]{11,17}|[0-9a-fA-F]{1,2}(?::[0-9a-fA-F]{1,2}){5})/i', $line, $m)) {
                $ip = $m[1];
                $mac = strtolower($m[2]);
                if (stripos($mac, 'incomplete') === false && !isset($online_hosts[$ip])) {
                    $online_hosts[$ip] = array(
                        'online' => true,
                        'mac' => $mac,
                        'interface' => '',
                        'status' => 'online'
                    );
                }
            }
        }
    }

    // 3. Suporte a IPv6 via ndp -an
    $raw_ndp = array();
    @exec('/usr/sbin/ndp -an 2>/dev/null', $raw_ndp);
    if (!empty($raw_ndp)) {
        foreach ($raw_ndp as $line) {
            $parts = preg_split('/\s+/', trim($line));
            if (count($parts) >= 2) {
                $ip6 = $parts[0];
                $mac6 = strtolower($parts[1]);
                if (strpos($ip6, ':') !== false && stripos($mac6, 'incomplete') === false && preg_match('/^[0-9a-f:]+$/i', $mac6)) {
                    if (!isset($online_hosts[$ip6])) {
                        $online_hosts[$ip6] = array(
                            'online' => true,
                            'mac' => $mac6,
                            'interface' => $parts[2] ?? '',
                            'status' => 'online'
                        );
                    }
                }
            }
        }
    }

    // 4. Sessão web atual e loopback são sempre Online
    $online_hosts['127.0.0.1'] = array('online' => true, 'mac' => 'loopback', 'interface' => 'lo0', 'status' => 'online');
    $online_hosts['::1'] = array('online' => true, 'mac' => 'loopback', 'interface' => 'lo0', 'status' => 'online');
    if (!empty($_SERVER['REMOTE_ADDR'])) {
        $online_hosts[$_SERVER['REMOTE_ADDR']] = array('online' => true, 'mac' => 'current_session', 'interface' => 'lan', 'status' => 'online');
    }

    return $online_hosts;
}

/**
 * Retorna se um endereço IP específico está online no momento
 */
function rules_wam_is_host_online($ip) {
    if (empty($ip)) return false;
    $online = rules_wam_get_online_hosts();
    return isset($online[$ip]) && !empty($online[$ip]['online']);
}

/**
 * Retorna o MAC address conhecido do host se disponível
 */
function rules_wam_get_host_mac($ip) {
    if (empty($ip)) return '';
    $online = rules_wam_get_online_hosts();
    if (isset($online[$ip]['mac']) && $online[$ip]['mac'] !== 'loopback' && $online[$ip]['mac'] !== 'current_session') {
        return $online[$ip]['mac'];
    }
    return '';
}

/**
 * Extrai os registros de tentativas de bloqueio dos logs do sistema
 * Se $limit <= 0, retorna todos os registros sem limitação
 */
function rules_wam_get_audit_events($limit = 1000) {
    $events = array();
    $cache_hn = array();
    $seen = array();
    $limit = intval($limit);

    // 1. Lê wam_audit.log direto
    if (file_exists(WAM_AUDIT_LOG)) {
        $lines = @file(WAM_AUDIT_LOG, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($lines) {
            for ($i = count($lines) - 1; $i >= 0; $i--) {
                $line = trim($lines[$i]);
                if (empty($line)) continue;

                $ts = '';
                $ip = '';
                $dom = '';
                $cat = '';
                $hn = '';

                if (strpos($line, '|') !== false) {
                    $parts = explode('|', $line);
                    if (count($parts) >= 3) {
                        $ts = trim($parts[0]);
                        $ip = trim($parts[1]);
                        $dom = rules_wam_clean_domain(trim($parts[2]));
                        $cat = isset($parts[3]) ? trim($parts[3]) : '';
                        $hn = isset($parts[4]) ? trim($parts[4]) : '';
                    }
                } elseif (preg_match('/\[(.*?)\]\s+CLIENT=([^\s]+)(?:\s+HOSTNAME=([^\s]+))?\s+DOMAIN=([^\s]+)(?:\s+CATEGORY="(.*?)")?/i', $line, $am)) {
                    $ts = trim($am[1]);
                    $ip = trim($am[2]);
                    $hn = !empty($am[3]) ? trim($am[3]) : '';
                    $dom = rules_wam_clean_domain(trim($am[4]));
                    $cat = !empty($am[5]) ? trim($am[5]) : '';
                }

                if (!empty($dom) && !empty($ip)) {
                    $key = "$ts|$ip|$dom";
                    if (!isset($seen[$key])) {
                        $seen[$key] = true;
                        $is_online = rules_wam_is_host_online($ip);
                        $events[] = array(
                            'timestamp' => $ts,
                            'ip' => $ip,
                            'hostname' => !empty($hn) ? $hn : rules_wam_resolve_hostname($ip, $cache_hn),
                            'online' => $is_online,
                            'status_label' => $is_online ? 'Online' : 'Offline',
                            'domain' => $dom,
                            'category' => !empty($cat) ? $cat : rules_wam_get_domain_category($dom)
                        );
                        if ($limit > 0 && count($events) >= $limit) return $events;
                    }
                }
            }
        }
    }

    // 2. Lê /var/log/resolver.log e /var/log/system.log do pfSense (consultas reais de rede de qualquer cliente)
    $log_lines = array();
    $log_files = array('/var/log/resolver.log', '/var/log/system.log');
    $tail_count = ($limit > 0) ? intval($limit * 3) : 100000;

    foreach ($log_files as $lfile) {
        if (!file_exists($lfile)) continue;

        // Se for circular clog (FreeBSD/pfSense)
        if (file_exists('/usr/local/sbin/clog')) {
            $clog_out = array();
            @exec('/usr/local/sbin/clog -f ' . escapeshellarg($lfile) . ' 2>/dev/null | tail -n ' . $tail_count, $clog_out);
            if (!empty($clog_out)) {
                $log_lines = array_merge($log_lines, $clog_out);
                continue;
            }
        }

        // Tenta tail nativo do shell
        $tail_out = array();
        @exec('tail -n ' . $tail_count . ' ' . escapeshellarg($lfile) . ' 2>/dev/null', $tail_out);
        if (!empty($tail_out)) {
            $log_lines = array_merge($log_lines, $tail_out);
            continue;
        }

        // Fallback PHP file()
        $f_lines = @file($lfile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($f_lines) {
            $log_lines = array_merge($log_lines, array_slice($f_lines, -$tail_count));
        }
    }

    if (!empty($log_lines)) {
        // Regex robusto:
        // - Datas ISO 8601 (2026-09-04T13:08:31... ou 2026-09-04 13:08:31)
        // - Datas BSD clássicas (Sep  4 13:08:31)
        // - info: ou query: com ou sem PID e porta
        $regex = '/(?:(\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[+-]\d{2}:?\d{2}|Z)?)|([A-Za-z]{3}\s+\d+\s+\d{2}:\d{2}:\d{2})).*?(?:info|query):\s+(?:query\s+(?:from\s+)?)?([0-9a-fA-F.:]+)(?:@\d+|\s+\d+)?\s+([a-zA-Z0-9_.-]+)\.?/i';

        for ($i = count($log_lines) - 1; $i >= 0; $i--) {
            $line = trim($log_lines[$i]);
            if (empty($line)) continue;

            if (preg_match($regex, $line, $m)) {
                $ts = !empty($m[1]) ? $m[1] : $m[2];
                $ip = $m[3];
                $raw_dom = $m[4];
                $dom = rules_wam_clean_domain($raw_dom);
                $lan_ip = function_exists('config_get_path') ? config_get_path('interfaces/lan/ipaddr', '') : (!empty($config['interfaces']['lan']['ipaddr']) ? $config['interfaces']['lan']['ipaddr'] : '');
                $cfg_ip = !empty($wam_cfg['block_page_ip']) ? $wam_cfg['block_page_ip'] : '';
                if (empty($dom) || $ip === '127.0.0.1' || $ip === '::1' || (!empty($lan_ip) && $ip === $lan_ip) || (!empty($cfg_ip) && $ip === $cfg_ip)) continue;

                // Checa se o domínio acessado pertence à nossa lista de bloqueio ativa
                if (rules_wam_is_domain_blocked($dom)) {
                    $key = "$ts|$ip|$dom";
                    if (!isset($seen[$key])) {
                        $seen[$key] = true;
                        $is_online = rules_wam_is_host_online($ip);
                        $events[] = array(
                            'timestamp' => $ts,
                            'ip' => $ip,
                            'hostname' => rules_wam_resolve_hostname($ip, $cache_hn),
                            'online' => $is_online,
                            'status_label' => $is_online ? 'Online' : 'Offline',
                            'domain' => $dom,
                            'category' => rules_wam_get_domain_category($dom)
                        );
                        if ($limit > 0 && count($events) >= $limit) return $events;
                    }
                }
            }
        }
    }

    return $events;
}

/**
 * Garante a existência dos certificados SSL e CA para o Banner de Bloqueio
 */
function rules_wam_ensure_banner_certs($block_page_ip = null) {
    if (empty($block_page_ip)) {
        $block_page_ip = rules_wam_get_lan_ip();
    }
    $ca_crt = '/var/etc/rules_wam_ca.crt';
    $ca_key = '/var/etc/rules_wam_ca.key';
    $ssl_crt = '/var/etc/rules_wam_ssl.crt';
    $ssl_key = '/var/etc/rules_wam_ssl.key';
    $pub_ca = '/usr/local/www/rules_wam_ca.crt';

    @mkdir('/var/etc', 0755, true);

    $need_gen = (!file_exists($ssl_crt) || !file_exists($ssl_key) || @filesize($ssl_crt) === 0 || @filesize($ssl_key) === 0);

    if (!$need_gen) {
        if (!file_exists($pub_ca) && file_exists($ca_crt)) {
            @copy($ca_crt, $pub_ca);
            @chmod($pub_ca, 0644);
        }
        return false;
    }

    // 1. Gera Autoridade Certificadora (CA) se ausente
    if (!file_exists($ca_crt) || !file_exists($ca_key) || @filesize($ca_crt) === 0) {
        $ca_cnf = "[req]\n"
            . "distinguished_name = req_distinguished_name\n"
            . "prompt = no\n"
            . "x509_extensions = v3_ca\n\n"
            . "[req_distinguished_name]\n"
            . "C = BR\nST = SP\nO = Seguranca Corporativa\nCN = Rules WAM Firewall CA\n\n"
            . "[v3_ca]\n"
            . "basicConstraints = critical, CA:TRUE\n"
            . "keyUsage = critical, digitalSignature, cRLSign, keyCertSign\n"
            . "subjectKeyIdentifier = hash\n"
            . "authorityKeyIdentifier = keyid:always,issuer\n";
        @file_put_contents('/tmp/rules_wam_ca.cnf', $ca_cnf);
        @exec("/usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 -config /tmp/rules_wam_ca.cnf -keyout {$ca_key} -out {$ca_crt} 2>/dev/null");
        @unlink('/tmp/rules_wam_ca.cnf');
        @chmod($ca_key, 0600);
        @chmod($ca_crt, 0644);
    }

    if (file_exists($ca_crt)) {
        @copy($ca_crt, $pub_ca);
        @chmod($pub_ca, 0644);
    }

    // 2. Monta configuração com SANs para o Banner
    $san_lines = array('DNS.1 = localhost', 'IP.1 = 127.0.0.1');
    $ip_idx = 2;
    $added = array('localhost' => true, '127.0.0.1' => true);

    if (!empty($block_page_ip) && !isset($added[$block_page_ip])) {
        $san_lines[] = "IP.{$ip_idx} = {$block_page_ip}";
        $added[$block_page_ip] = true;
        $ip_idx++;
    }

    // Inclui todos os IPs de interfaces internas configuradas no pfSense no certificado SAN
    $internal_ifaces = rules_wam_get_configured_interfaces(false);
    foreach ($internal_ifaces as $i_data) {
        if (!empty($i_data['ip']) && !isset($added[$i_data['ip']])) {
            $san_lines[] = "IP.{$ip_idx} = " . $i_data['ip'];
            $added[$i_data['ip']] = true;
            $ip_idx++;
        }
    }

    $idx = 2;
    $popular = array(
        'whatsapp.com', 'facebook.com', 'instagram.com', 'tiktok.com', 'twitter.com', 'x.com',
        'discord.com', 'telegram.org', 'bet365.com', 'betano.com', 'blaze.com', 'sportingbet.com',
        'xvideos.com', 'pornhub.com', 'xnxx.com', 'globo.com', 'uol.com.br'
    );
    foreach ($popular as $p) {
        if (!isset($added[$p])) {
            $san_lines[] = "DNS.{$idx} = {$p}";
            $idx++;
            $added[$p] = true;
        }
        $wild = "*.{$p}";
        if (!isset($added[$wild])) {
            $san_lines[] = "DNS.{$idx} = {$wild}";
            $idx++;
            $added[$wild] = true;
        }
    }

    $cnf = "[req]\n"
        . "distinguished_name = req_distinguished_name\n"
        . "prompt = no\n"
        . "req_extensions = v3_req\n\n"
        . "[req_distinguished_name]\n"
        . "C = BR\nST = SP\nO = Seguranca Corporativa\nCN = Rules WAM Block\n\n"
        . "[v3_req]\n"
        . "basicConstraints = critical, CA:FALSE\n"
        . "keyUsage = critical, digitalSignature, keyEncipherment\n"
        . "extendedKeyUsage = serverAuth\n"
        . "subjectKeyIdentifier = hash\n"
        . "subjectAltName = @alt_names\n\n"
        . "[alt_names]\n"
        . implode("\n", $san_lines) . "\n";

    @file_put_contents('/tmp/rules_wam_ssl.cnf', $cnf);
    @unlink($ssl_key);
    @unlink($ssl_crt);
    @exec("/usr/bin/openssl req -new -newkey rsa:2048 -nodes -keyout {$ssl_key} -out /tmp/rules_wam_ssl.csr -config /tmp/rules_wam_ssl.cnf 2>/dev/null");
    @exec("/usr/bin/openssl x509 -req -days 3650 -in /tmp/rules_wam_ssl.csr -CA {$ca_crt} -CAkey {$ca_key} -CAcreateserial -out {$ssl_crt} -extfile /tmp/rules_wam_ssl.cnf -extensions v3_req 2>/dev/null");

    if (!file_exists($ssl_crt) || @filesize($ssl_crt) === 0) {
        @exec("/usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 -config /tmp/rules_wam_ssl.cnf -extensions v3_req -keyout {$ssl_key} -out {$ssl_crt} 2>/dev/null");
    }

    @unlink('/tmp/rules_wam_ssl.csr');
    @unlink('/tmp/rules_wam_ssl.cnf');
    @chmod($ssl_key, 0640);
    @chmod($ssl_crt, 0644);

    return true;
}

/**
 * Sincroniza o servico NGINX do Banner de Bloqueio com a porta ativa da WebGUI
 */
function rules_wam_sync_banner_nginx() {
    global $config;
    require_once("config.inc");
    init_config_arr(array('system', 'webgui'));

    $sys_changed = false;
    // Assegura parâmetros de DNS Rebind e HTTP Redirect se ausentes
    if (!isset($config['system']['webgui']['nodnsrebindcheck'])) {
        $config['system']['webgui']['nodnsrebindcheck'] = true;
        $sys_changed = true;
    }
    if (!isset($config['system']['webgui']['disablehttpredirect'])) {
        $config['system']['webgui']['disablehttpredirect'] = true;
        $sys_changed = true;
    }

    // Libera porta 443 e 80 migrando WebGUI para 50443 caso esteja em conflito
    $cur_port = !empty($config['system']['webgui']['port']) ? $config['system']['webgui']['port'] : '';
    $cur_proto = !empty($config['system']['webgui']['protocol']) ? $config['system']['webgui']['protocol'] : 'https';
    $port_changed = false;
    if ($cur_port === '443' || $cur_port === '80' || (empty($cur_port) && $cur_proto === 'https') || $cur_port === '8443') {
        $config['system']['webgui']['port'] = '50443';
        $config['system']['webgui']['protocol'] = 'https';
        $port_changed = true;
        $sys_changed = true;
    }

    if ($sys_changed) {
        write_config("Rules WAM: Portas 80 e 443 liberadas para Banner (WebGUI ajustada para 50443)");
        if ($port_changed && file_exists('/etc/rc.restart_webgui')) {
            // Executa em segundo plano com delay para não encerrar a sessão HTTP atual do usuário
            if (function_exists('mwexec_bg')) {
                @mwexec_bg('/bin/sh -c "(sleep 2 && /etc/rc.restart_webgui) >/dev/null 2>&1 &"');
            } else {
                @mwexec('/bin/sh -c "(sleep 2 && /etc/rc.restart_webgui) >/dev/null 2>&1 &"');
            }
        }
        if (file_exists('/etc/rc.filter_configure')) {
            @mwexec('/etc/rc.filter_configure 2>/dev/null');
        } elseif (function_exists('filter_configure')) {
            filter_configure();
        }
    }

    // Assegura certificados SSL válidos para o Banner NGINX
    $cert_generated = rules_wam_ensure_banner_certs();

    $nginx_conf = '/usr/local/etc/nginx/rules_wam_ssl.conf';
    $conf_changed = false;

    // FastCGI direto para o PHP-FPM nativo do pfSense
    // Elimina completamente 502 Bad Gateway e dependência de porta/protocolo da WebGUI
    $conf_tpl = "worker_processes 1;\n"
        . "pid /var/run/rules_wam_ssl.pid;\n"
        . "error_log /var/log/rules_wam_ssl.log info;\n"
        . "events {\n    worker_connections 256;\n}\n"
        . "http {\n"
        . "    access_log off;\n"
        . "    error_log /var/log/rules_wam_ssl.log info;\n"
        . "    default_type text/html;\n"
        . "    types {\n"
        . "        text/html                             html htm;\n"
        . "        application/x-x509-ca-cert            crt;\n"
        . "    }\n\n"
        . "    server {\n"
        . "        listen 80;\n"
        . "        server_name _;\n"
        . "        root /usr/local/www;\n\n"
        . "        location = /rules_wam_ca.crt {\n"
        . "            root /usr/local/www;\n"
        . "        }\n\n"
        . "        location / {\n"
        . "            fastcgi_pass unix:/var/run/php-fpm.socket;\n"
        . "            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;\n"
        . "            fastcgi_param SCRIPT_NAME /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_URI /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_ROOT /usr/local/www;\n"
        . "            fastcgi_param QUERY_STRING domain=\$host&\$query_string;\n"
        . "            fastcgi_param REQUEST_METHOD \$request_method;\n"
        . "            fastcgi_param CONTENT_TYPE \$content_type;\n"
        . "            fastcgi_param CONTENT_LENGTH \$content_length;\n"
        . "            fastcgi_param SERVER_PROTOCOL \$server_protocol;\n"
        . "            fastcgi_param REMOTE_ADDR \$remote_addr;\n"
        . "            fastcgi_param REMOTE_PORT \$remote_port;\n"
        . "            fastcgi_param SERVER_ADDR \$server_addr;\n"
        . "            fastcgi_param SERVER_PORT \$server_port;\n"
        . "            fastcgi_param SERVER_NAME \$host;\n"
        . "            fastcgi_param HTTP_HOST \$host;\n"
        . "            fastcgi_param GATEWAY_INTERFACE CGI/1.1;\n"
        . "            fastcgi_param SERVER_SOFTWARE nginx;\n"
        . "            fastcgi_param REDIRECT_STATUS 200;\n"
        . "            fastcgi_buffers 16 16k;\n"
        . "            fastcgi_buffer_size 32k;\n"
        . "            fastcgi_read_timeout 15s;\n"
        . "            fastcgi_send_timeout 15s;\n"
        . "            fastcgi_connect_timeout 5s;\n"
        . "        }\n"
        . "    }\n\n"
        . "    server {\n"
        . "        listen 443 ssl;\n"
        . "        server_name _;\n"
        . "        ssl_certificate /var/etc/rules_wam_ssl.crt;\n"
        . "        ssl_certificate_key /var/etc/rules_wam_ssl.key;\n"
        . "        ssl_protocols TLSv1.2 TLSv1.3;\n"
        . "        ssl_ciphers HIGH:!aNULL:!MD5;\n"
        . "        root /usr/local/www;\n\n"
        . "        location = /rules_wam_ca.crt {\n"
        . "            root /usr/local/www;\n"
        . "        }\n\n"
        . "        location / {\n"
        . "            fastcgi_pass unix:/var/run/php-fpm.socket;\n"
        . "            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;\n"
        . "            fastcgi_param SCRIPT_NAME /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_URI /rules_wam_block.php;\n"
        . "            fastcgi_param DOCUMENT_ROOT /usr/local/www;\n"
        . "            fastcgi_param QUERY_STRING domain=\$host&\$query_string;\n"
        . "            fastcgi_param REQUEST_METHOD \$request_method;\n"
        . "            fastcgi_param CONTENT_TYPE \$content_type;\n"
        . "            fastcgi_param CONTENT_LENGTH \$content_length;\n"
        . "            fastcgi_param SERVER_PROTOCOL \$server_protocol;\n"
        . "            fastcgi_param REMOTE_ADDR \$remote_addr;\n"
        . "            fastcgi_param REMOTE_PORT \$remote_port;\n"
        . "            fastcgi_param SERVER_ADDR \$server_addr;\n"
        . "            fastcgi_param SERVER_PORT \$server_port;\n"
        . "            fastcgi_param SERVER_NAME \$host;\n"
        . "            fastcgi_param HTTP_HOST \$host;\n"
        . "            fastcgi_param HTTPS on;\n"
        . "            fastcgi_param GATEWAY_INTERFACE CGI/1.1;\n"
        . "            fastcgi_param SERVER_SOFTWARE nginx;\n"
        . "            fastcgi_param REDIRECT_STATUS 200;\n"
        . "            fastcgi_buffers 16 16k;\n"
        . "            fastcgi_buffer_size 32k;\n"
        . "            fastcgi_read_timeout 15s;\n"
        . "            fastcgi_send_timeout 15s;\n"
        . "            fastcgi_connect_timeout 5s;\n"
        . "        }\n"
        . "    }\n"
        . "}\n";

    if (!file_exists($nginx_conf) || @file_get_contents($nginx_conf) !== $conf_tpl) {
        @mkdir('/usr/local/etc/nginx', 0755, true);
        file_put_contents($nginx_conf, $conf_tpl);
        $conf_changed = true;
    }

    $rc_script = '/usr/local/etc/rc.d/rules_wam_ssl.sh';
    $rc_content = "#!/bin/sh\n"
        . "stop_banner() {\n"
        . "    pkill -TERM -f \"rules_wam_ssl.conf\" 2>/dev/null || true\n"
        . "    if [ -f /var/run/rules_wam_ssl.pid ]; then\n"
        . "        PID=\$(cat /var/run/rules_wam_ssl.pid 2>/dev/null)\n"
        . "        if [ -n \"\$PID\" ] && kill -0 \"\$PID\" 2>/dev/null; then\n"
        . "            kill -QUIT \"\$PID\" 2>/dev/null || kill -TERM \"\$PID\" 2>/dev/null || true\n"
        . "        fi\n"
        . "    fi\n"
        . "    sleep 1\n"
        . "    for p in \$(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print \$3}' | sort -u); do\n"
        . "        [ -n \"\$p\" ] && kill -TERM \"\$p\" 2>/dev/null || true\n"
        . "    done\n"
        . "    sleep 1\n"
        . "    for p in \$(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print \$3}' | sort -u); do\n"
        . "        [ -n \"\$p\" ] && kill -9 \"\$p\" 2>/dev/null || true\n"
        . "    done\n"
        . "    rm -f /var/run/rules_wam_ssl.pid\n"
        . "    sleep 1\n"
        . "}\n\n"
        . "case \"\$1\" in\n"
        . "    stop)\n"
        . "        stop_banner\n"
        . "        ;;\n"
        . "    start|restart|*)\n"
        . "        stop_banner\n"
        . "        chmod 666 /var/run/php-fpm.socket 2>/dev/null || true\n"
        . "        if [ ! -s /var/etc/rules_wam_ssl.crt ] || [ ! -s /var/etc/rules_wam_ssl.key ]; then\n"
        . "            /usr/local/bin/php -r 'require_once(\"/usr/local/pkg/rules_wam.inc\"); rules_wam_ensure_banner_certs();' 2>/dev/null || true\n"
        . "        fi\n"
        . "        /usr/local/sbin/nginx -c /usr/local/etc/nginx/rules_wam_ssl.conf 2>>/var/log/rules_wam_ssl.log || true\n"
        . "        ;;\nesac\n";

    if (!file_exists($rc_script) || @file_get_contents($rc_script) !== $rc_content) {
        @mkdir('/usr/local/etc/rc.d', 0755, true);
        file_put_contents($rc_script, $rc_content);
        @chmod($rc_script, 0755);
        $conf_changed = true;
    }

    // Verifica se o NGINX do banner já está em execução
    $is_banner_running = false;
    if (file_exists('/var/run/rules_wam_ssl.pid')) {
        $npid = trim(@file_get_contents('/var/run/rules_wam_ssl.pid'));
        if (!empty($npid) && function_exists('posix_kill') && @posix_kill($npid, 0)) {
            $is_banner_running = true;
        }
    }
    if (!$is_banner_running) {
        $p_out = array();
        @exec("/usr/bin/pgrep -f 'rules_wam_ssl.conf'", $p_out);
        $is_banner_running = !empty($p_out);
    }

    // Reinicia o Banner NGINX se a configuração mudou, certificados foram gerados ou serviço está parado
    if (file_exists($rc_script) && ($conf_changed || $cert_generated || !$is_banner_running)) {
        mwexec('/bin/sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart 2>/dev/null');
    }
}
?>