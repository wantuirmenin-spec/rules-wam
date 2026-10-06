<?php
/*
 * rules_wam.inc
 * Rules WAM - Web Access Manager para pfSense
 * Motor de aplicação de regras de bloqueio e auditoria no Unbound DNS
 */

require_once("config.inc");
require_once("util.inc");
require_once("services.inc");

define('RULES_WAM_VERSION', '1.4.3');
define('WAM_FEEDS_DIR', '/usr/local/share/wam/feeds');
define('WAM_CONF_FILE', '/var/unbound/wam_blocklist.conf');
// Include com curinga: se o arquivo sumir (ex.: /var em RAM disk após reboot) o Unbound continua subindo
define('WAM_CONF_INCLUDE', 'include: /var/unbound/wam_blocklist*.conf');
define('WAM_STATUS_FILE', '/var/log/wam_status.json');
define('WAM_AUDIT_LOG', '/var/log/wam_audit.log');
define('WAM_AUDIT_MAX_BYTES', 10 * 1024 * 1024);
define('WAM_CAT_INDEX', '/var/db/rules_wam_categories.json');
define('WAM_DEFAULT_CORP_SUBNETS', "10.0.0.0/8\n172.16.0.0/12\n192.168.0.0/16");

/**
 * Auxiliar para verificar se checkbox está marcada (aceita "yes", "on", 1, true)
 */
function rules_wam_is_checked($val) {
    if (empty($val)) return false;
    if ($val === 'yes' || $val === 'on' || $val === true || $val === '1' || $val === 1) return true;
    return false;
}

/**
 * Identifica interfaces do tipo WAN (inclusive WANs secundárias de multi-WAN):
 * a própria "wan", interfaces com gateway definido ou com endereço dinâmico de provedor.
 */
