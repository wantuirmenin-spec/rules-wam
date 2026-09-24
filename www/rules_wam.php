<?php
/*
 * rules_wam.php
 * Rules WAM - Web Access Manager para pfSense
 * Página Principal de Configuração de Regras e Categorias
 */

require_once("guiconfig.inc");
require_once("/usr/local/pkg/rules_wam.inc");

$save_msg = null;

$lan_default_ip = function_exists('rules_wam_get_lan_ip') ? rules_wam_get_lan_ip() : '192.168.1.1';

// Processa salvamento do formulário
if ($_POST && isset($_POST['save_rules_wam'])) {
    $wam_cfg = array(
        'enable'               => isset($_POST['enable']) ? 'yes' : 'no',
        'block_social'         => isset($_POST['block_social']) ? 'yes' : 'no',
        'block_adult'          => isset($_POST['block_adult']) ? 'yes' : 'no',
        'block_news'           => isset($_POST['block_news']) ? 'yes' : 'no',
        'block_sports'         => isset($_POST['block_sports']) ? 'yes' : 'no',
        'block_gaming'         => isset($_POST['block_gaming']) ? 'yes' : 'no',
        'block_streaming'      => isset($_POST['block_streaming']) ? 'yes' : 'no',
        'block_gambling'       => isset($_POST['block_gambling']) ? 'yes' : 'no',
        'block_shopping'       => isset($_POST['block_shopping']) ? 'yes' : 'no',
        'block_p2p'            => isset($_POST['block_p2p']) ? 'yes' : 'no',
        'block_doh'            => isset($_POST['block_doh']) ? 'yes' : 'no',
        'block_dns_bypass'     => isset($_POST['block_dns_bypass']) ? 'yes' : 'no',
        'enable_upstream_forwarding' => isset($_POST['enable_upstream_forwarding']) ? 'yes' : 'no',
        'block_vpn'            => isset($_POST['block_vpn']) ? 'yes' : 'no',
        'block_vpn_fortinet'   => isset($_POST['block_vpn_fortinet']) ? 'yes' : 'no',
        'block_vpn_cisco'      => isset($_POST['block_vpn_cisco']) ? 'yes' : 'no',
        'block_vpn_paloalto'   => isset($_POST['block_vpn_paloalto']) ? 'yes' : 'no',
        'block_ztna_zscaler'   => isset($_POST['block_ztna_zscaler']) ? 'yes' : 'no',
        'block_ztna_netskope'  => isset($_POST['block_ztna_netskope']) ? 'yes' : 'no',
        'block_ztna_cloudflare'=> isset($_POST['block_ztna_cloudflare']) ? 'yes' : 'no',
        'block_ztna_tailscale' => isset($_POST['block_ztna_tailscale']) ? 'yes' : 'no',
        'block_vpn_commercial' => isset($_POST['block_vpn_commercial']) ? 'yes' : 'no',
        'block_messaging'      => isset($_POST['block_messaging']) ? 'yes' : 'no',
        'block_msg_whatsapp'   => isset($_POST['block_msg_whatsapp']) ? 'yes' : 'no',
        'block_msg_telegram'   => isset($_POST['block_msg_telegram']) ? 'yes' : 'no',
        'block_msg_messenger'  => isset($_POST['block_msg_messenger']) ? 'yes' : 'no',
        'block_msg_teams_skype'=> isset($_POST['block_msg_teams_skype']) ? 'yes' : 'no',
        'block_msg_discord'    => isset($_POST['block_msg_discord']) ? 'yes' : 'no',
        'block_msg_slack'      => isset($_POST['block_msg_slack']) ? 'yes' : 'no',
        'block_msg_zoom_meet'  => isset($_POST['block_msg_zoom_meet']) ? 'yes' : 'no',
        'block_msg_others'     => isset($_POST['block_msg_others']) ? 'yes' : 'no',
        'schedule_enable'      => isset($_POST['schedule_enable']) ? 'yes' : 'no',
        'schedule_start'       => !empty($_POST['schedule_start']) ? trim($_POST['schedule_start']) : '08:00',
        'schedule_end'         => !empty($_POST['schedule_end']) ? trim($_POST['schedule_end']) : '18:00',
        'schedule_lunch_start' => !empty($_POST['schedule_lunch_start']) ? trim($_POST['schedule_lunch_start']) : '',
        'schedule_lunch_end'   => !empty($_POST['schedule_lunch_end']) ? trim($_POST['schedule_lunch_end']) : '',
        'schedule_weekend'     => isset($_POST['schedule_weekend']) ? 'yes' : 'no',
        'bypass_ips'           => isset($_POST['bypass_ips']) ? trim($_POST['bypass_ips']) : '',
        'custom_whitelist'     => isset($_POST['custom_whitelist']) ? trim($_POST['custom_whitelist']) : '',
        'custom_blacklist'     => isset($_POST['custom_blacklist']) ? trim($_POST['custom_blacklist']) : '',
        'custom_hosts'         => isset($_POST['custom_hosts']) ? trim($_POST['custom_hosts']) : '',
        'block_action'         => isset($_POST['block_action']) ? trim($_POST['block_action']) : 'block_page',
        'block_page_ip'        => !empty($_POST['block_page_ip']) ? trim($_POST['block_page_ip']) : $lan_default_ip,
        'corp_enable'          => isset($_POST['corp_enable']) ? 'yes' : 'no',
        'corp_ad_domain'       => isset($_POST['corp_ad_domain']) ? trim($_POST['corp_ad_domain']) : '',
        'corp_ad_dns_ips'      => isset($_POST['corp_ad_dns_ips']) ? trim($_POST['corp_ad_dns_ips']) : '',
        'corp_protect_netskope'=> isset($_POST['corp_protect_netskope']) ? 'yes' : 'no',
        'corp_protect_idp'     => isset($_POST['corp_protect_idp']) ? 'yes' : 'no',
        'corp_protect_tools'   => isset($_POST['corp_protect_tools']) ? 'yes' : 'no',
        'corp_protect_cloudflare' => isset($_POST['corp_protect_cloudflare']) ? 'yes' : 'no',
        'corp_protect_helpdesk'=> isset($_POST['corp_protect_helpdesk']) ? 'yes' : 'no',
        'corp_protect_voip'    => isset($_POST['corp_protect_voip']) ? 'yes' : 'no',
        'corp_reverse_lookup'  => isset($_POST['corp_reverse_lookup']) ? 'yes' : 'no',
        'corp_allowed_subnets' => isset($_POST['corp_allowed_subnets']) ? trim($_POST['corp_allowed_subnets']) : "172.24.0.0/16\n192.168.0.0/16\n192.192.0.0/16\n10.0.0.0/8",
        'initialized'          => 'yes'
    );

    // Grava no config.xml (em ambos os caminhos para compatibilidade total)
    config_set_path('installedpackages/rules_wam/config/0', $wam_cfg);
    config_set_path('installedpackages/wam/config/0', $wam_cfg);
    write_config("Rules WAM: configurações salvas via WebGUI");

    if ($wam_cfg['enable'] === 'yes') {
        rules_wam_apply_rules($wam_cfg);
        $save_msg = "Configurações salvas com sucesso! O serviço Rules WAM está ATIVO e as regras foram aplicadas no Unbound DNS.";
    } else {
        rules_wam_disable();
        $save_msg = "Configurações salvas. O serviço Rules WAM foi DESABILITADO e os acessos estão liberados.";
    }
}