function rules_wam_is_wan_like($if_key, $if_cfg) {
    if ($if_key === 'wan') {
        return true;
    }
    if (!empty($if_cfg['gateway']) || !empty($if_cfg['gatewayv6'])) {
        return true;
    }
    if (isset($if_cfg['ipaddr']) && in_array($if_cfg['ipaddr'], array('dhcp', 'pppoe', 'pptp', 'l2tp', 'ppp'), true)) {
        return true;
    }
    if (function_exists('interface_has_gateway') && interface_has_gateway($if_key)) {
        return true;
    }
    if (function_exists('interface_has_gatewayv6') && interface_has_gatewayv6($if_key)) {
        return true;
    }
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
            if (!$include_wan && rules_wam_is_wan_like($if_key, $if_cfg)) {
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
                'is_internal' => !rules_wam_is_wan_like($if_key, $if_cfg)
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
 * Obtém a configuração do Rules WAM do config.xml (installedpackages/rules_wam).
 * O caminho legado installedpackages/wam só é lido como fallback de migração.
 */
function rules_wam_get_config() {
    $cfg = null;

    foreach (array('installedpackages/rules_wam/config', 'installedpackages/wam/config') as $path) {
        $raw = config_get_path($path, null);
        if (is_array($raw) && !empty($raw)) {
            $cfg = (isset($raw[0]) && is_array($raw[0])) ? $raw[0] : $raw;
            break;
        }
    }

    if (is_array($cfg) && !empty($cfg)) {
        // Checkboxes ausentes no XML representam 'no' (exceto proteções essenciais, ativas por padrão)
        $default_yes = array(
            'corp_protect_tools', 'corp_protect_cloudflare', 'corp_protect_netskope',
            'corp_protect_idp', 'corp_protect_helpdesk', 'corp_protect_voip'
        );
        $checkbox_keys = array(
            'enable', 'block_adult', 'block_gambling', 'block_news', 'block_social',
            'block_sports', 'block_gaming', 'block_streaming', 'block_shopping',
            'block_p2p', 'block_doh', 'block_dns_bypass', 'block_vpn', 'block_messaging',
            'block_wa_by_ip',
            'schedule_enable', 'schedule_weekend',
            'corp_enable', 'corp_reverse_lookup',
            'enable_upstream_forwarding'
        );
        foreach (array_merge($checkbox_keys, $default_yes) as $chk) {
            if (!isset($cfg[$chk])) {
                $cfg[$chk] = in_array($chk, $default_yes, true) ? 'yes' : 'no';
            }
        }
        if (empty($cfg['block_action'])) {
            $cfg['block_action'] = 'block_page';
        }
        return $cfg;
    }

    // Configuração inicial padrão (instalação nova)
    return array(
        'enable'                     => 'yes',
        'block_adult'                => 'yes',
        'block_gambling'             => 'yes',
        'block_gaming'               => 'yes',
        'block_dns_bypass'           => 'no',
        'block_wa_by_ip'             => 'no',
        'enable_upstream_forwarding' => 'no',
        'block_action'               => 'block_page',
        'corp_protect_netskope'      => 'yes',
        'corp_protect_idp'           => 'yes',
        'corp_protect_tools'         => 'yes',
        'corp_protect_cloudflare'    => 'yes',
        'corp_protect_helpdesk'      => 'yes',
        'corp_protect_voip'          => 'yes',
        'corp_reverse_lookup'        => 'yes',
        'corp_allowed_subnets'       => WAM_DEFAULT_CORP_SUBNETS,
        'initialized'                => 'yes'
    );
}

/**
 * Normaliza um horário para HH:MM (aceita "8:00", "08:00", "0800"). Retorna '' se inválido.
 */
function rules_wam_normalize_time($t) {
    $t = trim((string)$t);
    if ($t === '') return '';
    if (preg_match('/^(\d{1,2}):?(\d{2})$/', $t, $m)) {
        $h = (int)$m[1];
        $mi = (int)$m[2];
        if ($h >= 0 && $h <= 23 && $mi >= 0 && $mi <= 59) {
            return sprintf('%02d:%02d', $h, $mi);
        }
    }
    return '';
}

/**
 * Lê o estado gravado da última aplicação (bloqueando ou não)
 */
function rules_wam_read_status() {
    if (!file_exists(WAM_STATUS_FILE)) return array();
    $s = @json_decode(@file_get_contents(WAM_STATUS_FILE), true);
    return is_array($s) ? $s : array();
}

/**
 * Função chamada pelo pfSense ao salvar configurações e pelo cron/boot
 */
function rules_wam_resync() {
    $wam_cfg = rules_wam_get_config();
    log_error("[Rules WAM] Resync disparado.");

    if (!rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
        rules_wam_disable();
        return;
    }

    if (rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null) && !rules_wam_is_in_schedule_window($wam_cfg)) {
        rules_wam_suspend_schedule($wam_cfg);
        return;
    }

    rules_wam_apply_rules($wam_cfg);
}

function wam_resync() {
    rules_wam_resync();
}

/**
 * Bloco de configuração comum (AD/NPS e redes autorizadas) usado com e sem bloqueio
 */
function rules_wam_build_common_conf($wam_cfg) {
    $conf = "";
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $corp_domains = rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '');
    $corp_reverse = (!isset($wam_cfg['corp_reverse_lookup']) || rules_wam_is_checked($wam_cfg['corp_reverse_lookup']));

    if ($corp_enable && !empty($corp_domains)) {
        $conf .= "  # Excecoes para Active Directory e NPS RADIUS (Anti-Rebinding e DNSSEC Bypass)\n";
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

    $corp_subnets_raw = !empty($wam_cfg['corp_allowed_subnets']) ? $wam_cfg['corp_allowed_subnets'] : WAM_DEFAULT_CORP_SUBNETS;
    $corp_subnets = rules_wam_parse_list($corp_subnets_raw);
    if (!empty($corp_subnets)) {
        $conf .= "  # Redes corporativas autorizadas a consultar o Unbound\n";
        foreach ($corp_subnets as $snet) {
            $snet = trim($snet);
            if (preg_match('#^(\d{1,3}\.){3}\d{1,3}(/(?:[0-9]|[12][0-9]|3[0-2]))?$#', $snet)) {
                $conf .= "  access-control: {$snet} allow\n";
            }
        }
    }
    return $conf;
}

/**
 * Lista de IPs/redes isentos (bypass) já validados no formato CIDR
 */
function rules_wam_get_bypass_list($wam_cfg) {
    $bypass = array();
    if (empty($wam_cfg['bypass_ips'])) {
        return $bypass;
    }
    foreach (preg_split('/[\s,;]+/', $wam_cfg['bypass_ips']) as $rip) {
        $rip = trim($rip);
        if ($rip === '') continue;
        if (filter_var($rip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            $bypass[] = $rip . '/32';
        } elseif (filter_var($rip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
            $bypass[] = $rip . '/128';
        } elseif (strpos($rip, '/') !== false) {
            list($net, $bits) = explode('/', $rip, 2);
            if (ctype_digit($bits)) {
                $b = (int)$bits;
                if (filter_var($net, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) && $b >= 0 && $b <= 32) {
                    $bypass[] = "{$net}/{$b}";
                } elseif (filter_var($net, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6) && $b >= 0 && $b <= 128) {
                    $bypass[] = "{$net}/{$b}";
                }
            }
        }
    }
    return array_values(array_unique($bypass));
}

/**
 * Verifica se um IP está na lista de bypass (comparação exata ou por sub-rede)
 */
function rules_wam_ip_in_bypass($ip, $wam_cfg) {
    if (empty($ip) || !filter_var($ip, FILTER_VALIDATE_IP)) return false;
    foreach (rules_wam_get_bypass_list($wam_cfg) as $cidr) {
        if (function_exists('ip_in_subnet')) {
            if (ip_in_subnet($ip, $cidr)) return true;
        } else {
            list($net, $bits) = explode('/', $cidr, 2);
            if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) && filter_var($net, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $mask = ((int)$bits === 0) ? 0 : (-1 << (32 - (int)$bits));
                if ((ip2long($ip) & $mask) === (ip2long($net) & $mask)) return true;
            } elseif ($ip === $net) {
                return true;
            }
        }
    }
    return false;
}

/**
 * Bloco "view" do Unbound para os IPs isentos: ignoram as zonas de bloqueio globais,
 * mas continuam enxergando host overrides e registros DHCP do pfSense.
 */
function rules_wam_build_bypass_view($bypass_list) {
    if (empty($bypass_list)) return "";
    $conf = "  # IPs isentos (bypass) - usam a view wam_bypass\n";
    foreach ($bypass_list as $cidr) {
        $conf .= "  access-control-view: {$cidr} \"wam_bypass\"\n";
    }
    $conf .= "view:\n";
    $conf .= "  name: \"wam_bypass\"\n";
    $conf .= "  view-first: no\n";
    $conf .= "  local-zone: \"wam-bypass.invalid.\" static\n";
    // Curingas evitam erro se o arquivo não existir
    $conf .= "  include: /var/unbound/host_entries.con[f]\n";
    $conf .= "  include: /var/unbound/dhcpleases_entries.con[f]\n";
    // Volta ao contexto server: para não afetar o que o pfSense incluir depois
    $conf .= "server:\n";
    return $conf;
}

/**
 * Estado interno do pacote (valores originais do sistema para restaurar na desinstalação)
 */
function rules_wam_state_get($key, $default = null) {
    return config_get_path("installedpackages/rules_wam/state/{$key}", $default);
}

function rules_wam_state_set_once($key, $value) {
    if (config_get_path("installedpackages/rules_wam/state/{$key}", null) === null) {
        config_set_path("installedpackages/rules_wam/state/{$key}", $value);
        return true;
    }
    return false;
}

/**
 * Domínios que nunca são bloqueados, conforme as proteções marcadas
 */
function rules_wam_build_whitelist($wam_cfg) {
    $whitelist = array();

    if (!empty($wam_cfg['custom_whitelist'])) {
        foreach (rules_wam_parse_list($wam_cfg['custom_whitelist']) as $line) {
            $d = rules_wam_clean_domain($line);
            if ($d) {
                $whitelist[$d] = true;
            }
        }
    }

    // Infraestrutura Google usada por quase todos os sites e pelo Meet
    foreach (array('meet.google.com', 'apis.google.com', 'ssl.gstatic.com', 'clients6.google.com') as $d) {
        $whitelist[$d] = true;
    }

    $groups = array();
    if (!isset($wam_cfg['corp_protect_netskope']) || rules_wam_is_checked($wam_cfg['corp_protect_netskope'])) {
        $groups[] = array(
            'netskope.com', 'goskope.com', 'netskopedns.com', 'netskope.io', 'addon-netskope.com'
        );
    }
    if (!isset($wam_cfg['corp_protect_idp']) || rules_wam_is_checked($wam_cfg['corp_protect_idp'])) {
        // Somente os endpoints de login - não libera microsoft.com/office.com inteiros (isso anulava o bloqueio do Teams/Skype)
        $groups[] = array(
            'login.microsoftonline.com', 'login.microsoft.com', 'login.live.com', 'login.windows.net',
            'device.login.microsoftonline.com', 'autologon.microsoftazuread-sso.com',
            'msftauth.net', 'msauth.net', 'aadcdn.msftauthimages.net', 'msftidentity.com', 'msidentity.com',
            'okta.com', 'oktacdn.com', 'okta-emea.com', 'accounts.google.com'
        );
    }
    if (!isset($wam_cfg['corp_protect_tools']) || rules_wam_is_checked($wam_cfg['corp_protect_tools'])) {
        $groups[] = array(
            'putty.org', 'chiark.greenend.org.uk', 'the.earth.li', 'tartarus.org',
            'winscp.net', 'filezilla-project.org', '7-zip.org', 'notepad-plus-plus.org',
            'github.com', 'githubusercontent.com', 'githubassets.com',
            'gitlab.com', 'git-scm.com', 'sourceforge.net', 'osdn.net',
            'sysinternals.com', 'wireshark.org', 'nmap.org', 'dbeaver.io', 'postman.com', 'curl.se', 'mobatek.net',
            'python.org', 'pypi.org', 'pythonhosted.org'
        );
    }
    if (!isset($wam_cfg['corp_protect_cloudflare']) || rules_wam_is_checked($wam_cfg['corp_protect_cloudflare'])) {
        $groups[] = array(
            'cdnjs.cloudflare.com', 'challenges.cloudflare.com',
            'static.cloudflareinsights.com', 'cloudflareinsights.com', 'cf-assets.net'
        );
    }
    if (!isset($wam_cfg['corp_protect_helpdesk']) || rules_wam_is_checked($wam_cfg['corp_protect_helpdesk'])) {
        $groups[] = array(
            'zendesk.com', 'zdassets.com', 'zdstatic.com', 'zdusercontent.com',
            'zopim.com', 'zopim.io', 'zopim.net',
            'glpi-project.org', 'glpi-network.cloud', 'glpi-network.com', 'teclib.com', 'teclib-edition.com',
            'screenconnect.com', 'screenconnect.net', 'connectwise.com', 'connectwise.net', 'hostedrmm.com'
        );
    }
    if (!isset($wam_cfg['corp_protect_voip']) || rules_wam_is_checked($wam_cfg['corp_protect_voip'])) {
        $groups[] = array(
            'stun.l.google.com', 'stun1.l.google.com', 'stun2.l.google.com', 'stun3.l.google.com', 'stun4.l.google.com',
            'stun.sipgate.net', 'stun.voipbuster.com', 'stun.ekiga.net', 'stun.counterpath.com', 'stun.counterpath.net',
            'zoiper.com', 'linphone.org', 'microsip.org', 'micro-sip.org', 'counterpath.com', 'bria.com', 'sip.audio',
            'yealink.com', 'yealinkphones.com', 'grandstream.com', 'gdms.cloud',
            'intelbras.com.br', 'intelbras.com', 'fanvil.com', 'poly.com', 'polycom.com', 'snom.com',
            '3cx.com', '3cx.net', '3cx.eu', '3cx.us', 'sipgate.de', 'sipgate.com', 'sipgate.net',
            'twilio.com', 'telnyx.com', 'plivo.com', 'ringcentral.com', 'vonage.com', 'nexmo.com', '8x8.com',
            'voip.ms', 'callcentric.com', 'didlogic.com', 'flowroute.com',
            'jive.com', 'gotoconnect.com', 'dialpad.com', 'totalvoice.com.br', 'zenvia.com'
        );
    }
    foreach ($groups as $g) {
        foreach ($g as $d) {
            $whitelist[$d] = true;
        }
    }

    if (rules_wam_is_checked($wam_cfg['corp_enable'] ?? null)) {
        foreach (rules_wam_parse_list($wam_cfg['corp_ad_domain'] ?? '') as $cdom) {
            $c = rules_wam_clean_domain($cdom);
            if ($c) {
                $whitelist[$c] = true;
            }
        }
    }
    return $whitelist;
}

/**
 * Mapa de categorias: chave de configuração => rótulo e arquivo de feed
 */
function rules_wam_category_map() {
    return array(
        'block_adult'     => array('label' => 'Conteúdo Adulto',        'file' => 'adult.txt'),
        'block_gambling'  => array('label' => 'Apostas & Bets',         'file' => 'gambling.txt'),
        'block_news'      => array('label' => 'Notícias & Portais',     'file' => 'news.txt'),
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
}

/**
 * Aplica as regras ativas no Unbound
 */
function rules_wam_apply_rules($wam_cfg = null) {
    log_error("[Rules WAM] Compilando regras de bloqueio por categoria...");

    if (empty($wam_cfg) || !is_array($wam_cfg)) {
        $wam_cfg = rules_wam_get_config();
    }

    $blocked_domains = array();
    $cat_index = array();
    $whitelist = rules_wam_build_whitelist($wam_cfg);
    $bypass_list = rules_wam_get_bypass_list($wam_cfg);
    $protect_netskope = (!isset($wam_cfg['corp_protect_netskope']) || rules_wam_is_checked($wam_cfg['corp_protect_netskope']));
    $protect_cloudflare = (!isset($wam_cfg['corp_protect_cloudflare']) || rules_wam_is_checked($wam_cfg['corp_protect_cloudflare']));
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);

    $categories_active = array();
    foreach (rules_wam_category_map() as $cfg_key => $meta) {
        if (!rules_wam_is_checked($wam_cfg[$cfg_key] ?? null)) {
            continue;
        }
        $categories_active[] = $meta['label'];
        if ($cfg_key === 'block_vpn') {
            $sub_map = array(
                'block_vpn_fortinet'    => 'vpn-fortinet.txt',
                'block_vpn_cisco'       => 'vpn-cisco.txt',
                'block_vpn_paloalto'    => 'vpn-paloalto.txt',
                'block_ztna_zscaler'    => 'ztna-zscaler.txt',
                'block_ztna_netskope'   => 'ztna-netskope.txt',
                'block_ztna_cloudflare' => 'ztna-cloudflare.txt',
                'block_ztna_tailscale'  => 'ztna-tailscale.txt',
                'block_vpn_commercial'  => 'vpn-commercial.txt',
            );
        } elseif ($cfg_key === 'block_messaging') {
            $sub_map = array(
                'block_msg_whatsapp'    => 'msg-whatsapp.txt',
                'block_msg_telegram'    => 'msg-telegram.txt',
                'block_msg_messenger'   => 'msg-messenger.txt',
                'block_msg_teams_skype' => 'msg-teams-skype.txt',
                'block_msg_discord'     => 'msg-discord.txt',
                'block_msg_slack'       => 'msg-slack.txt',
                'block_msg_zoom_meet'   => 'msg-zoom-meet.txt',
                'block_msg_others'      => 'msg-others.txt',
            );
        } else {
            rules_wam_load_feed_domains($meta['file'], $blocked_domains, $whitelist, $meta['label'], $cat_index);
            continue;
        }

        $any_sub_specified = false;
        foreach (array_keys($sub_map) as $sub_k) {
            if (isset($wam_cfg[$sub_k])) {
                $any_sub_specified = true;
                break;
            }
        }
        foreach ($sub_map as $sub_k => $sub_f) {
            if ($sub_k === 'block_ztna_netskope' && $protect_netskope) {
                continue; // Netskope protegido contra bloqueio acidental
            }
            if ($sub_k === 'block_ztna_cloudflare' && $protect_cloudflare && !rules_wam_is_checked($wam_cfg['block_ztna_cloudflare'] ?? null)) {
                continue;
            }
            $is_sub_active = $any_sub_specified ? rules_wam_is_checked($wam_cfg[$sub_k] ?? null) : true;
            if ($is_sub_active) {
                rules_wam_load_feed_domains($sub_f, $blocked_domains, $whitelist, rules_wam_feed_label($sub_f), $cat_index);
            }
        }
    }

    if (!empty($wam_cfg['custom_blacklist'])) {
        foreach (rules_wam_parse_list($wam_cfg['custom_blacklist']) as $line) {
            $d = rules_wam_clean_domain($line);
            if ($d && !isset($whitelist[$d])) {
                $blocked_domains[$d] = true;
                $cat_index[$d] = 'Lista Negra Personalizada';
            }
        }
    }

    $block_action = rules_wam_effective_block_action($wam_cfg);
    $block_page_ip = rules_wam_get_block_page_ip($wam_cfg);

    // Remove subdomínios cujo domínio pai já está na lista (evita conflitos no Unbound)
    $clean_domains = array();
    foreach (array_keys($blocked_domains) as $d) {
        if (rules_wam_is_whitelisted($d, $whitelist)) {
            continue;
        }
        $parts = explode('.', $d);
        $has_parent = false;
        while (count($parts) > 1) {
            array_shift($parts);
            if (isset($blocked_domains[implode('.', $parts)])) {
                $has_parent = true;
                break;
            }
        }
        if (!$has_parent) {
            $clean_domains[] = $d;
        }
    }
    $total = count($clean_domains);

    $zones = "";
    foreach ($clean_domains as $dom) {
        if ($block_action === 'always_null') {
            $zones .= "  local-zone: \"{$dom}\" always_null\n";
        } else {
            $zones .= "  local-zone: \"{$dom}\" redirect\n";
            $zones .= "  local-data: \"{$dom} 60 IN A {$block_page_ip}\"\n";
        }
    }

    $head  = "# ====================================================\n";
    $head .= "# Rules WAM " . RULES_WAM_VERSION . " - Auto-gerado (nao edite)\n";
    $head .= "# Atualizado em: " . date('Y-m-d H:i:s') . "\n";
    $head .= "# Categorias ativas (" . count($categories_active) . "): " . implode(', ', $categories_active) . "\n";
    $head .= "# Total de dominios bloqueados: {$total}\n";
    $head .= "# ====================================================\n";
    $head .= "server:\n";
    $head .= "  log-local-actions: yes\n";
    $head .= "  log-queries: yes\n";
    $head .= rules_wam_build_common_conf($wam_cfg);

    $conf_full = $head . $zones . rules_wam_build_bypass_view($bypass_list);
    $bypass_ok = true;
    if (!rules_wam_write_unbound_conf($conf_full)) {
        $bypass_ok = false;
        if (!empty($bypass_list)) {
            log_error("[Rules WAM] Configuracao com bypass rejeitada pelo unbound-checkconf; aplicando sem a view de bypass.");
            if (!rules_wam_write_unbound_conf($head . $zones)) {
                rules_wam_write_unbound_conf("# Rules WAM - Protecao contra falha de sintaxe\nserver:\n", false);
                $total = 0;
            }
        } else {
            rules_wam_write_unbound_conf("# Rules WAM - Protecao contra falha de sintaxe\nserver:\n", false);
            $total = 0;
        }
    }

    // Arquivo de versões antigas que podia ser incluído em duplicidade
    if (file_exists('/var/unbound/conf.d/wam_blocklist.conf')) {
        @unlink('/var/unbound/conf.d/wam_blocklist.conf');
    }
    rules_wam_write_category_index($cat_index);
    $need_unbound_configure = rules_wam_ensure_unbound_include();
    if (rules_wam_sync_domain_overrides($wam_cfg)) {
        $need_unbound_configure = true;
    }
    if ($need_unbound_configure) {
        write_config("Rules WAM: integracao com o DNS Resolver atualizada");
        if (function_exists('services_unbound_configure')) {
            services_unbound_configure();
        }
    }
    rules_wam_reload_unbound();

    rules_wam_sync_banner_nginx($wam_cfg, !defined('RULES_WAM_BOOT'));
    rules_wam_sync_firewall_rules($wam_cfg, true);

    $conflict = rules_wam_banner_conflict();
    $status_data = array(
        'enabled' => true,
        'schedule_active' => rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null),
        'is_blocking' => true,
        'updated_at' => date('Y-m-d H:i:s'),
        'total_blocked' => $total,
        'categories' => $categories_active,
        'whitelist_count' => count($whitelist),
        'bypass_ips_count' => $bypass_ok ? count($bypass_list) : 0,
        'block_action' => $block_action,
        'banner_conflict' => $conflict,
        'dns_bypass_protection' => rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? null) ? 'Ativo (NAT da porta 53 para o firewall)' : 'Desativado',
        'corp_integration' => $corp_enable ? 'Ativo (AD & NPS via IPsec)' : 'Desativado',
        'netskope_protection' => $protect_netskope ? 'Ativo (Auto-Whitelist)' : 'Desativado',
        'helpdesk_protection' => (!isset($wam_cfg['corp_protect_helpdesk']) || rules_wam_is_checked($wam_cfg['corp_protect_helpdesk'])) ? 'Ativo (Zendesk, GLPI, ScreenConnect)' : 'Desativado',
        'voip_protection' => (!isset($wam_cfg['corp_protect_voip']) || rules_wam_is_checked($wam_cfg['corp_protect_voip'])) ? 'Ativo (SIP & SIP Phone)' : 'Desativado'
    );
    @file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));

    log_error("[Rules WAM] Sucesso: {$total} dominios bloqueados aplicados no Unbound DNS (acao: {$block_action}).");
}

/**
 * Rótulo de categoria a partir do nome do arquivo de feed
 */
function rules_wam_feed_label($file) {
    $map = array(
        'adult.txt'            => 'Conteúdo Adulto',
        'gambling.txt'         => 'Apostas & Bets',
        'news.txt'             => 'Notícias & Portais',
        'social-media.txt'     => 'Mídias Sociais',
        'sports.txt'           => 'Esportes & Placares',
        'streaming.txt'        => 'Streaming & Vídeo',
        'gaming.txt'           => 'Jogos & Games',
        'shopping.txt'         => 'Compras & E-commerce',
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
        'msg-zoom-meet.txt'    => 'Zoom',
        'msg-others.txt'       => 'Mensageiros Instantâneos',
        'messaging.txt'        => 'Mensageiros & Chat'
    );
    return $map[$file] ?? 'Regra Personalizada / Outros';
}

/**
 * Valida a configuração completa do Unbound (unbound.conf + nosso include). Retorna true se válida.
 */
function rules_wam_unbound_checkconf() {
    $ub_conf = '/var/unbound/unbound.conf';
    if (!file_exists('/usr/local/sbin/unbound-checkconf') || !file_exists($ub_conf)) {
        return true;
    }
    $out = array();
    $rc = 0;
    exec("/usr/local/sbin/unbound-checkconf " . escapeshellarg($ub_conf) . " 2>&1", $out, $rc);
    if ($rc !== 0) {
        @file_put_contents('/var/log/wam_checkconf_err.log', implode("\n", $out));
        log_error("[Rules WAM] unbound-checkconf falhou: " . implode(' | ', array_slice($out, 0, 3)));
        return false;
    }
    @unlink('/var/log/wam_checkconf_err.log');
    return true;
}