// Carrega dados atuais do config.xml
$wam_cfg = rules_wam_get_config();

$pgtitle = array(gettext("Services"), gettext("Rules WAM"), gettext("Configurações de Bloqueio"));
include("head.inc");

$tab_array = array();
$tab_array[] = array(gettext("Configurações de Bloqueio"), true, "/rules_wam.php");
$tab_array[] = array(gettext("Status & Teste de Bloqueio"), false, "/rules_wam_status.php");
$tab_array[] = array(gettext("Dashboard & Tentativas de Acesso"), false, "/rules_wam_dashboard.php");
$tab_array[] = array(gettext("Banner de Bloqueio (Prévia)"), false, "/rules_wam_block.php");
display_top_tabs($tab_array);
?>

<?php if ($save_msg): ?>
    <div class="alert alert-success alert-dismissible" role="alert">
        <button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span></button>
        <i class="fa fa-check-circle"></i> <strong><?=htmlspecialchars($save_msg)?></strong>
    </div>
<?php endif; ?>

<form action="/rules_wam.php" method="post" name="iform" id="iform" class="form-horizontal">
    <div class="panel panel-default">
        <div class="panel-heading">
            <h2 class="panel-title"><?=gettext("Controle Geral")?></h2>
        </div>
        <div class="panel-body">
            <div class="form-group">
                <label class="col-sm-3 control-label"><strong><?=gettext("Habilitar Serviço Rules WAM")?></strong></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enable" value="yes" <?=rules_wam_is_checked($wam_cfg['enable'] ?? null) ? 'checked' : ''?> />
                            <strong><?=gettext("Marque para ativar a filtragem de categorias via DNS (Unbound)")?></strong>
                        </label>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="panel panel-default">
        <div class="panel-heading">
            <h2 class="panel-title"><?=gettext("Categorias de Bloqueio Disponíveis")?></h2>
        </div>
        <div class="panel-body">
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Conteúdo Adulto & Pornografia")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_adult" value="yes" <?=rules_wam_is_checked($wam_cfg['block_adult'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia portais adultos, pornografia, acompanhantes e cams (xvideos, xvideo, pornhub, xnxx, fatalmodel, etc. - Mais de 2.600 domínios)")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Mídias Sociais & Redes")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_social" value="yes" <?=rules_wam_is_checked($wam_cfg['block_social'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia YouTube, Instagram, Facebook, TikTok, Twitter/X, Kwai, Reddit, Discord, etc.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Apostas, Bets & Cassinos")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_gambling" value="yes" <?=rules_wam_is_checked($wam_cfg['block_gambling'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia casas de apostas esportivas, cassinos online, tigrinho, Blaze, Betano, Bet365, etc. - Mais de 1.500 domínios")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Streaming & Vídeo")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_streaming" value="yes" <?=rules_wam_is_checked($wam_cfg['block_streaming'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia Netflix, YouTube, Twitch, Disney+, HBO Max, Globoplay, Prime Video, Spotify, etc.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Jogos & Games Online")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_gaming" value="yes" <?=rules_wam_is_checked($wam_cfg['block_gaming'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia Steam, Epic Games, Roblox, Riot Games, Blizzard, PlayStation Network, Xbox Live, etc.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Notícias & Portais de Mídia")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_news" value="yes" <?=rules_wam_is_checked($wam_cfg['block_news'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia portais de notícias como G1, UOL, Folha, Estadão, R7, CNN Brasil, BBC, etc.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Esportes & Placares")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_sports" value="yes" <?=rules_wam_is_checked($wam_cfg['block_sports'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia GE, ESPN, Lance, Flashscore, SofaScore, transmissões piratas de futebol, etc.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Compras & E-commerce")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_shopping" value="yes" <?=rules_wam_is_checked($wam_cfg['block_shopping'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia Mercado Livre, Shopee, AliExpress, Amazon BR, Magalu, Shein, etc.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Torrents & P2P")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_p2p" value="yes" <?=rules_wam_is_checked($wam_cfg['block_p2p'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloqueia The Pirate Bay, 1337x, YTS, trackers BitTorrent públicos, etc.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Anti-Bypass DoH (DNS sobre HTTPS)")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_doh" value="yes" <?=rules_wam_is_checked($wam_cfg['block_doh'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Impede que navegadores usem DNS sobre HTTPS (Cloudflare 1.1.1.1, Google 8.8.8.8, Quad9) para burlar os bloqueios.")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Anti-Bypass DNS (Porta 53)")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_dns_bypass" value="yes" <?=rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? 'no') ? 'checked' : ''?> />
                            <strong><?=gettext("Interceptar e Redirecionar Consultas DNS Externas na Porta 53")?></strong> <span class="label label-primary"><?=gettext("Proteção contra 8.8.8.8 / 1.1.1.1 Manual")?></span><br />
                            <span class="text-muted"><?=gettext("Cria automaticamente regra de redirecionamento NAT (Port Forward) capturando consultas enviadas a 8.8.8.8, 1.1.1.1 ou qualquer outro DNS externo na porta 53, forçando resolução pelo Unbound e aplicando os bloqueios do Rules WAM. Dispositivos na lista de Bypass IPs continuam com acesso livre.")?></span>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Forwarding Upstream (Google & Cloudflare)")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="enable_upstream_forwarding" value="yes" <?=rules_wam_is_checked($wam_cfg['enable_upstream_forwarding'] ?? 'no') ? 'checked' : ''?> />
                            <strong><?=gettext("Usar Google DNS (8.8.8.8, 8.8.4.4) e Cloudflare (1.1.1.1, 1.0.0.1) como Forwarders Upstream")?></strong><br />
                            <span class="text-muted"><?=gettext("O Unbound do pfSense bloqueia as categorias do WAM instantaneamente (0.0.0.0) na rede local e encaminha todas as consultas permitidas aos Anycast de alta performance do Google e Cloudflare, acelerando a navegação na internet.")?></span>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("VPN, ZTNA & Proxies Anônimos")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_vpn" id="block_vpn" value="yes" <?=rules_wam_is_checked($wam_cfg['block_vpn'] ?? null) ? 'checked' : ''?> onchange="document.getElementById('vpn_sub_options').style.display = this.checked ? 'block' : 'none';" />
                            <strong><?=gettext("Ativar bloqueio de VPNs, Soluções ZTNA e Proxies")?></strong>
                        </label>
                    </div>

                    <div id="vpn_sub_options" style="margin-top: 10px; padding: 12px 16px; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 6px; <?=(rules_wam_is_checked($wam_cfg['block_vpn'] ?? null) ? '' : 'display:none;')?>">
                        <p style="font-size: 12px; color: #475569; margin-bottom: 10px;">
                            <i class="fa fa-info-circle"></i> <em>Marque os fornecedores que deseja bloquear. Se a sua empresa utiliza algum deles (ex: FortiClient ou Cisco), basta <strong>desmarcar</strong> para permitir o acesso.</em>
                        </p>
                        <div class="row">
                            <div class="col-sm-6">
                                <h5 style="margin-top: 5px; font-weight: bold; color: #1e293b; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;">🛡️ VPNs Corporativas &amp; Comerciais</h5>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_vpn_fortinet" value="yes" <?=(!isset($wam_cfg['block_vpn_fortinet']) || rules_wam_is_checked($wam_cfg['block_vpn_fortinet'])) ? 'checked' : ''?> />
                                        <strong>Fortinet / FortiGate</strong> (SSL-VPN / FortiClient)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_vpn_cisco" value="yes" <?=(!isset($wam_cfg['block_vpn_cisco']) || rules_wam_is_checked($wam_cfg['block_vpn_cisco'])) ? 'checked' : ''?> />
                                        <strong>Cisco AnyConnect</strong> / Secure Client
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_vpn_paloalto" value="yes" <?=(!isset($wam_cfg['block_vpn_paloalto']) || rules_wam_is_checked($wam_cfg['block_vpn_paloalto'])) ? 'checked' : ''?> />
                                        <strong>Palo Alto GlobalProtect</strong> / Prisma Access
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_vpn_commercial" value="yes" <?=(!isset($wam_cfg['block_vpn_commercial']) || rules_wam_is_checked($wam_cfg['block_vpn_commercial'])) ? 'checked' : ''?> />
                                        <strong>VPNs Comerciais &amp; Proxies Web</strong> (NordVPN, ExpressVPN, Tor, etc.)
                                    </label>
                                </div>
                            </div>
                            <div class="col-sm-6">
                                <h5 style="margin-top: 5px; font-weight: bold; color: #1e293b; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;">☁️ Provedores ZTNA &amp; Mesh Tunnels</h5>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_ztna_zscaler" value="yes" <?=(!isset($wam_cfg['block_ztna_zscaler']) || rules_wam_is_checked($wam_cfg['block_ztna_zscaler'])) ? 'checked' : ''?> />
                                        <strong>Zscaler</strong> (ZPA / ZIA Cloud)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_ztna_netskope" value="yes" <?=(!isset($wam_cfg['block_ztna_netskope']) || rules_wam_is_checked($wam_cfg['block_ztna_netskope'])) ? 'checked' : ''?> />
                                        <strong>Netskope</strong> (Security Cloud &amp; Private Access)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_ztna_cloudflare" value="yes" <?=(!isset($wam_cfg['block_ztna_cloudflare']) || rules_wam_is_checked($wam_cfg['block_ztna_cloudflare'])) ? 'checked' : ''?> />
                                        <strong>Cloudflare WARP</strong> &amp; Zero Trust
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_ztna_tailscale" value="yes" <?=(!isset($wam_cfg['block_ztna_tailscale']) || rules_wam_is_checked($wam_cfg['block_ztna_tailscale'])) ? 'checked' : ''?> />
                                        <strong>Tailscale, ZeroTier &amp; Tunnels</strong> (Ngrok, Twingate, Hamachi)
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Mensageiros & Comunicação")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="block_messaging" id="block_messaging" value="yes" <?=rules_wam_is_checked($wam_cfg['block_messaging'] ?? null) ? 'checked' : ''?> onchange="document.getElementById('msg_sub_options').style.display = this.checked ? 'block' : 'none';" />
                            <strong><?=gettext("Ativar bloqueio de Mensageiros Instantâneos & Ferramentas de Comunicação")?></strong>
                        </label>
                    </div>

                    <div id="msg_sub_options" style="margin-top: 10px; padding: 12px 16px; background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 6px; <?=(rules_wam_is_checked($wam_cfg['block_messaging'] ?? null) ? '' : 'display:none;')?>">
                        <p style="font-size: 12px; color: #475569; margin-bottom: 10px;">
                            <i class="fa fa-info-circle"></i> <em>Marque as ferramentas de comunicação que deseja bloquear. Se sua empresa utiliza alguma delas para trabalho (ex: Microsoft Teams, Slack ou WhatsApp), basta <strong>desmarcar</strong> para manter liberado.</em>
                        </p>
                        <div class="row">
                            <div class="col-sm-6">
                                <h5 style="margin-top: 5px; font-weight: bold; color: #1e293b; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;">💬 Mensageiros Mais Populares</h5>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_whatsapp" value="yes" <?=(!isset($wam_cfg['block_msg_whatsapp']) || rules_wam_is_checked($wam_cfg['block_msg_whatsapp'])) ? 'checked' : ''?> />
                                        <strong>WhatsApp</strong> (WhatsApp Web, apps desktop/móvel e chamadas)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_telegram" value="yes" <?=(!isset($wam_cfg['block_msg_telegram']) || rules_wam_is_checked($wam_cfg['block_msg_telegram'])) ? 'checked' : ''?> />
                                        <strong>Telegram</strong> (Web, Desktop, app e t.me)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_messenger" value="yes" <?=(!isset($wam_cfg['block_msg_messenger']) || rules_wam_is_checked($wam_cfg['block_msg_messenger'])) ? 'checked' : ''?> />
                                        <strong>Facebook Messenger</strong> (messenger.com, m.me)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_teams_skype" value="yes" <?=(!isset($wam_cfg['block_msg_teams_skype']) || rules_wam_is_checked($wam_cfg['block_msg_teams_skype'])) ? 'checked' : ''?> />
                                        <strong>Microsoft Teams &amp; Skype / MSN</strong> (teams.microsoft.com, skype.com)
                                    </label>
                                </div>
                            </div>
                            <div class="col-sm-6">
                                <h5 style="margin-top: 5px; font-weight: bold; color: #1e293b; border-bottom: 1px solid #e2e8f0; padding-bottom: 4px;">👥 Comunicação Corporativa &amp; Outros</h5>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_discord" value="yes" <?=(!isset($wam_cfg['block_msg_discord']) || rules_wam_is_checked($wam_cfg['block_msg_discord'])) ? 'checked' : ''?> />
                                        <strong>Discord</strong> (discord.com, discord.gg)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_slack" value="yes" <?=(!isset($wam_cfg['block_msg_slack']) || rules_wam_is_checked($wam_cfg['block_msg_slack'])) ? 'checked' : ''?> />
                                        <strong>Slack</strong> (slack.com, canais e mensagens)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_zoom_meet" value="yes" <?=(!isset($wam_cfg['block_msg_zoom_meet']) || rules_wam_is_checked($wam_cfg['block_msg_zoom_meet'])) ? 'checked' : ''?> />
                                        <strong>Zoom Meetings</strong> (zoom.us - Google Meet liberado)
                                    </label>
                                </div>
                                <div class="checkbox">
                                    <label>
                                        <input type="checkbox" name="block_msg_others" value="yes" <?=(!isset($wam_cfg['block_msg_others']) || rules_wam_is_checked($wam_cfg['block_msg_others'])) ? 'checked' : ''?> />
                                        <strong>Outros Mensageiros</strong> (Signal, WeChat, Viber, LINE, Omegle, etc.)
                                    </label>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="panel panel-info">
        <div class="panel-heading">
            <h2 class="panel-title"><i class="fa fa-sitemap"></i> <?=gettext("Integração Corporativa: Active Directory, NPS (RADIUS) & Netskope")?></h2>
        </div>
        <div class="panel-body">
            <p class="text-muted" style="margin-bottom: 20px;">
                <?=gettext("Configure este painel quando a unidade possuir conexão VPN IPsec com a Matriz e utilizar serviços centrais como Active Directory e NPS RADIUS, e/ou gerenciar navegação via Netskope Security Cloud.")?>
            </p>

            <div class="form-group">
                <label class="col-sm-3 control-label"><strong><?=gettext("Habilitar Split-DNS Corporativo")?></strong></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_enable" value="yes" <?=rules_wam_is_checked($wam_cfg['corp_enable'] ?? null) ? 'checked' : ''?> />
                            <strong><?=gettext("Encaminhar consultas do AD e NPS RADIUS para a Matriz via IPsec (Domain Overrides)")?></strong>
                        </label>
                    </div>
                    <span class="help-block"><?=gettext("Evita que consultas locais ao domínio corporativo caiam em filtros e assegura autenticação e resolução ininterruptas.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Domínio(s) do Active Directory")?></label>
                <div class="col-sm-6">
                    <input type="text" name="corp_ad_domain" class="form-control" value="<?=htmlspecialchars($wam_cfg['corp_ad_domain'] ?? '')?>" placeholder="Ex: madeiramadeira.local, corp.empresa.com.br" />
                    <span class="help-block"><?=gettext("Nome do domínio interno da empresa (se houver mais de um, separe por vírgula).")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("IPs dos Servidores DNS da Matriz")?></label>
                <div class="col-sm-6">
                    <input type="text" name="corp_ad_dns_ips" class="form-control" value="<?=htmlspecialchars($wam_cfg['corp_ad_dns_ips'] ?? '')?>" placeholder="Ex: 10.0.0.10, 10.0.0.11" />
                    <span class="help-block"><?=gettext("Endereços IP dos controladores de domínio (AD/DNS) e servidores NPS RADIUS alcançáveis através da VPN IPsec.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Zonas DNS Reversas")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_reverse_lookup" value="yes" <?=(!isset($wam_cfg['corp_reverse_lookup']) || rules_wam_is_checked($wam_cfg['corp_reverse_lookup'])) ? 'checked' : ''?> />
                            <?=gettext("Encaminhar também as zonas reversas (in-addr.arpa) das sub-redes dos servidores para a Matriz")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Redes Corporativas Autorizadas no DNS (CIDR)")?></label>
                <div class="col-sm-6">
                    <textarea name="corp_allowed_subnets" class="form-control" rows="4" placeholder="172.24.0.0/16&#10;192.168.0.0/16&#10;192.192.0.0/16&#10;10.0.0.0/8"><?=htmlspecialchars($wam_cfg['corp_allowed_subnets'] ?? "172.24.0.0/16\n192.168.0.0/16\n192.192.0.0/16\n10.0.0.0/8")?></textarea>
                    <span class="help-block"><?=gettext("Super-redes corporativas que terão permissão automática para resolver DNS no Unbound em todas as 18 unidades (incluindo sub-redes roteadas via Switch L3). Separe por linha.")?></span>
                </div>
            </div>

            <hr style="border-top: 1px dashed #ddd; margin: 15px 0;" />

            <div class="form-group">
                <label class="col-sm-3 control-label"><strong><?=gettext("Proteção Netskope Cloud")?></strong></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_protect_netskope" value="yes" <?=(!isset($wam_cfg['corp_protect_netskope']) || rules_wam_is_checked($wam_cfg['corp_protect_netskope'])) ? 'checked' : ''?> />
                            <strong><?=gettext("Auto-Whitelist para Netskope Security Cloud (ZTNA, SWG & NPA)")?></strong>
                        </label>
                    </div>
                    <span class="help-block"><?=gettext("Garante que os domínios da Netskope (goskope.com, netskope.com, gateway, etc.) fiquem permanentemente liberados, evitando que o agente Netskope perca conexão.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Provedores de Identidade (IdP)")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_protect_idp" value="yes" <?=(!isset($wam_cfg['corp_protect_idp']) || rules_wam_is_checked($wam_cfg['corp_protect_idp'])) ? 'checked' : ''?> />
                            <?=gettext("Proteger Provedores de Identidade em Nuvem (Microsoft 365 / Entra ID, Okta, Google)")?>
                        </label>
                    </div>
                    <span class="help-block"><?=gettext("Assegura que a autenticação SSO e MFA dos portais em nuvem da Netskope funcione sem bloqueios no DNS.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><strong><?=gettext("Ferramentas de TI & Downloads")?></strong></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_protect_tools" value="yes" <?=(!isset($wam_cfg['corp_protect_tools']) || rules_wam_is_checked($wam_cfg['corp_protect_tools'])) ? 'checked' : ''?> />
                            <strong><?=gettext("Liberar Downloads de Ferramentas de TI e Administração (PuTTY, WinSCP, 7-Zip, Notepad++, Git, GitHub, etc.)")?></strong>
                        </label>
                    </div>
                    <span class="help-block"><?=gettext("Garante que os sites oficiais de download e espelhos de softwares essenciais nunca sejam bloqueados por nenhuma categoria.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><strong><?=gettext("Infraestrutura Cloudflare")?></strong></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_protect_cloudflare" value="yes" <?=(!isset($wam_cfg['corp_protect_cloudflare']) || rules_wam_is_checked($wam_cfg['corp_protect_cloudflare'])) ? 'checked' : ''?> />
                            <strong><?=gettext("Liberar Infraestrutura Pública Cloudflare (CDN cdnjs, Captchas Turnstile, APIs públicas)")?></strong>
                        </label>
                    </div>
                    <span class="help-block"><?=gettext("Mantém liberadas as CDNs e serviços de validação de captcha da Cloudflare para que páginas da internet e links de download carreguem sem erros.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><strong><?=gettext("Helpdesk & Suporte Remoto")?></strong></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_protect_helpdesk" value="yes" <?=(!isset($wam_cfg['corp_protect_helpdesk']) || rules_wam_is_checked($wam_cfg['corp_protect_helpdesk'])) ? 'checked' : ''?> />
                            <strong><?=gettext("Liberar Helpdesk & Suporte Remoto (Zendesk, GLPI, ScreenConnect / ConnectWise)")?></strong>
                        </label>
                    </div>
                    <span class="help-block"><?=gettext("Protege plataformas de chamados, suporte ao cliente, ITSM e conexões de assistência remota ScreenConnect, impedindo qualquer bloqueio acidental.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><strong><?=gettext("Telefonia IP & Protocolo SIP")?></strong></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="corp_protect_voip" value="yes" <?=(!isset($wam_cfg['corp_protect_voip']) || rules_wam_is_checked($wam_cfg['corp_protect_voip'])) ? 'checked' : ''?> />
                            <strong><?=gettext("Liberar Telefonia IP, Protocolo SIP & Aparelhos SIP Phone (3CX, Zoiper, Linphone, Yealink, Grandstream, Twilio, etc.)")?></strong>
                        </label>
                    </div>
                    <span class="help-block"><?=gettext("Garante comunicação de voz ininterrupta: registro SIP, servidores STUN, troncos PABX e provisionamento de telefones IP corporativos.")?></span>
                </div>
            </div>
        </div>
    </div>

    <div class="panel panel-default">
        <div class="panel-heading">
            <h2 class="panel-title"><?=gettext("Agendamento por Horário de Trabalho")?></h2>
        </div>
        <div class="panel-body">
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Ativar Agendamento")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="schedule_enable" value="yes" <?=rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Bloquear somente durante o expediente de trabalho (fora do horário e no almoço os acessos são liberados)")?>
                        </label>
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Horário de Início / Fim")?></label>
                <div class="col-sm-4">
                    <input type="time" name="schedule_start" class="form-control" value="<?=htmlspecialchars($wam_cfg['schedule_start'] ?? '08:00')?>" />
                    <span class="help-block"><?=gettext("Início do expediente (padrão: 08:00)")?></span>
                </div>
                <div class="col-sm-4">
                    <input type="time" name="schedule_end" class="form-control" value="<?=htmlspecialchars($wam_cfg['schedule_end'] ?? '18:00')?>" />
                    <span class="help-block"><?=gettext("Fim do expediente (padrão: 18:00)")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Pausa de Almoço (Liberado)")?></label>
                <div class="col-sm-4">
                    <input type="time" name="schedule_lunch_start" class="form-control" value="<?=htmlspecialchars($wam_cfg['schedule_lunch_start'] ?? '12:00')?>" />
                    <span class="help-block"><?=gettext("Início do almoço (deixe em branco para não pausar)")?></span>
                </div>
                <div class="col-sm-4">
                    <input type="time" name="schedule_lunch_end" class="form-control" value="<?=htmlspecialchars($wam_cfg['schedule_lunch_end'] ?? '13:00')?>" />
                    <span class="help-block"><?=gettext("Fim do almoço")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Finais de Semana")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="schedule_weekend" value="yes" <?=rules_wam_is_checked($wam_cfg['schedule_weekend'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Manter bloqueio ativo também aos Sábados e Domingos")?>
                        </label>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="panel panel-default">
        <div class="panel-heading">
            <h2 class="panel-title"><?=gettext("Ação do Bloqueio & Banner na Tela do Host")?></h2>
        </div>
        <div class="panel-body">
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Comportamento do Bloqueio")?></label>
                <div class="col-sm-9">
                    <select name="block_action" class="form-control" style="max-width: 480px;">
                        <option value="block_page" <?=($wam_cfg['block_action'] ?? 'block_page') === 'block_page' ? 'selected' : ''?>>
                            <?=gettext("Exibir Banner de Bloqueio da Empresa (Porta 80 HTTP e 443 HTTPS)")?>
                        </option>
                        <option value="always_null" <?=($wam_cfg['block_action'] ?? '') === 'always_null' ? 'selected' : ''?>>
                            <?=gettext("Retornar 0.0.0.0 (Silencioso - Sem Banner)")?>
                        </option>
                    </select>
                    <span class="help-block">
                        <?=gettext("No modo <strong>Banner</strong>, o firewall intercepta a porta 80 (HTTP sem certificado) e 443 (HTTPS com suporte a CA) e exibe a página institucional com as políticas da empresa.")?><br/>
                        <?=gettext("No modo <strong>Silencioso (0.0.0.0)</strong>, a conexão é recusada imediatamente pelo navegador.")?>
                        <br/>
                        <a href="/rules_wam_block.php" target="_blank" class="btn btn-default btn-xs" style="margin-top: 5px;">
                            <i class="fa fa-eye"></i> <strong><?=gettext("Visualizar Modelo do Banner na Tela")?></strong>
                        </a>
                    </span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("IP do Firewall para o Banner")?></label>
                <div class="col-sm-5">
                    <div class="input-group">
                        <input type="text" id="block_page_ip" name="block_page_ip" class="form-control" value="<?=htmlspecialchars($wam_cfg['block_page_ip'] ?? $lan_default_ip)?>" placeholder="Ex: <?=$lan_default_ip?>" />
                        <div class="input-group-btn">
                            <button type="button" class="btn btn-default" onclick="document.getElementById('block_page_ip').value='<?=$lan_default_ip?>';" title="<?=gettext("Restaurar IP padrão detectado")?>">
                                <i class="fa fa-undo"></i> <?=gettext("Padrão")?>
                            </button>
                        </div>
                    </div>
                    <span class="help-block"><?=gettext("Endereço IP da interface interna do pfSense onde o banner institucional é respondido para as estações bloqueadas.")?></span>
                </div>
            </div>

            <?php
            $detected_internal_ifaces = function_exists('rules_wam_get_configured_interfaces') ? rules_wam_get_configured_interfaces(false) : array();
            if (!empty($detected_internal_ifaces)):
            ?>
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Interfaces Internas Detectadas")?></label>
                <div class="col-sm-9">
                    <div style="display: flex; flex-wrap: wrap; gap: 8px; margin-top: 4px;">
                        <?php foreach ($detected_internal_ifaces as $d_k => $d_if): ?>
                            <div style="background-color: #f7f9fa; border: 1px solid #d5d9df; border-radius: 4px; padding: 6px 12px; display: inline-flex; align-items: center; gap: 8px; font-size: 12px;">
                                <i class="fa fa-sitemap text-primary"></i>
                                <div>
                                    <strong style="color: #333;"><?=htmlspecialchars($d_if['descr'])?></strong>
                                    <?php if (strcasecmp($d_if['descr'], $d_if['logical_id']) !== 0): ?>
                                        <small class="text-muted">(<?=htmlspecialchars($d_if['logical_id'])?><?=!empty($d_if['real_if']) ? ' / ' . htmlspecialchars($d_if['real_if']) : ''?>)</small>
                                    <?php elseif (!empty($d_if['real_if'])): ?>
                                        <small class="text-muted">(<?=htmlspecialchars($d_if['real_if'])?>)</small>
                                    <?php endif; ?>
                                    <br/>
                                    <code style="font-size: 11px;"><?=!empty($d_if['ip']) ? htmlspecialchars($d_if['ip']) : gettext('Sem IPv4 estático')?></code>
                                </div>
                                <?php if (!empty($d_if['ip'])): ?>
                                    <button type="button" class="btn btn-xs btn-default" onclick="document.getElementById('block_page_ip').value='<?=htmlspecialchars($d_if['ip'])?>';" title="<?=gettext("Definir como IP do Banner de Bloqueio")?>">
                                        <i class="fa fa-check"></i> <?=gettext("Usar IP")?>
                                    </button>
                                <?php endif; ?>
                            </div>
                        <?php endforeach; ?>
                    </div>
                    <span class="help-block" style="margin-top: 6px;">
                        <?=gettext("Interfaces ativas no pfSense com seus nomes amigáveis oficiais. O firewall responde o banner HTTP/HTTPS em todas as interfaces internas.")?>
                    </span>
                </div>
            </div>
            <?php endif; ?>
        </div>
    </div>

    <div class="panel panel-default">
        <div class="panel-heading">
            <h2 class="panel-title"><?=gettext("Exceções & Personalização")?></h2>
        </div>
        <div class="panel-body">
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("IPs Isentos (Bypass IPs)")?></label>
                <div class="col-sm-9">
                    <textarea name="bypass_ips" rows="3" class="form-control" placeholder="172.24.60.20&#10;172.24.60.25"><?=htmlspecialchars($wam_cfg['bypass_ips'] ?? '')?></textarea>
                    <span class="help-block"><?=gettext("IPs locais que NUNCA sofrem bloqueio (Diretoria, TI, etc.). Um IP por linha ou separado por vírgula.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Lista Branca (Whitelist)")?></label>
                <div class="col-sm-9">
                    <textarea name="custom_whitelist" rows="3" class="form-control" placeholder="linkedin.com&#10;globoesporte.globo.com"><?=htmlspecialchars($wam_cfg['custom_whitelist'] ?? '')?></textarea>
                    <span class="help-block"><?=gettext("Domínios que devem ser sempre permitidos, mesmo que pertençam a uma categoria bloqueada.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Lista Negra Adicional (Blacklist)")?></label>
                <div class="col-sm-9">
                    <textarea name="custom_blacklist" rows="3" class="form-control" placeholder="site-indesejado.com&#10;outro-site.com"><?=htmlspecialchars($wam_cfg['custom_blacklist'] ?? '')?></textarea>
                    <span class="help-block"><?=gettext("Domínios adicionais manuais que você deseja bloquear agora.")?></span>
                </div>
            </div>

            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Mapeamento de Nomes de Hosts / Computadores")?></label>
                <div class="col-sm-9">
                    <textarea name="custom_hosts" rows="4" class="form-control" placeholder="172.24.60.118 = Computador Principal&#10;172.24.60.119 = Notebook TI"><?=htmlspecialchars($wam_cfg['custom_hosts'] ?? '')?></textarea>
                    <span class="help-block">
                        <?=gettext("Defina ou corrija o nome dos computadores na rede (um por linha no formato <code>IP = Nome</code>).")?><br/>
                        <?=gettext("Ideal para hosts conectados através de antenas, switches gerenciáveis, pontos de acesso (APs) ou com IPs fixos.")?>
                    </span>
                </div>
            </div>
        </div>
    </div>

    <div class="form-group">
        <div class="col-sm-9 col-sm-offset-3">
            <input type="hidden" name="save_rules_wam" value="1" />
            <button type="submit" class="btn btn-primary btn-lg"><i class="fa fa-save"></i> <?=gettext("Salvar e Aplicar Regras")?></button>
        </div>
    </div>
</form>

<?php include("foot.inc"); ?>