/**
 * Grava o arquivo de regras e, opcionalmente, valida. Em caso de falha, restaura o conteúdo anterior.
 */
function rules_wam_write_unbound_conf($content, $validate = true) {
    // Escreve via arquivo temporário + rename para o Unbound nunca ler um arquivo pela metade
    file_put_contents(WAM_CONF_FILE . '.tmp', $content);
    @chmod(WAM_CONF_FILE . '.tmp', 0644);
    rename(WAM_CONF_FILE . '.tmp', WAM_CONF_FILE);
    if (!$validate) {
        return true;
    }
    // Se o include ainda não está no unbound.conf, a checagem só valida o arquivo isolado
    $ub_conf = '/var/unbound/unbound.conf';
    $included = file_exists($ub_conf) && strpos((string)@file_get_contents($ub_conf), 'wam_blocklist') !== false;
    if ($included) {
        $ok = rules_wam_unbound_checkconf();
    } else {
        $ok = rules_wam_checkconf_standalone(WAM_CONF_FILE);
    }
    return $ok;
}

/**
 * Valida o arquivo de regras isoladamente (antes do include existir no unbound.conf)
 */
function rules_wam_checkconf_standalone($file) {
    if (!file_exists('/usr/local/sbin/unbound-checkconf')) {
        return true;
    }
    $tmp = '/tmp/rules_wam_check.conf';
    file_put_contents($tmp, "server:\n  chroot: \"\"\n  username: \"\"\n  directory: \"/tmp\"\ninclude: {$file}\n");
    $out = array();
    $rc = 0;
    exec("/usr/local/sbin/unbound-checkconf " . escapeshellarg($tmp) . " 2>&1", $out, $rc);
    @unlink($tmp);
    if ($rc !== 0) {
        log_error("[Rules WAM] unbound-checkconf (isolado) falhou: " . implode(' | ', array_slice($out, 0, 3)));
    }
    return $rc === 0;
}

/**
 * Garante a linha de include no custom_options do Unbound. Retorna true se alterou o config.
 */
function rules_wam_ensure_unbound_include($remove = false) {
    $raw_opts = config_get_path('unbound/custom_options', '');
    $cur_opts = '';
    if (!empty($raw_opts)) {
        $decoded = @base64_decode($raw_opts, true);
        $cur_opts = ($decoded !== false && base64_encode($decoded) === $raw_opts) ? $decoded : $raw_opts;
    }
    $lines = array();
    foreach (preg_split('/\r\n|\r|\n/', $cur_opts) as $l) {
        $t = trim($l);
        if ($t === '' || strpos($t, 'wam_blocklist') !== false) continue;
        $lines[] = $t;
    }
    if (!$remove) {
        $lines[] = WAM_CONF_INCLUDE;
    }
    $new_custom = trim(implode("\n", $lines));
    $changed = false;
    if ($new_custom !== trim($cur_opts)) {
        config_set_path('unbound/custom_options', ($new_custom === '') ? '' : base64_encode($new_custom));
        $changed = true;
    }
    if (!$remove) {
        // log de consultas é necessário para o dashboard; guarda o valor original para a desinstalação
        rules_wam_state_set_once('orig_log_queries', config_get_path('unbound/log_queries') !== null ? 'yes' : 'no');
        if (config_get_path('unbound/log_queries') === null) {
            config_set_path('unbound/log_queries', 'yes');
            $changed = true;
        }
    }
    $ub_conf = '/var/unbound/unbound.conf';
    if (!$remove && file_exists($ub_conf) && strpos((string)@file_get_contents($ub_conf), 'wam_blocklist') === false) {
        $changed = true;
    }
    return $changed;
}

/**
 * Grava o índice domínio => categoria usado pela página de bloqueio e pelo dashboard
 */
function rules_wam_write_category_index($cat_index) {
    @mkdir(dirname(WAM_CAT_INDEX), 0755, true);
    $json = json_encode($cat_index, JSON_UNESCAPED_UNICODE);
    if ($json !== false) {
        @file_put_contents(WAM_CAT_INDEX . '.tmp', $json);
        @rename(WAM_CAT_INDEX . '.tmp', WAM_CAT_INDEX);
    }
}

/**
 * Fora do horário: mantém só AD/redes autorizadas e as regras de acesso à WebGUI
 */
function rules_wam_suspend_schedule($wam_cfg = null) {
    if ($wam_cfg === null) {
        $wam_cfg = rules_wam_get_config();
    }
    $conf = "# Rules WAM - Fora do Horario Comercial (Acesso Liberado)\nserver:\n  log-local-actions: yes\n";
    $conf .= rules_wam_build_common_conf($wam_cfg);
    if (!rules_wam_write_unbound_conf($conf)) {
        rules_wam_write_unbound_conf("# Rules WAM - Protecao contra falha de sintaxe\nserver:\n", false);
    }
    if (rules_wam_ensure_unbound_include()) {
        write_config("Rules WAM: integracao com o DNS Resolver atualizada");
        if (function_exists('services_unbound_configure')) {
            services_unbound_configure();
        }
    }
    rules_wam_reload_unbound();

    // Banner e regras de bloqueio (WhatsApp, DoT, NAT 53) desligados fora do horário
    rules_wam_sync_banner_nginx(array('enable' => 'no', 'block_action' => 'always_null'));
    rules_wam_sync_firewall_rules($wam_cfg, false);

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
    @file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));
    log_error("[Rules WAM] Fora do horario comercial: bloqueios temporariamente liberados.");
}

/**
 * Desativa o filtro. Mantém as regras de acesso à WebGUI (evita perder o acesso administrativo).
 * $full = true remove tudo (usado na desinstalação).
 */
function rules_wam_disable($full = false) {
    @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Desativado\nserver:\n");
    @chmod(WAM_CONF_FILE, 0644);
    if (file_exists('/var/unbound/conf.d/wam_blocklist.conf')) {
        @unlink('/var/unbound/conf.d/wam_blocklist.conf');
    }

    $changed = rules_wam_ensure_unbound_include(true);
    if (rules_wam_sync_domain_overrides(array('corp_enable' => 'no'))) {
        $changed = true;
    }
    if ($full) {
        $orig = rules_wam_state_get('orig_log_queries');
        if ($orig === 'no' && config_get_path('unbound/log_queries') !== null) {
            if (function_exists('config_del_path')) {
                config_del_path('unbound/log_queries');
            } else {
                global $config;
                unset($config['unbound']['log_queries']);
            }
            $changed = true;
        }
    }
    if ($changed) {
        write_config("Rules WAM desativado no Unbound");
        if (function_exists('services_unbound_configure')) {
            services_unbound_configure();
        }
    }

    rules_wam_sync_banner_nginx(array('enable' => 'no', 'block_action' => 'always_null'));
    if ($full) {
        rules_wam_remove_firewall_rules();
    } else {
        rules_wam_sync_firewall_rules(array('enable' => 'no') + rules_wam_get_config(), false);
    }

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
    @file_put_contents(WAM_STATUS_FILE, json_encode($status_data, JSON_PRETTY_PRINT));
    rules_wam_reload_unbound();
    log_error("[Rules WAM] Servico desabilitado.");
}

/**
 * Normaliza uma regra para comparação (ignora carimbos de tempo e tracker)
 */
function rules_wam_rule_signature($rules) {
    // Normaliza tipos (o config.xml devolve tudo como string após gravar/ler)
    $norm = function ($v) use (&$norm) {
        if (is_array($v)) {
            ksort($v);
            return array_map($norm, $v);
        }
        if ($v === true || $v === null) return '';
        return (string)$v;
    };
    $out = array();
    foreach ((array)$rules as $r) {
        if (is_array($r)) {
            unset($r['created'], $r['updated'], $r['tracker'], $r['id']);
        }
        $out[] = $norm($r);
    }
    return serialize($out);
}

/**
 * Cria/atualiza ou remove um alias gerenciado pelo Rules WAM
 */
function rules_wam_set_alias($name, $type, $entries, $descr) {
    global $config;
    init_config_arr(array("aliases", "alias"));
    $idx_found = null;
    foreach ($config["aliases"]["alias"] as $idx => $a) {
        if (isset($a["name"]) && $a["name"] === $name) {
            $idx_found = $idx;
            break;
        }
    }
    if (empty($entries)) {
        if ($idx_found !== null) {
            unset($config["aliases"]["alias"][$idx_found]);
            $config["aliases"]["alias"] = array_values($config["aliases"]["alias"]);
            return true;
        }
        return false;
    }
    $data = array(
        "name" => $name,
        "type" => $type,
        "address" => implode(" ", $entries),
        "descr" => $descr . " (Rules WAM)",
        "detail" => implode("||", array_fill(0, count($entries), "Rules WAM"))
    );
    if ($idx_found !== null) {
        if ($config["aliases"]["alias"][$idx_found] == $data) {
            return false;
        }
        $config["aliases"]["alias"][$idx_found] = $data;
    } else {
        $config["aliases"]["alias"][] = $data;
    }
    return true;
}

/**
 * Lista de origens (IPs/CIDRs IPv4/IPv6) validadas a partir de um campo de texto
 */
function rules_wam_parse_sources($str) {
    $valid = array();
    foreach (rules_wam_parse_list($str) as $s) {
        if (is_ipaddr($s) || is_subnet($s)) {
            $valid[] = $s;
        }
    }
    return array_values(array_unique($valid));
}

/**
 * Monta uma regra de firewall no formato do config.xml do pfSense
 */
function rules_wam_make_rule($tracker, $type, $interface, $proto, $source, $destination, $descr, $floating = false, $ipproto = "inet46") {
    $r = array(
        "id" => "",
        "tracker" => (string)$tracker,
        "type" => $type,
        "interface" => $interface,
        "ipprotocol" => $ipproto,
        "tag" => "",
        "tagged" => "",
        "direction" => "in",
        "quick" => "yes",
        "source" => $source,
        "destination" => $destination,
        "descr" => "Rules WAM - " . $descr,
        "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => time(), "username" => "Rules WAM")
    );
    if (!empty($proto)) {
        $r["protocol"] = $proto;
    }
    if ($floating) {
        $r["floating"] = "yes";
    }
    return $r;
}

/**
 * Sincroniza as regras automáticas de firewall/NAT do Rules WAM.
 *
 * $blocking = true  -> aplica regras de bloqueio (WhatsApp, DoT, anti-bypass DNS) + acesso ao banner
 * $blocking = false -> mantém apenas as regras de acesso à WebGUI (usado fora do horário e com o serviço desativado)
 *
 * Nunca cria regras na WAN, exceto a regra de WebGUI restrita às origens definidas em "gui_wan_sources".
 * Nunca altera bogons, redes privadas na WAN, DNS rebind nem a porta da WebGUI.
 */
function rules_wam_sync_firewall_rules($wam_cfg = null, $blocking = true) {
    require_once("config.inc");
    require_once("filter.inc");
    require_once("util.inc");
    global $config;

    if ($wam_cfg === null) {
        $wam_cfg = rules_wam_get_config();
    }
    if (!rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
        $blocking = false;
    }

    init_config_arr(array("aliases", "alias"));
    init_config_arr(array("filter", "rule"));
    init_config_arr(array("nat", "rule"));
    $alias_changed = false;

    $configured_internal = rules_wam_get_configured_interfaces(false);
    if (empty($configured_internal)) {
        $configured_internal = array('lan' => array('key' => 'lan', 'descr' => 'LAN'));
    }
    $internal_ifaces = array_keys($configured_internal);
    $if_list = implode(",", $internal_ifaces);

    $rules_to_add = array();   // vão para o topo (bloqueios e banner)
    $gui_rules = array();      // vão para o FINAL: não passam por cima das regras do administrador
    $nat_to_add = array();

    // ------------------------------------------------------------------
    // 1. Acesso à WebGUI (porta atual) - destino restrito ao próprio firewall
    // ------------------------------------------------------------------
    $gui_proto = config_get_path('system/webgui/protocol', 'https');
    $gui_port = config_get_path('system/webgui/port', '');
    if (empty($gui_port)) {
        $gui_port = ($gui_proto === 'https') ? '443' : '80';
    }

    $admin_sources = rules_wam_parse_sources($wam_cfg['gui_admin_sources'] ?? '');
    $alias_changed = rules_wam_set_alias("WAM_GUI_Admins", "network", $admin_sources, "Origens autorizadas a acessar a WebGUI pelas redes internas") || $alias_changed;
    $gui_src = empty($admin_sources) ? array("any" => "") : array("address" => "WAM_GUI_Admins");

    $tracker = 1700000011;
    foreach ($configured_internal as $if_key => $if_data) {
        $if_label = !empty($if_data['descr']) ? $if_data['descr'] : strtoupper($if_key);
        $gui_rules[] = rules_wam_make_rule($tracker++, "pass", $if_key, "tcp", $gui_src,
            array("network" => "(self)", "port" => (string)$gui_port),
            "Acesso WebGUI {$if_label} (Porta {$gui_port})");
    }

    // WebGUI pela WAN somente se o administrador definir explicitamente as origens permitidas
    $wan_sources = rules_wam_parse_sources($wam_cfg['gui_wan_sources'] ?? '');
    $alias_changed = rules_wam_set_alias("WAM_GUI_WAN_Sources", "network", $wan_sources, "Origens externas autorizadas a acessar a WebGUI pela WAN") || $alias_changed;
    if (!empty($wan_sources)) {
        $gui_rules[] = rules_wam_make_rule(1700000010, "pass", "wan", "tcp",
            array("address" => "WAM_GUI_WAN_Sources"),
            array("network" => "(self)", "port" => (string)$gui_port),
            "Acesso WebGUI WAN restrito (Porta {$gui_port})");
    }

    // ------------------------------------------------------------------
    // 2. Regras de bloqueio (somente durante o bloqueio ativo)
    // ------------------------------------------------------------------
    $is_msg_active = rules_wam_is_checked($wam_cfg['block_messaging'] ?? null);
    $is_wa_active = !isset($wam_cfg['block_msg_whatsapp']) || rules_wam_is_checked($wam_cfg['block_msg_whatsapp']);
    $wa_by_ip = rules_wam_is_checked($wam_cfg['block_wa_by_ip'] ?? 'no');
    $wa_rules_on = $blocking && $is_msg_active && $is_wa_active;

    // Portas próprias do WhatsApp (5222 XMPP, 4244 mídia). A 5223 NÃO entra: é a porta do Apple Push (APNs).
    $alias_changed = rules_wam_set_alias("WAM_WhatsApp_Ports", "port", $wa_rules_on ? array("5222", "4244") : array(), "Portas do WhatsApp Mobile") || $alias_changed;

    // Bloqueio por faixa IP é opcional: as faixas são compartilhadas com Facebook/Instagram (Meta)
    $wa_cidrs = array(
        "157.240.128.0/17", "129.134.128.0/17", "102.132.112.0/20", "102.221.188.0/22",
        "185.89.216.0/22", "196.49.68.0/23", "204.15.20.0/22", "31.13.64.0/18"
    );
    $alias_changed = rules_wam_set_alias("WAM_WhatsApp_Nets", "network", ($wa_rules_on && $wa_by_ip) ? $wa_cidrs : array(), "Faixas IP Meta usadas pelo WhatsApp - afeta Facebook/Instagram") || $alias_changed;

    // Banner de bloqueio: só o IP do banner, portas 80/443
    $effective_action = rules_wam_effective_block_action($wam_cfg);
    $banner_ip = rules_wam_get_block_page_ip($wam_cfg);
    $banner_on = $blocking && $effective_action === 'block_page' && !empty($banner_ip);
    $alias_changed = rules_wam_set_alias("WAM_Banner_Ports", "port", $banner_on ? array("80", "443") : array(), "Portas do banner de bloqueio") || $alias_changed;

    // Remove alias legado do AD quando não utilizado
    $corp_enable = rules_wam_is_checked($wam_cfg['corp_enable'] ?? null);
    $valid_ad_ips = array();
    if ($corp_enable) {
        foreach (rules_wam_parse_list($wam_cfg['corp_ad_dns_ips'] ?? '') as $cip) {
            if (filter_var($cip, FILTER_VALIDATE_IP)) {
                $valid_ad_ips[] = $cip;
            }
        }
    }
    $block_dns_bypass = $blocking && rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? 'no');
    $alias_changed = rules_wam_set_alias("WAM_Corp_AD_DNS", "host", $block_dns_bypass ? $valid_ad_ips : array(), "Servidores DNS/AD e NPS RADIUS da matriz") || $alias_changed;

    if ($banner_on) {
        $rules_to_add[] = rules_wam_make_rule(1700000099, "pass", $if_list, "tcp",
            array("any" => ""),
            array("address" => $banner_ip, "port" => "WAM_Banner_Ports"),
            "Acesso ao Banner de Bloqueio ({$banner_ip} portas 80/443)", true, "inet");
    }

    // Anti-bypass DoT (853) somente quando a categoria Anti-Bypass DoH estiver marcada
    if ($blocking && rules_wam_is_checked($wam_cfg['block_doh'] ?? null)) {
        $rules_to_add[] = rules_wam_make_rule(1700000101, "reject", $if_list, "tcp/udp",
            array("any" => ""),
            array("any" => "", "port" => "853"),
            "Anti-Bypass DNS-over-TLS (853)", true);
    }

    if ($wa_rules_on) {
        $rules_to_add[] = rules_wam_make_rule(1700000202, "reject", $if_list, "tcp/udp",
            array("any" => ""),
            array("any" => "", "port" => "WAM_WhatsApp_Ports"),
            "Bloqueio de Portas WhatsApp Mobile (5222/4244)", true);
        if ($wa_by_ip) {
            $rules_to_add[] = rules_wam_make_rule(1700000303, "reject", $if_list, "",
                array("any" => ""),
                array("address" => "WAM_WhatsApp_Nets"),
                "Bloqueio por IP WhatsApp (faixas Meta)", true);
        }
    }

    // Anti-bypass DNS porta 53 (NAT para o Unbound local)
    if ($block_dns_bypass) {
        if (!empty($valid_ad_ips)) {
            $rules_to_add[] = rules_wam_make_rule(1700000504, "pass", $if_list, "tcp/udp",
                array("any" => ""),
                array("address" => "WAM_Corp_AD_DNS", "port" => "53"),
                "Liberacao Direta de DNS para Controladores de Dominio AD", true);
        }
        foreach ($internal_ifaces as $idx => $intf) {
            $intf_label = !empty($configured_internal[$intf]['descr']) ? $configured_internal[$intf]['descr'] : strtoupper($intf);
            if (!empty($valid_ad_ips)) {
                $nat_to_add[] = array(
                    "id" => "",
                    "tracker" => (string)(1700004030 + $idx),
                    "interface" => $intf,
                    "nordr" => "yes",
                    "ipprotocol" => "inet",
                    "protocol" => "tcp/udp",
                    "source" => array("any" => ""),
                    "destination" => array("address" => "WAM_Corp_AD_DNS", "port" => "53"),
                    "descr" => "Rules WAM - Excecao NAT Anti-Bypass AD/DNS ({$intf_label})",
                    "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => time(), "username" => "Rules WAM")
                );
            }
            $nat_to_add[] = array(
                "id" => "",
                "tracker" => (string)(1700004040 + $idx),
                "interface" => $intf,
                "ipprotocol" => "inet",
                "protocol" => "tcp/udp",
                "source" => array("any" => ""),
                "destination" => array("not" => "", "network" => "{$intf}ip", "port" => "53"),
                "target" => "127.0.0.1",
                "local-port" => "53",
                "descr" => "Rules WAM - Anti-Bypass DNS Redirection ({$intf_label} Porta 53)",
                "associated-rule-id" => "pass",
                "created" => function_exists("make_config_revision_entry") ? make_config_revision_entry() : array("time" => time(), "username" => "Rules WAM")
            );
        }
    }

    // ------------------------------------------------------------------
    // 3. Mescla com as regras do administrador (as do Rules WAM vão no topo)
    // ------------------------------------------------------------------
    $current_filter_rules = $config["filter"]["rule"];
    $current_nat_rules = $config["nat"]["rule"];

    $old_wam_rules = array();
    $cleaned_rules = array();
    foreach ($current_filter_rules as $r) {
        if (isset($r["descr"]) && strpos($r["descr"], "Rules WAM - ") === 0) {
            $old_wam_rules[] = $r;
        } else {
            $cleaned_rules[] = $r;
        }
    }
    $old_wam_nat = array();
    $cleaned_nat = array();
    foreach ($current_nat_rules as $nr) {
        if (isset($nr["descr"]) && strpos($nr["descr"], "Rules WAM - ") === 0) {
            $old_wam_nat[] = $nr;
        } else {
            $cleaned_nat[] = $nr;
        }
    }

    $filter_changed = (rules_wam_rule_signature($old_wam_rules) !== rules_wam_rule_signature(array_merge($rules_to_add, $gui_rules)));
    $nat_changed = (rules_wam_rule_signature($old_wam_nat) !== rules_wam_rule_signature($nat_to_add));

    if (!$filter_changed && !$nat_changed && !$alias_changed) {
        return false;
    }

    $config["filter"]["rule"] = array_merge($rules_to_add, $cleaned_rules, $gui_rules);
    $config["nat"]["rule"] = array_merge($cleaned_nat, $nat_to_add);
    write_config("Rules WAM: sincronizacao das regras de firewall/NAT");
    filter_configure();

    // Derruba conexões já estabelecidas com as faixas do WhatsApp somente se o bloqueio por IP estiver ativo
    if ($wa_rules_on && $wa_by_ip) {
        foreach ($wa_cidrs as $cidr) {
            mwexec('/sbin/pfctl -k 0.0.0.0/0 -k ' . escapeshellarg($cidr) . ' 2>/dev/null');
        }
    }

    log_error("[Rules WAM] Regras de firewall sincronizadas (bloqueio " . ($blocking ? "ativo" : "inativo") . ").");
    return true;
}

/**
 * Remove TODAS as regras/aliases automáticos do Rules WAM (usado apenas na desinstalação)
 */
function rules_wam_remove_firewall_rules() {
    require_once("config.inc");
    require_once("filter.inc");
    global $config;

    init_config_arr(array("filter", "rule"));
    init_config_arr(array("nat", "rule"));
    init_config_arr(array("aliases", "alias"));
    $changed = false;

    foreach (array(array("filter", "rule"), array("nat", "rule")) as $p) {
        $kept = array();
        foreach ($config[$p[0]][$p[1]] as $r) {
            if (isset($r["descr"]) && strpos($r["descr"], "Rules WAM") !== false) {
                $changed = true;
                continue;
            }
            $kept[] = $r;
        }
        $config[$p[0]][$p[1]] = $kept;
    }
    $kept = array();
    foreach ($config["aliases"]["alias"] as $a) {
        if (isset($a["name"]) && strpos($a["name"], "WAM_") === 0) {
            $changed = true;
            continue;
        }
        $kept[] = $a;
    }
    $config["aliases"]["alias"] = $kept;

    if ($changed) {
        write_config("Rules WAM: remocao das regras de firewall, NAT e aliases");
        filter_configure();
    }
    return $changed;
}

function rules_wam_is_in_schedule_window($wam_cfg, $now = null) {
    if ($now === null) {
        $now = time();
    }
    $now_dow = intval(date('w', $now));
    $now_time = date('H:i', $now);

    if (($now_dow === 0 || $now_dow === 6) && !rules_wam_is_checked($wam_cfg['schedule_weekend'] ?? null)) {
        return false;
    }

    $start = rules_wam_normalize_time($wam_cfg['schedule_start'] ?? '') ?: '08:00';
    $end   = rules_wam_normalize_time($wam_cfg['schedule_end'] ?? '') ?: '18:00';
    $l_start = rules_wam_normalize_time($wam_cfg['schedule_lunch_start'] ?? '');
    $l_end   = rules_wam_normalize_time($wam_cfg['schedule_lunch_end'] ?? '');

    if ($l_start !== '' && $l_end !== '' && $now_time >= $l_start && $now_time < $l_end) {
        return false;
    }

    if ($start <= $end) {
        return ($now_time >= $start && $now_time < $end);
    }
    // Janela que atravessa a meia-noite (ex.: 22:00 -> 06:00)
    return ($now_time >= $start || $now_time < $end);
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
 * O config.xml do pfSense perde as quebras de linha de campos multilinha
 * (as linhas eram gravadas grudadas, ex.: "10.0.0.0/8172.16.0.0/12").
 * Por isso as listas são gravadas em uma linha só, separadas por espaço.
 */
function rules_wam_list_to_store($str) {
    return implode(' ', rules_wam_parse_list((string)$str));
}

/** Lista gravada -> texto para o textarea (um item por linha) */
function rules_wam_list_to_text($str) {
    return implode("\n", rules_wam_parse_list((string)$str));
}

/** Mapeamento "IP = Nome" (nomes podem ter espaço): gravado com " | " entre as entradas */
function rules_wam_hosts_split($str) {
    $out = array();
    foreach (preg_split('/[\r\n|]+/', (string)$str) as $l) {
        $l = trim($l);
        if ($l !== '') {
            $out[] = $l;
        }
    }
    return $out;
}

function rules_wam_hosts_to_store($str) {
    return implode(' | ', rules_wam_hosts_split($str));
}

function rules_wam_hosts_to_text($str) {
    return implode("\n", rules_wam_hosts_split($str));
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

    if ($new_overrides == $existing_overrides) {
        return false;
    }
    config_set_path('unbound/domainoverrides', $new_overrides);
    return true;
}

function rules_wam_load_feed_domains($feed_file, &$blocked_domains, &$whitelist, $label = null, &$cat_index = null) {
    $path = WAM_FEEDS_DIR . '/' . basename($feed_file);
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
            if ($label !== null && is_array($cat_index) && !isset($cat_index[$d])) {
                $cat_index[$d] = $label;
            }
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

    // 2. Última barreira: se a configuração completa estiver inválida, neutraliza nossas regras
    //    para não derrubar o DNS da rede (o motivo fica em /var/log/wam_checkconf_err.log)
    if (!rules_wam_unbound_checkconf()) {
        log_error("[Rules WAM] Configuracao do Unbound invalida. Neutralizando regras do Rules WAM para proteger a rede.");
        @file_put_contents(WAM_CONF_FILE, "# Rules WAM - Protecao contra falha de sintaxe\nserver:\n");
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
        // reload relê a configuração e já descarta o cache
        mwexec("/usr/local/sbin/unbound-control -c {$ub_conf} reload 2>/dev/null");
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
        $lines = rules_wam_hosts_split($wam_cfg['custom_hosts']);
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
    // 1. Índice pré-calculado na aplicação das regras (rápido; usado pela página de bloqueio)
    if ($cat_index === null && file_exists(WAM_CAT_INDEX)) {
        $idx = @json_decode(@file_get_contents(WAM_CAT_INDEX), true);
        if (is_array($idx) && !empty($idx)) {
            $cat_index = $idx;
        }
    }
    // 2. Fallback: varre os feeds (apenas se o índice ainda não existir)
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
    if (empty($d)) return 'Regra Personalizada / Outros';
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
            // Formato FreeBSD: ? (192.168.10.10) at 00:11:22:33:44:55 on em0 expires in 1198 seconds [ethernet]
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
    // "Sem limite" fica limitado a 20.000 eventos para não estourar memória/tempo da WebGUI
    if ($limit <= 0 || $limit > 20000) {
        $limit = 20000;
    }
    $wam_cfg = rules_wam_get_config();
    $lan_ip = config_get_path('interfaces/lan/ipaddr', '');
    $cfg_ip = !empty($wam_cfg['block_page_ip']) ? $wam_cfg['block_page_ip'] : '';

    // 1. Lê o final do wam_audit.log (registros da página de bloqueio)
    if (file_exists(WAM_AUDIT_LOG)) {
        $lines = array();
        @exec('/usr/bin/tail -n ' . intval($limit * 2) . ' ' . escapeshellarg(WAM_AUDIT_LOG) . ' 2>/dev/null', $lines);
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
                    if (count($parts) >= 3 && count($parts) <= 5) {
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
                if (!filter_var($ip, FILTER_VALIDATE_IP) || empty($dom) || strpos($dom, '.') === false) {
                    continue; // linha malformada/forjada
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
    $tail_count = min(intval($limit * 3), 60000);

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
 * Remove caracteres que quebrariam o formato do log ou virariam fórmula em planilhas
 */
function rules_wam_log_field($v, $max = 253) {
    $v = preg_replace('/[\x00-\x1F\x7F|]+/u', ' ', (string)$v);
    $v = trim($v);
    return mb_substr($v, 0, $max);
}

/**
 * Grava um evento no log de auditoria (com trava e rotação simples por tamanho)
 */
function rules_wam_audit_write($ip, $domain, $category = '', $hostname = '') {
    if (!filter_var($ip, FILTER_VALIDATE_IP)) {
        return false;
    }
    $domain = rules_wam_clean_domain($domain);
    if (empty($domain)) {
        return false;
    }
    clearstatcache(true, WAM_AUDIT_LOG);
    if (file_exists(WAM_AUDIT_LOG) && filesize(WAM_AUDIT_LOG) > WAM_AUDIT_MAX_BYTES) {
        @rename(WAM_AUDIT_LOG, WAM_AUDIT_LOG . '.1');
    }
    $line = implode('|', array(
        date('Y-m-d H:i:s'),
        $ip,
        $domain,
        rules_wam_log_field($category, 80),
        rules_wam_log_field($hostname, 120)
    )) . "\n";
    return @file_put_contents(WAM_AUDIT_LOG, $line, FILE_APPEND | LOCK_EX) !== false;
}

/**
 * Protege células de CSV contra injeção de fórmula (Excel/LibreOffice)
 */
function rules_wam_csv_safe($v) {
    $v = (string)$v;
    if ($v !== '' && strpos("=+-@\t\r", $v[0]) !== false) {
        return "'" . $v;
    }
    return $v;
}

/**
 * IP em que o banner é servido (precisa ser um IP de interface interna)
 */
function rules_wam_get_block_page_ip($wam_cfg = null) {
    if ($wam_cfg === null) {
        $wam_cfg = rules_wam_get_config();
    }
    $ip = trim($wam_cfg['block_page_ip'] ?? '');
    if (!empty($ip) && filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        foreach (rules_wam_get_configured_interfaces(false) as $if_data) {
            if (!empty($if_data['ip']) && $if_data['ip'] === $ip) {
                return $ip;
            }
        }
    }
    return rules_wam_get_lan_ip();
}

/**
 * Verifica se a WebGUI ocupa as portas 80/443 (o banner não pode subir nesse caso).
 * Retorna string com o motivo ou '' se não houver conflito.
 */
function rules_wam_banner_conflict() {
    $proto = config_get_path('system/webgui/protocol', 'https');
    $port = config_get_path('system/webgui/port', '');
    if (empty($port)) {
        $port = ($proto === 'https') ? '443' : '80';
    }
    if ($port === '80' || $port === '443') {
        return "A WebGUI está na porta {$port}.";
    }
    if ($proto === 'https' && config_get_path('system/webgui/disablehttpredirect') === null) {
        return "O redirecionamento HTTP da WebGUI (porta 80) está ativo.";
    }
    return '';
}

/**
 * Ação efetiva: cai para 'always_null' quando o banner não pode ser servido
 */
function rules_wam_effective_block_action($wam_cfg) {
    $action = !empty($wam_cfg['block_action']) ? trim($wam_cfg['block_action']) : 'block_page';
    if ($action !== 'always_null' && $action !== 'block_page') {
        $action = 'block_page';
    }
    if ($action === 'block_page' && rules_wam_banner_conflict() !== '') {
        return 'always_null';
    }
    return $action;
}

/**
 * Gera a configuração do NGINX do banner.
 * - Escuta somente no IP do banner (nunca em todas as interfaces)
 * - Porta 80: página de bloqueio via PHP-FPM (mesmo usuário da WebGUI do pfSense, sem chmod no socket)
 * - Porta 443: recusa o handshake TLS (sem CA nas máquinas, falha rápida em vez de aviso de certificado)
 * - Limite de requisições por cliente
 */
function rules_wam_banner_nginx_conf($banner_ip, $with_tls_reject = true) {
    $c  = "# Gerado automaticamente pelo Rules WAM - nao edite\n";
    $c .= "user root wheel;\n";
    $c .= "worker_processes 1;\n";
    $c .= "pid /var/run/rules_wam_ssl.pid;\n";
    $c .= "error_log /var/log/rules_wam_ssl.log warn;\n";
    $c .= "events {\n    worker_connections 512;\n}\n";
    $c .= "http {\n";
    $c .= "    access_log off;\n";
    $c .= "    server_tokens off;\n";
    $c .= "    default_type text/html;\n";
    $c .= "    client_max_body_size 1k;\n";
    $c .= "    client_body_timeout 5s;\n";
    $c .= "    client_header_timeout 5s;\n";
    $c .= "    keepalive_timeout 5s;\n";
    $c .= "    limit_req_zone \$binary_remote_addr zone=wam_banner:1m rate=5r/s;\n";
    $c .= "    limit_req_status 429;\n\n";
    $c .= "    server {\n";
    $c .= "        listen {$banner_ip}:80 default_server;\n";
    $c .= "        server_name _;\n";
    $c .= "        location = /favicon.ico { return 204; }\n";
    $c .= "        location = /robots.txt { return 204; }\n";
    $c .= "        location / {\n";
    $c .= "            limit_req zone=wam_banner burst=20 nodelay;\n";
    $c .= "            if (\$request_method !~ ^(GET|HEAD)\$) { return 405; }\n";
    $c .= "            fastcgi_pass unix:/var/run/php-fpm.socket;\n";
    $c .= "            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;\n";
    $c .= "            fastcgi_param SCRIPT_NAME /rules_wam_block.php;\n";
    $c .= "            fastcgi_param DOCUMENT_URI /rules_wam_block.php;\n";
    $c .= "            fastcgi_param DOCUMENT_ROOT /usr/local/www;\n";
    $c .= "            fastcgi_param QUERY_STRING \"\";\n";
    $c .= "            fastcgi_param REQUEST_METHOD \$request_method;\n";
    $c .= "            fastcgi_param REQUEST_URI /;\n";
    $c .= "            fastcgi_param SERVER_PROTOCOL \$server_protocol;\n";
    $c .= "            fastcgi_param REMOTE_ADDR \$remote_addr;\n";
    $c .= "            fastcgi_param SERVER_ADDR \$server_addr;\n";
    $c .= "            fastcgi_param SERVER_PORT \$server_port;\n";
    $c .= "            fastcgi_param SERVER_NAME \$host;\n";
    $c .= "            fastcgi_param HTTP_HOST \$host;\n";
    $c .= "            fastcgi_param WAM_BANNER 1;\n";
    $c .= "            fastcgi_param GATEWAY_INTERFACE CGI/1.1;\n";
    $c .= "            fastcgi_param SERVER_SOFTWARE nginx;\n";
    $c .= "            fastcgi_param REDIRECT_STATUS 200;\n";
    $c .= "            fastcgi_pass_request_headers off;\n";
    $c .= "            fastcgi_read_timeout 10s;\n";
    $c .= "            fastcgi_send_timeout 10s;\n";
    $c .= "            fastcgi_connect_timeout 3s;\n";
    $c .= "        }\n";
    $c .= "    }\n";
    if ($with_tls_reject) {
        $c .= "\n    server {\n";
        $c .= "        listen {$banner_ip}:443 ssl default_server;\n";
        $c .= "        server_name _;\n";
        $c .= "        ssl_reject_handshake on;\n";
        $c .= "    }\n";
    }
    $c .= "}\n";
    return $c;
}

/**
 * Script rc.d do banner. Para somente o NGINX do Rules WAM (pelo PID/arquivo de config),
 * nunca outros processos nas portas 80/443.
 */
function rules_wam_banner_rc_script() {
    return <<<'EOF_RC'
#!/bin/sh
# Rules WAM - NGINX do banner de bloqueio (gerado automaticamente)
CONF=/usr/local/etc/nginx/rules_wam_ssl.conf
PIDF=/var/run/rules_wam_ssl.pid

stop_banner() {
    if [ -f "$PIDF" ]; then
        PID=$(cat "$PIDF" 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill -QUIT "$PID" 2>/dev/null || true
            sleep 1
        fi
    fi
    pkill -TERM -f "nginx: master process .*rules_wam_ssl.conf" 2>/dev/null || true
    rm -f "$PIDF"
}

start_banner() {
    [ -f "$CONF" ] || exit 0
    /usr/local/sbin/nginx -t -c "$CONF" >/dev/null 2>>/var/log/rules_wam_ssl.log || exit 1
    /usr/local/sbin/nginx -c "$CONF" 2>>/var/log/rules_wam_ssl.log
}

case "$1" in
    stop)
        stop_banner
        ;;
    restart)
        stop_banner
        start_banner
        ;;
    start|*)
        # Na inicialização do sistema, regenera as regras (o /var pode ser RAM disk) sem reiniciar o banner em loop
        if [ "$1" = "start" ] && [ -f /usr/local/pkg/wam_cron.php ]; then
            /usr/local/bin/php -q /usr/local/pkg/wam_cron.php --boot >/dev/null 2>&1 || true
        fi
        stop_banner
        start_banner
        ;;
esac
EOF_RC;
}

/**
 * Sincroniza o NGINX do banner. Não altera a WebGUI: se houver conflito de portas,
 * o banner fica desligado e o bloqueio usa 0.0.0.0 (always_null).
 */
function rules_wam_sync_banner_nginx($wam_cfg = null, $start = true) {
    if ($wam_cfg === null) {
        $wam_cfg = rules_wam_get_config();
    }
    $nginx_conf = '/usr/local/etc/nginx/rules_wam_ssl.conf';
    $rc_script = '/usr/local/etc/rc.d/rules_wam_ssl.sh';

    $want_banner = rules_wam_is_checked($wam_cfg['enable'] ?? null)
        && rules_wam_effective_block_action($wam_cfg) === 'block_page';

    // O script rc.d fica sempre instalado: além do banner, ele regenera as regras no boot
    $rc_content = rules_wam_banner_rc_script();
    if (!file_exists($rc_script) || @file_get_contents($rc_script) !== $rc_content) {
        @mkdir('/usr/local/etc/rc.d', 0755, true);
        file_put_contents($rc_script, $rc_content);
        @chmod($rc_script, 0755);
    }

    if (!$want_banner) {
        if (file_exists($nginx_conf)) {
            mwexec('/bin/sh ' . escapeshellarg($rc_script) . ' stop');
        }
        @unlink($nginx_conf);
        $conflict = rules_wam_banner_conflict();
        if ($conflict !== '' && ($wam_cfg['block_action'] ?? 'block_page') === 'block_page') {
            log_error("[Rules WAM] Banner desativado: {$conflict} Bloqueio usando 0.0.0.0 ate a porta ser liberada.");
        }
        return false;
    }

    $banner_ip = rules_wam_get_block_page_ip($wam_cfg);
    @mkdir('/usr/local/etc/nginx', 0755, true);
    @mkdir('/usr/local/etc/rc.d', 0755, true);

    $conf = rules_wam_banner_nginx_conf($banner_ip, true);
    // Valida a configuração; se o NGINX não suportar ssl_reject_handshake (< 1.19.4), sobe só a porta 80
    $tmp = '/tmp/rules_wam_ssl.conf.test';
    file_put_contents($tmp, $conf);
    $rc = 0;
    $out = array();
    exec('/usr/local/sbin/nginx -t -c ' . escapeshellarg($tmp) . ' 2>&1', $out, $rc);
    if ($rc !== 0 && stripos(implode(' ', $out), 'ssl_reject_handshake') !== false) {
        $conf = rules_wam_banner_nginx_conf($banner_ip, false);
        log_error("[Rules WAM] NGINX sem suporte a ssl_reject_handshake; banner apenas na porta 80.");
    } elseif ($rc !== 0) {
        log_error("[Rules WAM] Configuracao do NGINX do banner invalida: " . implode(' | ', array_slice($out, 0, 2)));
    }
    @unlink($tmp);

    $changed = false;
    if (!file_exists($nginx_conf) || @file_get_contents($nginx_conf) !== $conf) {
        file_put_contents($nginx_conf, $conf);
        $changed = true;
    }
    // Remove sobras da versão anterior (CA/certificados do banner HTTPS)
    foreach (array('/var/etc/rules_wam_ca.crt', '/var/etc/rules_wam_ca.key', '/var/etc/rules_wam_ca.srl',
                   '/var/etc/rules_wam_ssl.crt', '/var/etc/rules_wam_ssl.key', '/usr/local/www/rules_wam_ca.crt') as $old) {
        if (file_exists($old)) {
            @unlink($old);
        }
    }

    if (!$start) {
        return $changed;
    }

    $running = false;
    if (file_exists('/var/run/rules_wam_ssl.pid')) {
        $npid = (int)trim(@file_get_contents('/var/run/rules_wam_ssl.pid'));
        $running = ($npid > 0 && function_exists('posix_kill') && @posix_kill($npid, 0));
    }
    if ($changed || !$running) {
        mwexec('/bin/sh ' . escapeshellarg($rc_script) . ' restart');
    }
    return $changed;
}
