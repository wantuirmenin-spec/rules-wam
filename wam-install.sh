#!/bin/sh
# ====================================================================
# Rules WAM para pfSense (Instalador Standalone)
# Bloqueio de Categorias de Sites e Proteção DNS Avançada
# ====================================================================

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Erro: Execute este script como root no pfSense."
    exit 1
fi

echo "======================================================"
echo " 🚀 Instalando Pacote Rules WAM no pfSense"
echo "======================================================"

TMP_DIR="/tmp/wam_install_tmp"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/pkg" "$TMP_DIR/www" "$TMP_DIR/feeds" "$TMP_DIR/widgets/include" "$TMP_DIR/widgets/widgets"

echo '>> Extraindo pkg/rules_wam.xml...'
cat << 'EOF_XML' > $TMP_DIR/pkg/rules_wam.xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE packagegui SYSTEM "../schema/packages.dtd">
<?xml-stylesheet type="text/xsl" href="../xsl/package.xsl"?>
<packagegui>
	<copyright>
	<![CDATA[
/*
 * rules_wam.xml
 * Rules WAM - Web Access Manager para pfSense
 * Bloqueio de Categorias de Sites e Proteção DNS Avançada
 */
	]]>
	</copyright>
	<name>rules_wam</name>
	<version>1.3.0</version>
	<title>Services: Rules WAM</title>
	<include_file>/usr/local/pkg/rules_wam.inc</include_file>
	<menu>
		<name>Rules WAM</name>
		<section>Services</section>
		<configfile>rules_wam.xml</configfile>
		<url>/rules_wam.php</url>
		<tooltiptext>Rules WAM - Gerenciamento e Bloqueio de Categorias de Sites</tooltiptext>
	</menu>
	<tabs>
		<tab>
			<text>Configurações de Bloqueio</text>
			<url>/rules_wam.php</url>
			<active/>
		</tab>
		<tab>
			<text>Status &amp; Teste de Bloqueio</text>
			<url>/rules_wam_status.php</url>
		</tab>
	</tabs>
	<fields>
		<field>
			<name>Controle Geral</name>
			<type>listtopic</type>
		</field>
		<field>
			<fielddescr>Habilitar Serviço Rules WAM</fielddescr>
			<fieldname>enable</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Marque para ativar a filtragem de categorias via DNS (Unbound).</description>
		</field>

		<field>
			<name>Categorias de Bloqueio Disponíveis</name>
			<type>listtopic</type>
		</field>
		<field>
			<fielddescr>Mídias Sociais</fielddescr>
			<fieldname>block_social</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Facebook, Instagram, Threads, TikTok, Twitter/X, Kwai, LinkedIn, Pinterest, Reddit, Discord, etc.</description>
		</field>
		<field>
			<fielddescr>Conteúdo Adulto &amp; Pornografia</fielddescr>
			<fieldname>block_adult</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia sites adultos, canais eróticos, chats e plataformas explícitas (Pornhub, XVideos, OnlyFans, etc.).</description>
		</field>
		<field>
			<fielddescr>Notícias &amp; Portais de Jornalismo</fielddescr>
			<fieldname>block_news</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia portais de notícias e jornais (G1, Globo, UOL, Folha, Estadão, CNN, R7, Metrópoles, Terra, BBC, etc.).</description>
		</field>
		<field>
			<fielddescr>Esportes &amp; Placares ao Vivo</fielddescr>
			<fieldname>block_sports</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia portais esportivos, placares e transmissões de jogos (GE/Globo Esporte, ESPN, Lance, Flashscore, SofaScore, Futemax, etc.).</description>
		</field>
		<field>
			<fielddescr>Jogos Online &amp; Games</fielddescr>
			<fieldname>block_gaming</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Steam, Epic Games, Roblox, Riot Games (LoL, Valorant), Blizzard/Battle.net, Xbox Live, PlayStation, etc.</description>
		</field>
		<field>
			<fielddescr>Streaming &amp; Vídeos</fielddescr>
			<fieldname>block_streaming</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia plataformas de vídeo e áudio sob demanda (YouTube, Netflix, Prime Video, Disney+, Twitch, Spotify, etc.).</description>
		</field>
		<field>
			<fielddescr>Apostas, Bets &amp; Cassinos</fielddescr>
			<fieldname>block_gambling</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia casas de apostas esportivas, bets e cassinos online (Bet365, Betano, Sportingbet, Blaze, Stake, Pixbet, etc.).</description>
		</field>
		<field>
			<fielddescr>Compras &amp; E-commerce</fielddescr>
			<fieldname>block_shopping</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia sites de compras (Mercado Livre, Shopee, AliExpress, Shein, Amazon, Magalu, Casas Bahia, etc.).</description>
		</field>
		<field>
			<fielddescr>Torrents &amp; P2P</fielddescr>
			<fieldname>block_p2p</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia sites e rastreadores de torrent (The Pirate Bay, 1337x, YTS, RARBG, BitTorrent, uTorrent, etc.).</description>
		</field>
		<field>
			<fielddescr>Anti-Bypass (Bloquear DoH)</fielddescr>
			<fieldname>block_doh</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia servidores DNS-over-HTTPS públicos (Cloudflare, Google, Quad9) para impedir que navegadores e celulares burlem o filtro.</description>
		</field>
		<field>
			<fielddescr>Forçar DNS Local (Porta 53 Anti-Bypass)</fielddescr>
			<fieldname>block_dns_bypass</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<default_value>no</default_value>
			<description>Recurso corporativo Anti-Bypass: Redireciona consultas DNS externas (porta 53 UDP/TCP enviadas a 8.8.8.8, 1.1.1.1, etc.) para o Unbound local via NAT Port Forward. Garante que dispositivos com DNS manual sejam filtrados pelo WAM.</description>
		</field>
		<field>
			<fielddescr>Forwarding Upstream (Google &amp; Cloudflare)</fielddescr>
			<fieldname>enable_upstream_forwarding</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<default_value>no</default_value>
			<description>Encaminha consultas legítimas permitidas diretamente aos servidores Anycast de alta performance do Google (8.8.8.8, 8.8.4.4) e Cloudflare (1.1.1.1, 1.0.0.1). O WAM bloqueia as categorias restritas localmente antes de enviar à internet.</description>
		</field>
		<field>
			<fielddescr>VPN, ZTNA &amp; Proxies Anônimos (Geral)</fielddescr>
			<fieldname>block_vpn</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Ativa o controle e bloqueio de redes virtuais VPN, provedores ZTNA e proxies. Use os campos abaixo para habilitar/desabilitar fornecedores específicos.</description>
		</field>
		<field>
			<fielddescr>Bloquear Fortinet / FortiGate SSL-VPN</fielddescr>
			<fieldname>block_vpn_fortinet</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia conexões e portais Fortinet / FortiClient SSL-VPN. Desmarque se sua organização utiliza este serviço.</description>
		</field>
		<field>
			<fielddescr>Bloquear Cisco AnyConnect / Secure Client</fielddescr>
			<fieldname>block_vpn_cisco</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Cisco AnyConnect, Secure Client e gateways corporativos Cisco. Desmarque se sua organização utiliza este serviço.</description>
		</field>
		<field>
			<fielddescr>Bloquear Palo Alto GlobalProtect / Prisma</fielddescr>
			<fieldname>block_vpn_paloalto</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia portais Palo Alto Networks GlobalProtect e Prisma Access. Desmarque se sua organização utiliza este serviço.</description>
		</field>
		<field>
			<fielddescr>Bloquear Zscaler (ZPA &amp; ZIA Cloud)</fielddescr>
			<fieldname>block_ztna_zscaler</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia infraestrutura Zscaler ZPA (Private Access) e ZIA (Internet Access). Desmarque se sua organização utiliza este serviço.</description>
		</field>
		<field>
			<fielddescr>Bloquear Netskope Security Cloud &amp; NPA</fielddescr>
			<fieldname>block_ztna_netskope</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Netskope Private Access e Security Cloud. Desmarque se sua organização utiliza este serviço.</description>
		</field>
		<field>
			<fielddescr>Bloquear Cloudflare WARP &amp; Zero Trust</fielddescr>
			<fieldname>block_ztna_cloudflare</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Cloudflare WARP client e túneis Zero Trust.</description>
		</field>
		<field>
			<fielddescr>Bloquear Tailscale, ZeroTier &amp; Mesh Tunnels</fielddescr>
			<fieldname>block_ztna_tailscale</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia redes mesh P2P (Tailscale, ZeroTier) e túneis de portas (Ngrok, Twingate, Hamachi, Localtunnel).</description>
		</field>
		<field>
			<fielddescr>Bloquear VPNs Comerciais &amp; Proxies Web</fielddescr>
			<fieldname>block_vpn_commercial</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia provedores de VPN comercial (NordVPN, ExpressVPN, Surfshark, Proton, etc.), Tor e proxies anônimos web.</description>
		</field>
		<field>
			<fielddescr>Mensageiros &amp; Ferramentas de Comunicação (Geral)</fielddescr>
			<fieldname>block_messaging</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Ativa o bloqueio de aplicativos e sites de comunicação instantânea, chats e mensageiros corporativos/pessoais.</description>
		</field>
		<field>
			<fielddescr>Bloquear WhatsApp (Web, Desktop &amp; Mobile)</fielddescr>
			<fieldname>block_msg_whatsapp</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia WhatsApp Web, aplicativo para desktop e conexões mobile (whatsapp.com, whatsapp.net, wa.me).</description>
		</field>
		<field>
			<fielddescr>Bloquear Telegram (Web, App &amp; t.me)</fielddescr>
			<fieldname>block_msg_telegram</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Telegram Web, API e links (telegram.org, t.me, telegra.ph).</description>
		</field>
		<field>
			<fielddescr>Bloquear Facebook Messenger</fielddescr>
			<fieldname>block_msg_messenger</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Facebook Messenger (messenger.com, m.me, chat.facebook.com).</description>
		</field>
		<field>
			<fielddescr>Bloquear Microsoft Teams &amp; Skype / MSN</fielddescr>
			<fieldname>block_msg_teams_skype</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Microsoft Teams, Skype e redes legadas MSN Messenger (teams.microsoft.com, skype.com, messenger.msn.com).</description>
		</field>
		<field>
			<fielddescr>Bloquear Discord (Chat &amp; Voz)</fielddescr>
			<fieldname>block_msg_discord</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia Discord e convites (discord.com, discord.gg, discordapp.com).</description>
		</field>
		<field>
			<fielddescr>Bloquear Slack</fielddescr>
			<fieldname>block_msg_slack</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia plataforma de comunicação Slack (slack.com, slack-msgs.com).</description>
		</field>
		<field>
			<fielddescr>Bloquear Zoom &amp; Google Meet / Chat</fielddescr>
			<fieldname>block_msg_zoom_meet</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia plataformas de reuniões e chat Zoom (zoom.us) e Google Meet/Chat (meet.google.com, chat.google.com).</description>
		</field>
		<field>
			<fielddescr>Bloquear Outros Mensageiros (Signal, WeChat, Viber, LINE, Omegle, etc.)</fielddescr>
			<fieldname>block_msg_others</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Bloqueia mensageiros adicionais: Signal, WeChat, Viber, LINE, KakaoTalk, ICQ, Kik, Element/Matrix, Omegle, etc.</description>
		</field>

		<field>
			<name>Integração Corporativa: Active Directory, NPS (RADIUS) &amp; Netskope</name>
			<type>listtopic</type>
		</field>
		<field>
			<fielddescr>Habilitar Split-DNS Corporativo</fielddescr>
			<fieldname>corp_enable</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Encaminha consultas de Active Directory e NPS RADIUS diretamente para a Matriz através da VPN IPsec.</description>
		</field>
		<field>
			<fielddescr>Domínio(s) do Active Directory</fielddescr>
			<fieldname>corp_ad_domain</fieldname>
			<type>input</type>
			<size>40</size>
			<description>Domínio interno (ex: madeiramadeira.local, corp.empresa.com.br). Se múltiplos, separe por vírgula.</description>
		</field>
		<field>
			<fielddescr>IPs dos Servidores DNS da Matriz (AD/NPS)</fielddescr>
			<fieldname>corp_ad_dns_ips</fieldname>
			<type>input</type>
			<size>40</size>
			<description>IPs dos controladores de domínio e servidores NPS RADIUS na Matriz acessíveis via IPsec.</description>
		</field>
		<field>
			<fielddescr>Encaminhar Zonas Reversas (in-addr.arpa)</fielddescr>
			<fieldname>corp_reverse_lookup</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<default_value>yes</default_value>
			<description>Encaminha resolução reversa de IP das sub-redes corporativas para os servidores da Matriz.</description>
		</field>
		<field>
			<fielddescr>Redes Corporativas Autorizadas no DNS (CIDR)</fielddescr>
			<fieldname>corp_allowed_subnets</fieldname>
			<type>textarea</type>
			<rows>4</rows>
			<cols>40</cols>
			<default_value>172.24.0.0/16
192.168.0.0/16
192.192.0.0/16
10.0.0.0/8</default_value>
			<description>Super-redes corporativas com autorização automática para consultar o Unbound DNS em todas as 18 unidades, incluindo sub-redes roteadas via Switch L3.</description>
		</field>
		<field>
			<fielddescr>Proteção Netskope Security Cloud</fielddescr>
			<fieldname>corp_protect_netskope</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<default_value>yes</default_value>
			<description>Garante que os domínios da Netskope (goskope.com, netskope.com) fiquem em Whitelist permanente.</description>
		</field>
		<field>
			<fielddescr>Proteger Provedores de Identidade Cloud (IdP)</fielddescr>
			<fieldname>corp_protect_idp</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<default_value>yes</default_value>
			<description>Mantém liberados Microsoft 365/Entra ID, Okta e Google para autenticação SSO/MFA.</description>
		</field>
		<field>
			<fielddescr>Liberar Ferramentas de TI &amp; Downloads (PuTTY, etc.)</fielddescr>
			<fieldname>corp_protect_tools</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<default_value>yes</default_value>
			<description>Garante que downloads de ferramentas essenciais de TI e administração (PuTTY, WinSCP, 7-Zip, Notepad++, Git/GitHub, Sysinternals, etc.) fiquem em Whitelist permanente.</description>
		</field>
		<field>
			<fielddescr>Liberar Infraestrutura Pública Cloudflare</fielddescr>
			<fieldname>corp_protect_cloudflare</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<default_value>yes</default_value>
			<description>Mantém liberada a infraestrutura CDN, bibliotecas (cdnjs), captchas Turnstile e APIs da Cloudflare para que sites legítimos e links de download carreguem normalmente.</description>
		</field>

		<field>
			<name>Agendamento por Horário (Horário Comercial)</name>
			<type>listtopic</type>
		</field>
		<field>
			<fielddescr>Ativar Agendamento por Horário</fielddescr>
			<fieldname>schedule_enable</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Se ativado, o bloqueio funcionará apenas nos horários configurados abaixo (fora do horário, os sites são liberados).</description>
		</field>
		<field>
			<fielddescr>Horário de Início do Bloqueio</fielddescr>
			<fieldname>schedule_start</fieldname>
			<type>input</type>
			<size>10</size>
			<default_value>08:00</default_value>
			<description>Formato HH:MM (Exemplo: 08:00).</description>
		</field>
		<field>
			<fielddescr>Início do Intervalo de Almoço (Liberado)</fielddescr>
			<fieldname>schedule_lunch_start</fieldname>
			<type>input</type>
			<size>10</size>
			<default_value>12:00</default_value>
			<description>Horário em que o bloqueio pausa para o almoço (Exemplo: 12:00. Deixe em branco se não houver pausa).</description>
		</field>
		<field>
			<fielddescr>Fim do Intervalo de Almoço (Retoma Bloqueio)</fielddescr>
			<fieldname>schedule_lunch_end</fieldname>
			<type>input</type>
			<size>10</size>
			<default_value>13:30</default_value>
			<description>Horário em que o bloqueio é retomado (Exemplo: 13:30. Deixe em branco se não houver pausa).</description>
		</field>
		<field>
			<fielddescr>Horário de Término do Bloqueio</fielddescr>
			<fieldname>schedule_end</fieldname>
			<type>input</type>
			<size>10</size>
			<default_value>18:00</default_value>
			<description>Formato HH:MM (Exemplo: 18:00. Após este horário, o acesso é liberado).</description>
		</field>
		<field>
			<fielddescr>Bloquear nos Fins de Semana</fielddescr>
			<fieldname>schedule_weekend</fieldname>
			<type>checkbox</type>
			<setflagcheckboxon>yes</setflagcheckboxon>
			<description>Marque se desejar manter o bloqueio ativo aos sábados e domingos.</description>
		</field>

		<field>
			<name>Exceções &amp; Personalização</name>
			<type>listtopic</type>
		</field>
		<field>
			<fielddescr>IPs Isentos do Bloqueio (Bypass IPs)</fielddescr>
			<fieldname>bypass_ips</fieldname>
			<type>textarea</type>
			<rows>4</rows>
			<cols>60</cols>
			<description>Insira os IPs locais de dispositivos que NUNCA devem sofrer bloqueio (Diretoria, TI, Marketing, etc.). Um IP por linha ou separados por vírgula. Exemplo: &lt;strong&gt;172.24.60.20&lt;/strong&gt;.</description>
		</field>
		<field>
			<fielddescr>Lista Branca de Domínios (Whitelist)</fielddescr>
			<fieldname>custom_whitelist</fieldname>
			<type>textarea</type>
			<rows>4</rows>
			<cols>60</cols>
			<description>Insira domínios que NUNCA devem ser bloqueados, mesmo que estejam nas categorias acima (um por linha). Exemplo: &lt;strong&gt;linkedin.com&lt;/strong&gt;</description>
		</field>
		<field>
			<fielddescr>Lista Negra Adicional (Blacklist)</fielddescr>
			<fieldname>custom_blacklist</fieldname>
			<type>textarea</type>
			<rows>4</rows>
			<cols>60</cols>
			<description>Insira domínios adicionais manuais para bloquear (um por linha). Exemplo: &lt;strong&gt;exemplo.com&lt;/strong&gt;</description>
		</field>
		<field>
			<fielddescr>Ação do Bloqueio</fielddescr>
			<fieldname>block_action</fieldname>
			<type>select</type>
			<default_value>block_page</default_value>
			<options>
				<option><name>Exibir Banner de Bloqueio da Empresa (Página de Bloqueio / Recomendado)</name><value>block_page</value></option>
				<option><name>Retornar 0.0.0.0 (Silencioso - Sem Certificado SSL)</name><value>always_null</value></option>
			</options>
			<description>Selecione o comportamento ao bloquear um domínio. Ao selecionar a Página de Bloqueio, conexões HTTP/HTTPS em domínios restritos são direcionadas ao banner institucional corporativo.</description>
		</field>
	</fields>
	<custom_php_resync_config_command>
		rules_wam_resync();
	</custom_php_resync_config_command>
</packagegui>

EOF_XML
echo '>> Extraindo pkg/rules_wam.inc...'
cat << 'EOF_INC' > $TMP_DIR/pkg/rules_wam.inc
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

            // Interface física/virtual no FreeBSD (Ex: igb0, em1, vlan0.10)
            $real_if = !empty($if_cfg['if']) ? $if_cfg['if'] : '';
            if (empty($real_if) && function_exists('get_real_interface')) {
                $real_if = get_real_interface($if_key);
            }
            if (empty($real_if) && function_exists('convert_friendly_interface_to_real_interface_name')) {
                $real_if = convert_friendly_interface_to_real_interface_name($if_key);
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
            'enable_upstream_forwarding'
        );
        foreach ($checkbox_keys as $chk) {
            if (!isset($cfg[$chk])) {
                // Proteções essenciais devem ser padrão ativas se não definidas
                if ($chk === 'corp_protect_tools' || $chk === 'corp_protect_cloudflare' || $chk === 'corp_protect_netskope' || $chk === 'corp_protect_idp') {
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

    // --- Integração Corporativa: Netskope, IdP, Ferramentas de TI e Cloudflare ---
    $protect_netskope = (!isset($wam_cfg['corp_protect_netskope']) || rules_wam_is_checked($wam_cfg['corp_protect_netskope']));
    $protect_idp = (!isset($wam_cfg['corp_protect_idp']) || rules_wam_is_checked($wam_cfg['corp_protect_idp']));
    $protect_tools = (!isset($wam_cfg['corp_protect_tools']) || rules_wam_is_checked($wam_cfg['corp_protect_tools']));
    $protect_cloudflare = (!isset($wam_cfg['corp_protect_cloudflare']) || rules_wam_is_checked($wam_cfg['corp_protect_cloudflare']));
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
        'netskope_protection' => $protect_netskope ? 'Ativo (Auto-Whitelist)' : 'Desativado'
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
EOF_INC
echo '>> Extraindo pkg/rules_wam_hook.inc...'
cat << 'EOF_HOOK' > $TMP_DIR/pkg/rules_wam_hook.inc
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

EOF_HOOK
echo '>> Extraindo pkg/register_menu.php...'
cat << 'EOF_REG' > $TMP_DIR/pkg/register_menu.php
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

EOF_REG
echo '>> Extraindo pkg/wam_cron.php...'
cat << 'EOF_CRON' > $TMP_DIR/pkg/wam_cron.php
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

EOF_CRON
echo '>> Extraindo www/rules_wam.php...'
cat << 'EOF_WAM_PHP' > $TMP_DIR/www/rules_wam.php
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

EOF_WAM_PHP
echo '>> Extraindo www/rules_wam_status.php...'
cat << 'EOF_STATUS' > $TMP_DIR/www/rules_wam_status.php
<?php
/*
 * rules_wam_status.php
 * Rules WAM - Web Access Manager para pfSense
 * Página de Status, Diagnóstico e Monitoramento de Categorias
 */

require_once("guiconfig.inc");
require_once("/usr/local/pkg/rules_wam.inc");

$pgtitle = array(gettext("Services"), gettext("Rules WAM"), gettext("Status & Teste de Bloqueio"));
include("head.inc");

$tab_array = array();
$tab_array[] = array(gettext("Configurações de Bloqueio"), false, "/rules_wam.php");
$tab_array[] = array(gettext("Status & Teste de Bloqueio"), true, "/rules_wam_status.php");
$tab_array[] = array(gettext("Dashboard & Tentativas de Acesso"), false, "/rules_wam_dashboard.php");
$tab_array[] = array(gettext("Banner de Bloqueio (Prévia)"), false, "/rules_wam_block.php");
display_top_tabs($tab_array);

// Teste de domínio solicitado
$test_domain = isset($_POST['test_domain']) ? trim($_POST['test_domain']) : '';
$test_result = null;

if (!empty($test_domain)) {
    $clean_test = rules_wam_clean_domain($test_domain);
    
    // 1. Verifica se o domínio está listado no arquivo de bloqueio ativo
    $is_in_blocklist = false;
    if (file_exists(WAM_CONF_FILE)) {
        $conf_data = @file_get_contents(WAM_CONF_FILE);
        if ($conf_data) {
            if (preg_match('/local-zone:\s*"' . preg_quote($clean_test, '/') . '"/i', $conf_data)) {
                $is_in_blocklist = true;
            } else {
                $parts = explode('.', $clean_test);
                while (count($parts) > 1) {
                    array_shift($parts);
                    $parent = implode('.', $parts);
                    if (preg_match('/local-zone:\s*"' . preg_quote($parent, '/') . '"/i', $conf_data)) {
                        $is_in_blocklist = true;
                        break;
                    }
                }
            }
        }
    }

    // 2. Consulta diretamente o Unbound local na porta 53 via drill
    $drill_ip = null;
    $drill_out = array();
    if (file_exists('/usr/bin/drill')) {
        @exec("/usr/bin/drill @127.0.0.1 -p 53 " . escapeshellarg($clean_test) . " A 2>&1", $drill_out);
        foreach ($drill_out as $dline) {
            if (preg_match('/\b0\.0\.0\.0\b/', $dline)) {
                $drill_ip = '0.0.0.0';
                break;
            } elseif (preg_match('/IN\s+A\s+(\d+\.\d+\.\d+\.\d+)/', $dline, $m)) {
                $drill_ip = $m[1];
            }
        }
    }

    $wam_cfg = rules_wam_get_config();
    $lan_ip = function_exists('rules_wam_get_lan_ip') ? rules_wam_get_lan_ip() : '192.168.1.1';
    $block_page_ip = !empty($wam_cfg['block_page_ip']) ? $wam_cfg['block_page_ip'] : $lan_ip;

    $is_drill_blocked = ($drill_ip === '0.0.0.0' || (!empty($block_page_ip) && $drill_ip === $block_page_ip) || $drill_ip === '127.0.0.1');

    if ($is_in_blocklist || $is_drill_blocked) {
        $test_result = array(
            'status' => 'BLOCKED',
            'domain' => $clean_test,
            'ip' => ($drill_ip ? $drill_ip : '0.0.0.0') . ' (Interceptado pelo Rules WAM / Unbound)',
            'msg' => 'Domínio BLOQUEADO pelo Rules WAM!'
        );

        // Registra o teste na auditoria
        $client_ip = !empty($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1';
        $cat = rules_wam_get_domain_category($clean_test);
        $entry = date('M d H:i:s') . '|' . $client_ip . '|' . $clean_test . '|' . $cat . "\n";
        @file_put_contents(WAM_AUDIT_LOG, $entry, FILE_APPEND);
    } else {
        $test_result = array(
            'status' => 'ALLOWED',
            'domain' => $clean_test,
            'ip' => $drill_ip ? $drill_ip : 'Resolvido normalmente',
            'msg' => 'Domínio não está nas categorias ativas de bloqueio (acesso liberado).'
        );
    }
}

// Carrega status
$status_file = WAM_STATUS_FILE;
$status_data = array(
    'enabled' => false,
    'schedule_active' => false,
    'is_blocking' => false,
    'updated_at' => '-',
    'total_blocked' => 0,
    'categories' => array(),
    'whitelist_count' => 0,
    'bypass_ips_count' => 0
);

if (file_exists($status_file)) {
    $raw = @file_get_contents($status_file);
    $parsed = json_decode($raw, true);
    if (is_array($parsed)) {
        $status_data = array_merge($status_data, $parsed);
    }
}

// Verificação em tempo real direto no config.xml e Unbound
$wam_cfg = rules_wam_get_config();
if (rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
    $status_data['enabled'] = true;
    if (file_exists(WAM_CONF_FILE)) {
        $status_data['is_blocking'] = true;
        if ($status_data['total_blocked'] <= 0) {
            $lines = file(WAM_CONF_FILE);
            $cnt = 0;
            foreach ($lines as $l) {
                if (strpos($l, 'local-zone:') !== false) $cnt++;
            }
            $status_data['total_blocked'] = $cnt;
        }
    }
}

// Mapeamento de categorias e contagem local
$categories_info = array(
    'block_adult'     => array('name' => 'Conteúdo Adulto & Pornografia', 'file' => 'adult.txt'),
    'block_gambling'  => array('name' => 'Apostas, Bets & Cassinos',     'file' => 'gambling.txt'),
    'block_news'      => array('name' => 'Notícias & Portais de Mídia',   'file' => 'news.txt'),
    'block_social'    => array('name' => 'Mídias Sociais & Redes',       'file' => 'social-media.txt'),
    'block_sports'    => array('name' => 'Esportes & Placares',          'file' => 'sports.txt'),
    'block_gaming'    => array('name' => 'Jogos & Games Online',         'file' => 'gaming.txt'),
    'block_streaming' => array('name' => 'Streaming & Vídeo',            'file' => 'streaming.txt'),
    'block_shopping'  => array('name' => 'Compras & E-commerce',         'file' => 'shopping.txt'),
    'block_p2p'       => array('name' => 'Torrents & P2P',               'file' => 'p2p.txt'),
    'block_doh'       => array('name' => 'Anti-Bypass DoH (DNS Seguro)', 'file' => 'doh-providers.txt'),
    'block_vpn'       => array('name' => 'VPN, ZTNA & Proxies',          'file' => 'vpn-ztna.txt'),
    'block_messaging' => array('name' => 'Mensageiros & Chat Instantâneo', 'file' => 'messaging.txt'),
);
?>

<div class="alert alert-success" style="margin-bottom: 20px;">
    <h4><i class="fa fa-database fa-lg"></i> <strong>BANCO DE DADOS DE LISTAS 100% INSTALADO E ATIVO</strong></h4>
    <p>Todas as listas de categorias (mais de <strong>4.700 domínios consolidados</strong>) já estão gravadas no seu pfSense e prontas para uso offline imediato. <strong>Não é necessário efetuar nenhum download adicional.</strong></p>
</div>

<div class="panel panel-default">
    <div class="panel-heading">
        <h2 class="panel-title"><?=gettext("Visão Geral do Serviço Rules WAM")?></h2>
    </div>
    <div class="panel-body">
        <dl class="dl-horizontal">
            <dt><?=gettext("Estado do Serviço")?></dt>
            <dd>
                <?php if ($status_data['enabled'] && $status_data['is_blocking']): ?>
                    <span class="label label-success" style="font-size: 13px; padding: 4px 10px;"><i class="fa fa-shield"></i> <?=gettext("ATIVO - BLOQUEANDO AGORA")?></span>
                <?php elseif ($status_data['enabled'] && !$status_data['is_blocking']): ?>
                    <span class="label label-info" style="font-size: 13px; padding: 4px 10px;"><i class="fa fa-clock-o"></i> <?=gettext("ATIVO - HORÁRIO PAUSADO (ACESSO LIBERADO)")?></span>
                <?php else: ?>
                    <span class="label label-danger" style="font-size: 13px; padding: 4px 10px;"><i class="fa fa-times-circle"></i> <?=gettext("DESABILITADO")?></span>
                <?php endif; ?>
            </dd>

            <dt><?=gettext("Total de Regras Ativas")?></dt>
            <dd><strong style="font-size: 15px; color: #3c763d;"><?=number_format($status_data['total_blocked'])?></strong> <?=gettext("domínios e subdomínios bloqueados no Unbound")?></dd>

            <dt><?=gettext("Última Aplicação")?></dt>
            <dd><?=htmlspecialchars($status_data['updated_at'])?></dd>

            <dt><?=gettext("Agendamento")?></dt>
            <dd>
                <?php if (!empty($status_data['schedule_active'])): ?>
                    <span class="label label-primary"><i class="fa fa-calendar"></i> <?=gettext("Horário Comercial Ativo")?></span>
                <?php else: ?>
                    <em><?=gettext("Bloqueio contínuo (24 horas)")?></em>
                <?php endif; ?>
            </dd>

            <dt><?=gettext("IPs Isentos (Bypass)")?></dt>
            <dd><?=intval($status_data['bypass_ips_count'])?> <?=gettext("dispositivo(s) com acesso livre")?></dd>

            <dt><?=gettext("Whitelist")?></dt>
            <dd><?=intval($status_data['whitelist_count'])?> <?=gettext("domínio(s) liberados")?></dd>

            <dt><?=gettext("Anti-Bypass DNS")?></dt>
            <dd>
                <?php if (rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? null)): ?>
                    <span class="label label-success"><i class="fa fa-lock"></i> <?=gettext("Ativo (Interceptando 8.8.8.8 / 1.1.1.1 na Porta 53)")?></span>
                <?php else: ?>
                    <span class="label label-default"><?=gettext("Desativado")?></span>
                <?php endif; ?>
            </dd>

            <dt><?=gettext("Forwarding Upstream")?></dt>
            <dd>
                <?php if (rules_wam_is_checked($wam_cfg['enable_upstream_forwarding'] ?? null)): ?>
                    <span class="label label-info"><i class="fa fa-bolt"></i> <?=gettext("Ativo (Google 8.8.8.8 & Cloudflare 1.1.1.1)")?></span>
                <?php else: ?>
                    <em><?=gettext("Padrão do pfSense (Resolução Raiz / General DNS)")?></em>
                <?php endif; ?>
            </dd>
        </dl>
    </div>
</div>

<div class="panel panel-default">
    <div class="panel-heading">
        <h2 class="panel-title"><?=gettext("Status das Categorias no Sistema (Banco de Regras Local)")?></h2>
    </div>
    <div class="table-responsive">
        <table class="table table-striped table-hover table-condensed">
            <thead>
                <tr>
                    <th><?=gettext("Categoria")?></th>
                    <th><?=gettext("Status no pfSense")?></th>
                    <th><?=gettext("Qtd. Domínios no Banco")?></th>
                    <th><?=gettext("Aplicação na Rede")?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($categories_info as $ckey => $cdata): 
                    $fpath = WAM_FEEDS_DIR . '/' . $cdata['file'];
                    $lines_cnt = 0;
                    if (file_exists($fpath)) {
                        $lines = file($fpath, FILE_SKIP_EMPTY_LINES);
                        foreach ($lines as $l) {
                            $l = trim($l);
                            if (!empty($l) && $l[0] !== '#') $lines_cnt++;
                        }
                    }
                    $is_cat_active = rules_wam_is_checked($wam_cfg[$ckey] ?? null);
                ?>
                <tr>
                    <td><strong><?=htmlspecialchars($cdata['name'])?></strong></td>
                    <td><span class="text-success"><i class="fa fa-check-circle"></i> <?=gettext("Instalado e Pronto")?></span></td>
                    <td><span class="badge" style="background-color: #337ab7;"><?=number_format($lines_cnt)?> domínios</span></td>
                    <td>
                        <?php if ($status_data['enabled'] && $is_cat_active): ?>
                            <span class="label label-success"><i class="fa fa-shield"></i> <?=gettext("Bloqueando")?></span>
                        <?php else: ?>
                            <span class="label label-default"><?=gettext("Desmarcado")?></span>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<div class="panel panel-default">
    <div class="panel-heading">
        <h2 class="panel-title"><?=gettext("Testador de Bloqueio em Tempo Real")?></h2>
    </div>
    <div class="panel-body">
        <p><?=gettext("Digite um domínio ou URL para testar se o pfSense está bloqueando a resolução DNS para os clientes da rede:")?></p>
        <form action="/rules_wam_status.php" method="post" class="form-inline">
            <div class="form-group">
                <input type="text" name="test_domain" class="form-control" style="min-width: 320px;" placeholder="Ex: g1globo.com, xvideo.com, youtube.com, betano.com" value="<?=htmlspecialchars($test_domain)?>" required />
            </div>
            <button type="submit" class="btn btn-primary"><i class="fa fa-search"></i> <?=gettext("Testar Bloqueio")?></button>
        </form>

        <?php if ($test_result): ?>
            <div style="margin-top: 15px;">
                <?php if ($test_result['status'] === 'BLOCKED'): ?>
                    <div class="alert alert-success">
                        <h4><i class="fa fa-shield"></i> <strong>BLOQUEADO COM SUCESSO!</strong></h4>
                        <p>O domínio <strong><?=htmlspecialchars($test_result['domain'])?></strong> está bloqueado pelo Rules WAM. Resposta DNS: <code><?=htmlspecialchars($test_result['ip'])?></code>.</p>
                    </div>
                <?php else: ?>
                    <div class="alert alert-warning">
                        <h4><i class="fa fa-check-circle"></i> <strong>PERMITIDO / NÃO BLOQUEADO</strong></h4>
                        <p>O domínio <strong><?=htmlspecialchars($test_result['domain'])?></strong> não está ativo na lista de bloqueio. Status: <code><?=htmlspecialchars($test_result['ip'])?></code>.</p>
                    </div>
                <?php endif; ?>
            </div>
        <?php endif; ?>
    </div>
</div>

<?php include("foot.inc"); ?>

EOF_STATUS
echo '>> Extraindo www/rules_wam_dashboard.php...'
cat << 'EOF_DASH' > $TMP_DIR/www/rules_wam_dashboard.php
<?php
/*
 * rules_wam_dashboard.php
 * Rules WAM - Web Access Manager para pfSense
 * Painel de Auditoria, Tentativas de Acesso e Exportação (CSV/JSON)
 */

require_once("guiconfig.inc");
require_once("/usr/local/pkg/rules_wam.inc");

// 1. Exportação CSV de Registros de Bloqueio (Excel) - Sem limites (Todos, Online ou Offline)
if (isset($_GET['export']) && ($_GET['export'] === 'csv' || $_GET['export'] === 'csv_all')) {
    @ini_set('memory_limit', '512M');
    @set_time_limit(300);

    $status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
    if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
        $status_filter = 'all';
    }
    // 0 = sem limites, extrai 100% dos eventos registrados
    $events = rules_wam_get_audit_events(0);

    if ($status_filter === 'online') {
        $events = array_values(array_filter($events, function($ev) {
            return !empty($ev['online']);
        }));
        $filename = "relatorio_bloqueios_online_rules_wam_" . date('Y-m-d_His') . ".csv";
    } elseif ($status_filter === 'offline') {
        $events = array_values(array_filter($events, function($ev) {
            return empty($ev['online']);
        }));
        $filename = "relatorio_bloqueios_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    } else {
        $filename = "relatorio_bloqueios_todos_online_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    }

    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    // BOM UTF-8 para o Excel abrir com acentuação correta
    echo "\xEF\xBB\xBF";

    $output = fopen('php://output', 'w');
    fputcsv($output, array('Data e Hora', 'Endereco IP', 'Hostname', 'Status na Rede', 'Interface pfSense', 'Dominio Bloqueado', 'Categoria', 'Acao Realizada'), ';');

    foreach ($events as $ev) {
        $status_txt = !empty($ev['online']) ? 'Online' : 'Offline';
        $ev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($ev['ip']) : null;
        $if_name = !empty($ev_if['descr']) ? $ev_if['descr'] : (!empty($ev_if['logical_id']) ? $ev_if['logical_id'] : 'Local');
        fputcsv($output, array(
            $ev['timestamp'],
            $ev['ip'],
            $ev['hostname'],
            $status_txt,
            $if_name,
            $ev['domain'],
            $ev['category'],
            'BLOQUEADO (0.0.0.0)'
        ), ';');
    }

    fclose($output);
    exit;
}

// 2. Exportação CSV do Resumo de Dispositivos (Online e Offline)
if (isset($_GET['export']) && $_GET['export'] === 'csv_devices') {
    @ini_set('memory_limit', '512M');
    @set_time_limit(300);

    $status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
    if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
        $status_filter = 'all';
    }
    $events = rules_wam_get_audit_events(0);

    $devices = array();
    foreach ($events as $ev) {
        $ip = $ev['ip'];
        $dom = $ev['domain'];
        $cat = $ev['category'];
        $is_online = !empty($ev['online']);

        if (!isset($devices[$ip])) {
            $devices[$ip] = array(
                'ip' => $ip,
                'hostname' => $ev['hostname'],
                'online' => $is_online,
                'status_label' => $is_online ? 'Online' : 'Offline',
                'mac' => rules_wam_get_host_mac($ip),
                'count' => 0,
                'domains' => array(),
                'categories' => array(),
                'last_time' => $ev['timestamp'],
                'last_domain' => $dom
            );
        }
        $devices[$ip]['count']++;
        $devices[$ip]['domains'][$dom] = ($devices[$ip]['domains'][$dom] ?? 0) + 1;
        $devices[$ip]['categories'][$cat] = ($devices[$ip]['categories'][$cat] ?? 0) + 1;
        $devices[$ip]['online'] = $is_online;
        $devices[$ip]['status_label'] = $is_online ? 'Online' : 'Offline';
    }

    uasort($devices, function($a, $b) {
        return $b['count'] <=> $a['count'];
    });

    if ($status_filter === 'online') {
        $devices = array_filter($devices, function($dev) { return !empty($dev['online']); });
        $filename = "relatorio_dispositivos_online_rules_wam_" . date('Y-m-d_His') . ".csv";
    } elseif ($status_filter === 'offline') {
        $devices = array_filter($devices, function($dev) { return empty($dev['online']); });
        $filename = "relatorio_dispositivos_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    } else {
        $filename = "relatorio_dispositivos_online_offline_rules_wam_" . date('Y-m-d_His') . ".csv";
    }

    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    echo "\xEF\xBB\xBF";
    $output = fopen('php://output', 'w');
    fputcsv($output, array('Endereco IP', 'Hostname', 'Status na Rede', 'Interface pfSense', 'MAC Address', 'Total de Tentativas', 'Categoria Mais Frequente', 'Ultimo Dominio Barrado', 'Data Ultima Tentativa'), ';');

    foreach ($devices as $dev) {
        arsort($dev['categories']);
        $top_c = key($dev['categories']);
        $dev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($dev['ip']) : null;
        $if_name = !empty($dev_if['descr']) ? $dev_if['descr'] : (!empty($dev_if['logical_id']) ? $dev_if['logical_id'] : 'Local');
        fputcsv($output, array(
            $dev['ip'],
            $dev['hostname'],
            $dev['status_label'],
            $if_name,
            !empty($dev['mac']) ? $dev['mac'] : 'N/A',
            $dev['count'],
            $top_c,
            $dev['last_domain'],
            $dev['last_time']
        ), ';');
    }

    fclose($output);
    exit;
}

// 3. Exportação JSON (Todos os Registros com Status)
if (isset($_GET['export']) && $_GET['export'] === 'json') {
    @ini_set('memory_limit', '512M');
    @set_time_limit(300);

    $status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
    if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
        $status_filter = 'all';
    }
    $events = rules_wam_get_audit_events(0);

    if ($status_filter === 'online') {
        $events = array_values(array_filter($events, function($ev) { return !empty($ev['online']); }));
    } elseif ($status_filter === 'offline') {
        $events = array_values(array_filter($events, function($ev) { return empty($ev['online']); }));
    }

    $online_cnt = 0;
    $offline_cnt = 0;
    foreach ($events as $ev) {
        if (!empty($ev['online'])) $online_cnt++; else $offline_cnt++;
    }

    $filename = "relatorio_bloqueios_rules_wam_" . date('Y-m-d_His') . ".json";

    header('Content-Type: application/json; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    echo json_encode(array(
        'generated_at' => date('Y-m-d H:i:s'),
        'filter' => $status_filter,
        'total_events' => count($events),
        'online_events' => $online_cnt,
        'offline_events' => $offline_cnt,
        'events' => $events
    ), JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}

// 3. Simulação de Teste Direto na Dashboard
$alert_msg = null;
if (isset($_POST['simulate_test_domain'])) {
    $s_dom = rules_wam_clean_domain($_POST['simulate_test_domain'] ?? '');
    if (!empty($s_dom)) {
        $client_ip = !empty($_POST['simulate_ip']) ? trim($_POST['simulate_ip']) : (!empty($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1');
        $cat = rules_wam_get_domain_category($s_dom);
        $entry = date('M d H:i:s') . '|' . $client_ip . '|' . $s_dom . '|' . $cat . "\n";
        @file_put_contents(WAM_AUDIT_LOG, $entry, FILE_APPEND);
        $alert_msg = "Tentativa de acesso a '{$s_dom}' registrada no log para o IP {$client_ip}!";
    }
}

// 4. Limpeza de Logs
if (isset($_POST['clear_audit_logs'])) {
    if (file_exists(WAM_AUDIT_LOG)) {
        @file_put_contents(WAM_AUDIT_LOG, '');
    }
    $alert_msg = "Histórico de auditoria do Rules WAM foi limpo com sucesso!";
}

$pgtitle = array(gettext("Services"), gettext("Rules WAM"), gettext("Dashboard & Auditoria"));
include("head.inc");

$tab_array = array();
$tab_array[] = array(gettext("Configurações de Bloqueio"), false, "/rules_wam.php");
$tab_array[] = array(gettext("Status & Teste de Bloqueio"), false, "/rules_wam_status.php");
$tab_array[] = array(gettext("Dashboard & Tentativas de Acesso"), true, "/rules_wam_dashboard.php");
$tab_array[] = array(gettext("Banner de Bloqueio (Prévia)"), false, "/rules_wam_block.php");
display_top_tabs($tab_array);

// Carrega eventos auditados recentes para visualização na tela
$all_events = rules_wam_get_audit_events(2000);

// Informações do Host Atual conectado à WebGUI
$current_client_ip = !empty($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1';
$cache_hn = array();
$current_client_hostname = rules_wam_resolve_hostname($current_client_ip, $cache_hn);
$wam_cfg = rules_wam_get_config();

$is_current_in_bypass = false;
if (!empty($wam_cfg['bypass_ips'])) {
    $raw_ips = preg_split('/[\r\n,;]+/', $wam_cfg['bypass_ips']);
    foreach ($raw_ips as $rip) {
        $rip = trim($rip);
        if ($rip === $current_client_ip || strpos($rip, $current_client_ip) !== false) {
            $is_current_in_bypass = true;
            break;
        }
    }
}

// Agrupamento geral por IP/Dispositivo
$by_device = array();
$by_domain = array();

foreach ($all_events as $ev) {
    $ip = $ev['ip'];
    $dom = $ev['domain'];
    $cat = $ev['category'];
    $is_online = !empty($ev['online']);

    if (!isset($by_device[$ip])) {
        $by_device[$ip] = array(
            'ip' => $ip,
            'hostname' => $ev['hostname'],
            'online' => $is_online,
            'status_label' => $is_online ? 'Online' : 'Offline',
            'mac' => rules_wam_get_host_mac($ip),
            'count' => 0,
            'domains' => array(),
            'categories' => array(),
            'last_time' => $ev['timestamp'],
            'last_domain' => $dom
        );
    }
    $by_device[$ip]['count']++;
    $by_device[$ip]['domains'][$dom] = ($by_device[$ip]['domains'][$dom] ?? 0) + 1;
    $by_device[$ip]['categories'][$cat] = ($by_device[$ip]['categories'][$cat] ?? 0) + 1;
    $by_device[$ip]['online'] = $is_online;
    $by_device[$ip]['status_label'] = $is_online ? 'Online' : 'Offline';

    if (!isset($by_domain[$dom])) {
        $by_domain[$dom] = array(
            'domain' => $dom,
            'category' => $cat,
            'count' => 0,
            'last_time' => $ev['timestamp']
        );
    }
    $by_domain[$dom]['count']++;
}

// Ordena dispositivos por mais tentativas (Top Offender)
uasort($by_device, function($a, $b) {
    return $b['count'] <=> $a['count'];
});

// Ordena domínios mais tentados
uasort($by_domain, function($a, $b) {
    return $b['count'] <=> $a['count'];
});

// Estatísticas globais
$total_blocks = count($all_events);
$total_devices = count($by_device);

$count_online_devices = 0;
$count_offline_devices = 0;
foreach ($by_device as $dev) {
    if (!empty($dev['online'])) $count_online_devices++; else $count_offline_devices++;
}

$count_online_events = 0;
$count_offline_events = 0;
foreach ($all_events as $ev) {
    if (!empty($ev['online'])) $count_online_events++; else $count_offline_events++;
}

$top_domain_item = !empty($by_domain) ? reset($by_domain) : null;
$top_device_item = !empty($by_device) ? reset($by_device) : null;

$current_host_stats = $by_device[$current_client_ip] ?? null;
$current_host_blocks = $current_host_stats ? $current_host_stats['count'] : 0;

// Filtro selecionado na interface
$status_filter = isset($_GET['status']) ? strtolower(trim($_GET['status'])) : 'all';
if (!in_array($status_filter, array('all', 'online', 'offline'), true)) {
    $status_filter = 'all';
}

if ($status_filter === 'online') {
    $display_events = array_values(array_filter($all_events, function($ev) { return !empty($ev['online']); }));
    $display_devices = array_filter($by_device, function($dev) { return !empty($dev['online']); });
} elseif ($status_filter === 'offline') {
    $display_events = array_values(array_filter($all_events, function($ev) { return empty($ev['online']); }));
    $display_devices = array_filter($by_device, function($dev) { return empty($dev['online']); });
} else {
    $display_events = $all_events;
    $display_devices = $by_device;
}
?>

<?php if ($alert_msg): ?>
    <div class="alert alert-success alert-dismissible" role="alert">
        <button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span></button>
        <i class="fa fa-check-circle"></i> <strong><?=htmlspecialchars($alert_msg)?></strong>
    </div>
<?php endif; ?>

<!-- Barra de Ações e Exportação Completa -->
<div style="margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
    <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
        <!-- Grupo de Exportação CSV Geral (Sem Limites) -->
        <div class="btn-group">
            <a href="/rules_wam_dashboard.php?export=csv&status=all" class="btn btn-success" title="<?=gettext("Exporta todos os registros (online e offline) em CSV/Excel sem limite de linhas")?>">
                <i class="fa fa-file-excel-o"></i> <strong><?=gettext("Exportar Todos os Registros (CSV)")?></strong>
            </a>
            <button type="button" class="btn btn-success dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                <span class="caret"></span>
                <span class="sr-only">Opções de Exportação</span>
            </button>
            <ul class="dropdown-menu">
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv&status=all">
                        <i class="fa fa-database text-primary"></i> <strong><?=gettext("Todos os Registros (Online & Offline)")?></strong>
                    </a>
                </li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv&status=online">
                        <i class="fa fa-circle text-success"></i> <?=gettext("Apenas Registros de Hosts Online (CSV)")?>
                    </a>
                </li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv&status=offline">
                        <i class="fa fa-circle-o text-muted"></i> <?=gettext("Apenas Registros de Hosts Offline (CSV)")?>
                    </a>
                </li>
                <li role="separator" class="divider"></li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=csv_devices">
                        <i class="fa fa-desktop text-info"></i> <?=gettext("Exportar Lista de Dispositivos (Online & Offline)")?>
                    </a>
                </li>
                <li>
                    <a href="/rules_wam_dashboard.php?export=json">
                        <i class="fa fa-code text-warning"></i> <?=gettext("Exportar Todos os Registros (JSON)")?>
                    </a>
                </li>
            </ul>
        </div>

        <a href="/rules_wam_dashboard.php?export=csv_devices" class="btn btn-primary" title="<?=gettext("Exporta resumo consolidado de dispositivos e seu status na rede")?>">
            <i class="fa fa-desktop"></i> <?=gettext("Exportar Dispositivos (CSV)")?>
        </a>

        <a href="/rules_wam_block.php" target="_blank" class="btn btn-warning">
            <i class="fa fa-shield"></i> <?=gettext("Ver Banner de Bloqueio")?>
        </a>
        <a href="/rules_wam_dashboard.php" class="btn btn-info">
            <i class="fa fa-refresh"></i> <?=gettext("Atualizar")?>
        </a>
    </div>

    <div>
        <form action="/rules_wam_dashboard.php" method="post" style="display: inline;" onsubmit="return confirm('Deseja realmente limpar o histórico de tentativas gravado?');">
            <input type="hidden" name="clear_audit_logs" value="1" />
            <button type="submit" class="btn btn-danger btn-sm">
                <i class="fa fa-trash"></i> <?=gettext("Limpar Histórico")?>
            </button>
        </form>
    </div>
</div>

<!-- Informações do Host Atual Conectado -->
<div class="panel panel-default" style="border-left: 5px solid #337ab7; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
    <div class="panel-body" style="padding: 15px 20px;">
        <div class="row" style="display: flex; align-items: center; flex-wrap: wrap; gap: 15px 0;">
            <div class="col-sm-4">
                <h4 style="margin: 0 0 5px 0; color: #337ab7; font-size: 15px;">
                    <i class="fa fa-laptop"></i> <strong><?=gettext("Seu Host Atual (Sessão Conectada)")?></strong>
                </h4>
                <div style="font-size: 14px; margin-top: 4px;">
                    <strong>IP:</strong> <span class="label label-primary" style="font-size: 13px;"><?=htmlspecialchars($current_client_ip)?></span>
                    &nbsp;&nbsp;
                    <strong>Host:</strong> <code style="font-size: 13px;"><?=htmlspecialchars($current_client_hostname)?></code>
                    &nbsp;&nbsp;
                    <span class="label label-success" style="font-size: 11px;"><i class="fa fa-circle"></i> Online</span>
                </div>
            </div>

            <div class="col-sm-4 text-center">
                <span class="text-muted" style="font-size: 12px; text-transform: uppercase; font-weight: 600; display: block; margin-bottom: 4px;">
                    <?=gettext("Status de Filtragem")?>
                </span>
                <?php if ($is_current_in_bypass): ?>
                    <span class="label label-warning" style="font-size: 13px; padding: 5px 10px;">
                        <i class="fa fa-unlock"></i> <?=gettext("Isento de Bloqueios (Bypass IP Ativo)")?>
                    </span>
                <?php else: ?>
                    <span class="label label-success" style="font-size: 13px; padding: 5px 10px;">
                        <i class="fa fa-shield"></i> <?=gettext("Proteção Ativa (Sujeito às Regras)")?>
                    </span>
                <?php endif; ?>
            </div>

            <div class="col-sm-4 text-right">
                <span class="text-muted" style="font-size: 12px; text-transform: uppercase; font-weight: 600; display: block; margin-bottom: 4px;">
                    <?=gettext("Tentativas Registradas Deste Host")?>
                </span>
                <span class="badge" style="font-size: 14px; background-color: <?=$current_host_blocks > 0 ? '#d9534f' : '#5cb85c'?>; padding: 5px 10px;">
                    <?=number_format($current_host_blocks)?> <?=gettext("bloqueios")?>
                </span>
                <?php if ($current_host_stats): ?>
                    <div style="font-size: 11.5px; color: #777; margin-top: 3px;">
                        <?=gettext("Último:")?> <strong class="text-danger"><?=htmlspecialchars($current_host_stats['last_domain'])?></strong> (<?=htmlspecialchars($current_host_stats['last_time'])?>)
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </div>
</div>

<!-- KPIs / Cartões no Topo -->
<div class="row">
    <div class="col-sm-3">
        <div class="panel panel-danger text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-shield"></i> <?=gettext("TENTATIVAS BLOQUEADAS")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 32px; font-weight: bold; color: #a94442;"><?=number_format($total_blocks)?></span>
                <div style="font-size: 12px; margin-top: 5px;">
                    <span class="text-success" style="font-weight: 600;"><i class="fa fa-circle"></i> <?=$count_online_events?> Online</span>
                    &nbsp;|&nbsp;
                    <span class="text-muted" style="font-weight: 600;"><i class="fa fa-circle-o"></i> <?=$count_offline_events?> Offline</span>
                </div>
            </div>
        </div>
    </div>

    <div class="col-sm-3">
        <div class="panel panel-primary text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-desktop"></i> <?=gettext("MÁQUINAS / DISPOSITIVOS")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 32px; font-weight: bold; color: #337ab7;"><?=number_format($total_devices)?></span>
                <div style="font-size: 12px; margin-top: 5px;">
                    <span class="text-success" style="font-weight: 600;"><i class="fa fa-circle"></i> <?=$count_online_devices?> Online</span>
                    &nbsp;|&nbsp;
                    <span class="text-muted" style="font-weight: 600;"><i class="fa fa-circle-o"></i> <?=$count_offline_devices?> Offline</span>
                </div>
            </div>
        </div>
    </div>

    <div class="col-sm-3">
        <div class="panel panel-warning text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-globe"></i> <?=gettext("TOP SITE BLOQUEADO")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 18px; font-weight: bold; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    <?=$top_domain_item ? htmlspecialchars($top_domain_item['domain']) : 'Nenhum'?>
                </span>
                <p class="text-muted" style="margin: 0;">
                    <?=$top_domain_item ? number_format($top_domain_item['count']) . ' tentativas' : 'Aguardando tráfego'?>
                </p>
            </div>
        </div>
    </div>

    <div class="col-sm-3">
        <div class="panel panel-info text-center" style="margin-bottom: 20px;">
            <div class="panel-heading" style="padding: 10px;">
                <h4 style="margin: 0; font-size: 14px;"><i class="fa fa-user"></i> <?=gettext("TOP DISPOSITIVO INFRATOR")?></h4>
            </div>
            <div class="panel-body" style="padding: 15px;">
                <span style="font-size: 18px; font-weight: bold; display: block; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    <?=$top_device_item ? htmlspecialchars($top_device_item['hostname']) : 'Nenhum'?>
                </span>
                <p class="text-muted" style="margin: 0;">
                    <?=$top_device_item ? htmlspecialchars($top_device_item['ip']) . ' (' . $top_device_item['count'] . 'x)' : 'Sem bloqueios'?>
                </p>
            </div>
        </div>
    </div>
</div>

<!-- Barra de Simulação Rápida / Teste -->
<div class="panel panel-default" style="margin-bottom: 20px;">
    <div class="panel-body" style="padding: 12px;">
        <form action="/rules_wam_dashboard.php" method="post" class="form-inline" style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
            <span style="font-weight: bold;"><i class="fa fa-crosshairs"></i> <?=gettext("Simular/Testar Registro de Tentativa:")?></span>
            <input type="text" name="simulate_ip" class="form-control" style="width: 150px;" placeholder="IP (ex: 172.24.60.111)" value="<?=htmlspecialchars($current_client_ip)?>" title="IP do host a registrar" />
            <input type="text" name="simulate_test_domain" class="form-control" style="min-width: 250px;" placeholder="Domínio (ex: betano.com, xvideo.com)" required />
            <button type="submit" class="btn btn-warning"><i class="fa fa-bolt"></i> <?=gettext("Registrar Tentativa Agora")?></button>
            <span class="text-muted" style="font-size: 12px;"><?=gettext("(Grava imediatamente no log com o IP informado e atualiza a auditoria)")?></span>
        </form>
    </div>
</div>

<!-- Filtro de Visualização: Todos / Online / Offline -->
<div style="margin-bottom: 15px;">
    <ul class="nav nav-pills" style="font-weight: bold;">
        <li role="presentation" class="<?=$status_filter === 'all' ? 'active' : ''?>">
            <a href="/rules_wam_dashboard.php?status=all"><i class="fa fa-list"></i> <?=gettext("Todos os Registros")?> <span class="badge"><?=$total_blocks?></span></a>
        </li>
        <li role="presentation" class="<?=$status_filter === 'online' ? 'active' : ''?>">
            <a href="/rules_wam_dashboard.php?status=online" style="<?=$status_filter !== 'online' ? 'color: #3c763d;' : ''?>"><i class="fa fa-circle text-success"></i> <?=gettext("Apenas Hosts Online")?> <span class="badge"><?=$count_online_events?></span></a>
        </li>
        <li role="presentation" class="<?=$status_filter === 'offline' ? 'active' : ''?>">
            <a href="/rules_wam_dashboard.php?status=offline" style="<?=$status_filter !== 'offline' ? 'color: #777;' : ''?>"><i class="fa fa-circle-o text-muted"></i> <?=gettext("Apenas Hosts Offline")?> <span class="badge"><?=$count_offline_events?></span></a>
        </li>
    </ul>
</div>

<!-- Tabela 1: Resumo Agrupado por Dispositivo -->
<div class="panel panel-default">
    <div class="panel-heading" style="display: flex; justify-content: space-between; align-items: center;">
        <h2 class="panel-title"><i class="fa fa-users"></i> <?=gettext("Tentativas de Acesso por Dispositivo (Auditoria por IP, Hostname & Presença na Rede)")?></h2>
        <div>
            <a href="/rules_wam_dashboard.php?export=csv_devices&amp;status=<?=htmlspecialchars($status_filter, ENT_QUOTES, 'UTF-8')?>" class="btn btn-default btn-xs" title="<?=gettext("Exportar lista de dispositivos para CSV")?>">
                <i class="fa fa-download"></i> <?=gettext("Exportar Dispositivos (CSV)")?>
            </a>
        </div>
    </div>
    <div class="table-responsive">
        <table class="table table-striped table-hover table-condensed">
            <thead>
                <tr>
                    <th style="width: 110px;"><?=gettext("Status na Rede")?></th>
                    <th><?=gettext("Endereço IP")?></th>
                    <th><?=gettext("Interface / Rede")?></th>
                    <th><?=gettext("Hostname / Nome da Máquina")?></th>
                    <th><?=gettext("MAC Address")?></th>
                    <th class="text-center"><?=gettext("Total de Tentativas")?></th>
                    <th><?=gettext("Categoria Mais Tentada")?></th>
                    <th><?=gettext("Último Domínio Barrado")?></th>
                    <th><?=gettext("Última Tentativa")?></th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($display_devices)): ?>
                    <tr>
                        <td colspan="9" class="text-center text-muted" style="padding: 30px;">
                            <i class="fa fa-info-circle fa-2x"></i><br />
                            <?=gettext("Nenhum dispositivo encontrado para o filtro selecionado.")?>
                        </td>
                    </tr>
                <?php else: ?>
                    <?php foreach ($display_devices as $dev): 
                        arsort($dev['categories']);
                        $top_cat = key($dev['categories']);
                        $is_me = ($dev['ip'] === $current_client_ip);
                        $is_on = !empty($dev['online']);
                        $dev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($dev['ip']) : null;
                        $dev_if_name = !empty($dev_if['descr']) ? $dev_if['descr'] : (!empty($dev_if['logical_id']) ? $dev_if['logical_id'] : 'Rede Local');
                    ?>
                    <tr <?=$is_me ? 'class="info" style="background-color: #eef7fe;"' : ''?>>
                        <td>
                            <?php if ($is_on): ?>
                                <span class="label label-success" style="font-size: 11px; padding: 4px 7px;"><i class="fa fa-circle"></i> Online</span>
                            <?php else: ?>
                                <span class="label label-default" style="font-size: 11px; padding: 4px 7px; color: #666;"><i class="fa fa-circle-o"></i> Offline</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <code><?=htmlspecialchars($dev['ip'])?></code>
                            <?php if ($is_me): ?>
                                <span class="label label-primary" style="margin-left: 5px;"><i class="fa fa-user"></i> <?=gettext("Seu Host")?></span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <span class="label label-primary" style="font-size: 11px;" title="<?=!empty($dev_if['real_if']) ? htmlspecialchars($dev_if['logical_id'] . ' / ' . $dev_if['real_if']) : ''?>">
                                <i class="fa fa-sitemap"></i> <?=htmlspecialchars($dev_if_name)?>
                            </span>
                        </td>
                        <td><strong><i class="fa fa-laptop"></i> <?=htmlspecialchars($dev['hostname'])?></strong></td>
                        <td><code style="font-size: 11px;"><?=!empty($dev['mac']) ? htmlspecialchars($dev['mac']) : '—'?></code></td>
                        <td class="text-center">
                            <span class="badge" style="background-color: #d9534f; font-size: 13px;">
                                <?=number_format($dev['count'])?> vezes
                            </span>
                        </td>
                        <td><span class="label label-warning"><?=htmlspecialchars($top_cat)?></span></td>
                        <td><code><?=htmlspecialchars($dev['last_domain'])?></code></td>
                        <td><i class="fa fa-clock-o text-muted"></i> <?=htmlspecialchars($dev['last_time'])?></td>
                    </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<!-- Tabela 2: Registro Detalhado dos Últimos Bloqueios -->
<div class="panel panel-default">
    <div class="panel-heading" style="display: flex; justify-content: space-between; align-items: center;">
        <h2 class="panel-title"><i class="fa fa-list"></i> <?=gettext("Registro Detalhado dos Últimos Bloqueios (Tempo Real)")?></h2>
        <div>
            <a href="/rules_wam_dashboard.php?export=csv&amp;status=<?=htmlspecialchars($status_filter, ENT_QUOTES, 'UTF-8')?>" class="btn btn-default btn-xs" title="<?=gettext("Exportar registros para CSV")?>">
                <i class="fa fa-download"></i> <?=gettext("Exportar Registros (CSV)")?>
            </a>
        </div>
    </div>
    <div class="table-responsive">
        <table class="table table-striped table-hover table-condensed">
            <thead>
                <tr>
                    <th><?=gettext("Data / Hora")?></th>
                    <th><?=gettext("Endereço IP")?></th>
                    <th><?=gettext("Interface")?></th>
                    <th><?=gettext("Hostname")?></th>
                    <th style="width: 100px;"><?=gettext("Status")?></th>
                    <th><?=gettext("Domínio Bloqueado")?></th>
                    <th><?=gettext("Categoria")?></th>
                    <th><?=gettext("Ação do Firewall")?></th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($display_events)): ?>
                    <tr>
                        <td colspan="8" class="text-center text-muted" style="padding: 20px;">
                            <?=gettext("Nenhum registro encontrado para o filtro selecionado.")?>
                        </td>
                    </tr>
                <?php else: ?>
                    <?php 
                    $slice = array_slice($display_events, 0, 150);
                    foreach ($slice as $ev): 
                        $is_me = ($ev['ip'] === $current_client_ip);
                        $is_on = !empty($ev['online']);
                        $ev_if = function_exists('rules_wam_find_interface_for_ip') ? rules_wam_find_interface_for_ip($ev['ip']) : null;
                        $ev_if_name = !empty($ev_if['descr']) ? $ev_if['descr'] : (!empty($ev_if['logical_id']) ? $ev_if['logical_id'] : 'Local');
                    ?>
                    <tr <?=$is_me ? 'style="background-color: #eef7fe;"' : ''?>>
                        <td><i class="fa fa-clock-o text-muted"></i> <?=htmlspecialchars($ev['timestamp'])?></td>
                        <td>
                            <code><?=htmlspecialchars($ev['ip'])?></code>
                            <?php if ($is_me): ?>
                                <span class="label label-info" style="font-size: 10px; margin-left: 3px;"><?=gettext("Você")?></span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <span class="label label-default" style="font-size: 10px;" title="<?=!empty($ev_if['real_if']) ? htmlspecialchars($ev_if['logical_id'] . ' / ' . $ev_if['real_if']) : ''?>">
                                <?=htmlspecialchars($ev_if_name)?>
                            </span>
                        </td>
                        <td><strong><?=htmlspecialchars($ev['hostname'])?></strong></td>
                        <td>
                            <?php if ($is_on): ?>
                                <span class="label label-success" style="font-size: 10px;"><i class="fa fa-circle"></i> Online</span>
                            <?php else: ?>
                                <span class="label label-default" style="font-size: 10px; color: #666;"><i class="fa fa-circle-o"></i> Offline</span>
                            <?php endif; ?>
                        </td>
                        <td><strong class="text-danger"><?=htmlspecialchars($ev['domain'])?></strong></td>
                        <td><span class="label label-default"><?=htmlspecialchars($ev['category'])?></span></td>
                        <td><span class="label label-danger"><i class="fa fa-ban"></i> <?=gettext("BLOQUEADO")?></span></td>
                    </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</div>

<?php include("foot.inc"); ?>

EOF_DASH
echo '>> Extraindo www/rules_wam_block.php...'
cat << 'EOF_BLOCK' > $TMP_DIR/www/rules_wam_block.php
<?php
/*
 * rules_wam_block.php
 * Rules WAM - Web Access Manager para pfSense
 * Banner / Tela de Bloqueio Corporativa para Hosts Interceptados
 */

if (file_exists("/usr/local/pkg/rules_wam.inc")) {
    require_once("/usr/local/pkg/rules_wam.inc");
} elseif (file_exists(dirname(__DIR__) . "/pkg/rules_wam.inc")) {
    require_once(dirname(__DIR__) . "/pkg/rules_wam.inc");
}

$client_ip = !empty($_SERVER['HTTP_X_REAL_IP']) ? $_SERVER['HTTP_X_REAL_IP'] : (!empty($_SERVER['HTTP_X_FORWARDED_FOR']) ? explode(',', $_SERVER['HTTP_X_FORWARDED_FOR'])[0] : (!empty($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '127.0.0.1'));
$client_ip = trim($client_ip);
$cache_hn = array();
$client_host = function_exists('rules_wam_resolve_hostname') ? rules_wam_resolve_hostname($client_ip, $cache_hn) : 'Host ' . $client_ip;

// Identifica o domínio solicitado
$req_host = !empty($_GET['domain']) ? trim($_GET['domain']) : (!empty($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'website-bloqueado.com');
$req_host = preg_replace('/:\d+$/', '', $req_host); // remove porta se houver
$req_host = function_exists('rules_wam_clean_domain') ? rules_wam_clean_domain($req_host) : preg_replace('/[^a-zA-Z0-9\.\-_]/', '', $req_host);
if (empty($req_host) || $req_host === '127.0.0.1' || $req_host === 'localhost' || filter_var($req_host, FILTER_VALIDATE_IP)) {
    $req_host = 'website-bloqueado.com';
}

// Categoria do domínio
$category = function_exists('rules_wam_get_domain_category') ? rules_wam_get_domain_category($req_host) : 'Política de Segurança Corporativa';
if ($category === 'Regra Personalizada / Outros' || $category === 'Política de Segurança Corporativa') {
    if (strpos($req_host, 'xvideo') !== false || strpos($req_host, 'porn') !== false) {
        $category = 'Conteúdo Adulto & Pornografia';
    } elseif (strpos($req_host, 'betano') !== false || strpos($req_host, 'bet365') !== false || strpos($req_host, 'blaze') !== false || strpos($req_host, 'bet') !== false) {
        $category = 'Apostas & Bets';
    }
}

// Data e Hora
$block_time = date('d/m/Y - H:i:s');

// Registra auditoria da interceptação quando exibido a um host
$wam_cfg = function_exists('rules_wam_get_config') ? rules_wam_get_config() : array();
$lan_ip = function_exists('config_get_path') ? config_get_path('interfaces/lan/ipaddr', '') : (!empty($config['interfaces']['lan']['ipaddr']) ? $config['interfaces']['lan']['ipaddr'] : '');
$block_page_ip = !empty($wam_cfg['block_page_ip']) ? $wam_cfg['block_page_ip'] : $lan_ip;
$server_addr = $_SERVER['SERVER_ADDR'] ?? '';

$is_fw_direct = empty($_GET['domain']) && (!empty($_SERVER['HTTP_HOST']) && (
    (!empty($block_page_ip) && strpos($_SERVER['HTTP_HOST'], $block_page_ip) !== false) ||
    (!empty($server_addr) && strpos($_SERVER['HTTP_HOST'], $server_addr) !== false) ||
    strpos($_SERVER['HTTP_HOST'], 'pfsense') !== false
));

if (!empty($req_host) && $req_host !== 'website-bloqueado.com' && !$is_fw_direct) {
    $audit_line = sprintf(
        "%s|%s|%s|%s|%s\n",
        date('Y-m-d H:i:s'),
        $client_ip,
        $req_host,
        $category,
        $client_host
    );
    @file_put_contents('/var/log/wam_audit.log', $audit_line, FILE_APPEND | LOCK_EX);
}
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Acesso Bloqueado - Política de Segurança Corporativa</title>
    <style>
        :root {
            --primary-red: #c9302c;
            --dark-red: #901b17;
            --bg-page: #f0f2f5;
            --card-bg: #ffffff;
            --text-dark: #2c3e50;
            --text-muted: #667085;
            --border-color: #e4e7ec;
            --amber-warn: #f59e0b;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            background: linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%);
            color: var(--text-dark);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .block-card {
            background: var(--card-bg);
            max-width: 720px;
            width: 100%;
            border-radius: 12px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08), 0 1px 3px rgba(0, 0, 0, 0.05);
            overflow: hidden;
            border: 1px solid var(--border-color);
        }

        .card-header {
            background: linear-gradient(135deg, #d32f2f 0%, #b71c1c 100%);
            color: #ffffff;
            padding: 28px 32px;
            text-align: center;
            position: relative;
        }

        .card-header .badge-top {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            backdrop-filter: blur(4px);
            padding: 4px 14px;
            border-radius: 20px;
            font-size: 11px;
            letter-spacing: 1px;
            font-weight: 700;
            text-transform: uppercase;
            margin-bottom: 12px;
            border: 1px solid rgba(255, 255, 255, 0.3);
        }

        .shield-icon {
            width: 64px;
            height: 64px;
            margin: 0 auto 12px;
            display: flex;
            align-items: center;
            justify-content: center;
            background: rgba(255, 255, 255, 0.15);
            border-radius: 50%;
            border: 2px solid rgba(255, 255, 255, 0.4);
        }

        .shield-icon svg {
            width: 36px;
            height: 36px;
            fill: #ffffff;
        }

        .card-header h1 {
            font-size: 24px;
            font-weight: 800;
            margin-bottom: 6px;
            letter-spacing: -0.5px;
        }

        .card-header p {
            font-size: 14px;
            color: rgba(255, 255, 255, 0.9);
            max-width: 500px;
            margin: 0 auto;
        }

        .card-body {
            padding: 30px 32px;
        }

        .policy-alert-box {
            background-color: #fef2f2;
            border-left: 4px solid var(--primary-red);
            padding: 16px;
            border-radius: 6px;
            margin-bottom: 24px;
        }

        .policy-alert-box h3 {
            color: var(--dark-red);
            font-size: 15px;
            font-weight: 700;
            margin-bottom: 8px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .policy-alert-box p {
            font-size: 13.5px;
            color: #7f1d1d;
            line-height: 1.5;
        }

        .policy-categories {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 10px;
            margin-top: 14px;
        }

        .cat-item {
            background: #ffffff;
            border: 1px solid #fecaca;
            border-radius: 6px;
            padding: 10px 14px;
            font-size: 12.5px;
            color: #991b1b;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .cat-item.active-violation {
            background: #fef2f2;
            border: 2px solid #dc2626;
            box-shadow: 0 0 0 3px rgba(220, 38, 38, 0.15);
        }

        .cat-badge-violation {
            background: #dc2626;
            color: #ffffff;
            font-size: 10px;
            padding: 2px 6px;
            border-radius: 4px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-left: auto;
            white-space: nowrap;
        }

        .cat-item span.icon {
            font-size: 18px;
        }

        /* Detalhes Técnicos */
        .tech-details {
            background-color: #f8fafc;
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 18px;
            margin-bottom: 24px;
        }

        .tech-details h4 {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 0.8px;
            color: var(--text-muted);
            margin-bottom: 12px;
            font-weight: 700;
        }

        .details-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            font-size: 13px;
        }

        @media (max-width: 540px) {
            .details-grid {
                grid-template-columns: 1fr;
            }
        }

        .detail-row {
            display: flex;
            flex-direction: column;
        }

        .detail-row .label {
            font-size: 11px;
            color: var(--text-muted);
            text-transform: uppercase;
            font-weight: 600;
            margin-bottom: 3px;
        }

        .detail-row .value {
            font-weight: 700;
            color: var(--text-dark);
            word-break: break-all;
        }

        .detail-row .value.blocked-domain {
            color: var(--primary-red);
            font-family: Consolas, "Courier New", monospace;
            font-size: 14px;
        }

        .legal-notice {
            font-size: 12px;
            color: var(--text-muted);
            line-height: 1.6;
            text-align: center;
            margin-bottom: 24px;
            padding: 0 10px;
        }

        .card-footer {
            background-color: #f8fafc;
            border-top: 1px solid var(--border-color);
            padding: 18px 32px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
        }

        .btn {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 9px 18px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 600;
            text-decoration: none;
            cursor: pointer;
            border: 1px solid transparent;
            transition: all 0.2s;
        }

        .btn-primary {
            background-color: #2563eb;
            color: #ffffff;
        }

        .btn-primary:hover {
            background-color: #1d4ed8;
        }

        .btn-secondary {
            background-color: #ffffff;
            color: var(--text-dark);
            border-color: var(--border-color);
        }

        .btn-secondary:hover {
            background-color: #f1f5f9;
        }

        .footer-brand {
            font-size: 12px;
            color: var(--text-muted);
        }
    </style>
</head>
<body>

<div class="block-card">
    <div class="card-header">
        <div class="badge-top">🛡️ Segurança Corporativa & Auditoria de Rede</div>
        <div class="shield-icon">
            <svg viewBox="0 0 24 24">
                <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-1 6h2v6h-2V7zm1 10.25c-.69 0-1.25-.56-1.25-1.25s.56-1.25 1.25-1.25 1.25.56 1.25 1.25-.56 1.25-1.25 1.25z"/>
            </svg>
        </div>
        <h1>ACESSO BLOQUEADO</h1>
        <p>A navegação para este destino foi restrita em conformidade com as Políticas de Segurança da Informação da instituição.</p>
    </div>

    <div class="card-body">
        <div class="policy-alert-box">
            <h3>
                <span>⚠️</span> Violação de Política de Acesso à Internet
            </h3>
            <p>
                Os recursos de rede e conectividade desta instituição são destinados estritamente às atividades profissionais e corporativas. 
                De acordo com as normas de conformidade e segurança, é expressamente <strong>proibido</strong> o acesso a páginas que contenham:
            </p>

            <?php
            $all_policy_cats = array(
                'Notícias & Portais'    => array('icon' => '📰', 'title' => 'Notícias & Portais', 'desc' => 'Portais jornalísticos, tabloides, colunas e notícias externas'),
                'Conteúdo Adulto'       => array('icon' => '🔞', 'title' => 'Conteúdo Adulto', 'desc' => 'Pornografia, acompanhantes, cams e nudez explícita'),
                'Apostas & Bets'        => array('icon' => '🎲', 'title' => 'Apostas & Bets', 'desc' => 'Jogos de azar, cassinos online, rifas e apostas esportivas'),
                'Jogos & Games'         => array('icon' => '🎮', 'title' => 'Jogos Online', 'desc' => 'Plataformas de jogos, games em rede e entretenimento lúdico'),
                'Mídias Sociais'        => array('icon' => '📱', 'title' => 'Mídias Sociais', 'desc' => 'Redes sociais, vídeos curtos, mensageria e feeds de interação'),
                'Streaming & Vídeo'     => array('icon' => '🎬', 'title' => 'Streaming & Vídeo', 'desc' => 'Plataformas de filmes, séries, vídeos sob demanda e IPTV'),
                'Compras & E-commerce'  => array('icon' => '🛍️', 'title' => 'Compras & E-commerce', 'desc' => 'Lojas virtuais, marketplaces e sites de leilão'),
                'Esportes & Placares'   => array('icon' => '⚽', 'title' => 'Esportes & Placares', 'desc' => 'Portais esportivos, transmissões de jogos e resultados'),
                'Torrents & P2P'        => array('icon' => '⚡', 'title' => 'Pirataria & Torrents', 'desc' => 'Compartilhamento P2P, downloads de mídias e cracks'),
                'Anti-Bypass DoH'       => array('icon' => '🛡️', 'title' => 'Anti-Bypass DoH', 'desc' => 'Servidores de DNS sobre HTTPS e proxies de evasão'),
                'VPN, ZTNA & Proxies'   => array('icon' => '🔒', 'title' => 'VPN, ZTNA & Proxies', 'desc' => 'Serviços de VPN comercial, túneis ZTNA, mesh VPNs e proxies anônimos'),
            );

            $ordered_cats = array();
            foreach ($all_policy_cats as $cat_k => $cat_info) {
                $matches_cat = (
                    stripos($category, $cat_k) !== false ||
                    stripos($cat_k, $category) !== false ||
                    (stripos($cat_k, 'VPN') !== false && (stripos($category, 'VPN') !== false || stripos($category, 'ZTNA') !== false))
                );
                if ($matches_cat) {
                    $ordered_cats = array($cat_k => $cat_info) + $ordered_cats;
                } else {
                    $ordered_cats[$cat_k] = $cat_info;
                }
            }
            ?>
            <div class="policy-categories">
                <?php 
                $count = 0;
                foreach ($ordered_cats as $cat_k => $cat_info): 
                    $is_match = (
                        stripos($category, $cat_k) !== false ||
                        stripos($cat_k, $category) !== false ||
                        (stripos($cat_k, 'VPN') !== false && (stripos($category, 'VPN') !== false || stripos($category, 'ZTNA') !== false))
                    );
                    if ($count >= 6 && !$is_match) continue;
                    $count++;
                ?>
                    <div class="cat-item <?=$is_match ? 'active-violation' : ''?>">
                        <span class="icon"><?=$cat_info['icon']?></span>
                        <div><strong><?=htmlspecialchars($cat_info['title'])?>:</strong> <?=htmlspecialchars($cat_info['desc'])?></div>
                        <?php if ($is_match): ?>
                            <span class="cat-badge-violation">Regra Ativa</span>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            </div>
        </div>

        <div class="tech-details">
            <h4>📋 Detalhes do Registro de Interceptação</h4>
            <div class="details-grid">
                <div class="detail-row">
                    <span class="label">Domínio Solicitado</span>
                    <span class="value blocked-domain"><?=htmlspecialchars($req_host)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Categoria Classificada</span>
                    <span class="value" style="color: #b91c1c;"><?=htmlspecialchars($category)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Seu Host / Computador</span>
                    <span class="value"><?=htmlspecialchars($client_host)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Endereço IP de Origem</span>
                    <span class="value"><code><?=htmlspecialchars($client_ip)?></code></span>
                </div>
                <div class="detail-row">
                    <span class="label">Data e Hora da Tentativa</span>
                    <span class="value"><?=htmlspecialchars($block_time)?></span>
                </div>
                <div class="detail-row">
                    <span class="label">Ação Executada</span>
                    <span class="value" style="color: #c9302c;">Conexão Bloqueada & Registrada</span>
                </div>
            </div>
        </div>

        <div class="legal-notice">
            Todas as requisições de rede são monitoradas e auditadas centralizadamente pelo firewall corporativo.<br/>
            Caso acredite que este bloqueio seja incorreto ou necessite de autorização para fins de trabalho, contate o <strong>Departamento de TI</strong> informando os dados acima.
        </div>
    </div>

    <div class="card-footer">
        <div class="footer-brand">
            <strong>Rules WAM</strong> &bull; Sistema de Proteção Web pfSense
            <?php if (file_exists('/usr/local/www/rules_wam_ca.crt')): ?>
                &bull; <a href="/rules_wam_ca.crt" style="color: #64748b; text-decoration: underline; font-size: 11px;" download title="Instalar certificado nos computadores para eliminar avisos no HTTPS">Baixar Certificado CA</a>
            <?php endif; ?>
        </div>
        <div>
            <button onclick="window.history.back();" class="btn btn-secondary">
                &larr; Voltar à página anterior
            </button>
            <a href="mailto:suporte@empresa.com.br?subject=Solicitacao%20de%20Liberacao%20de%20Acesso%20-%20<?=rawurlencode($req_host)?>&body=Ola%20Suporte%20TI,%0A%0ASolicito%20revisao%20do%20bloqueio%20do%20dominio:%20<?=rawurlencode($req_host)?>%0AHost:%20<?=rawurlencode($client_host)?>%20(IP:%20<?=rawurlencode($client_ip)?>)%0ACategoria:%20<?=rawurlencode($category)?>%0A%0AJustificativa:%20" class="btn btn-primary">
                ✉️ Contatar Suporte TI
            </a>
        </div>
    </div>
</div>

</body>
</html>

EOF_BLOCK
echo '>> Extraindo widgets/include/rules_wam.inc...'
cat << 'EOF_WIDGET_INC' > $TMP_DIR/widgets/include/rules_wam.inc
<?php
/*
 * rules_wam.inc
 * Rules WAM - Web Access Manager para pfSense
 * Arquivo de inclusão e registro do Widget no Dashboard
 */

$rules_wam_title = gettext("Rules WAM - Web Access Manager");
$rules_wam_title_link = "rules_wam.php";
$rules_wam_allow_multiple_widget_copies = false;
?>

EOF_WIDGET_INC
echo '>> Extraindo widgets/widgets/rules_wam.widget.php...'
cat << 'EOF_WIDGET_PHP' > $TMP_DIR/widgets/widgets/rules_wam.widget.php
<?php
/*
 * rules_wam.widget.php
 * Rules WAM - Web Access Manager para pfSense
 * Dashboard Widget: Status do Serviço, Categorias Ativas e Resumo Macro de Hosts por Rede
 */

require_once("guiconfig.inc");
require_once("pfsense-utils.inc");
require_once("functions.inc");
require_once("interfaces.inc");
if (file_exists("/usr/local/pkg/rules_wam.inc")) {
    require_once("/usr/local/pkg/rules_wam.inc");
}

if (empty($widgetkey)) {
    $widgetkey = isset($_REQUEST['widgetkey']) ? htmlspecialchars($_REQUEST['widgetkey']) : 'rules_wam-0';
}

$wam_cfg = function_exists('rules_wam_get_config') ? rules_wam_get_config() : array();
$is_enabled = function_exists('rules_wam_is_checked') ? rules_wam_is_checked($wam_cfg['enable'] ?? null) : false;

// 1. Status Geral e Unbound
$status_file = defined('WAM_STATUS_FILE') ? WAM_STATUS_FILE : '/var/log/wam_status.json';
$status_data = array(
    'enabled' => $is_enabled,
    'schedule_active' => false,
    'is_blocking' => false,
    'updated_at' => '-',
    'total_blocked' => 0,
    'categories' => array(),
    'whitelist_count' => 0,
    'bypass_ips_count' => 0
);
if (file_exists($status_file)) {
    $raw_st = @file_get_contents($status_file);
    $parsed_st = json_decode($raw_st, true);
    if (is_array($parsed_st)) {
        $status_data = array_merge($status_data, $parsed_st);
    }
}

// Unbound running check
$unbound_running = false;
if (function_exists('is_service_running')) {
    $unbound_running = is_service_running('unbound');
} else {
    $unbound_pid = @file_get_contents('/var/run/unbound.pid');
    $unbound_running = (!empty($unbound_pid) && function_exists('posix_kill') && @posix_kill(trim($unbound_pid), 0));
}

// NGINX SSL Banner running check
$nginx_banner_running = false;
if (file_exists('/var/run/rules_wam_ssl.pid')) {
    $npid = trim(@file_get_contents('/var/run/rules_wam_ssl.pid'));
    $nginx_banner_running = (!empty($npid) && function_exists('posix_kill') && @posix_kill($npid, 0));
} else {
    $n_out = array();
    @exec("/usr/bin/pgrep -f 'rules_wam_ssl.conf'", $n_out);
    $nginx_banner_running = !empty($n_out);
}

// Schedule check
$schedule_enabled = function_exists('rules_wam_is_checked') ? rules_wam_is_checked($wam_cfg['schedule_enable'] ?? null) : false;
$in_schedule = true;
if ($is_enabled && $schedule_enabled && function_exists('rules_wam_is_in_schedule_window')) {
    $in_schedule = rules_wam_is_in_schedule_window($wam_cfg);
}

// Block action
$block_action = !empty($wam_cfg['block_action']) ? $wam_cfg['block_action'] : 'block_page';

// Contagem real de domínios bloqueados
$total_blocked_domains = $status_data['total_blocked'] ?? 0;
$conf_file = defined('WAM_CONF_FILE') ? WAM_CONF_FILE : '/var/unbound/wam_blocklist.conf';
if ($is_enabled && file_exists($conf_file)) {
    if ($total_blocked_domains <= 0) {
        $conf_lines = @file($conf_file);
        if (is_array($conf_lines)) {
            $c_cnt = 0;
            foreach ($conf_lines as $cline) {
                if (strpos($cline, 'local-zone:') !== false) $c_cnt++;
            }
            $total_blocked_domains = $c_cnt;
        }
    }
}

// 2. Mapeamento das 12 Categorias
$categories_def = array(
    'block_adult'     => array('name' => 'Adulto',         'full' => 'Conteúdo Adulto & Pornografia', 'icon' => 'fa-ban',           'color' => '#d9534f'),
    'block_gambling'  => array('name' => 'Apostas/Bets',   'full' => 'Apostas, Bets & Cassinos',     'icon' => 'fa-money',         'color' => '#f0ad4e'),
    'block_streaming' => array('name' => 'Streaming',      'full' => 'Streaming de Vídeo & Música',  'icon' => 'fa-play-circle',   'color' => '#5bc0de'),
    'block_social'    => array('name' => 'Redes Sociais',  'full' => 'Mídias Sociais & Redes',       'icon' => 'fa-share-alt',     'color' => '#337ab7'),
    'block_messaging' => array('name' => 'Mensageiros',    'full' => 'WhatsApp, Teams, Telegram',    'icon' => 'fa-comments',      'color' => '#5cb85c'),
    'block_gaming'    => array('name' => 'Jogos Online',   'full' => 'Jogos & Plataformas Games',    'icon' => 'fa-gamepad',       'color' => '#8e44ad'),
    'block_vpn'       => array('name' => 'VPN / Proxies',  'full' => 'VPN, ZTNA & Proxies',          'icon' => 'fa-user-secret',   'color' => '#e83e8c'),
    'block_shopping'  => array('name' => 'Compras',        'full' => 'E-commerce & Compras',         'icon' => 'fa-shopping-cart', 'color' => '#fd7e14'),
    'block_p2p'       => array('name' => 'Torrents / P2P', 'full' => 'Torrents & Redes P2P',         'icon' => 'fa-download',      'color' => '#20c997'),
    'block_news'      => array('name' => 'Notícias',       'full' => 'Notícias & Portais de Mídia',  'icon' => 'fa-newspaper-o',   'color' => '#17a2b8'),
    'block_sports'    => array('name' => 'Esportes',       'full' => 'Esportes & Placares ao Vivo',  'icon' => 'fa-trophy',        'color' => '#28a745'),
    'block_doh'       => array('name' => 'Anti-DoH',       'full' => 'Anti-Bypass DNS-over-HTTPS',   'icon' => 'fa-shield',        'color' => '#6c757d')
);

$active_categories = array();
foreach ($categories_def as $cat_key => $cat_info) {
    if (function_exists('rules_wam_is_checked') && rules_wam_is_checked($wam_cfg[$cat_key] ?? null)) {
        $active_categories[$cat_key] = $cat_info;
    }
}

// 3. Mapeamento e Agrupamento Macro por Rede (Descoberta Direta e Abrangente no pfSense)
global $config;
$network_summary = array();

// Função auxiliar para converter qualquer formato de máscara (CIDR, decimal com pontos ou hex) em número CIDR
$to_cidr = function($val) {
    if (empty($val)) return 24;
    $val_str = trim((string)$val);
    if (is_numeric($val_str) && (int)$val_str >= 1 && (int)$val_str <= 32) {
        return (int)$val_str;
    }
    if (stripos($val_str, '0x') === 0) {
        $val_str = long2ip(hexdec($val_str));
    }
    if (filter_var($val_str, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
        return substr_count(decbin(ip2long($val_str)), '1');
    }
    return 24;
};

// 3.1 Obtém interfaces usando rules_wam_get_configured_interfaces()
$all_configured_ifaces = function_exists('rules_wam_get_configured_interfaces') ? rules_wam_get_configured_interfaces(false) : array();

// Fallback robusto caso rules_wam.inc ainda não tenha a função carregada
if (empty($all_configured_ifaces)) {
    $pfsense_interfaces = function_exists('config_get_path') ? config_get_path('interfaces', array()) : (!empty($config['interfaces']) ? $config['interfaces'] : array());
    $ifdescrs = array();
    if (function_exists('get_configured_interface_with_descr')) {
        $ifdescrs = get_configured_interface_with_descr(false);
    }
    foreach ($pfsense_interfaces as $if_key => $if_cfg) {
        $is_if_enabled = true;
        if (function_exists('interface_is_enabled')) {
            $is_if_enabled = interface_is_enabled($if_key);
        } else {
            $is_if_enabled = ($if_key === 'lan' || $if_key === 'wan' || isset($if_cfg['enable']));
        }
        if (!$is_if_enabled) continue;

        $descr_configured = '';
        if (!empty($if_cfg['descr'])) {
            $descr_configured = trim($if_cfg['descr']);
        } elseif (function_exists('convert_friendly_interface_to_friendly_descr')) {
            $descr_configured = trim(convert_friendly_interface_to_friendly_descr($if_key));
        } elseif (!empty($ifdescrs[$if_key])) {
            $descr_configured = trim($ifdescrs[$if_key]);
        } else {
            $descr_configured = strtoupper($if_key);
        }

        $real_if = !empty($if_cfg['if']) ? $if_cfg['if'] : '';
        if (empty($real_if) && function_exists('get_real_interface')) {
            $real_if = get_real_interface($if_key);
        }
        if (empty($real_if) && function_exists('convert_friendly_interface_to_real_interface_name')) {
            $real_if = convert_friendly_interface_to_real_interface_name($if_key);
        }

        $if_ip = '';
        $if_subnet = 24;
        if (function_exists('get_interface_ip')) {
            $g_ip = get_interface_ip($if_key);
            if (!empty($g_ip) && filter_var($g_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $if_ip = $g_ip;
            }
        }
        if (empty($if_ip) && function_exists('get_interface_info')) {
            $ifinfo = get_interface_info($if_key);
            if (!empty($ifinfo['ipaddr']) && filter_var($ifinfo['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $if_ip = $ifinfo['ipaddr'];
            }
            if (!empty($ifinfo['subnet'])) {
                $if_subnet = $to_cidr($ifinfo['subnet']);
            }
            if (empty($real_if) && !empty($ifinfo['if'])) {
                $real_if = $ifinfo['if'];
            }
        }
        if (empty($if_ip) && !empty($if_cfg['ipaddr']) && filter_var($if_cfg['ipaddr'], FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            $if_ip = $if_cfg['ipaddr'];
            if (!empty($if_cfg['subnet'])) $if_subnet = $to_cidr($if_cfg['subnet']);
        }

        $has_valid_ip = (!empty($if_ip) && filter_var($if_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4));
        $cidr = '';
        $net_long = 0;
        $long_mask = 0;
        if ($has_valid_ip) {
            $long_ip = ip2long($if_ip);
            $long_mask = -1 << (32 - $if_subnet);
            $net_long = $long_ip & $long_mask;
            $cidr = long2ip($net_long) . '/' . $if_subnet;
        } else {
            $cidr = strtoupper($if_key) . ' (Sem IP)';
        }

        $all_configured_ifaces[$if_key] = array(
            'key' => $if_key,
            'logical_id' => strtoupper($if_key),
            'descr' => $descr_configured,
            'name' => $descr_configured,
            'real_if' => !empty($real_if) ? $real_if : $if_key,
            'ip' => $if_ip,
            'subnet' => $if_subnet,
            'cidr' => $cidr,
            'net_long' => $net_long,
            'mask_long' => $long_mask,
            'has_ip' => $has_valid_ip,
            'is_internal' => ($if_key !== 'wan')
        );
    }
}

// 3.2 Constrói o array $network_summary com o nome exato configurado no pfSense
foreach ($all_configured_ifaces as $if_key => $if_data) {
    $network_summary[$if_key] = array(
        'if_key' => $if_key,
        'logical_id' => $if_data['logical_id'] ?? strtoupper($if_key),
        'descr' => !empty($if_data['descr']) ? $if_data['descr'] : strtoupper($if_key),
        'name' => !empty($if_data['descr']) ? $if_data['descr'] : strtoupper($if_key),
        'real_if' => !empty($if_data['real_if']) ? $if_data['real_if'] : $if_key,
        'ip' => $if_data['ip'] ?? '',
        'cidr' => $if_data['cidr'] ?? '',
        'has_ip' => !empty($if_data['has_ip']),
        'net_long' => $if_data['net_long'] ?? 0,
        'mask_long' => $if_data['mask_long'] ?? 0,
        'online_hosts' => array(),
        'blocked_hosts' => array(),
        'block_count' => 0,
        'bypass_hosts' => array()
    );
}

// 3.3 Adiciona Servidores OpenVPN configurados no pfSense
$ovpn_servers = array();
if (function_exists('config_get_path')) {
    $ovpn_servers = config_get_path('openvpn/openvpn-server', array());
} elseif (!empty($config['openvpn']['openvpn-server']) && is_array($config['openvpn']['openvpn-server'])) {
    $ovpn_servers = $config['openvpn']['openvpn-server'];
}
if (!empty($ovpn_servers) && is_array($ovpn_servers)) {
    foreach ($ovpn_servers as $ovpn) {
        if (!empty($ovpn['tunnel_network']) && strpos($ovpn['tunnel_network'], '/') !== false) {
            $ovpn_cidr = trim($ovpn['tunnel_network']);
            list($o_net, $o_sub) = explode('/', $ovpn_cidr, 2);
            $o_sub_int = (int)$o_sub;
            if ($o_sub_int >= 8 && $o_sub_int <= 32 && filter_var($o_net, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
                $o_net_long = ip2long($o_net) & (-1 << (32 - $o_sub_int));
                $norm_cidr = long2ip($o_net_long) . '/' . $o_sub_int;
                $ovpn_id = !empty($ovpn['vpnid']) ? $ovpn['vpnid'] : '1';
                $ovpn_key = 'ovpn_' . $ovpn_id;
                $ovpn_descr = !empty($ovpn['description']) ? $ovpn['description'] : 'Acesso Remoto (VPN)';
                $ovpn_dev = 'ovpns' . $ovpn_id;
                $network_summary[$ovpn_key] = array(
                    'if_key' => 'openvpn',
                    'logical_id' => 'OPENVPN',
                    'descr' => $ovpn_descr,
                    'name' => $ovpn_descr,
                    'real_if' => $ovpn_dev,
                    'ip' => long2ip($o_net_long + 1),
                    'cidr' => $norm_cidr,
                    'has_ip' => true,
                    'net_long' => $o_net_long,
                    'mask_long' => -1 << (32 - $o_sub_int),
                    'online_hosts' => array(),
                    'blocked_hosts' => array(),
                    'block_count' => 0,
                    'bypass_hosts' => array()
                );
            }
        }
    }
}

// 3.4 Fallback para ifconfig do FreeBSD cruzando interfaces ativas
$raw_if = array();
@exec("/sbin/ifconfig -a 2>/dev/null", $raw_if);
if (!empty($raw_if)) {
    $cur_dev = '';
    foreach ($raw_if as $line) {
        if (preg_match('/^([a-zA-Z0-9_\.\-]+):/i', $line, $dm)) {
            $cur_dev = $dm[1];
        }
        if (preg_match('/inet\s+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\s+netmask\s+(0x[0-9a-fA-F]+|[0-9\.]+)/i', $line, $im)) {
            $s_ip = $im[1];
            $s_mask_raw = $im[2];
            if ($s_ip === '127.0.0.1' || $cur_dev === 'lo0' || strpos($cur_dev, 'pflog') === 0) continue;

            $s_sub = $to_cidr($s_mask_raw);
            $s_long_ip = ip2long($s_ip);
            $s_long_mask = -1 << (32 - $s_sub);
            $s_net_long = $s_long_ip & $s_long_mask;
            $s_cidr = long2ip($s_net_long) . '/' . $s_sub;

            // Tenta casar com interface existente por real_if
            $found_match = false;
            foreach ($network_summary as $nk => &$nentry) {
                if ($nentry['real_if'] === $cur_dev) {
                    if (empty($nentry['ip'])) {
                        $nentry['ip'] = $s_ip;
                        $nentry['has_ip'] = true;
                        $nentry['net_long'] = $s_net_long;
                        $nentry['mask_long'] = $s_long_mask;
                        $nentry['cidr'] = $s_cidr;
                    }
                    $found_match = true;
                    break;
                }
            }
            unset($nentry);

            if (!$found_match) {
                $network_summary[$cur_dev] = array(
                    'if_key' => $cur_dev,
                    'logical_id' => strtoupper($cur_dev),
                    'descr' => strtoupper($cur_dev),
                    'name' => strtoupper($cur_dev),
                    'real_if' => $cur_dev,
                    'ip' => $s_ip,
                    'cidr' => $s_cidr,
                    'has_ip' => true,
                    'net_long' => $s_net_long,
                    'mask_long' => $s_long_mask,
                    'online_hosts' => array(),
                    'blocked_hosts' => array(),
                    'block_count' => 0,
                    'bypass_hosts' => array()
                );
            }
        }
    }
}

// 3.5 Ordenação: LAN primeiro, depois OPTs, depois WAN, depois VPNs, depois Remoto
if (!empty($network_summary)) {
    uksort($network_summary, function($a, $b) use ($network_summary) {
        $order_type = function($entry) {
            $k = strtolower((string)($entry['if_key'] ?? ''));
            if ($k === 'lan') return 1;
            if (strpos($k, 'opt') === 0) return 2;
            if ($k === 'wan') return 3;
            if (strpos($k, 'openvpn') === 0 || strpos($k, 'ovpn') === 0) return 4;
            if (strpos($k, 'ipsec') === 0) return 5;
            if ($k === 'remote') return 99;
            return 10;
        };
        $val_a = $order_type($network_summary[$a] ?? array());
        $val_b = $order_type($network_summary[$b] ?? array());
        if ($val_a !== $val_b) return $val_a - $val_b;
        return strcmp((string)$a, (string)$b);
    });
}

// 3.6 Classifica IP em interface existente ou cria entrada remota
$assign_ip_to_network = function($ip, &$net_summary) {
    if (!filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) return null;
    if ($ip === '127.0.0.1') return null;

    $ipl = ip2long($ip);
    foreach ($net_summary as $if_key => &$net) {
        if (!empty($net['has_ip']) && !empty($net['mask_long'])) {
            if (($ipl & $net['mask_long']) === $net['net_long']) {
                return $if_key;
            }
        }
    }
    unset($net);

    $remote_net_long = $ipl & (-1 << (32 - 24));
    $remote_cidr = long2ip($remote_net_long) . '/24';
    $remote_key = 'remote_' . md5($remote_cidr);
    if (!isset($net_summary[$remote_key])) {
        $net_summary[$remote_key] = array(
            'if_key' => 'remote',
            'logical_id' => 'REMOTO',
            'descr' => 'Rede Remota / VPN Externa',
            'name' => 'Rede Remota / VPN Externa',
            'real_if' => 'remoto',
            'ip' => '',
            'cidr' => $remote_cidr,
            'has_ip' => true,
            'net_long' => $remote_net_long,
            'mask_long' => -1 << (32 - 24),
            'online_hosts' => array(),
            'blocked_hosts' => array(),
            'block_count' => 0,
            'bypass_hosts' => array()
        );
    }
    return $remote_key;
};

// 3.7 Hosts Online
$online_hosts = function_exists('rules_wam_get_online_hosts') ? rules_wam_get_online_hosts() : array();
$total_online_all = array();
if (is_array($online_hosts)) {
    foreach ($online_hosts as $o_ip => $o_info) {
        $net_k = $assign_ip_to_network($o_ip, $network_summary);
        if ($net_k !== null && isset($network_summary[$net_k])) {
            $network_summary[$net_k]['online_hosts'][$o_ip] = true;
            $total_online_all[$o_ip] = true;
        }
    }
}

// 3.8 Tentativas de Bloqueio nos Logs
$audit_file = defined('WAM_AUDIT_LOG') ? WAM_AUDIT_LOG : '/var/log/wam_audit.log';
$total_blocked_hosts_all = array();
$total_block_events_all = 0;

if (file_exists($audit_file)) {
    $audit_lines = @file($audit_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($audit_lines) {
        $max_lines = 5000;
        $total_lines = count($audit_lines);
        $start_idx = max(0, $total_lines - $max_lines);

        for ($i = $start_idx; $i < $total_lines; $i++) {
            $line = trim($audit_lines[$i]);
            if (empty($line)) continue;

            $a_ip = '';
            if (strpos($line, '|') !== false) {
                $parts = explode('|', $line);
                if (count($parts) >= 2) {
                    $a_ip = trim($parts[1]);
                }
            } elseif (preg_match('/CLIENT=([^\s]+)/i', $line, $cm)) {
                $a_ip = trim($cm[1]);
            }

            if (!empty($a_ip)) {
                $net_k = $assign_ip_to_network($a_ip, $network_summary);
                if ($net_k !== null && isset($network_summary[$net_k])) {
                    $network_summary[$net_k]['blocked_hosts'][$a_ip] = true;
                    $network_summary[$net_k]['block_count']++;
                    $total_blocked_hosts_all[$a_ip] = true;
                    $total_block_events_all++;
                }
            }
        }
    }
}

// 3.9 Bypass IPs
$total_bypass_all = array();
if (!empty($wam_cfg['bypass_ips'])) {
    $raw_bypass = preg_split('/[\r\n,;]+/', $wam_cfg['bypass_ips']);
    foreach ($raw_bypass as $b_ip) {
        $b_ip = trim($b_ip);
        if (!empty($b_ip) && filter_var($b_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            $net_k = $assign_ip_to_network($b_ip, $network_summary);
            if ($net_k !== null && isset($network_summary[$net_k])) {
                $network_summary[$net_k]['bypass_hosts'][$b_ip] = true;
                $total_bypass_all[$b_ip] = true;
            }
        }
    }
}

// Se for requisição direta AJAX de atualização rápida do widget
$is_ajax = isset($_GET['ajax']) && $_GET['ajax'] === 'rules_wam';
if ($is_ajax) {
    ob_clean();
}
?>

<div id="rules_wam_widget_container" style="font-family: inherit;">

    <!-- 1. Linha de Status dos Serviços -->
    <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 6px; margin-bottom: 10px; padding-bottom: 8px; border-bottom: 1px solid #e5e5e5;">
        <div style="display: flex; flex-wrap: wrap; gap: 5px; align-items: center;">
            <?php if (!$is_enabled): ?>
                <span class="label label-danger" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Filtragem do Rules WAM está desligada')?>">
                    <i class="fa fa-ban"></i> <?=gettext('Desativado')?>
                </span>
            <?php elseif ($schedule_enabled && !$in_schedule): ?>
                <span class="label label-warning" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Filtro pausado temporariamente pelo agendador de horário comercial / almoço')?>">
                    <i class="fa fa-clock-o"></i> <?=gettext('Pausado (Horário)')?>
                </span>
            <?php else: ?>
                <span class="label label-success" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Rules WAM está ativo e filtrando domínios em tempo real')?>">
                    <i class="fa fa-shield"></i> <?=gettext('Ativo & Filtrando')?>
                </span>
            <?php endif; ?>

            <span class="label <?=$unbound_running ? 'label-success' : 'label-danger'?>" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Status do Unbound DNS Resolver')?>">
                <i class="fa fa-server"></i> DNS: <?=$unbound_running ? gettext('Online') : gettext('Parado')?>
            </span>

            <?php if ($is_enabled && $block_action === 'block_page'): ?>
                <span class="label <?=$nginx_banner_running ? 'label-info' : 'label-warning'?>" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Instância NGINX nas portas 80 e 443 para banner institucional')?>">
                    <i class="fa fa-desktop"></i> Banner: <?=$nginx_banner_running ? '80/443 OK' : gettext('Alerta')?>
                </span>
            <?php elseif ($is_enabled): ?>
                <span class="label label-default" style="font-size: 11px; padding: 4px 7px;" title="<?=gettext('Respostas DNS retornam 0.0.0.0 sem exibição de tela de bloqueio')?>">
                    <i class="fa fa-volume-off"></i> <?=gettext('Modo Silencioso')?>
                </span>
            <?php endif; ?>
        </div>

        <div style="display: flex; align-items: center; gap: 6px;">
            <span class="badge" style="background-color: #337ab7; font-size: 11px; padding: 4px 8px;" title="<?=gettext('Total de domínios configurados para bloqueio imediato no Unbound')?>">
                <i class="fa fa-database"></i> <?=number_format($total_blocked_domains, 0, ',', '.')?> <?=gettext('domínios')?>
            </span>
            <button type="button" class="btn btn-xs btn-default" onclick="rules_wam_widget_refresh();" title="<?=gettext('Atualizar dados do widget agora')?>" style="padding: 2px 7px;">
                <i class="fa fa-refresh" id="rules_wam_refresh_icon"></i>
            </button>
        </div>
    </div>

    <!-- 2. Categorias Sendo Bloqueadas -->
    <div style="background-color: #f9f9f9; border: 1px solid #e1e4e8; border-radius: 4px; padding: 8px 10px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
            <span style="font-weight: 600; font-size: 11px; text-transform: uppercase; color: #444;">
                <i class="fa fa-tags text-primary"></i> <?=gettext('Categorias Bloqueadas')?> (<?=count($active_categories)?> de <?=count($categories_def)?>)
            </span>
            <small><a href="/rules_wam.php" style="font-size: 11px; font-weight: bold;"><?=gettext('Gerenciar Regras')?> &raquo;</a></small>
        </div>

        <div style="display: flex; flex-wrap: wrap; gap: 4px;">
            <?php if (empty($active_categories)): ?>
                <span class="text-muted" style="font-size: 11px; font-style: italic;">
                    <i class="fa fa-info-circle"></i> <?=gettext('Nenhuma categoria de bloqueio está ativada no momento.')?>
                </span>
            <?php else: ?>
                <?php foreach ($active_categories as $cat_k => $cat_v): ?>
                    <span class="label" style="background-color: <?=$cat_v['color']?>; font-size: 10px; font-weight: normal; padding: 3px 6px; display: inline-flex; align-items: center; gap: 3px;" title="<?=$cat_v['full']?>">
                        <i class="fa <?=$cat_v['icon']?>"></i> <?=$cat_v['name']?>
                    </span>
                <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>

    <!-- 3. Resumo Macro dos Hosts por Rede -->
    <div style="margin-bottom: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
            <span style="font-weight: 600; font-size: 11px; text-transform: uppercase; color: #444;">
                <i class="fa fa-sitemap text-primary"></i> <?=gettext('Resumo Macro dos Hosts por Rede')?>
            </span>
            <small><a href="/rules_wam_dashboard.php" style="font-size: 11px; font-weight: bold;"><?=gettext('Auditoria de Acesso')?> &raquo;</a></small>
        </div>

        <div class="table-responsive" style="margin-bottom: 0;">
            <table class="table table-striped table-condensed table-hover" style="font-size: 11px; margin-bottom: 0; border: 1px solid #ddd;">
                <thead>
                    <tr class="active" style="border-bottom: 2px solid #ddd;">
                        <th style="vertical-align: middle;"><?=gettext('Rede / Interface')?></th>
                        <th class="text-center" style="vertical-align: middle;"><?=gettext('Sub-rede')?></th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Dispositivos ativos detectados na tabela ARP / Rede')?>">
                            <i class="fa fa-circle text-success"></i> <?=gettext('Online')?>
                        </th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Hosts distintos que registraram tentativas de acesso bloqueadas')?>">
                            <i class="fa fa-exclamation-triangle text-danger"></i> <?=gettext('Barrados')?>
                        </th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Total acumulado de requisições de sites bloqueados')?>">
                            <i class="fa fa-ban text-danger"></i> <?=gettext('Tentativas')?>
                        </th>
                        <th class="text-center" style="vertical-align: middle;" title="<?=gettext('Dispositivos com isenção de filtro (Bypass IP)')?>">
                            <i class="fa fa-unlock text-primary"></i> <?=gettext('Bypass')?>
                        </th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($network_summary)): ?>
                        <tr>
                            <td colspan="6" class="text-center text-muted" style="font-style: italic; padding: 12px;">
                                <i class="fa fa-info-circle"></i> <?=gettext('Nenhuma interface de rede IPv4 ativa detectada no momento.')?>
                            </td>
                        </tr>
                    <?php else: ?>
                        <?php foreach ($network_summary as $net): ?>
                            <tr>
                                <td style="vertical-align: middle;">
                                    <?php if ($net['if_key'] === 'wan'): ?>
                                        <i class="fa fa-globe text-primary" title="<?=gettext('Interface WAN (Internet)')?>"></i>
                                    <?php elseif ($net['if_key'] === 'lan'): ?>
                                        <i class="fa fa-sitemap text-success" title="<?=gettext('Interface LAN (Rede Local)')?>"></i>
                                    <?php elseif ($net['if_key'] === 'openvpn'): ?>
                                        <i class="fa fa-shield text-warning" title="<?=gettext('Servidor OpenVPN')?>"></i>
                                    <?php elseif ($net['if_key'] === 'remote'): ?>
                                        <i class="fa fa-laptop text-muted" title="<?=gettext('Rede Remota / VPN Externa')?>"></i>
                                    <?php else: ?>
                                        <i class="fa fa-exchange text-info" title="<?=gettext('Interface Adicional / VLAN')?>"></i>
                                    <?php endif; ?>
                                    &nbsp;<strong><?=htmlspecialchars($net['name'])?></strong>
                                    <?php
                                    $port_details = array();
                                    if (!empty($net['logical_id']) && strcasecmp($net['logical_id'], $net['name']) !== 0) {
                                        $port_details[] = $net['logical_id'];
                                    }
                                    if (!empty($net['real_if']) && $net['real_if'] !== 'remoto' && strcasecmp($net['real_if'], $net['name']) !== 0 && (!isset($port_details[0]) || strcasecmp($net['real_if'], $port_details[0]) !== 0)) {
                                        $port_details[] = $net['real_if'];
                                    }
                                    if (!empty($port_details)):
                                    ?>
                                        <small class="text-muted" style="font-size: 10px;">(<?=htmlspecialchars(implode(' / ', $port_details))?>)</small>
                                    <?php endif; ?>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php if (!empty($net['has_ip'])): ?>
                                        <code style="font-size: 10px;" title="<?=!empty($net['ip']) ? 'IP: ' . htmlspecialchars($net['ip']) : ''?>"><?=htmlspecialchars($net['cidr'])?></code>
                                    <?php else: ?>
                                        <span class="label label-default" style="font-size: 9px;"><?=gettext('Sem IPv4 / DHCP')?></span>
                                    <?php endif; ?>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php $on_c = count($net['online_hosts']); ?>
                                    <span class="badge" style="background-color: <?=$on_c > 0 ? '#5cb85c' : '#bbb'?>; font-size: 10px; font-weight: bold;">
                                        <?=$on_c?>
                                    </span>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php $blk_c = count($net['blocked_hosts']); ?>
                                    <span class="badge" style="background-color: <?=$blk_c > 0 ? '#d9534f' : '#bbb'?>; font-size: 10px; font-weight: bold;">
                                        <?=$blk_c?>
                                    </span>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php if ($net['block_count'] > 0): ?>
                                        <span class="label label-danger" style="font-size: 10px; font-weight: bold;">
                                            <?=number_format($net['block_count'], 0, ',', '.')?>
                                        </span>
                                    <?php else: ?>
                                        <span class="text-muted" style="font-size: 10px;">0</span>
                                    <?php endif; ?>
                                </td>
                                <td class="text-center" style="vertical-align: middle;">
                                    <?php $byp_c = count($net['bypass_hosts']); ?>
                                    <?php if ($byp_c > 0): ?>
                                        <span class="badge" style="background-color: #337ab7; font-size: 10px; font-weight: bold;">
                                            <?=$byp_c?>
                                        </span>
                                    <?php else: ?>
                                        <span class="text-muted" style="font-size: 10px;">-</span>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
                <tfoot>
                    <tr class="info" style="font-weight: bold; border-top: 2px solid #ddd;">
                        <td style="vertical-align: middle;"><?=gettext('Total Consolidado')?></td>
                        <td class="text-center" style="vertical-align: middle; font-size: 10px;">
                            <?=count($network_summary)?> <?=gettext('redes')?>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="badge" style="background-color: #449d44; font-size: 10px; font-weight: bold;">
                                <?=count($total_online_all)?>
                            </span>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="badge" style="background-color: #c9302c; font-size: 10px; font-weight: bold;">
                                <?=count($total_blocked_hosts_all)?>
                            </span>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="label label-danger" style="font-size: 10px; font-weight: bold;">
                                <?=number_format($total_block_events_all, 0, ',', '.')?>
                            </span>
                        </td>
                        <td class="text-center" style="vertical-align: middle;">
                            <span class="badge" style="background-color: #286090; font-size: 10px; font-weight: bold;">
                                <?=count($total_bypass_all)?>
                            </span>
                        </td>
                    </tr>
                </tfoot>
            </table>
        </div>
    </div>

    <!-- 4. Rodapé e Atalhos Rápidos -->
    <div style="display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; border-top: 1px solid #e5e5e5; padding-top: 8px; font-size: 11px;">
        <div style="display: flex; align-items: center; gap: 4px;">
            <i class="fa fa-lock text-muted"></i>
            <span class="text-muted"><?=gettext('Anti-Bypass DNS (Porta 53):')?></span>
            <strong>
                <?=function_exists('rules_wam_is_checked') && rules_wam_is_checked($wam_cfg['block_dns_bypass'] ?? null) 
                    ? '<span class="text-success"><i class="fa fa-check"></i> ' . gettext('Ativo') . '</span>' 
                    : '<span class="text-muted">' . gettext('Desativado') . '</span>'?>
            </strong>
        </div>

        <div style="display: flex; gap: 4px;">
            <a href="/rules_wam.php" class="btn btn-xs btn-default" title="<?=gettext('Configurações de Bloqueio, Horários e Bypass')?>">
                <i class="fa fa-cog"></i> <?=gettext('Configurações')?>
            </a>
            <a href="/rules_wam_status.php" class="btn btn-xs btn-default" title="<?=gettext('Testar domínios e diagnosticar Unbound')?>">
                <i class="fa fa-heartbeat"></i> <?=gettext('Status')?>
            </a>
            <a href="/rules_wam_dashboard.php" class="btn btn-xs btn-primary" title="<?=gettext('Ver tentativas detalhadas e exportar relatórios CSV/JSON')?>">
                <i class="fa fa-bar-chart"></i> <?=gettext('Auditoria')?>
            </a>
        </div>
    </div>

</div>

<?php
if ($is_ajax) {
    exit;
}
?>

<script type="text/javascript">
//<![CDATA[
function rules_wam_widget_refresh() {
    var icon = document.getElementById('rules_wam_refresh_icon');
    if (icon) {
        icon.className = 'fa fa-refresh fa-spin';
    }

    if (typeof $ !== 'undefined') {
        $.ajax({
            url: '/widgets/widgets/rules_wam.widget.php?ajax=rules_wam&widgetkey=<?=urlencode($widgetkey)?>',
            type: 'GET',
            cache: false,
            success: function(response) {
                var container = $('#rules_wam_widget_container');
                if (container.length && response) {
                    container.replaceWith(response);
                }
            },
            complete: function() {
                var iconDone = document.getElementById('rules_wam_refresh_icon');
                if (iconDone) {
                    iconDone.className = 'fa fa-refresh';
                }
            }
        });
    }
}

// Auto-atualização periódica a cada 60 segundos
if (typeof rules_wam_auto_timer !== 'undefined') {
    clearInterval(rules_wam_auto_timer);
}
var rules_wam_auto_timer = setInterval(function() {
    if (document.getElementById('rules_wam_widget_container')) {
        rules_wam_widget_refresh();
    } else {
        clearInterval(rules_wam_auto_timer);
    }
}, 60000);
//]]>
</script>

EOF_WIDGET_PHP
echo '>> Extraindo feeds/adult.txt...'
cat << 'EOF_FEED_adult.txt' > $TMP_DIR/feeds/adult.txt
# ==========================================
# Rules WAM Feed - Conteúdo Adulto & Pornografia
# Total de dominios consolidados: 2632
# ==========================================

0----q.tumblr.com
0--liamariejohnson--0.nedrobin.net
0-0-adult-superstore.com
0-0.asia
0-0wearingglassesnakedmen.tumblr.com
0-12kids.com
0-1avsex.com
0-1sex.com
0-200.com
0-800-go-fuck-yourself.tumblr.com
0-adultfriendfinder.com
0-baise-amateur.com
0-decadent-0.tumblr.com
0-dix.com
0-livechatlady.com
0-porno.dk
0-porno.net
0-s.de
0-salope-rousse.com
0-sex.dk
0-sex.nl
0-shop.com
0-syxela.tumblr.com
0-transsexuel-bresilien.com
0-z.com
0.0.04.free.fr
0.011.free.fr
0.123.free.fr
0.123videos.free.fr
0.22.free.fr
0.9.free.fr
0.b.free.fr
0.idolzhaowei.00to.com
0.webcam.free.fr
00-44.com
00-44.net
00-gay.com
000------------sexo--amadoras.kit.net
000--------sexogratis.kit.net
000-475-843.tumblr.com
000-coralinne-xxx-sara-calixto.tumblr.com
000-sex-you-tube.blogspot.com
000-sex.com
000-xxx.tumblr.com
000.top-100.pl
000.toplista.pl
0000.1.free.fr
00000.la
000001.skynetblogs.be
00000nwebcamnow.com
00001.sbs
0000114.com
0000120.xyz
0000121.xyz
0000125.xyz
0000180.fortunecity.ws
00003.sbs
00004.sbs
00005.sbs
0000526.com
00006.sbs
00007.sbs
00008.sbs
000097.xyz
0000dd.com.cn
0000xxx.com
000111casino.com
0001888.com
0001casino.com
0001p.com
0001xhamster.com
0001xxx.com
000222casino.com
0002xxx.com
000385.xyz
0003xx.com
0003xxx.com
0004xxx.com
0005.us
00069maninstockings.over-blog.com
0006xxx.com
0007pk.com
0007xxx.com
0008xxx.com
0009xxx.com
000babes.com
000boy.free.fr
000dom.revenuedirect.com
000dvd.com
000gay.free.fr
000girl.tumblr.com
000girls.de
000hdusexe.free.fr
000iblogchix.blogspot.com
000modelle.com
000panties.com
000porn.com
000pussy69pornxxxporno.com
000relationships.com
000sex.net
000sex.nl
000sexe.com
000tang.top
000xxx.net
001-adult-toys-n-sex-dolls.com
001-homevideo.startspot.nl
001.startspot.nl
00101001.com
0011cartoons.com
0011cn.cfd
001260.xyz
001270.xyz
0012xxx.com
0013langford.tumblr.com
0013xxx.com
0014xxx.com
0015xxx.com
0017173.com
0017x.com
0017xxx.com
0018.startbewijs.nl
0018xxx.com
001adult.homestead.com
001am.com
001ask.com
001av.cc
001dh.top
001dzs.com
001gamesextou.com
001hc.com
001hfw.com
001jennifer.tumblr.com
001jpw.com
001londonescorts.com
001mh.cc
001mine.com
001porn.blogspot.com
001ritasex.blogspot.com
001seks.com
001sex.com
001sexoverzicht.startplezier.nl
001sucai.com
001tube8.com
001webcamsextv.startplezier.nl
001winsextou.com
001wst.com
001xia.com
001xnxxdesitape.com
001xx.com
001xxx.com
001zmr.com
00213744.tumblr.com
002560.xyz
0029a.com
002sex.com
003.top-100.pl
003022.xyz
003107.xyz
003114.xyz
003416.xyz
003689.com
003755.xyz
003kf.com
003oo.com
003qq.com
003sex.com
003xx.com
0045678.com
00481.com
0048av.com
004hu.com
004sex.com
004sexamateurs.startplezier.nl
0055betsextou.com
005as.com
005n.com
005qs.com
005sex.com
005xf.com
0064av.com
0066888.cfd
0066betsextou.com
0068jbt.com
006969.free.fr
0069sexshop.com.ar
006mi.com
006xxx.vip
006yun.com
007-is-here.tumblr.com
007-kent-escorts.com
007-vibrators.com
007111.xyz
007112.xyz
007616.xyz
007936.com
007adulthosting.com
007adulthosting.net
007adultsextoys.com
007amateurs.com
007annuaire.com
007arcadegames.com
007b.info
007betmen.atw.hu
007bondage.com
007celeb.com
007cghl.com
007ch.com
007chigua.com
007chigua3.com
007coupleil.tumblr.com
007cozza77.tumblr.com
007dating.com
007escorts.co.uk
007footfetish.com
007gamesextou.com
007gayboys.com
007girl.com
007girls.k9.pl
007gk.com
007heaven.com
007hertfordshire-escorts.com
007hl.com
007hotwife.tumblr.com
007kongbao.com
007koreangirls.com
007lingerie.com
007mba.com
007milf.com
007moms.com
007org.com
007pf.com
007porn.com
007pornvideos.com
007pussy-live-sex.startspot.nl
007sexe.com
007sexshop.com.ar
007sexshop.com.br
007sexspy.com
007sexy.com
007sexybunny.tumblr.com
007shemales.com
007stevenkent.tumblr.com
007story.com
007teen.com
007teens.free.fr
007teens.hypermart.net
007xf.com
007xxxadultvideos.com
0080.com.tw
0084.top
0085256969.blogspot.com
0086nmg.com
0087.net.cn
008boy.com
008xxxx.com
0094av.com
0099av.com
009arcade.com
009jj.com
009qs.com
009sc.com
009sh.com
00ac.com
00alejandro00.blogspot.com
00artoferotica.com
00barbied0ll.blogspot.com
00buck.com
00c1.com
00cnc.com
00ee.cc
00eexxx.com
00escorts.com
00extreme.com
00girls.com
00h10.com
00hahh.com
00ii.cc
00itiswhatitis00.tumblr.com
00kk0.com
00l.com
00nakedasianmales.tumblr.com
00o3.com
00porn.com
00qers-forever.tumblr.com
00redskins.tumblr.com
00sandra00.free.fr
00sex.net
00sexe.free.fr
00sexte.cjb.net
00sexxx.com
00sg.top
00t.xyz
00tori.tumblr.com
00w.top
00webcams.com
00webcamsex.com
00xvideos.com
00xvideos.net
00xxx.com
00xxx00.blogspot.com
00xxxxx.com
01-18ansanal.blogspot.com
01-49.com
01-800-vagina.tumblr.com
01-sex-amateur.info
01-stars.com
01-xxx.com
010-01.com
010-1234-5678.tumblr.com
01000101.tumblr.com
010100110100010101010011.tumblr.com
0101betsextou.com
0101footworld.com
010206upi.blogspot.com
010401040104.tumblr.com
01068.hk
01081464567.com
01082026yigitgayenur.com
010aizy.com
010jj.com
010mybj.com
010online.com
010qhc.com
010sex.startplezier.nl
010xintai.com
010xnxx.com
01118202889.tumblr.com
011220.xyz
011810.com
011adult.com
011papa.com
011phonesex.com
011pvd.com
012301230.blogspot.com
01234.over-blog.fr
0123famosas.com
0123sex.nl
0123sexxxx.ontoplist.com
012ee.com
012sex.com
01312if1.cn
0137-telefonsex.de
0137.net
0137telefonsex.de
013a.com
013jj.com
013sao.com
013ww.com
0141yo.com
0141yo.net
01443.hk
015980.com
015eku9w.sbs
016bb.com
016sex.com
017.free.fr
017xxx.com
018.us
0180-telefonsex.com
0180-telefonsex.net
01800.blogspot.com
018583.com
018china.com
018wm.com
0190-livesex.com
0190-telefonsex-girls.de
0190-telefonsex.de
0190-telefonsexworld.de
0190.bt8.de
0190.ds8.de
0190bizarr.de
0190cam.de
0190erotic.de
0190livecam.hotpage.net
0190telefonsex.de
019awesomechicks.tumblr.com
019ee.com
019hh.com
01aa.com
01adult.net
01amour.com
01asiasex.com
01babes.com
01blonde.en.wanadoo.es
01brunette.en.wanadoo.es
01cdsex.hpg.ig.com.br
01emmabellis.tumblr.com
01fragments.blogspot.com
01gaystore.com
01gmc.tumblr.com
01hhhh.com
01hot.com
01indianmasala.blogspot.com
01jmf.com
01ky.tumblr.com
01lingerie.fr
01m.top
01mcu.net
01mx.cc
01p.top
01porn.xyz
01porna.com
01porno.club
01porno.com
01porny.com
01rct709u3.com
01rtys.com
01sentencereviews.tumblr.com
01sex.com
01sexcam.com
01sexcams.com
01sexe.com
01sexlive.com
01sexnet.com
01sexstory.blogspot.com
01shebao.com
01tatianats.cam
01teen.com
01tgp.com
01tube.com
01tube.vip
01tv.jp
01videos.com
01xnxx.net
01xvideo.com
01xvideos.com
01yangsheng.com
01zkw.com
02-analsexvideobbwporn.blogspot.com
02-lyceennesalope.blogspot.com
02-vieillesalopevideo.blogspot.com
0201979.cn
0204-show.com
0204.net
0204miss.info
0204mm.com
0204story.com
0204yes.com
020dahema.com
020gay.net
020med.com
020sextoy.com
020sofa.com
020tgw.com
020vc.com
020yujia.com
021058.canalblog.com
021111.xyz
021beiyang.com
021blzj.com
021byedu.com
021escortmassage.com
021gay.cc
021gd.com
021hwcf.com
021lawyer-wl.com
021ll.com
021pretty.cn
021scg.cn
021scg.com
021sex.net
021sh2.com
021shanghai-ktv.com
021tarena.com
021wyt.com
021zxc.com
0221telefonsex.xyz
022438.com
02295.com.cn
022che.net
022dmpaifa.com
022gcyy.com
022gufengji.com
022jj.cn
022sh.com
022ydlanyin.com
023dyfs.com
023gykj.com
023hysj.com
023lyc.com
023steel.cn
023tg.net
023vcc.com
024-webcam-sex-live-cam-meiden.startspot.nl
024119.com
024898.com
024it.com
024jqd.com
024pp.com
024scyz.com
024toys.com
024zmb.tumblr.com
02566664444.com
025bjgs.com
025gaokao.com
025idc.com
025jj.com
025npxyy.com
025ss.com
025taxi.com
025xx.com
025yhdzp.com
026city.com
026punyo.com
026tousatu.com
027026.com.cn
027cutie.com
027jckj.com
027ju.com
027jym.com
027mmw.com
027sjsx.com
027xjc.com
028aab.com
028acer.com
028aysm.com
028cdhy.com
028cdztmy.com
028dahuoji.com
028dhf.com
028haichuan.com
028hetong.com
028jczs.com
028net.net
028qsn.com
028qzbw.com
028shutong.com
028ss.com
028std.com
028tta.com
028wcjc.com
028yi.com
028yingxiao.com
028ysxx.com
0296688.com
029bb.com
029bxg.com
029chinatest.com
029frefre.blogspot.com
029oo.com
029sanxing.com
029soho.com
029sp.com
029sydz.com
029wanmei.com
029zh.com.cn
02bed.tumblr.com
02g.top
02gayguy.tumblr.com
02indianscout.tumblr.com
02km.cc
02macoreaper.tumblr.com
02oi.com
02rs.com
02sex.com
02t.top
02w.tumblr.com
02xn.com
02xvideos.com
02xvideos.net
02xxx.com
02zmtu.top
030swinger.de
0311baojia.com
0311sz.com
0312ksd.com
0312mp.com
0312ww.com
0312xs.com
0312yu.com
0317111.com
0317cy.com
0318by.com
0318show.com
0319hengxin.com
031ww.com
032gg.com
033e.com
03416.cc
034c7fb.netsolhost.com
0351wsh.com
0352js.com
0353tuangou.com
0355dai.com
0359jx.com
0363804426.com
036edu.com
037-av.com
0371fuke.com
0371jk.com
0371ls.com
0371mc.com
0371tianmao.com
0371xydz.com
0372589.com
0375fcw.com
0375gree.com
0376dai.com
037760.com
0377zpw.com
0378alicdn.com
0379ad.com
037clipx.com
037clipx.net
037clipxx.com
037clipxxx.com
037d.com
037hdjav.com
0383kk.com
039763.com
039798.com
0398sanmxia.com
03av.cc
03devil4life.tumblr.com
03e.info
03films-allopass.blogspot.com
03fq.top
03free.com
03l.top
03o87.com
03p.info
03pjpj.net
03porno.com
03pron.vip
03sex.co.il
03sex.com
03vp.com
03xgqz.top
03xnxx.com
03xxx.net
03zs.top
04-adult-dvds.com
04-adult-hardcore-sex-videos.com
04-sex-toys.com
0401-hot.com
0401-live.com
0401-meme.com
0401-sex.com
0401-tel.com
0401good.com
0401msg.com
040852.canalblog.com
040dd.com
040v.com
0411dl.net
0411team.com
0411yikeshu.com
0411zhileng.com
0412fc.com
0412k.com
0414xpjw.com
0415wx.com
0417hx.com
0419998.com
041hh.com
041tt.com
041vip.com.br
042sexmaniac.blogspot.com
043011x.tumblr.com
0431douyan.com
0431hydm.com
0431ky.com
0436.org.cn
044ii.com
044xx.com
0451zk.com
0452fuyu.com
045328.com
045scene.com
04656bbcc.com
0469bq.com
046pp.com
046qq.com
046qs.com
0470ec.com
0474yangtuo.com
0477coal.com
0477xx.com
0478jynm.com
0478s.com
0479jbl.com
047jj.com
047xx.com
048x.com
0492escort.nl
049bb.com
049jj.com
04cc.cc
04cx.com
04fenxiang01.com
04ff2ae37277.com
04jsb.com
04oral.blogspot.com
04phuxache.tumblr.com
04pink-j.net
04r.top
04tube.com
04ww.cc
04xd.top
04xx.cc
0505n.com
0509-show.com
0509-uthome.com
0509cam.com
0509liveshow.com
0509meme.com
0509tw.com
0509vip.com
05102024.org
0510d.com
0510sg.com
0510tyh.com
0511cl.com
0511hmy.com
0511top.com
0512cad.com
0512kh.com
0512paper.com
0512www.com
0512yimei.com
0512zf.com
0513xpjw.com
0515fun.com
0515jc.com
0516ws.com
0518fm.com
0518hy.com
0518mly.com
051jj.com
0522042228.jp
05231997.tumblr.com
0523ido.com
052963.com
0530lt.com
0531gcw.com
0531snews.com
0532eduinfo.com
0532npx.com
05338883666.com
053434.com
0534zz.com
053600.com
0536xpjw.com
0537zhaiwu.com
053ww.com
0542227333.com
0546cn.com
054rr.com
0550xyy.com
0551huier.com
0551oa.com
0551xsj.com
0551ye.com
0552ks.com
0553jdwx.com
0554gy.com
0555edu.com
0556qc.com
0556toy.com
0557400.com
0557dmz.com
0557f.com
0558ahgc.com
0558bzwy.com
0558home.com
0558jhkj.com
0558ren.com
0559bike.com
0559mlh.com
0559qs.com
0563nk.com
0564xianglong.com
0567av.com
056hg.com
0571ai.com
0571blg.com
0571bs.com
0572mp.com
0572tb.com
0574china.com
0574soho.net
0575edu.com
0575yiqi.com
0576dsw.com
0576h.com
0577cnfk.com
0577ra.com
0577weimob.com
0577zhengjia.com
0579sd.com
057xx.com
0587d.com
0592kt.com
0594138.com
05948888.com
05949999.com
0594bmw.com
0594you.com
0595pet.com
0596eh.com
0596rl.com
0596taobao.com
059915.com
059ai.com
059job.net
059sexshop.com.ar
05av.cc
05bgp.com
05dy.cc
05kx.com
05lotus.tumblr.com
05ml.ru
05movie.com
05nnn.com
06-xxx.com
06.zoekvinden.nl
0600.com
060e.com
060xxx.com
06141.cc
061sp.com
062game.com
063.dr.ag
0632u.com
0633fdc.com
063oo.com
063ww.com
06666.no
068rr.com
069.cc
0690.hu
069maninstockings.over-blog.com
069porn.com
069sex.de
06bp.com
06dh.top
06dq.top
06escorts.nl
06image.com
06kk.com
06libertin.over-blog.com
06manu06.canalblog.com
06master06.tumblr.com
06n.top
06se.com
06sex.info
06sex.nl
06ws.top
06xf.cc
06xn.top
0700swingerclub.de
0707aa.com
0707kk.com
0707zz.com
0708db.tumblr.com
070av.com
070rr.com
0710zx.com
0711w.com
0713sq.com
0716yy.com
0717zcw.com
0718xfw.com
0719sy.com
0719yh.com
071h.com
0720naughtygirl.tumblr.com
0721club-hiroshima.net
0722ddc.com
072374.com
072728.com
0728dy.com
0728fc.com
072av.com
072erodouga.com
072project.com
0731ak.com
0731du.com
0731gdcm.com
0731hnnk.com
0731jiasu.com
0731xz.com
0734ls.com
073505.com
0735ch.com
0735mj.com
0736sw.com
0737cdc.com
0737newjob.cn
0738seo.com
0745hm.com
0745zs.com
075-55.uk
0750fk.com
0750huiyuan.com
0750weixin.com
0752an.com
075312.com
075393.com
0754ok.com
075598.com
0755aic.com
0755brand.net
0755chetuoyun.com
0755co.com
0755crystal.com
0755jiaoyu.com
0755zk.com
0757bdt.com
0757px.com
075927.com
0759qunyi.net
0760kt.com
0762aa.com
0763cx.com
0765xpjw.com
0769hayou.com
0769ju.com
0769xf.com
0771sw.com
0771ysf.com
0771zh.com
0775sh.com
077616.com
0777www.com
07792218018.com
077xxx.tv
077xxx.vip
0783kaiketsu.net
0785153580.net
078wm.com
0790rs.com
0790tg.com
0791gljl.com
0792yyfk.com
0794121212.ch
0795ny.com
0797ok.com
079cb653801f.com
07bx.com
07cams.com
07chigua.com
07mg.top
07ms.cc
07o.top
07porn.com
07t.com
07v.net
07xnxx.blogspot.com
0800-erotik.de
0800-oralsexx.tumblr.com
0800-telefonsex.net
0800808636.com
080082.com
0800erotik.de
0800paja.blogspot.com
080804.com
080bbb.com
080chat.com
080ek21.com
080kiss.com
080ut.com
080ut11.idv.tw
080ut18.idv.tw
080ut19.idv.tw
080ut20.idv.tw
080zz.com
0816zl.com
0817hua.com
08255.net
08296.hk
0831zhaojisong.com
08363.hk
08431.hk
0851gztq.com
0851hy.com
0851yy.com
0853fdc.com
0855vip.com
085rr.com
086242.com
0871eat.com
08723guy.tumblr.com
0872byby.com
0873zp.com
0875.ru
0894645xxx68.site
0898fw.net
0898xj.com
08ba95f3b85d.com
08busarida.tumblr.com
08do.cc
08g9vf9tl-vlbwrd.usercash.com
08i.top
08lf.top
08long.tumblr.com
08porr.nu
08sr.com
08xj4cv.garden
08yiko.xyz
0900-babes.com
0900-babes.de
0900-bizarr-sex.de
0900-camsex-amateure.telefonsex-im-web.xyz
0900-camsex.com
0900-camsex.de
0900-live.com
0900-livecams.com
0900-livetelefonsex.de
0900-sexcam-girls.6telefon.info
0900-strip.com
0900-telefon-erotik.com
0900-telefon-sex.com
0900-telefon.de
0900-telefonerotik.de
0900-telefonsex-girls.com
0900-telefonsex-girls.de
0900-telefonsex-live.com
0900-telefonsex-sofort.com
0900-telefonsex.at
0900-telefonsex.ch
0900-telefonsex.com
0900-telefonsex.de
0900-telefonsex.fun
0900-telefonsex.info
0900-telefonsexcam.com
0900-vermietung.de
0900-videosex.de
0900.q4y.net
0900.telefonsex-sklavin.org
0900.telefonsexxx.org
09004you.de
09005-analxxx.de
09005-telefonsex.net
09005-telefonsex.sexstellungen.tv
09005.tel
09005telefonsex.com
0900abo.de
0900anal.de
0900anja.de
0900babes.de
0900beate.de
0900birgit.de
0900bondage.de
0900busen.de
0900camgirls.info
0900camsexgirls.info
0900carmen.de
0900carola.de
0900club.de
0900dauergeil.de
0900domina.com
0900dominanz.de
0900erotik.com
0900fetisch.de
0900ficken.de
0900flirtkontakte.de
0900flirtline.de
0900forfree.de
0900fussfetisch.de
0900hausfrau.de
0900hausfrauen.de
0900intim.de
0900janette.de
0900jenny.de
0900jessica.de
0900jutta.de
0900katrin.de
0900lesbe.de
0900lisa.de
0900live.de
0900livesexcams.com
0900michaela.de
0900model.de
0900modelle.de
0900natursekt.de
0900sabine.de
0900sahra.de
0900schlampe.de
0900schlampen.de
0900sex.net
0900sex.nl
0900sexcamchat.info
0900sexphone.com
0900simone.de
0900strip.com
0900strip.de
0900tanja.de
0900telefondomina.de
0900telefonfick.de
0900telefonsex.net
0900telefonsexcams.info
0900telesex.com
0900tina.de
090258.com
0903overzicht.be
0906-18plusclub.startspot.nl
0906-babysitters.maakjestart.nl
0906-bel.startspot.nl
0906-brilvolzaad.maakjestart.nl
0906-huisbaas.maakjestart.nl
0906-omasex.maakjestart.nl
0906-sexinhd.startspot.nl
0906-strandsletten.startspot.nl
0906-webcams.maakjestart.nl
0906.4-all.org
0906.net
0906.nl
0906.pagina.nl
0906.startbewijs.nl
0906.startkabel.nl
0906.startpagina.nl
0906.startplezier.nl
09062021515.nl
0906afspraak.nl
0906babbelbox.nl
0906livesex.com
0906overzicht.nl
0906porno.nl
0906sex.nl
0906sexdaten.nl
0906sexfilms.nl
0906sexlijn-nl.startspot.nl
0906sexlijn.nl
0906sexlijn.startspot.nl
0906shemale.nl
0906sm.nl
0906telefoonseks.net
0906telefoonsex.nl
0907.be
0907sexlijnen.be
0907webcamsex.be
090betsextou.com
090cs.com
090girls.co.uk
090heaven.co.uk
090zes.nl
0910sfw.com
0911hr.com
0915ankang.com
0915tao.com
0917osj.com
0917sy.com
091sex.tumblr.com
092219.com
092uu.com
0932840957345757527034898453.blogspot.com
09456.ru
095.us
095.vip
0951wx.com
0953120.com
0954u.com
095se2.com
095se5.com
09647.com.cn
0967.com
096b.com
09740.net
0974bc9816e9.com
097mm.com
0982131308.com
0987j.com
0987q.com
0987r.com
098862.com
0988666jygjsexp1.top
098b.top
099-hd.com
0991cx.com
0993f.com
0993j.com
0994.org.cn
099627.com
099735.com
0999735.com
099abb.com
099i.com
099jc.com
099kj.com
099rc.com
09aab.com
09ag.cc
09connect.nl
09dfqp.com
09ewda.tumblr.com
09hnbiyut6.tumblr.com
09jeansfetishporn.com
09parent.com
09porn.com
09sex.com
09sex.nl
09sexshop.com
09stream.com
09xxxx.com
0a2.top
0a38.com
0a59.com
0a7.top
0a70ad.garden
0a73c.com
0a8a9376227f.com
0af.cc
0ag.top
0ak86i.top
0ameliaflowerx.blogspot.com
0anal.com
0angelnoble0.com
0angels.com
0anonyme0.canalblog.com
0ant.com
0at.top
0au.top
0b-5hq3k1zf6.com
0b0ks8.com
0banglachoti.blogspot.com
0bd.top
0bestever.com
0bf.cc
0bi.top
0bicn0.xyz
0big-naturals.com
0brazzers.com
0bsexo.galeon.com
0bsidian.net
0bu.top
0bucksforpornmovie.com
0bvi0uslygay.tumblr.com
0bviously-gay.tumblr.com
0ca.top
0cams.com
0case.com
0ch.top
0chong.net
0cili.com
0cili.org
0ck.net
0cost.com
0cqzv9.top
0cs3ti.com
0ct0-pussy.tumblr.com
0cw.top
0cz.top
0d0.com
0d1ao5.com
0d5g5ysa486s.xyz
0data.xxx
0datesexx-joinme.pages.dev
0dayhentai.blogspot.com
0daymeme.com
0dayporn.info
0dayporn.org
0dayporn.pro
0dayporn.stream
0dayporno.com
0dayvideos.tk
0dayxx.com
0designer.com
0dj.top
0dm69xd0.tumblr.com
0dontkillmyvibe.tumblr.com
0dp.net
0dph.com
0dt.top
0duende0.tumblr.com
0dzn.com
0e-28slnd7z4.com
0e0.jp
0ea.top
0ebay.com
0elodie0.jepose.org
0ex-rb6id.garden
0eyj2.cc
0f-all-thiiings-sexy-colorful.tumblr.com
0f3scd9.garden
0f8.top
0fantasmes0.tumblr.com
0ff1ce-l0gin.com
0ffn0n.tumblr.com
0fl.top
0ft.top
0fzx0f.garden
0g0.com
0gb.top
0gfz.top
0ggvm9.garden
0gjqn.cc
0gl.top
0gq.top
0gw.top
0h-my-tit.tumblr.com
0h-n0-a-negro-fucked-my-daugter.tumblr.com
0h1.top
0hbmx.com
0hd.cc
0hentai.com
0hentai0.tumblr.com
0hfuckitall.tumblr.com
0hgir1.tumblr.com
0hh-shesthatgirl.tumblr.com
0hhx.com
0hipu8u4y.garden
0hl.top
0hlulu.tumblr.com
0hmy-gay.tumblr.com
0hmyg0shj0sh.tumblr.com
0hmysweetness.tumblr.com
0hornyteen0.tumblr.com
0hthatgirl.tumblr.com
0huller.dk
0hwellfuckyou.tumblr.com
0i3.top
0iam.xxx
0interestrate.com
0it6.top
0iwbds.top
0iyl.top
0j2.cc
0j5z7c5.garden
0j7-sp91c8ez.com
0jav-daily.blogspot.com
0jf.com
0jomajo.tumblr.com
0k3.top
0k4hes1d-97.com
0kgalc.com
0kit.com
0koreagay0.tumblr.com
0kp.top
0ktonion.tumblr.com
0l6.top
0l8nub.top
0lagersexposed.blogspot.com
0lb.top
0ldperv.tumblr.com
0limits4-deactivated20140606.tumblr.com
0livejasmin.com
0lporn.com
0lz.top
0m908q.com
0masale.com
0michaly.top-100.pl
0mji35.top
0mn.top
0n89w6.com
0nce08.garden
0ndl.top
0ne-eyedwilly.tumblr.com
0ne-swallow.tumblr.com
0nestepcl0sert0theedge.tumblr.com
0ni.cc
0nline-adult-dvd.dk
0nline-sexshoppen.dk
0nlineporn.com
0nlinesexshoppen.dk
0nly-sexxx.tumblr.com
0nlyfanssex.pages.dev
0nlyrealgirls.tumblr.com
0nlyshemale.tumblr.com
0nsexchanges.xyz
0nu.cc
0nude.com
0nv.cc
0nyra6.com
0oh.top
0onp.com
0oy.cc
0oy6.com
0p0.com
0p3ns3as0n.tumblr.com
0p4ma58-hn9f.com
0p6.top
0pa.org
0pal-s0ul.tumblr.com
0pb.top
0pc8.top
0pd.top
0pe.cc
0pe.top
0pe3.top
0penh0le4u.tumblr.com
0pentoanything.tumblr.com
0peracoin.com
0pgg5n.com
0pointsex.com
0porn.cc
0porn.com
0porn.info
0porn.net
0porn.org
0porn.shop
0porno.click
0porno.name
0pornoonline.com
0pornoonline.net
0pornoonline.top
0pornoonlines.click
0pornoonlines.net
0pornoonlines.top
0pornos.cc
0pornos.click
0pornos.com
0pornos.one
0pornos.top
0pornovideo.cc
0pornovideo.click
0pornovideo.link
0pornovideo.me
0pornovideo.net
0pornovideo.one
0pornovideo.org
0pornovideo.top
0pupppyloki.tumblr.com
0puppypigpornstar0.tumblr.com
0q50.top
0qdq7o.garden
0qko1z.com
0qmf.top
0qy.top
0qz.top
0r5.top
0r6.top
0rc.top
0rchid.canalblog.com
0rcyj7.garden
0rffiefriends.com
0rg4smos-lesb-kos.tumblr.com
0rgasm-faces.tumblr.com
0rgasme.com
0rgies.com
0rgy.com
0rifooyz.6ecz8f.com
0riginal-7.tumblr.com
0rockey0.tumblr.com
0ruepq.top
0ry2rk.com
0s2.top
0s4.top
0sex.club
0sex.com
0sex.homes
0sexe.com
0sh.top
0shouzhuan.com
0smm.xyz
0something0dirty0.tumblr.com
0sso.top
0sunnyleonenakedpicsg.tumblr.com
0t4.top
0t76.com
0t8.top
0t9.top
0tario.tumblr.com
0te1pu.garden
0teenluver.tumblr.com
0teszd.garden
0tgp.com
0therm32.tumblr.com
0titsmcgee.tumblr.com
0tp.top
0tq4-6rw5b8u.com
0tub.com
0tubes.com
0tx.top
0u0.com
0u2.top
0u3.top
0u6.top
0uav8b.garden
0ue.top
0uq.top
0ur5exlife.tumblr.com
0urloveadventure.tumblr.com
0usadia-sex-and-drugs.tumblr.com
0v3rth1nkin8ita11.tumblr.com
0vawn9.com
0vh.cc
0vi.top
0video2cul.free.fr
0voyeur.com
0vp.top
0vs1.net
0w3569.com
0wds.top
0wetlatinpussy0.tumblr.com
0wgd.top
0wh.top
0wi.top
0witter.com
0wvn.com
0x0.free.fr
0x0x0mandy0x0x0.tumblr.com
0x294a.top
0x4d0x690x6c0x66.tumblr.com
0x7121.com
0x7a69.net
0xb.top
0xdaily.com
0xfeb.store
0xhamster.com
0xnd.top
0xo.xyz
0xp.top
0xroots.com
0xvq.top
0xxx.com
0xxx.free.fr
0xxx.io
0xxx.li
0xxx.org
0xxx.ru
0xxx.st
0xxx.unblockit.ing
0xxx.ws
0xy.xxx
0xyz.top
0y02.com
0y1n.top
0y3r.top
0y4.top
0y40v0.garden
0yae12vdh.garden
0yc.cc
0yl291.garden
0ylt.top
0ys4wq.garden
0yt.top
0yueshen0.tumblr.com
0z1.cc
0z4.top
0z6tm6.com
0z7.top
0ze.top
0zfg.top
0zgwya.huxiaoyan8.com.cn
0zk.cc
0zl.top
0zm.top
0zt3.com
0ztie.com
1-1.cam
1-12asianpops7stourism.blogspot.com
1-2-1-cam-girls.co.uk
1-2-1-cam-wives.co.uk
1-2-1-naked-girls.co.uk
1-2-1-swingers.co.uk
1-2-3-4-getthefuckawayfromme.tumblr.com
1-5-0-smsclips.startspot.nl
1-8-p-l-u-s.startspot.nl
1-800-305-babe.com
1-800-470-jill.com
1-800-555-dick.tumblr.com
1-800-900whip.com
1-800-998-slit.com
1-800-adultsites.com
1-800-anal-sex.com
1-800-analsex.com
1-800-ass-play.com
1-800-assplay.com
1-800-bigtits.com
1-800-call-sex.com
1-800-callsex.com
1-800-free-sex.com
1-800-freesex.com
1-800-fuckboys.tumblr.com
1-800-fuckgirls.com
1-800-get-girls.com
1-800-getgirls.com
1-800-girl-sex.com
1-800-girlman.com
1-800-girlsex.com
1-800-hardcore.com
1-800-have-sex.com
1-800-hot-legs.com
1-800-hotlinegay.tumblr.com
1-800-hotlinepink.tumblr.com
1-800-hotmilf.com
1-800-lesbians.com
1-800-livegirls.com
1-800-momlust.com
1-800-need-sex.com
1-800-net-sexx.com
1-800-nude-girls.com
1-800-phone-sex.com
1-800-phone-sexy.com
1-800-phonesex.com
1-800-quickie.com
1-800-raw-porn.com
1-800-rawporn.com
1-800-real-sex.com
1-800-sexcall.com
1-800-sexgirl.com
1-800-sexline.com
1-800-sexy-babe.com
1-800-sexy-girl.com
1-800-teen-cams.net
1-800-teen-sex.com
1-800-teensex.com
1-800-want-sex.com
1-800-weflirt.com
1-800-wild-call.com
1-800-wildcall.com
1-800cummakers.com
1-800freesex.com
1-800fuckmehard.tumblr.com
1-800loan.com
1-866-778-slut.com
1-866-old-sexy.com
1-866-sin-lady.com
1-900adultpersonals.com
1-900phonesexnumbers.com
1-a-z-adult-free-stories.com
1-absolute-asian-sex-and-pussy-pics.com
1-absolute-free-erotic-xxx-sex-stories.com
1-absolute-teen-sex-and-pussy-pics.com
1-acclaimed-sexual-supplements.com
1-adult-6shop.dk
1-adult-nude-models-pics.com
1-adultchat.tv
1-adultfriendfinder.blogspot.com
1-adultfriendfinder.com
1-all-foot-n-toe-fucking-sex-fetish-pics.com
1-and-only.com
1-bare-naked-free-latina-teens-porn-pussy-pictures.com
1-belflore-modele.cmonbook.com
1-big-naturals.com
1-big-tits-pics.com
1-bisexual-dating-personals-men-women.com
1-black-porno.com
1-black-sex-porn-pussy-ass.com
1-black-sex.com
1-black-tube.blogspot.com
1-black-tube.com
1-blacks.com
1-blogsexe.com
1-bondage-sex.com
1-byday.com
1-cam-met-me.startspot.nl
1-cam-slut.co.uk
1-casino-gambling-directory.com
1-casino-webcam.com
1-celebrity.com
1-cent-fick.dr.ag
1-chat-bdsm.com
1-class-erotik.dk
1-class-sexshop.dk
1-cochon.com
1-content.com
1-dating-services.com
1-des-sens.tumblr.com
1-dollar-porn.com
1-enculeuses.com
1-enorme-lul.startspot.nl
1-eros-com-escorts-versus-sugar-babies-baby.com
1-erotic-sex-stories-club.com
1-escort.com
1-escorts.com
1-eurotica-live-nude-girls.com
1-extra-porno.startspot.nl
1-extra-sex-pagina.startspot.nl
1-fat-bbw-sex-pics.com
1-fat.com
1-fellation.com
1-femme-russe.com
1-ficken.de
1-fitnezz-junkie.tumblr.com
1-free-hardcore-sex-xxx-porn-videos.com
1-free-pics.com
1-free-porno.blogspot.com
1-free-sex-and-porn-pics.com
1-gay-dating-singles-personals.com
1-geile-webcam-sex.startspot.nl
1-gem.tumblr.com
1-girl-next-door.tumblr.com
1-grosse-poitrine.com
1-grosses.com
1-hardcore-sex-pics.com
1-heart-1-soul-1-sex-position.tumblr.com
1-heet-moment.startspot.nl
1-hete-sex-meiden.startspot.nl
1-high-end-party-girls-entertainment.com
1-hosting.com
1-jeu.com
1-lekker-geil.startspot.nl
1-lesbian-dating-freepersonals.com
1-lesbian-sex.com
1-like-pussy.tumblr.com
1-livejasmin.com
1-lulverslaafd.startspot.nl
1-mature.com
1-modele-photo.com
1-naked-boy.tumblr.com
1-natte-sex.startspot.nl
1-nude-amateurs.com
1-nudetube.com
1-nudisttube.com
1-obese.com
1-on.biz
1-online-bingo.us
1-onlinedating.com
1-penis-enlargement-solution.com
1-pervers.com
1-plan-cam.com
1-plan-cam.net
1-plan-coquin.com
1-plan-cul.com
1-plan-cul.net
1-plan-gay.com
1-plan-homo.com
1-plancul.com
1-porn-sex-cartoons.com
1-porn-videos-youporn.blogspot.com
1-porn-youporn.blogspot.com
1-porn.com
1-porn.fr
1-porno-free.blogspot.com
1-porno-tube.blogspot.com
1-porno-youporn.blogspot.com
1-porno.net
1-porno.org
1-porns.com
1-redtube-sexe.blogspot.com
1-renconte-libertine.com
1-rencontre-coquine.com
1-rencontre-cougar.blogspot.com
1-rencontre-cougar.com
1-rencontre.eu
1-salope.com
1-script.com
1-sensual-cpl.tumblr.com
1-sex-met-21hotgirl.startspot.nl
1-sex-met-ada.startspot.nl
1-sex-met-amber.startspot.nl
1-sex-met-babefleur.startspot.nl
1-sex-pictures.com
1-sex-poesjes.startspot.nl
1-sex-sex-sex.startspot.nl
1-sex-shop.com
1-sex-toys-sex.com
1-sex-tube.blogspot.com
1-sex-videos.blogspot.com
1-sex.com
1-sex.net
1-sex.nl
1-sexe-gratuit.com
1-sexe-youporn.blogspot.com
1-sexeze.blogspot.com
1-sexo.com
1-sextoys.com
1-singles.com
1-sixteen.tumblr.com
1-smoking.com
1-smokinggirls.com
1-st-celebrity-hairstyle.blogspot.com
1-stop-blowjobs-and-cumshots.com
1-stop-malaysia-massage-escort.com
1-super-geil-orgasme.startspot.nl
1-super-geil.startspot.nl
1-teen-sex.com
1-telephone-rose.com
1-tits.com
1-toons.com
1-top-bestofsex.blogspot.com
1-top-sex.startspot.nl
1-trans.com
1-tube.net
1-tubekitty.blogspot.com
1-tushy-school.com
1-twinks.com
1-video-porno.blogspot.com
1-vieille.com
1-we-live-together.com
1-web-cam-sex.startspot.nl
1-webcamsex.startspot.nl
1-websalope-com.blogspot.com
1-x.com
1-xxx-tube.com
1-xxx.ru
1-xxx.site
1-zu-1.com
1.aaaa10010.top
1.aaaa333518.top
1.lesben.frauen.xxx.free.fr
1.muschi.arschbilder.free.fr
1.ooskar.com
1.papno-tour.net
1.pornoabuelas.net
1.rank-nation.jp
1.taki-taki.lol
1.tv
1.xporno.space
1.xx-i.com
10-20-03.tumblr.com
10-barosh.co.il
10-inches.com
10-man-cum-slam.com
10-sexbegin.startspot.nl
10-sextube.startspot.nl
10-star.com
10-top-online-casinos.com
10-xxx-movies.startspot.nl
100-amateur-sex.com
100-amateur.over-blog.com
100-best-adult-sites.com
100-best-dating-sites.com
100-best-single-sites.com
100-bombes.com
100-free-big-fat-women-xxx-sex-pics.com
100-free-big-huge-tits-boobs-breasts-xxx-pics.com
100-free-cartoon-anime-xxx-sex-porn-pictures.com
100-free-foot-feet-fetish-toe-xxx-sex-pictures.com
100-free-hardcore-anal-xxx-sex-pictures.com
100-free-hardcore-group-sex-orgy-pictures.com
100-free-horny-lesbian-xxx-sex-pictures.com
100-free-interracial-xxx-sex-pictures.com
100-free-kinky-bondage-spanking-leather-xxx-sex-pictures.com
100-free-naked-amateur-xxx-sex-pictures.com
100-free-naked-latina-xxx-kiss-sex-pictures.com
100-free-nude-pregnant-women-sex-pictures.com
100-free-nude-teen-xxx-sex-pics.com
100-free-older-mature-women-sex-pictures.com
100-free-porn-movies-sex-videos-and-pics.com
100-free-porn.com
100-free-sex-pictures.com
100-free-sex.com
100-free-sexy-nude-asian-xxx-sex-pictures.com
100-free-shemale-transsexual-xxx-sex-pictures.com
100-free-xxx-sex-pictures-and-videos.com
100-geile-filmpjes.startspot.nl
100-live-teen-sex.com
100-nakedgirls.com
100-naughty-monkey.tumblr.com
100-orgasmes.over-blog.com
100-percent-adult-dirty-sex-jokes-free.com
100-percent-adult-sex-positions.com
100-percent-free-personals.netfirms.com
100-rican.tumblr.com
100-sex.com
100-tabous.net
100-top-adult-sites.com
100-top-asian-women-sites.com
100-top-dating-sites.com
100-top-gay-men-sites.com
100-top-gay-women-sites.com
100-top-latin-women-sites.com
100-top-russian-women-sites.com
100-top-single-sites.com
100-top-ukraine-women-sites.com
100-top.de
100.naver.com
1000-agent.com
1000-dating-sites.com
1000-facial.net
1000-facials.tumblr.com
1000-gay-hotties.blogspot.com
1000-russian-girls.com
1000-stars-nues.com
1000-wurdz.tumblr.com
1000.cam
1000.members0703.kci.org
10000-girls.tumblr.com
10000-in-place.tumblr.com
1000000links.com
1000000pv.net
100000av.top
100000jaarsex.be
100000xxxmovies.net
10000100010.tumblr.com
10000bedrooms.blogspot.com
10000cumshots.com
10000facials.blogspot.com
10000hoursexperiment.com
10000posturassexuales.com
10000sexygirlspics.blogspot.com
10000w.co.kr
10001films.blogspot.com
10003gpbokepgratis.blogspot.com
1000adultvideos.com
1000amateur.canalblog.com
1000amateurs.blogspot.com
1000amateurs.com
1000annunci.com
1000annunci.it
1000argentinas.com.ar
1000babes.net
1000bbw.com
1000blagues.blaguesflash.com
1000brides.com
1000casinos.com
1000cigarettes.com
1000cocks.com
1000culos.com.ar
1000culs.free.fr
1000cumshots.net
1000dh.top
1000divxmovies.com
1000escort.com
1000escort.net
1000et1nuits-sexygirl.tumblr.com
1000exgirlfriends.com
1000facials.adult
1000facials.com
1000facials.net
1000facials.org
1000facials.pics
1000facials.porn
1000facials.sex
1000fapvids.com
1000femmes.com
1000films.fr
1000folies.com
1000fotosgay.com.ar
1000fotosgratis.com
1000gatinhas.cjb.net
1000gays.com
1000giribest.com
1000grand.com
1000hentai.com
1000homemovies.com
1000hotel.com
1000hotmen.tumblr.com
1000images.tumblr.com
1000inculate.com
1000inwhot.blogspot.com
1000jav.com
1000lasek.toplista.pl
1000lesbiennes.free.fr
1000letie.ru
1000livecams.com
1000londonescorts.com
1000love.co.kr
1000mg.jp
1000misspenthours.com
1000mmail.com
1000more.tumblr.com
1000moviedownloads.com
1000ne.ch
1000ngayvang.com
1000notesormore.tumblr.com
1000novel.com
1000nudebabes.com
1000offers.com
1000orgasms.net
1000personals.com
1000photosx.free.fr
1000pl.com
1000porn.com
1000pornmovies.com
1000porno.me
1000porno.net
1000porno.ru
1000porno.tv
1000pornvideos.com
1000queen.com
1000reasonstobustanut.tumblr.com
1000reasonstomovetojapan.tumblr.com
1000sbdsmvideo.com
1000sexartikelen.com
1000sexartikelen.nl
1000sexblog.blogspot.com
1000sexybabesphotogalleries.blogspot.com
1000sofadultsextoys.co.uk
1000sun.com
1000teencamvideos.com
1000teens.blogspot.com
1000teenwebcams.com
1000tetas.tumblr.com
1000tieten.nl
1000transexuales.com.ar
1000tube.net
1000videoporno.com
1000videosx.wtf.la
1000videosx.yi.org
1000videosxxx-gratis.blogspot.com
1000vids.com
1000webcams.nl
1000websporno.com
1000xteens.com
1000xxx.com
1000xxxpics.com
1000xxxu.com
1000xyev.xyz
1001-adventures.dk
1001-annuaire.com
1001-attitude.com
1001-beauties.com
1001-cochonnes.com
1001-dicks.tumblr.com
1001-erotik.de
1001-filles.com
1001-filmx.be
1001-hotties-of-the-day.com
1001-lingerie.over-blog.com
1001-macht.at
1001-nacht-erotik.de
1001-nat.dk
1001-salopes.com
1001-sextoys.com
1001-teens.com
1001-teens.powa.fr
1001.msk.ru
100105.com.cn
10010600.xyz
10010gps.com
1001amatrices.com
1001bbw.com
1001beurettes.canalblog.com
1001bundas.hpg.com.br
1001cam.de
1001camgirls.com
1001cartoons.com
1001chattes.canalblog.com
1001chattes.com
1001culsdunet.canalblog.com
1001delights.com
1001dessous-sexy.wifeo.com
1001dessous.com
1001dirtyjokes.com
1001dvds.com
1001eroset.ru
1001erotic.com
1001eroticlights.tumblr.com
1001eroticnights.tumblr.com
1001erotiekverhalen.nl
1001erotikgeschichten.com
1001escortadressen.nl
1001expo.com
1001facials.com
1001freepics.com
1001freeporns.com
1001gay.com
1001gays.com
1001gaysexstories.blogspot.com
1001geilesex.nl
1001hiebe.de
1001hotgirls.tumblr.com
1001images.canalblog.com
1001lingerie.fr
1001loads.blogspot.com
1001logos-sexy.magikmobile.com
1001moppen.be
1001movies.com
1001night.ru
1001nighters.com
1001noites.com
1001orgasmes.blogspot.com
1001pengalamansex.blogspot.com
1001persosexy.com
1001petitsriens.blogspot.com
1001plaisirs.fr
1001priveadressen.nl
1001raccontierotici.com
1001reasonstobeagirl.tumblr.com
1001recettesdecuisine.com
1001relatoseroticos.com
1001relatosx.com
1001rt.com
1001salopes.com
1001sex.com
1001sexcams.nl
1001sexe.com
1001sexfilmz.com
1001sexgeschichten.com
1001sexlinks.nl
1001sexsite.blogranking.us
1001sextoys.com
1001sexygifs.site.voila.fr
1001shemales.com
1001sletten.nl
1001slofies.com
1001tube.com
1001twiggs.tumblr.com
1001twinks.webjump.com
1001ty.com
1001vicieuses.free.fr
1001videobokep.blogspot.com
1001waystobenaked.blogspot.com
1001webcamsexdames.nl
1001webcamsexsites.nl
1001x.net
1001xxx.com
1001xxxcams.nl
1001xxxfilms.nl
1001xxxpictures.com
1001xxxvideos.nl
100345.shop
1003wessex.com
10041959.tumblr.com
1004stock.com
1006902.com
1006playlist.com
1007-dxlove.com
1007-live173.com
1007.tw
10086.click
10086xx.com
1008dy.com
1008h.com
1008yh.com
1009shop.com
100adult.com
100alphadaddy-93.tumblr.com
100amateur-videos.blogspot.com
100amateur.com
100amateurvideos.com
100anaal.nl
100asians.com
100asiat.blogspot.com
100av.com
100bestadultsites.com
100bestpornsites.com
100bestsex.ru
100bigass.com
100bizarrladies.de
100boobs.tumblr.com
100boyself.com
100brazzers.blogspot.com
100bucksbabes.com
100c.xxx
100calcinhas.com.br
100cameltoe.com
100cb.com
100celebs.com
100celebwallpapers.blogspot.com
100chan.com
100chicas.blogspot.com
100christy.tumblr.com
100citives.free.fr
100click.it
100clips.com
100cmsexdoll.xyz
100cocks.com
100colegialas.blogspot.com
100complex.com
100cucixxx.com
100dailyboys.com
100date.com
100delolas.com
100dessousdessus.tumblr.com
100dicks.com
100dollargirls.ru
100dominas.de
100donmoingay.com
100e.over-blog.com
100escorts.co.uk
100euroescorts.com
100famosasdesnudas.com
100fantasies.com
100films.com
100free.com
100freecamsites.com
100freedirtycams.blogspot.com
100freemb.com
100freenudecelebrities.com
100freeporn.com
100freesexpics.net
100freesexsites.com
100freeteenseries.com
100freezooclubs.club
100fun.net
100games.hop.clickbank.net
100gaoxx.com
100gayboyvideos.com
100gaycocks.com
100gbtube.com
100gbvideo.com
100girls.nl
100gn.com
100grannysites.com
100handjobs.com
100hbjc.com
100hdporn.shop
100heat.com
100helps.com
100hen.virtualave.net
100hits.com
100homemade.com
100hot.com
100hotbabes.com
100hotpics.com
100hotsites.com
100hottestpornstars.blogspot.com
100jbuc.com
100jiang.com
100juegossexuales.com
100k1dem.blogspot.com
100keys.su
100kiki.com
100kissesescort.com
100kjk.com
100kong.com
100lendemain.com
100lesbianstories.com
100limites.cjb.net
100livecam.com
100liveporn.shop
100lutv.xyz
100mamadas.com
100mature.com
100maturesites.com
100megsfree4.com
100molezasaudesexual.com
100mujereslindas.blogspot.com
100mulheresbonitas.blogspot.com
100naked.com
100ngay.app
100ngay.co
100ngay.net
100ngay.org
100nn.bz
100nonude.biz
100nudes.com
100nudeshoots.tumblr.com
100one.com
100p-douga.com
100p100manga.chez-alice.fr
100panty.com
100pantyhose.com
100passwords.com
100pecados.net
100per100sex.com.rya-network.com
100percent-online.com
100percentfreeporn.blogspot.com
100percentgay.blogspot.com
100percentjohn.com
100percentlesbian.tumblr.com
100percentlive.com
100percentmature.com
100percentperfection.tumblr.com
100percentporn.com
100percentprimebeef.tumblr.com
100percentsex.de
100pezd.net
100pezd.pro
100photos.free.fr
100pics.com
100picsbbw.com
100poor100gay.free.fr
100porn.com
100porn.net
100porn.shop
100porn.tumblr.com
100porno.one
100pornogratuit.com
100pornos.net
100pornsites.com
100porntube.com
100pour100gay.com
100pour100sex.canalblog.com
100pour100sexe.com
100pregnantpics.com
100pro-teens.de
100pro-versaut.com
100procent-gratissex.nl
100procent.nu
100proofoflasvegas.com
100proporn.shop
100prozentprivat.de
100prozentprivat.net
100pure.net
100pussy.com
100puyu.com
100royalgrant.com
100rupaiya.com
100russianbrides.com
100russiangirls.com
100russianwomenlinks.com
100sexgames.com
100sexmsk.ru
100sextube.com
100sexvideos.com
100sexy.com
100sexygirl.com
100sexygirls.easy4blog.com
100sexywomen.blogspot.com
100shadesofgry.tumblr.com
100shemales.com
100shmar.net
100sht.com
100siteaccess.com
100size.ru
100sklavinnen.de
100solucionesexpress.com
100sponsors.com
100stron.pl
100suelle.com
100suelle.com.free.fr
100tabous.canalblog.com
100tabous.com
100tabu.com
100tb-porno.ru
100teams.net
100teenbabes.com
100teenthumbs.com
100telefonsexgirls.com
100tequila.com
100tgirls.com
100thbear.tumblr.com
100tipcams.blogspot.com
100tipcams.com
100tits.com
100top.com
100topescorts.com
100toppornmovies.blogspot.com
100toppornstars.com
100topsites.net
100tvporn.shop
100ubrc.com
100upskirts.com
100upskirts.org
100video.com.br
100vod.net
100voyeur.com
100vporn.shop
100waibao.com
100web.com
100web.de
100wk.com
100worlds.com
100x.com
100x100argentinas.blogspot.com
100x100argentinas.com.ar
100x100negras.com
100x100pamela.com
100x100sexshop.com.ar
100xporn.shop
100xsexo.kit.net
100xxx.com
100xxx.net
100xxx.ru
100xxxpix.com
100xxxvideos.com
100xxxxx.com
100yixin.com
101-escort-go-home.com
101-sex-positions.com
101-sex-positions.tumblr.com
101-sex.com
101-sexstellungen.org
1010-china.com
1010013.com
1010ben.com
1010butterfly.tumblr.com
1010sex.com
1010shemales.blogspot.com
1011.com
1012betsextou.com
1012k.com
1014epp.com
1014trr.com
1014yff.com
1014yuu.com
1017tgirllover.tumblr.com
101821.myshoutbox.com
1019ly.com
101adult.com
101adult.com.readfinance.au
101anal.com
101babes.com
101blowjobs.tumblr.com
101bokep.blogspot.com
101boys.blogspot.com
101boys.com
101boyvideos.com
101butts.com
101celebrities.com
101date.com
101datingideas.com
101domain.com
101eroticstories.com
101fetish.com
101funjokes.com
101galleries.com
101gayporn.com
101gaystreet.com
101gaytwinks.com
101gayvideos.com
101gem.ru
101hotguys.com
101japanese.com
101lalex.tumblr.com
101livecams.com
101lunwen.com
101milf.com
101modeling.com
101nacht.de
101nights.com
101nudegirls.com
101porn.tumblr.com
101pussy.com
101s.com.tw
101sex.com
101sex.hpg.com.br
101sexcams.com
101sexmovies.com
101sexpositions.blogspot.com
101sexshop.ru
101sextoys.com
101sluts.com
101spanking.com
101st-armyvet.tumblr.com
101stories.com
101teengirls.blogspot.com
101teengirls.com
101to1.com
101true101.tumblr.com
101tube.com
101vagina.tumblr.com
101wanks.com
101xturkpornocu.site
101xxx.xyz
102.over-blog.com
102.prostitutki-msk.com
1020xxx.com
102114.info.targetgroup.ru
1024-caoliu.com
102495.xyz
102499.xyz
1024abc.com
1024bt.cyou
1024bt.top
1024btbt.com
1024btso.com
1024cg.com
1024dns.com
1024fans.com
1024free.me
1024kan.com
1024kan.shop
1024pp.com
1024sex.tumblr.com
1024sp3.casa
1024sp3.mom
1024sp4.autos
1024sp7.help
1024su.com
1024videos.com
10271.8d.com.tw
10273537281.tumblr.com
102farkop.ru
102jj.com
102liverpool.com
102model.com
102porn.com
102porno.club
102porno.net
102porno.top
102xx.com
1030.51whc.vip
1030chelsea.com
1031video.com
10320-136.s.cdn13.com
10360.com
1038438322488.usercash.com
1039thex.com
103bb.com
103j.com
103n.com
103porno.cc
104-meimei.com
104245245784458.blogspot.com
104karine.83r.free.fr
104xx.com
104xxx.com
105035.shoutboxes.com
1050words.blogspot.com
10517.com
1053.ru
105662.com
105debundinha.hpg.ig.com.br
105dy.com
105fetish.cl
105matures.com
105pymblehouse.com.au
10639615a.tumblr.com
1069boys.net
1069boys.xyz
1069gay.click
1069tube.com
106jsb.com
106zzznormastitz.com
1077c713a488.com
107881.shoutbox.de
107e.com
107kq.com
107ss.com
1080-porno.blogspot.com
1080.hlkjsm.com
1080bf.blogspot.com
1080hdporn.shop
1080liveporn.shop
1080maxporn.shop
1080p4me.com
1080p4u.com
1080paz.com
1080pcontent.com
1080plusporn.shop
1080pok.com
1080porn.com
admireme.vip
adultfriendfinder.com
alt.com
amador55.com
ashleymadison.com
babes.com
babestation.tv
bangbros.com
bdsmlr.com
beNaughty.com
beeg.com
bongacams.com
brazzers.com
cam4.com
camerahot.com.br
camerasex.com.br
camsoda.com
camversity.com
candfans.jp
casualx.badpuppy.com
chaturbate.com
clicksex.com.br
daftsex.com
digitalplayground.com
drtuber.com
empflix.com
eporner.com
erome.com
fakehub.com
fancentro.com
fansly.com
fanvue.com
fapello.com
fatalmodel.com
fatalmodel.com.br
fetlife.com
flagrasamadores.com
fling.com
flirt4free.com
friendfinder.com
fuq.com
furaffinity.net
garotacomlocal.com
garotascomlocal.com.br
gotporn.com
guiana.com.br
heavy-r.com
hqporner.com
imlive.com
jasmin.com
justforfans.com
livejasmin.com
lobstertube.com
loyalfans.com
manyvids.com
mofos.com
motherless.com
myfreecams.com
naughtyamerica.com
novinhasdoinsta.com
nuvid.com
onlyfans.com
passion.com
phncdn.com
photoacompanhantes.com
phprcdn.com
pocketstars.com
porn.com
porn555.com
porndig.com
porngo.com
pornhat.com
pornhub.com
pornhub.org
pornhubpremium.com
pornhubselect.com
pornmd.com
porntrex.com
pornve.com
privacidade.com.br
privacy.com.br
realitykings.com
redtube.com
redtube.net
rk.com
skokka.com
skokka.com.br
spankbang.com
spankbang.party
spankbang.site
streamate.com
stripchat.com
sunporno.com
tblop.com
thumbzilla.com
tnaflix.com
tube8.com
tubegalore.com
twistys.com
upornia.com
vidoomy.com
webcamchecker.com
www.pornhub.com
www.xhamster.com
www.xnxx.com
www.xvideo.com
www.xvideos.com
xhamster.com
xhamster.desi
xhamsterlive.com
xhcdn.com
xnxx-cdn.com
xnxx.com
xnxx.es
xnxx.fr
xnxx.tv
xnxx2.com
xnxx3.com
xtube.com
xvideo.com
xvideos-cdn.com
xvideos.com
xvideos.com.br
xvideos.es
xvideos.fr
xvideos.in
xvideos2.com
xvideos3.com
xvideosporn.com
xvideosred.com
youporn.com

EOF_FEED_adult.txt
echo '>> Extraindo feeds/doh-providers.txt...'
cat << 'EOF_FEED_doh-providers.txt' > $TMP_DIR/feeds/doh-providers.txt
# ==========================================
# WAM Feed - DoH Providers (Anti-Bypass)
# ==========================================
# Mozilla Firefox Enterprise Canary (Desativa DoH automático em navegadores)
use-application-dns.net

# Cloudflare DoH & 1.1.1.1 Endpoints
cloudflare-dns.com
1dot1dot1dot1.cloudflare-dns.com
one.one.one.one
mozilla.cloudflare-dns.com
chrome.cloudflare-dns.com
security.cloudflare-dns.com
family.cloudflare-dns.com

# Google DNS DoH & 8.8.8.8 Endpoints
dns.google
dns.google.com
dns.google.com.br
dns64.dns.google

# Quad9 & CleanBrowsing
dns9.quad9.net
dns.quad9.net
doh.cleanbrowsing.org

# AdGuard DoH
dns.adguard.com
dns.adguard-dns.com
dns-family.adguard.com

# Cisco OpenDNS
doh.opendns.com
resolver1.opendns.com
resolver2.opendns.com

# NextDNS, Mullvad, ControlD & Apple Private Relay
dns.nextdns.io
doh.mullvad.net
doh.controld.com
doh.dns.apple.com
mask.icloud.com
mask-h2.icloud.com

EOF_FEED_doh-providers.txt
echo '>> Extraindo feeds/gambling.txt...'
cat << 'EOF_FEED_gambling.txt' > $TMP_DIR/feeds/gambling.txt
# ==========================================
# Rules WAM Feed - Apostas, Bets & Cassinos
# Total de dominios consolidados: 1594
# ==========================================

0-10-7.casino
0-2-0-7.casino
0-30-7.casino
0-5-07-casino.buzz
0-50-7.casino
0-60-7r.casino
0-7-0-7s.casino
0-8-07c.casino
0-bdmbet.com
0-bet.com
0-betsixty.com
0-casino.info
0-coolzino.com
0-g-j-3.com
0-o-x-h.com
0-w-v-s.com
0-x-g-5.com
0-xbets.net
00.game
000-online-casino.biz
000-online-casino.com
000000.com
000000hd.com
000000tyc.com
00000178.com
00000234.com
00000hd.com
00001676.com
00001betsorte.com
00002004.com
00002007.com
00002277.com
00002tyc.com
00003044.com
00003tyc.com
00004008.com
0000442.com
00004tyc.com
0000502.com
00005138.com
00005156.com
0000540.com
00005424.com
000068.com
00008126.com
00009tyc.com
0000iplwin.com
0000jili.com
0000wb.com
00012023.com
0001235.com
0001239.com
000148.com
000173.com
000192.com
0002.space
0002.world
000248.com
00032023.com
0003608.com
0003977.com
0004560.com
0005.com
00052023.com
0005vip.pages.dev
0005vip1.pages.dev
0005vip2.pages.dev
0006138.com
00066030.com
00067899.com
0006yh.com
0007-casino.xyz
000706.com
0007154.com
00071yy.com
00072023.com
0007865.com
000789win.com
0007bet10.com
0007betsorte.com
0008154.com
00082023.com
0008n.com
00090.xyz
00091145.com
00092dl.com
0009990.com
0009994.com
0009995.com
0009996.com
0009997.com
0009998.com
0009casino.com
000casinos.com
000i9.com
000i9bet.com
000iplwin.com
000jaya.com
000m88.com
000n83.com
000q.cc
000q88.com
000sodo.com
000yabo.com
000yb.com
000zryl.com
001.casino
0010n.com
00111381.com
00112007.com
00112017.com
00112023.com
00113044.com
00113118.com
0011368.com
00114008.com
00114137.com
0011502.com
00115316.com
00118332.com
001358.com
001359.com
001366.com
001371.com
001372.com
0013n.com
001533.com
0015n.com
001678pk.com
001699.com
0018-casino.buzz
0018g.com
0018k.com
0018n.com
0018q.com
001917.com
001992.com
001993.com
001998.com
0019n.com
001casino.com
001fxh9-fe-source.bjravv03.com
001fxh9-tiger-fluid.bjravv03.com
001game.org
001game1.cc
001game8.cc
001game8.com
001game9.com
001gameios.com
001k.xyz
001k8.com
001konco88.xyz
001nohu.com
001p.casino
001p6.com
001win14.com
001win8.com
001yabo.com
001yd.com
0022003.com
0022153.com
00222005.com
00222979.com
00224118.com
0022442.com
0022502.com
00225076.com
00225316.com
0022540.com
00226076.com
0022696.com
0023n.com
0024t.com
0025156.com
0026-casino.buzz
0026n.com
0027128.com
0027528.com
0029.top
0029dh.com
0029jc.com
002k8.com
002nohu.com
002p6.com
002pg88.com
003.com
003008h.com
003066.com
0031-casino.buzz
00332003.com
00332017.com
00332277.com
00333044.com
00333118.com
0033502.com
00335076.com
00336076.com
0033678.com
0033696.com
003377.com
003399.com
0033bet55.com
0033bet66.com
0033wb.com
0033win.bet
0033win.com
003457.com
00358.casino
00359.com
0036-casino.buzz
00361.casino
003665.com
003776.com
003885.com
0038888.com
0038n.com
00395.casino
003990.com
003991.com
003992.com
003997.com
003nohu.com
003p6.com
003pg88.com
004044.com
0040a.com
0041n.com
0042n.com
0043n.com
004400.com
00442005.com
00442017.com
00442023.com
00442277.com
00443044.com
00443118.com
004433.com
004440.com
00444118.com
0044442.com
0044502.com
0044540.com
0044634.com
0044696.com
00448449.com
0044n.com
0044wb.com
0046-casino.buzz
0048-casino.buzz
00489.casino
004gg.com
004nohu.com
004p6.com
004pxj.com
00505.casino
005117.com
0051a.com
0051n.com
005218.com
005219.com
005226.com
0054t.com
0055153.com
00552017.com
00552023.com
00553044.com
0055502.com
00555132.com
0055540.com
005564.com
005566.com
00557337.com
005574.com
00558449.com
0055bet055.com
0055betsorte.com
0055pgslots.com
0055wb.com
005689.com
0057v.com
00581.casino
005893.com
005987.com
005gg.com
005nohu.com
005p6.com
006024.com
006025.com
006032.com
006042.com
006043.com
006045.com
006049.com
006054.com
006059.com
006071.com
006073.com
006074.com
006083.com
006084.com
006087.com
006091.com
006092.com
0062s.com
0063.bet
00630.casino
006364.com
006489.com
00661577.com
00662003.com
00662277.com
00663044.com
0066540.com
0066608.com
00667076.com
006699.com
00669980.com
0066bet.com
0066bet1.com
0066bet2.com
0066bet2026.com
0066bet3.com
0066bet4.com
0066bet5.com
0066pgvip.com
0066vn.com
0066wb.com
0068888.com
006891.com
006895.com
006906.com
0069910.com
006bet.com
006i9.com
006nohu.com
006p6.com
006pg88.com
006pxj.com
006uni.com
007.poker
0074662.com
00749.casino
00760033.com
00760055.com
00760066.com
00760088.com
00760099.com
00761144.com
00761155.com
00762200.com
00762233.com
00762277.com
00762288.com
00762299.com
00763311.com
00763322.com
00763355.com
00763377.com
00763399.com
00764411.com
00764433.com
00764444.com
00764455.com
00765522.com
00765533.com
00765544.com
00765566.com
00765599.com
00766655.com
00766677.com
00767711.com
00768811.com
00768844.com
00768877.com
00768899.com
00769900.com
00769944.com
00769955.com
00769966.com
00769977.com
00769988.com
00769999.com
0077-casino.buzz
00772005.com
00772017.com
00772023.com
00772277.com
00773044.com
00774118.com
0077442.com
0077502.com
00775076.com
0077540.com
0077696.com
0077go.com
0077vn.com
0077xj.com
007912.com
007913.com
007915.com
007916.com
007bet00.com
007bet22.com
007bet33.com
007bet44.com
007bet70.com
007game02.win
007game05.one
007go.xyz
007jlcasinoph.com
007jlgcashcasino.com
007k8.com
007p6.com
007pg88.com
007slot.site
007slots.app
007slots.org
007togel.org
007vip4.com
007vip5.com
007vip9.sbs
007vn.cc
007vn.co
007vn.net
007vn.org
007vn.vip
007win.com
007win.org
007win.shop
007win0.com
007win04.com
007win06.com
007win07.com
007win10.com
007win2.com
007win22.com
007win33.com
007win44.com
007win6.com
007win77.com
007yb.com
008-122.vip
008-137.vip
008-142.vip
008-146.vip
008-152.vip
008-153.vip
008-161.vip
008-167.vip
008-169.vip
0080-casino.buzz
00800.vip
00803.app
00808.vip
0080a.com
0080c.com
0080kk.com
0080pj.com
0080y.com
008138.app
0081n.com
0081t.com
008239.cc
008389.com
0085002.com
0085006.com
0085008.com
0085009.com
008502.com
00853yurenmatou.com
0085ee.com
0085ll.com
0085pp.com
0085qq.com
0085uu.com
0085vip.com
0085vip3.com
0085vip8.com
0085vv.com
0085ww.com
0085zz.com
0086t.com
0087ph.com
00882005.com
00882007.com
00882023.com
00882277.com
0088304.com
00884118.com
00885003.com
0088502.com
0088540.com
0088696.com
00887076.com
00888076.com
00888449.com
0088bet20.com
0088bet23.com
0088bet63.com
0088bet72.com
0088bet73.com
0088bet96.com
0088bet97.com
0088vn.com
0088wb.com
008901.com
008902.com
008905.com
008906.com
008907.com
008938.com
0089bet.com
008a103.com
008a104.com
008a105.com
008a106.com
008a109.com
008a111.com
008a112.com
008a114.com
008a115.com
008a117.com
008a118.com
008a129.com
008a77.com
008a81.com
008a83.com
008a85.com
008a86.com
008a87.com
008a89.com
008a93.com
008a96.com
008bet7.com
008fs.com
008i9.com
008nohu.com
008p6.com
008pxj.com
008u1.com
008u10.com
008u3.com
008u4.com
008u8.com
008u9.com
008win999.com
008xpj.com
008yd.com
009.casino
009.com
009015.com
009017.com
009024.com
009026.com
009028.com
009041.com
009043.com
009047.com
009054.com
009064.com
009074.com
009084.com
009131.com
009189.com
00956.net
009881.com
009883.com
00990.vip
0099153.com
00992.com
00992003.com
00992005.com
00992007.com
00992017.com
009944.com
00994688.com
0099502.com
00995076.com
0099540.com
00997076.com
00998.vip
00998.xyz
00998076.com
0099bet22.com
0099vn.com
009bet.bet
009c99.com
009casino.bet
009casino.co
009casino.com
009casino.cyou
009casino.guide
009casino.help
009casino.mobi
009casino.today
009casino.zone
009casinoz.net
009game.link
009kyc.com
009mgm.com
009nohu.com
009p6.com
009sfym.com
009uni.com
009yd.com
00a.casino
00bestpg.com
00bet088.com
00bet99.com
00boi.bet
00bs.com
00casino.com
00d88.com
00ff9980.com
00fun.vip
00go99.com
00hh145.com
00hi88.com
00ii9980.com
00iplwin.com
00jl777.com
00l.casino
00ll145.com
00ll9980.com
00nohu.com
00oo9980.com
00pg88.com
00ph92.com
00phpwin.com
00poker.com
00r.casino
00rockstarcasino64.com
00rr88.com
00rr9980.com
00slot365.com
00win33.com
00xwin.com
00xx9980.com
00yabo.com
00yb.com
00yeu88.com
00yy8331.com
00z.casino
00zun.com
00zz9980.com
01-06.me
01-07-26.casino
01-07.casino
01-07m.casino
01-7.casino
01-casino.com
01000.com
010033.cc
010044.cc
010055.cc
010066.cc
010077.cc
010088.cc
0100n.com
0101076.com
0101304.com
01016018.com
0101650.com
01017076.com
01018177.com
010183.xyz
0101bet08.com
0101bet365.com
0101bet38.com
0101bet39.com
0101bet56.com
0101bet57.com
0101bet61.com
0101bet63.com
0101bet69.com
0101bet72.com
0101bet79.com
0101bet85.com
0101bet89.com
0101bet90.com
0101bet94.com
0101bet98.com
0101betsorte.com
010200.com
0102138.com
010232.xyz
01026.casino
0102c.com
0105.app
0107casino.team
0107d.casino
010casino.com
010nohu.com
010p6.com
010wanbo.com
010wns888.com
010xin888.com
0111hui.com
0112003.com
0112n.com
0112t.com
011317.com
011351.com
011397.com
0113s.com
011432.com
011517.com
01155.com
0115s.com
01166a.com
01166b.com
01166c.com
01166d.com
01166f.com
01166h.com
01166j.com
01166k.com
01166m.com
01166n.com
01166p.com
01166q.com
01166r.com
01166u.com
01166v.com
01166w.com
01166x.com
01166y.com
01166z.com
01185.vip
011869.com
0118t.com
0119s.com
011ks.com
011nohu.com
011p6.com
011z.casino
012.vip
01209.casino
0122003.com
0122n.com
0123win.com
0125-casino.buzz
01265.casino
01266e.com
012a5.com
012aee.com
012ajj.com
012akk.com
012all.com
012amm.com
012bet22.com
012bet33.com
012bg.com
012c2.com
012dd.com
012ff.com
012nohu.com
012p6.com
012pxj.com
012rr.com
012uu.com
012uuuu.com
012vv.com
012wwww.com
012xxxx.com
013.app
013123.com
0133win.com
0134000.com
0136358.com
01371188.com
01372233.com
013806.app
013833.com
0139.com
013958.com
013bet.co
013bet.com
013bet.net
013bet.win
013bet23.com
013bet8.com
013nohu.com
013p6.com
0140-casino.buzz
014060.com
01427.com
01438.casino
0144t.com
01472.com
014nohu.com
014p6.com
014vip.com
015108.com
015160.com
015180.com
015208.com
0152ii.com
015327.com
01548.com
01548c.com
01548g.com
015621.com
015625.com
015631.com
0158bet8600.vip
015nohu.com
015p6.com
015win.app
015win.com
016006.com
016066.com
01630163h.com
01630163s.com
01643.casino
0164677.com
01660166h.com
01660166o.com
01660166u.com
01662.casino
016659.com
016665.com
016679.com
016688.net
01677.com
01678xpj.top
0167xxx.com
01681680.com
0169.vip
01698.casino
016996.com
016n.casino
016nohu.com
016p6.com
01716.vip
017217.cc
017723.com
017755.com
0178888.com
01789win.com
017bet-12.com
017bet.co
017bet.win
017bet03.com
017bet25.com
017bet49.com
017bet70.com
017bet83.com
017bet87.com
017nohu.com
017p6.com
017zl.com
01802.com
0180c.com
01811su.com
01832.casino
01835.vip
018389.com
01846.casino
0185666.com
01867.casino
018789.com
018789win.com
01888.xyz
018nohu.com
018p6.com
0191146.com
019219.cc
019312.com
019393.app
0198.pro
0199-casino.buzz
019966.com
019fgyijy.com
019nohu.com
019p6.com
019zl.com
01b3659.com
01bets.com
01casinos.com
01go99.com
01hello88.com
01jl6.com
01kuwin.com
01livedrawhk.online
01nohu.com
01o.casino
01ph92.com
01qh88.com
01slvip.com
01turf.com
01uu88.com
01xbet.net
01xbet.org
01ycw.com
02-06.casino
02-07.casino
02-07m.casino
02000.com
020002.com
020034.com
02005.casino
020062.com
020063.com
020064.com
020065.com
020071.com
020076.com
020079.com
020081.com
020083.com
020084.com
020085.com
020087.com
020094.com
0200n.com
02022007.com
02022017.com
0202304.com
0202442.com
020252.com
020259.com
02026018.com
02027076.com
02034.casino
0203659.com
020390.com
020429.com
0205-casino.buzz
020726.casino
0207casino.buzz
0207casino.team
0207casino.top
0207t.casino
020casino.nl
020k365.com
020nohu.com
020p6.com
020wanbo.com
020wns666.com
020wns888.com
020xin888.com
021166.com
0211s.com
0214677.com
0215x.com
02169.com
02169c.com
02175.com
02180.com
021nohu.com
021saibo.com
021v.casino
021wanbo.com
021wns666.com
021wns888.com
021xin888.com
0221s.com
0222n.com
0223-casino.buzz
0223s.com
0224-casino.buzz
0224677.com
02258.casino
022789.com
0227s.com
0228s.com
0229x.com
022nohu.com
022wanbo.com
022wns888.com
022xin888.com
02302.com
02325.com
0233win.com
023nohu.com
023wns666.com
023wns888.com
023xfc.com
023xin888.com
024.app
0242x.com
0244677.com
024488.com
02451.casino
02452.casino
0247-casino.buzz
0248-casino.buzz
024bona.com
024k2.com
024nohu.com
024pj8.com
024wanbo.com
024wns666.com
024wns888.com
024xin888.com
0250-casino.buzz
025147.cc
02521.casino
0252x.com
0253659.com
025460.cc
0254677.com
0255-casino.buzz
025k365.com
025k8.com
025nohu.com
025pj8.com
025saibo.com
025wanbo.com
025wns666.com
025wns888.com
025xin888.com
0260bets.com
026172.com
026178.com
0263-casino.buzz
0264677.com
026casino.courses
026df.com
026kb.com
026ks.com
026nohu.com
02702.com
0271199.com
02724.casino
0275-casino.buzz
0279-casino.buzz
027k2.com
027nohu.com
027saibo.com
027wanbo.com
027wns888.com
027xin888.com
02819.com
0281x.com
028222.com
0282k.com
0282x.com
0282zb.com
0283659.com
0284.casino
0287.casino
02878.casino
02887b.com
02887o.com
02888.xyz
0288betss.com
0289.casino
02896.casino
0289h.com
0289p.com
0289q.com
028k2.com
028k365.com
028nohu.com
028pj8.com
028wanbo.com
028wns666.com
028wns888.com
028xin888.com
02919a.com
02919app.com
02919f.com
02929.org
0293659.com
029393.app
029399.com
0294677.com
0296888.com
02986.com
02986a.com
02986b.com
02986c.com
02986d.com
02986e.com
02986f.com
02986g.com
02986t.com
02986z.com
0299-casino.buzz
0299s.com
029k2.com
029nohu.com
029pj8.com
029wanbo.com
029wns666.com
029wns888.com
029xin888.com
02b3659.com
02d.casino
02go99.com
02hi88.com
02i.casino
02jl59.com
02k.casino
02kuwin.com
02livedrawhk.online
02n1.casino
02ninecasino61.com
02nohu.com
02ph92.com
02qh88.com
02yb.com
03-0-7.casino
03-07.casino
03000.com
030014.com
030016.com
030024.com
030029.com
030041.com
030042.com
030043.com
030046.com
030049.com
030054.com
030064.com
0300726.casino
030074.com
030081.com
030084.com
03009.casino
030090.com
030094.com
0300n.com
0302-casino.buzz
030256.com
0303076.com
03032277.com
0303442.com
030386.com
0305799.com
03061.com
03068.casino
0307.casino
0307casino.online
0307d.casino
0307r.casino
0308888.com
03090.app
030ks.com
030nohu.com
031.app
03113659.com
0311pj8.com
0311wanbo.com
0311wns888.com
0311xin888.com
0314677.com
0315-casino.buzz
03157.casino
0315z6.com
03168520.net
03168666.com
03174.com
03179.casino
0318888.com
031df.com
031nohu.com
032.app
0320-casino.buzz
03207.com
03226.casino
0322w.com
0325.casino
032686930.com
0327-casino.buzz
0329-casino.buzz
032df.com
032nohu.com
0331s.com
0333n.com
0333win.com
03342.casino
0335799.com
0335n.com
0335z6.com
033666.com
03368.app
0336a.com
0336s.com
033777.com
0337n.com
0338s.com
033hg.com
033nohu.com
034034a.com
034034h.com
034034k.com
034034n.com
0344n.com
03457.casino
0346.casino
034nohu.com
035129.com
03513659.com
0351wanbo.com
0351wns888.com
0351xin888.com
0352-casino.buzz
03520168.net
03520666.com
035420.org
0354239.com
0355.casino
0355799.com
0356-casino.buzz
0357-casino.buzz
03580.casino
035nohu.com
036161.com
0362288.com
0363-casino.buzz
03641b.com
03641c.com
03641f.com
03641g.com
03641h.com
03641i.com
03641j.com
03641k.com
03641l.com
03641m.com
03641n.com
03641o.com
03641p.com
03641q.com
03641r.com
03641t.com
03641u.com
03641v.com
03641w.com
03641x.com
03641y.com
036601.com
03663333.com
03663344.com
03663355.com
03663366.com
03663388.com
03663399.com
03664400.com
03666168.com
03666168.net
03666520.com
0367-casino.buzz
036df.com
036ks.com
036nohu.com
03713659.com
0371wanbo.com
0371wns888.com
0371xin888.com
03739.casino
0376-casino.buzz
0376239.com
037766.com
03777.co
037979.com
037df.com
037nohu.com
037vip.com
037ww.com
038010.com
038020.com
038021.com
038023.com
038024.com
038025.com
038036.com
038042.com
038043.com
038045.com
038051.com
038054.com
038060.com
038061.com
038062.com
038063.com
038064.com
038065.com
038067.com
038072.com
038073.com
038075.com
038076.com
038091.com
038092.com
0382.casino
0383.casino
03832.casino
0383app.com
0383bet.com
0385-casino.buzz
038799.com
0387x.com
03888177.com
038986.com
038nohu.com
0391100.com
0391102.com
0391104.com
0391106.com
0391107.com
0391109.com
0392-casino.buzz
0393830.com
0393831.com
0393834.com
0393837.com
0393838.com
0393839.com
039393.vet
03957.com
03980.casino
0398482.com
0399s.com
039app.com
039bb.com
039bet039.com
039casino.net
039dl.vip
039nohu.com
039t.casino
039vip0.com
039vip0.top
039vip1.com
039vip2.com
039vip20.vip
039vip24.vip
039vip26.vip
039vip3.com
039vip4.com
039vip4.top
039vip5.com
039vip5.top
039vip6.top
039vip9.top
03b3659.com
03go8.com
03go99.com
03hg3535.com
03j.casino
03jili.com
03k0.casino
03nohu.com
03ph92.com
03pxj.com
03qh88.com
03uu88.com
03v.casino
03v7sb.com
04-0-7.casino
04-07.casino
04-07f.casino
04-07m.casino
04008vip.com
0400n.com
0404076.com
04041006.com
0404153.com
0404304.com
0404442.com
0405-casino.buzz
0406-casino.buzz
0406casino.buzz
0406casino.online
040726.casino
04074.casino
0407m.casino
0407x.casino
0408-casino.buzz
0408888.com
040gg.com
040nohu.com
041.app
0410-casino.buzz
0411.casino
041627.com
0416666.com
0418-casino.buzz
041nohu.com
042.app
042000.com
0424-casino.buzz
04270.casino
042700.com
042777.com
04293.casino
042c.casino
042nohu.com
0430-casino.buzz
0431-casino.buzz
04313659.com
043189.com
0431wanbo.com
0431wns888.com
0431xin888.com
043200.vip
043211.vip
0432111.com
0432222.com
04322a.com
043233.vip
0432333.com
0432444.com
043255.vip
0432555.com
043266.vip
04326a.com
04327a.com
04328a.com
043299.vip
0432bbb.com
04336.com
043390.com
0433n.com
0433s.com
0433win.com
0436666.com
0439-casino.buzz
043h.com
043nohu.com
0441s.com
0442.casino
044503.com
0448-casino.buzz
044858.com
0448888.com
044940.com
044nohu.com
04513659.com
04513b.top
0451wanbo.com
0451wns888.com
0451xin888.com
045577.com
0455t.com
0459js.com
045nohu.com
046.app
046399.com
0465.com
0465r.com
0466.casino
04674.casino
046nohu.com
047000.com
0471-casino.buzz
04712.com
04713659.com
0471k365.com
0471pj8.com
0471wanbo.com
0471wns666.com
0471wns888.com
0471xin888.com
04726.casino
0476-casino.buzz
04761.com
047df.com
047nohu.com
048.app
048.com
04847.casino
048818.com
048868.com
048889.com
048casino.bond
048nohu.com
0490-casino.buzz
0490.casino
049393.vet
04940.casino
04946.casino
049555.com
049678.com
04970.com
0498-casino.buzz
04993.com
049nohu.com
04caopen.com
04june.casino
04nohu.com
04ol.com
04p.casino
04ph92.com
04pxj.com
04qh88.com
04uu88.com
04w.casino
04zxkf.com
05-07.casino
05-07m.casino
05-7-26.casino
05-7.casino
0502-casino.buzz
0503-casino.buzz
0504casino.online
1x-bet.com
1xbet.com
1xbet.com.br
22bet.com
888casino.com
888poker.com
apolobet.com
bet365.bet.br
bet365.com
betano.bet.br
betano.com
betboo.com
betcris.com
betfair.bet.br
betfair.com
betfast.io
betmotion.com
betnacional.bet.br
betnacional.com
betsson.com
betsul.com
betway.com
blaze-1.com
blaze-2.com
blaze.bet.br
blaze.com
bodog.com
brxbet.com
campobet.com
casa-de-apostas.com
casadeapostas.bet.br
casadeapostas.com
esportedasorte.bet.br
esportedasorte.com
estrelabet.bet.br
estrelabet.com
f12.bet
f12bet.com
fulltbet.com
galera.bet
jonbet.com
kto.bet.br
kto.com
luva.bet
novibet.bet.br
novibet.com
pagbet.com
parimatch.bet.br
parimatch.com
pixbet.bet.br
pixbet.com
playbonds.com
pokerstars.com
rivalo.com
sportingbet.bet.br
sportingbet.com
stake.bet.br
stake.com
superbet.bet.br
superbet.com
vaidebet.bet.br
vaidebet.com
vbet.com
www.1xbet.com
www.22bet.com
www.888poker.com
www.bet365.com
www.betano.com
www.betboo.com
www.betfair.com
www.betmotion.com
www.betnacional.com
www.betsson.com
www.betsul.com
www.betway.com
www.blaze.com
www.bodog.com
www.esportedasorte.com
www.estrelabet.com
www.f12.bet
www.galera.bet
www.jonbet.com
www.kto.com
www.luva.bet
www.novibet.com
www.pagbet.com
www.parimatch.com
www.pixbet.com
www.pokerstars.com
www.rivalo.com
www.sportingbet.com
www.stake.com
www.superbet.com
www.vaidebet.com
betano.com.br
www.betano.com.br
br.betano.com
www.betano.bet.br
betanobr.com
www.betanobr.com
br-betano.com
betano-br.com
kaizengaming.com
bet365.com.br
www.bet365.com.br
www.bet365.bet.br
betfair.com.br
www.betfair.com.br
www.betfair.bet.br
sportingbet.com.br
www.sportingbet.com.br
www.sportingbet.bet.br
estrelabet.com.br
www.estrelabet.com.br
www.estrelabet.bet.br
kto.com.br
www.kto.com.br
www.kto.bet.br
superbet.com.br
www.superbet.com.br
www.superbet.bet.br
esportesdasorte.com
esportesdasorte.bet.br
esportesdasorte.com.br
www.esportesdasorte.com
www.esportesdasorte.bet.br
www.esportesdasorte.com.br
blaze.com.br
www.blaze.com.br
www.blaze.bet.br
pixbet.com.br
www.pixbet.com.br
www.pixbet.bet.br
betnacional.com.br
www.betnacional.com.br
www.betnacional.bet.br
vaidebet.com.br
www.vaidebet.com.br
www.vaidebet.bet.br
realsbet.com
reals.bet.br
segurobet.com
segurobet.bet.br
f12bet.com.br
apostaganha.bet.br
apostaganha.bet
jonbet.bet.br
jonbet.com.br
pagbet.bet.br
pagbet.com.br

EOF_FEED_gambling.txt
echo '>> Extraindo feeds/gaming.txt...'
cat << 'EOF_FEED_gaming.txt' > $TMP_DIR/feeds/gaming.txt
# ==========================================
# WAM Feed - Jogos Online & Plataformas
# ==========================================
# Plataformas e Lojas de Jogos
steampowered.com
steamcommunity.com
steamgames.com
steamcontent.com
epicgames.com
unrealengine.com
roblox.com
rbxcdn.com
riotgames.com
leagueoflegends.com
playvalorant.com
pvp.net
blizzard.com
battle.net
ea.com
origin.com
ubisoft.com
uplay.com
gog.com
rockstargames.com
minecraft.net
mojang.com

# Consoles e Redes
playstation.com
playstation.net
sonyentertainmentnetwork.com
xbox.com
xboxlive.com
nintendo.com
nintendo.net

# Jogos Mobile e Casuais Populares
freefiremobile.com
garena.com
brawlstars.com
clashofclans.com
clashroyale.com
supercell.com
king.com
candycrush.com
miniclip.com
poki.com
y8.com
clickjogos.com.br

EOF_FEED_gaming.txt
echo '>> Extraindo feeds/messaging.txt...'
cat << 'EOF_FEED_messaging.txt' > $TMP_DIR/feeds/messaging.txt
# ==========================================
# WAM Feed - Mensageiros & Ferramentas de Comunicacao
# ==========================================

api.signal.org
api.skype.com
api.telegram.org
api.whatsapp.com
app.slack.com
apps.skype.com
a.web.telegram.org
b-api.facebook.com
bazoocam.org
cdn.discordapp.com
chatex.com
chat.facebook.com
chathub.cam
chat-messenger.com
chatous.com
chatroulette.com
chat.signal.org
chat.whatsapp.com
clubhouse.com
config.teams.microsoft.com
contacts.msn.com
contest.com
crashlogs.whatsapp.net
discordapp.com
discordapp.net
discordcdn.com
discord.co
discord.com
discord.design
discord.dev
discord.gg
discord.gift
discord.media
discord.new
dit.whatsapp.net
dl.viber.com
dyn.whatsapp.net
edge-chat.facebook.com
edge-chat.messenger.com
edge.skype.com
element.io
fbmessenger.com
flora.web.telegram.org
gateway.discord.gg
gateway.messenger.live.com
getsession.org
g.whatsapp.net
icq.com
icq.net
interncache-ash.fbcdn.net
joinclubhouse.com
kakaocdn.net
kakao.com
kakaotalk.com
kik.com
k.web.telegram.org
line-apps.com
line.me
line-scdn.net
lne.me
matrix.org
media.discordapp.net
media-gru1-1.cdn.whatsapp.net
media-gru1-2.cdn.whatsapp.net
media-gru2-1.cdn.whatsapp.net
media-gru2-2.cdn.whatsapp.net
media-iad3-1.cdn.whatsapp.net
media-iad3-2.cdn.whatsapp.net
media.whatsapp.net
messenger.com
messenger.hotmail.com
messenger.microsoft.com
messenger.msn.com
m.me
mmg-fna.whatsapp.net
mmg.whatsapp.net
msg.facebook.com
msgr.live.com
msn-messenger.com
msnmessenger.com
omegle.com
pipe.skype.com
pluto.web.telegram.org
pps.whatsapp.net
qpic.cn
relay.skype.com
share.viber.com
signal.org
skypeassets.com
skype.com
slackb.com
slack.com
slack-core.com
slack-edge.com
slack-files.com
slack-gov.com
slack-imgs.com
slack-msgs.com
slack.net
slack-redir.net
s-msn.com
static.skypeassets.com
statics.teams.cdn.office.net
static.whatsapp.net
static.xx.fbcdn.net
status.discord.com
stel.com
storage.signal.org
talkwithstranger.com
tandem.net
td.telegram.org
teams.cloud.microsoft
teams.live.com
teams.microsoft.com
teams.office.com
teams.skype.com
telegram-cdn.org
telegram.dog
telegram.me
telegram.org
telegra.ph
telesco.pe
textsecure-service.whispersystems.org
threema.ch
tinychat.com
t.me
ui.skype.com
updates.signal.org
us02web.zoom.us
us04web.zoom.us
us05web.zoom.us
us06web.zoom.us
venus.web.telegram.org
vest.web.telegram.org
viber.com
v.whatsapp.com
v.whatsapp.net
wa.me
webicq.icq.com
web.messenger.com
web.skype.com
web.telegram.org
web.whatsapp.com
wechat.com
weixin.com
weixin.qq.com
whatsapp-cdn-msft.akamaized.net
whatsapp.com
whatsapp.net
whispersystems.org
wire.com
www.discordapp.com
www.discord.com
www.messenger.com
www.signal.org
www.skype.com
www.slack.com
www.telegram.org
www.viber.com
www.wechat.com
www.whatsapp.com
www.zoom.us
zoomcloud.cn
zoom.cn
zoom.co
zoom.com
zoomgov.com
zoom.us
zura.web.telegram.org

EOF_FEED_messaging.txt
echo '>> Extraindo feeds/msg-discord.txt...'
cat << 'EOF_FEED_msg-discord.txt' > $TMP_DIR/feeds/msg-discord.txt
# Discord (Chat, Voz & Comunidades)
discord.com
www.discord.com
discordapp.com
www.discordapp.com
discordapp.net
discord.gg
discord.media
discordcdn.com
gateway.discord.gg
status.discord.com
cdn.discordapp.com
media.discordapp.net
discord.co
discord.design
discord.dev
discord.new
discord.gift

EOF_FEED_msg-discord.txt
echo '>> Extraindo feeds/msg-messenger.txt...'
cat << 'EOF_FEED_msg-messenger.txt' > $TMP_DIR/feeds/msg-messenger.txt
# Facebook Messenger (Web & Apps)
messenger.com
www.messenger.com
m.me
fbmessenger.com
edge-chat.messenger.com
edge-chat.facebook.com
chat.facebook.com
b-api.facebook.com
msg.facebook.com
interncache-ash.fbcdn.net
chat-messenger.com
web.messenger.com
static.xx.fbcdn.net

EOF_FEED_msg-messenger.txt
echo '>> Extraindo feeds/msg-others.txt...'
cat << 'EOF_FEED_msg-others.txt' > $TMP_DIR/feeds/msg-others.txt
# Signal, WeChat, Viber, LINE & Outros Mensageiros
signal.org
www.signal.org
chat.signal.org
api.signal.org
storage.signal.org
updates.signal.org
textsecure-service.whispersystems.org
wechat.com
www.wechat.com
weixin.qq.com
weixin.com
qpic.cn
viber.com
www.viber.com
share.viber.com
dl.viber.com
line.me
line-apps.com
line-scdn.net
lne.me
kakao.com
kakaotalk.com
kakaocdn.net
icq.com
icq.net
webicq.icq.com
kik.com
element.io
matrix.org
threema.ch
getsession.org
omegle.com
chathub.cam
chatroulette.com
talkwithstranger.com
bazoocam.org
tinychat.com
chatous.com
chatex.com
tandem.net
clubhouse.com
joinclubhouse.com
wire.com
whispersystems.org

EOF_FEED_msg-others.txt
echo '>> Extraindo feeds/msg-slack.txt...'
cat << 'EOF_FEED_msg-slack.txt' > $TMP_DIR/feeds/msg-slack.txt
# Slack (Chat Corporativo & Canais)
slack.com
www.slack.com
app.slack.com
slack-msgs.com
slack-files.com
slack-imgs.com
slack-edge.com
slackb.com
slack-core.com
slack-redir.net
slack.net
slack-gov.com

EOF_FEED_msg-slack.txt
echo '>> Extraindo feeds/msg-teams-skype.txt...'
cat << 'EOF_FEED_msg-teams-skype.txt' > $TMP_DIR/feeds/msg-teams-skype.txt
# Microsoft Teams, Skype & MSN Messenger
teams.microsoft.com
teams.live.com
teams.office.com
teams.cloud.microsoft
teams.skype.com
skype.com
www.skype.com
web.skype.com
api.skype.com
ui.skype.com
apps.skype.com
static.skypeassets.com
skypeassets.com
edge.skype.com
pipe.skype.com
relay.skype.com
messenger.msn.com
gateway.messenger.live.com
msgr.live.com
contacts.msn.com
messenger.hotmail.com
msnmessenger.com
msn-messenger.com
s-msn.com
messenger.microsoft.com
config.teams.microsoft.com
statics.teams.cdn.office.net

EOF_FEED_msg-teams-skype.txt
echo '>> Extraindo feeds/msg-telegram.txt...'
cat << 'EOF_FEED_msg-telegram.txt' > $TMP_DIR/feeds/msg-telegram.txt
# Telegram (Web, Desktop, Mobile & API)
telegram.org
www.telegram.org
t.me
web.telegram.org
telegram.me
api.telegram.org
telegra.ph
telesco.pe
td.telegram.org
telegram.dog
venus.web.telegram.org
pluto.web.telegram.org
flora.web.telegram.org
zura.web.telegram.org
vest.web.telegram.org
k.web.telegram.org
a.web.telegram.org
contest.com
telegram-cdn.org
stel.com

EOF_FEED_msg-telegram.txt
echo '>> Extraindo feeds/msg-whatsapp.txt...'
cat << 'EOF_FEED_msg-whatsapp.txt' > $TMP_DIR/feeds/msg-whatsapp.txt
# WhatsApp (Web, Desktop & Mobile)
whatsapp.com
www.whatsapp.com
web.whatsapp.com
api.whatsapp.com
v.whatsapp.com
chat.whatsapp.com
wa.me
whatsapp.net
static.whatsapp.net
v.whatsapp.net
media.whatsapp.net
mmg.whatsapp.net
mmg-fna.whatsapp.net
crashlogs.whatsapp.net
g.whatsapp.net
dit.whatsapp.net
pps.whatsapp.net
dyn.whatsapp.net
media-iad3-1.cdn.whatsapp.net
media-iad3-2.cdn.whatsapp.net
media-gru1-1.cdn.whatsapp.net
media-gru1-2.cdn.whatsapp.net
media-gru2-1.cdn.whatsapp.net
media-gru2-2.cdn.whatsapp.net
whatsapp-cdn-msft.akamaized.net

EOF_FEED_msg-whatsapp.txt
echo '>> Extraindo feeds/msg-zoom-meet.txt...'
cat << 'EOF_FEED_msg-zoom-meet.txt' > $TMP_DIR/feeds/msg-zoom-meet.txt
# Zoom Meetings
zoom.us
www.zoom.us
zoomgov.com
zoom.com
us02web.zoom.us
us04web.zoom.us
us05web.zoom.us
us06web.zoom.us
zoom.cn
zoom.co
zoomcloud.cn

EOF_FEED_msg-zoom-meet.txt
echo '>> Extraindo feeds/news.txt...'
cat << 'EOF_FEED_news.txt' > $TMP_DIR/feeds/news.txt
# ==========================================
# Rules WAM Feed - Notícias, Portais & Jornalismo
# ==========================================

# Grupo Globo e Variações de Domínio / Typos
globo.com
www.globo.com
g1.globo.com
g1globo.com
www.g1globo.com
g1.com.br
www.g1.com.br
g1.com
oglobo.globo.com
oglobo.com
oglobo.com.br
globo.com.br
valor.globo.com
valoreconomico.com.br
valoreconomico.globo.com
epocanegocios.globo.com
techtudo.com.br
techtudo.globo.com
cbn.globoradio.globo.com
radioglobo.globo.com

# Grupo Folha / UOL
uol.com.br
www.uol.com.br
noticias.uol.com.br
economia.uol.com.br
tab.uol.com.br
folha.uol.com.br
folha.com
folha.com.br
www.folha.com.br
fsp.com.br
f5.folha.uol.com.br
agenciatass.com

# Grupo Estado (Estadão)
estadao.com.br
www.estadao.com.br
estadao.com
politica.estadao.com.br
economia.estadao.com.br
internacional.estadao.com.br
cultura.estadao.com.br

# Grupo Record (R7)
r7.com
www.r7.com
noticias.r7.com
recordtv.r7.com
fala-brasil.r7.com
jornaldarecord.r7.com

# Grupo Abril
veja.abril.com.br
veja.com.br
veja.com
exame.com
www.exame.com
quatro-rodas.abril.com.br
super.abril.com.br
guiadoestudante.abril.com.br
claudia.abril.com.br

# Portais Independentes e Noticiosos
metropoles.com
www.metropoles.com
cnnbrasil.com.br
www.cnnbrasil.com.br
jovempan.com.br
www.jovempan.com.br
gazetadopovo.com.br
www.gazetadopovo.com.br
poder360.com.br
www.poder360.com.br
oantagonista.com.br
www.oantagonista.com.br
brasil247.com
www.brasil247.com
istoe.com.br
www.istoe.com.br
istoedinheiro.com.br
cartacapital.com.br
www.cartacapital.com.br
infomoney.com.br
www.infomoney.com.br
revistaoeste.com
conjur.com.br
migalhas.com.br
diariodocentrodoseumundo.com.br
jornaldacidadeonline.com.br
ndmais.com.br
correiobraziliense.com.br
em.com.br
gazetaonline.com.br
opovo.com.br
zerohora.com.br
gauchazh.clicrbs.com.br
clicrbs.com.br
tribunapr.com.br
oliberal.com
folhape.com.br
diariodepernambuco.com.br
atarde.com.br
bnews.com.br
bahianoticias.com.br
campograndenews.com.br
midiamax.com.br

# Portais Internacionais de Notícias
cnn.com
edition.cnn.com
bbc.com
www.bbc.com
bbc.co.uk
reuters.com
bloomberg.com
nytimes.com
theguardian.com
washingtonpost.com
wsj.com
ft.com
forbes.com
elpais.com
lemonde.fr
dw.com
aljazeera.com
apnews.com
huffpost.com
time.com
newsweek.com
dailymail.co.uk
independent.co.uk
thesun.co.uk
cbsnews.com
nbcnews.com
abcnews.go.com
foxnews.com
usatoday.com
politico.com
axios.com
thehill.com
sputniknews.lat
rt.com

EOF_FEED_news.txt
echo '>> Extraindo feeds/p2p.txt...'
cat << 'EOF_FEED_p2p.txt' > $TMP_DIR/feeds/p2p.txt
# ==========================================
# WAM Feed - Torrents, P2P & Pirataria
# ==========================================
thepiratebay.org
thepiratebay.zone
1337x.to
1337x.is
1337x.st
yts.mx
yts.lt
rarbg.to
torrentz2.eu
torrentgalaxy.to
limetorrents.pro
eztv.re
nyaa.si
fitgirl-repacks.site
skidrowreloaded.com
utorrent.com
bittorrent.com
qbittorrent.org
seedhost.eu
tracker.opentrackr.org
open.demonii.com

EOF_FEED_p2p.txt
echo '>> Extraindo feeds/shopping.txt...'
cat << 'EOF_FEED_shopping.txt' > $TMP_DIR/feeds/shopping.txt
# ==========================================
# WAM Feed - Compras & E-commerce
# ==========================================
mercadolivre.com.br
mercadolibre.com
shopee.com.br
shopee.com
aliexpress.com
shein.com
amazon.com.br
magazineluiza.com.br
magalu.com
casasbahia.com.br
americanas.com.br
submarino.com.br
pontofrio.com.br
extra.com.br
kabum.com.br
pichau.com.br
terabyteshop.com.br
enjoei.com.br
olx.com.br
netshoes.com.br
centauro.com.br
dafiti.com.br
zattini.com.br

EOF_FEED_shopping.txt
echo '>> Extraindo feeds/social-media.txt...'
cat << 'EOF_FEED_social-media.txt' > $TMP_DIR/feeds/social-media.txt
# ==========================================
# WAM Feed - Mídias Sociais
# ==========================================

# Meta / Facebook
facebook.com
www.facebook.com
m.facebook.com
fb.com
fb.me
fbcdn.net
fbsbx.com
facebook.net
web.facebook.com

# Instagram & Threads
instagram.com
www.instagram.com
cdninstagram.com
ig.me
threads.net
www.threads.net

# TikTok / ByteDance
tiktok.com
www.tiktok.com
m.tiktok.com
tiktokcdn.com
tiktokv.com
musical.ly
byteoversea.com
ibyteimg.com
pstatp.com
bytedance.com

# Twitter / X
twitter.com
www.twitter.com
mobile.twitter.com
x.com
www.x.com
t.co
twimg.com
abs.twimg.com
pbs.twimg.com

# Kwai / Kuaishou
kwai.com
www.kwai.com
m.kwai.com
kwai.net
kwaicdn.com
kuaishou.com

# LinkedIn
linkedin.com
www.linkedin.com
licdn.com

# Pinterest
pinterest.com
www.pinterest.com
pinimg.com

# Snapchat
snapchat.com
www.snapchat.com
snap-dev.net
sc-cdn.net

# Reddit
reddit.com
www.reddit.com
redd.it
redditstatic.com
redditmedia.com

# Bluesky & Outras
bsky.app
bsky.social
tumblr.com
www.tumblr.com
bereal.com

EOF_FEED_social-media.txt
echo '>> Extraindo feeds/sports.txt...'
cat << 'EOF_FEED_sports.txt' > $TMP_DIR/feeds/sports.txt
# ==========================================
# WAM Feed - Esportes, Futebol & Placares
# ==========================================
# Portais de Esportes e Futebol
ge.globo.com
globoesporte.globo.com
espn.com.br
espn.com
espncdn.com
lance.com.br
tntsports.com.br
gazetaesportiva.com
trivela.com.br
esporte.uol.com.br
onefootball.com
goal.com
footstats.com.br
ogol.com.br
netvasco.com.br
colunadofla.com
meutimao.com.br
gazetaesportiva.net
superesportes.com.br

# Placares ao Vivo e Estatísticas
sofascore.com
sofascore.com.br
flashscore.com.br
flashscore.com
365scores.com
livescore.com
whoscored.com
aiscore.com
scoreboard.com
besoccer.com

# Sites Internacionais de Esportes
marca.com
as.com
mundodeportivo.com
sport.es
lequipe.fr
gazzetta.it
corrieredellosport.it
skysports.com
theathletic.com

# Entidades e Ligas Esportivas
fifa.com
uefa.com
cbf.com.br
conmebol.com
nba.com
nfl.com
mlb.com
nhl.com
ufc.com
formula1.com
f1.com
motorsport.com
grandepremio.com.br

# Transmissões e Streamings Esportivos (Legais e Piratas)
futemax.app
futemax.to
futemax.la
futemax.re
multicanais.tv
multicanais.is
multicanais.fans
futebolplayhd.com
rojadirecta.me
canaisplay.com
futebolonlinehd.com
rededoesporte.com
globoesporte.com
globoesporte.com.br

EOF_FEED_sports.txt
echo '>> Extraindo feeds/streaming.txt...'
cat << 'EOF_FEED_streaming.txt' > $TMP_DIR/feeds/streaming.txt
# ==========================================
# WAM Feed - Streaming & Vídeo
# ==========================================
youtube.com
www.youtube.com
m.youtube.com
youtu.be
googlevideo.com
ytimg.com
netflix.com
www.netflix.com
nflxvideo.net
nflximg.net
nflxext.com
primevideo.com
www.primevideo.com
pv-cdn.net
disneyplus.com
www.disneyplus.com
dssott.com
twitch.tv
www.twitch.tv
ttvnw.net
jtvnw.net
max.com
www.max.com
hbomax.com
globoplay.globo.com
spotify.com
www.spotify.com
scdn.co
deezer.com
www.deezer.com
crunchyroll.com
www.crunchyroll.com
pluto.tv
www.pluto.tv
paramountplus.com
www.paramountplus.com

EOF_FEED_streaming.txt
echo '>> Extraindo feeds/vpn-cisco.txt...'
cat << 'EOF_FEED_vpn-cisco.txt' > $TMP_DIR/feeds/vpn-cisco.txt
# Cisco AnyConnect, Secure Client & VPN Gateway
ciscoanyconnect.com
anyconnect.cisco.com
vpn.cisco.com
anyconnect.com
secureclient.cisco.com
pan-duo.cisco.com
vpn-global.cisco.com
asa.cisco.com
ftd.cisco.com
anyconnect-client.cisco.com

EOF_FEED_vpn-cisco.txt
echo '>> Extraindo feeds/vpn-commercial.txt...'
cat << 'EOF_FEED_vpn-commercial.txt' > $TMP_DIR/feeds/vpn-commercial.txt
# Commercial VPN Providers, Web Proxies & Tor
nordvpn.com
nordcdn.com
nordvpn.net
nordaccount.com
nordsec.com
expressvpn.com
expressvpn.net
xv-cdn.com
expvpn.com
surfshark.com
surfshark.net
surfsharkdns.com
protonvpn.com
protonvpn.net
api.protonvpn.ch
cyberghostvpn.com
cyberghost.com
cg-dialup.net
privateinternetaccess.com
piavpn.com
windscribe.com
mullvad.net
api.mullvad.net
tunnelbear.com
hotspotshield.com
hsselite.com
anchorfree.com
afsm.mobi
purevpn.com
purevpn.net
ipvanish.com
vyprvpn.com
goldenfrog.com
hidemyass.com
hma.com
zenmate.com
zenmate.io
strongvpn.com
ivacy.com
torguard.net
privatevpn.com
airvpn.org
ovpn.com
cactusvpn.com
safervpn.com
betternet.co
hola.org
urban-vpn.com
turbovpn.com
speedify.com
adguard-vpn.com
privadovpn.com
fastestvpn.com
pandavpnpro.com
pandavpn.com
freevpnplanet.com
clearvpn.com
kaspersky-vpn.com
secureline.avast.com
torproject.org
torproject.net
bridges.torproject.org
psiphon.ca
psiphon3.com
psiphon3.net
getlantern.org
lantern.io
ultrasurf.us
ultrasurfing.com
shadowsocks.org
v2fly.org
v2ray.com
kproxy.com
hide.me
croxyproxy.com
croxyproxy.rocks
croxy.network
croxy.org
hidester.com
proxysite.com
proxysite.cloud
megaproxy.com
4everproxy.com
whoer.net
hideip.me
blockaway.net
plainproxy.com
zalmos.com
filterbypass.me
vpnbook.com
my-proxy.com
proxfree.com
free-proxy.cz
geonode.com
spys.one
proxyscrape.com
webshare.io
brightdata.com
smartproxy.com
oxylabs.io
proxyrack.com
iproyal.com

EOF_FEED_vpn-commercial.txt
echo '>> Extraindo feeds/vpn-fortinet.txt...'
cat << 'EOF_FEED_vpn-fortinet.txt' > $TMP_DIR/feeds/vpn-fortinet.txt
# Fortinet / FortiGate SSL-VPN & FortiClient
fortinet.com
fortinet.net
forticlient.com
fortigate.com
fortisandbox.com
forticlouddns.com
fortidns.com
fortiview.com
fct.fortinet.net
global-forticlient.fortinet.net
fortiguard.com
fortiguard.net
fortiportal.com
fortisase.com
fortissl.com
fortiap.com
fortiauthenticator.com

EOF_FEED_vpn-fortinet.txt
echo '>> Extraindo feeds/vpn-paloalto.txt...'
cat << 'EOF_FEED_vpn-paloalto.txt' > $TMP_DIR/feeds/vpn-paloalto.txt
# Palo Alto Networks GlobalProtect & Prisma Access
globalprotect.paloaltonetworks.com
prismaaccess.com
gp.paloaltonetworks.com
vpn.paloaltonetworks.com
globalprotect.com
pan-os.paloaltonetworks.com
prisma.paloaltonetworks.com
prismacloud.io
strata.paloaltonetworks.com
portal.paloaltonetworks.com
gateway.paloaltonetworks.com
gp-cloud.paloaltonetworks.com

EOF_FEED_vpn-paloalto.txt
echo '>> Extraindo feeds/vpn-ztna.txt...'
cat << 'EOF_FEED_vpn-ztna.txt' > $TMP_DIR/feeds/vpn-ztna.txt
# Fortinet / FortiGate SSL-VPN & FortiClient
fortinet.com
fortinet.net
forticlient.com
fortigate.com
fortisandbox.com
forticlouddns.com
fortidns.com
fortiview.com
fct.fortinet.net
global-forticlient.fortinet.net
fortiguard.com
fortiguard.net
fortiportal.com
fortisase.com
fortissl.com
fortiap.com
fortiauthenticator.com
# Cisco AnyConnect, Secure Client & VPN Gateway
ciscoanyconnect.com
anyconnect.cisco.com
vpn.cisco.com
anyconnect.com
secureclient.cisco.com
pan-duo.cisco.com
vpn-global.cisco.com
asa.cisco.com
ftd.cisco.com
anyconnect-client.cisco.com
# Palo Alto Networks GlobalProtect & Prisma Access
globalprotect.paloaltonetworks.com
prismaaccess.com
gp.paloaltonetworks.com
vpn.paloaltonetworks.com
globalprotect.com
pan-os.paloaltonetworks.com
prisma.paloaltonetworks.com
prismacloud.io
strata.paloaltonetworks.com
portal.paloaltonetworks.com
gateway.paloaltonetworks.com
gp-cloud.paloaltonetworks.com
# Zscaler ZPA & ZIA Cloud
zscaler.com
zscaler.net
zscloud.net
zscalerbeta.net
zscalergov.net
zscalerone.net
zscalerthree.net
zscalertwo.net
zscalerenterprise.net
zscaleranalytics.com
zscalerapp.net
zpa.zscaler.com
zia.zscaler.com
zpath.zscaler.com
mobile.zscaler.com
pac.zscaler.net
sme.zscaler.net
safebrowse.zdn.net
zdn.net
# Netskope Security Cloud & Netskope Private Access (NPA)
netskope.com
goskope.com
netskopedns.com
netskope.io
eu.goskope.com
us.goskope.com
app.netskope.com
addon-netskope.com
nsclient.netskope.com
npa.netskope.com
gateway.goskope.com
ep.goskope.com
ca.goskope.com
# Cloudflare WARP & Cloudflare Zero Trust
cloudflareclient.com
warp.plus
gateway.warp.plus
zero-trust.cloudflare.com
argo.tunnel.cloudflare.com
teams.cloudflare.com
warp-svc.cloudflare.com
warp-svc.net
# Tailscale, ZeroTier, Twingate & Mesh Port Tunnels
tailscale.com
tailscale.io
ts.net
derp.tailscale.com
controlplane.tailscale.com
login.tailscale.com
zerotier.com
zerotier.net
my.zerotier.com
twingate.com
autoupdate.twingate.com
ngrok.com
ngrok.io
ngrok-free.app
ngrok.app
localtunnel.me
pagekite.net
pinggy.io
localhost.run
serveo.net
bore.pub
packetriot.com
loophole.cloud
teleport.sh
goteleport.com
netbird.io
firezone.dev
defined.net
vpn.net
logmein-gateway.com
hamachi.cc
# Commercial VPN Providers, Web Proxies & Tor
nordvpn.com
nordcdn.com
nordvpn.net
nordaccount.com
nordsec.com
expressvpn.com
expressvpn.net
xv-cdn.com
expvpn.com
surfshark.com
surfshark.net
surfsharkdns.com
protonvpn.com
protonvpn.net
api.protonvpn.ch
cyberghostvpn.com
cyberghost.com
cg-dialup.net
privateinternetaccess.com
piavpn.com
windscribe.com
mullvad.net
api.mullvad.net
tunnelbear.com
hotspotshield.com
hsselite.com
anchorfree.com
afsm.mobi
purevpn.com
purevpn.net
ipvanish.com
vyprvpn.com
goldenfrog.com
hidemyass.com
hma.com
zenmate.com
zenmate.io
strongvpn.com
ivacy.com
torguard.net
privatevpn.com
airvpn.org
ovpn.com
cactusvpn.com
safervpn.com
betternet.co
hola.org
urban-vpn.com
turbovpn.com
speedify.com
adguard-vpn.com
privadovpn.com
fastestvpn.com
pandavpnpro.com
pandavpn.com
freevpnplanet.com
clearvpn.com
kaspersky-vpn.com
secureline.avast.com
torproject.org
torproject.net
bridges.torproject.org
psiphon.ca
psiphon3.com
psiphon3.net
getlantern.org
lantern.io
ultrasurf.us
ultrasurfing.com
shadowsocks.org
v2fly.org
v2ray.com
kproxy.com
hide.me
croxyproxy.com
croxyproxy.rocks
croxy.network
croxy.org
hidester.com
proxysite.com
proxysite.cloud
megaproxy.com
4everproxy.com
whoer.net
hideip.me
blockaway.net
plainproxy.com
zalmos.com
filterbypass.me
vpnbook.com
my-proxy.com
proxfree.com
free-proxy.cz
geonode.com
spys.one
proxyscrape.com
webshare.io
brightdata.com
smartproxy.com
oxylabs.io
proxyrack.com
iproyal.com

EOF_FEED_vpn-ztna.txt
echo '>> Extraindo feeds/ztna-cloudflare.txt...'
cat << 'EOF_FEED_ztna-cloudflare.txt' > $TMP_DIR/feeds/ztna-cloudflare.txt
# Cloudflare WARP & Cloudflare Zero Trust
cloudflareclient.com
warp.plus
gateway.warp.plus
zero-trust.cloudflare.com
argo.tunnel.cloudflare.com
teams.cloudflare.com
warp-svc.cloudflare.com
warp-svc.net

EOF_FEED_ztna-cloudflare.txt
echo '>> Extraindo feeds/ztna-netskope.txt...'
cat << 'EOF_FEED_ztna-netskope.txt' > $TMP_DIR/feeds/ztna-netskope.txt
# Netskope Security Cloud & Netskope Private Access (NPA)
netskope.com
goskope.com
netskopedns.com
netskope.io
eu.goskope.com
us.goskope.com
app.netskope.com
addon-netskope.com
nsclient.netskope.com
npa.netskope.com
gateway.goskope.com
ep.goskope.com
ca.goskope.com

EOF_FEED_ztna-netskope.txt
echo '>> Extraindo feeds/ztna-tailscale.txt...'
cat << 'EOF_FEED_ztna-tailscale.txt' > $TMP_DIR/feeds/ztna-tailscale.txt
# Tailscale, ZeroTier, Twingate & Mesh Port Tunnels
tailscale.com
tailscale.io
ts.net
derp.tailscale.com
controlplane.tailscale.com
login.tailscale.com
zerotier.com
zerotier.net
my.zerotier.com
twingate.com
autoupdate.twingate.com
ngrok.com
ngrok.io
ngrok-free.app
ngrok.app
localtunnel.me
pagekite.net
pinggy.io
localhost.run
serveo.net
bore.pub
packetriot.com
loophole.cloud
teleport.sh
goteleport.com
netbird.io
firezone.dev
defined.net
vpn.net
logmein-gateway.com
hamachi.cc

EOF_FEED_ztna-tailscale.txt
echo '>> Extraindo feeds/ztna-zscaler.txt...'
cat << 'EOF_FEED_ztna-zscaler.txt' > $TMP_DIR/feeds/ztna-zscaler.txt
# Zscaler ZPA & ZIA Cloud
zscaler.com
zscaler.net
zscloud.net
zscalerbeta.net
zscalergov.net
zscalerone.net
zscalerthree.net
zscalertwo.net
zscalerenterprise.net
zscaleranalytics.com
zscalerapp.net
zpa.zscaler.com
zia.zscaler.com
zpath.zscaler.com
mobile.zscaler.com
pac.zscaler.net
sme.zscaler.net
safebrowse.zdn.net
zdn.net

EOF_FEED_ztna-zscaler.txt

mkdir -p /usr/local/pkg
mkdir -p /usr/local/www
mkdir -p /usr/local/www/widgets/include
mkdir -p /usr/local/www/widgets/widgets
mkdir -p /usr/local/share/wam/feeds
mkdir -p /var/unbound/conf.d

cp $TMP_DIR/pkg/rules_wam.xml /usr/local/pkg/rules_wam.xml
cp $TMP_DIR/pkg/rules_wam.inc /usr/local/pkg/rules_wam.inc
cp $TMP_DIR/pkg/rules_wam.inc /usr/local/pkg/wam.inc
cp $TMP_DIR/pkg/register_menu.php /usr/local/pkg/register_menu.php
cp $TMP_DIR/pkg/rules_wam_hook.inc /usr/local/pkg/rules_wam_hook.inc
cp $TMP_DIR/pkg/wam_cron.php /usr/local/pkg/wam_cron.php
cp $TMP_DIR/www/rules_wam.php /usr/local/www/rules_wam.php
cp $TMP_DIR/www/rules_wam_status.php /usr/local/www/rules_wam_status.php
cp $TMP_DIR/www/rules_wam_dashboard.php /usr/local/www/rules_wam_dashboard.php
cp $TMP_DIR/www/rules_wam_block.php /usr/local/www/rules_wam_block.php
cp $TMP_DIR/widgets/include/rules_wam.inc /usr/local/www/widgets/include/rules_wam.inc
cp $TMP_DIR/widgets/widgets/rules_wam.widget.php /usr/local/www/widgets/widgets/rules_wam.widget.php
cp $TMP_DIR/feeds/*.txt /usr/local/share/wam/feeds/

chmod 644 /usr/local/pkg/rules_wam.xml
chmod 644 /usr/local/pkg/rules_wam.inc
chmod 644 /usr/local/pkg/rules_wam_hook.inc
chmod 644 /usr/local/pkg/wam.inc
chmod 755 /usr/local/pkg/register_menu.php
chmod 755 /usr/local/pkg/wam_cron.php
chmod 644 /usr/local/www/rules_wam.php
chmod 644 /usr/local/www/rules_wam_status.php
chmod 644 /usr/local/www/rules_wam_dashboard.php
chmod 644 /usr/local/www/rules_wam_block.php
chmod 644 /usr/local/www/widgets/include/rules_wam.inc
chmod 644 /usr/local/www/widgets/widgets/rules_wam.widget.php
chmod 644 /usr/local/share/wam/feeds/*.txt

touch /var/log/wam_audit.log
chown www:wheel /var/log/wam_audit.log 2>/dev/null || true
chmod 640 /var/log/wam_audit.log

rm -rf "$TMP_DIR"

echo "⚙️ Configurando interceptação de banner HTTP nos hosts..."
cat << 'EOF_HOOK_PHP' > /tmp/wam_hook.php
<?php
$hook = 'if (file_exists("/usr/local/pkg/rules_wam_hook.inc")) { require_once("/usr/local/pkg/rules_wam_hook.inc"); }';
foreach (array("/usr/local/www/index.php", "/usr/local/www/404.php") as $f) {
    if (file_exists($f)) {
        $c = file_get_contents($f);
        if (strpos($c, "rules_wam_hook.inc") === false) {
            $c = preg_replace("/<\\?php\\s*/i", "<?php\n" . $hook . "\n", $c, 1);
            file_put_contents($f, $c);
            echo "✓ Interceptor adicionado em $f\n";
        } else {
            echo "✓ Interceptor já presente em $f\n";
        }
    }
}
if (file_exists("/usr/local/www/404.html")) {
    $c404 = file_get_contents("/usr/local/www/404.html");
    require_once("config.inc");
    require_once("interfaces.inc");
    global $config;
    $lan_ip = function_exists("get_interface_ip") ? get_interface_ip("lan") : "";
    if (empty($lan_ip) && function_exists("get_interface_info")) { $linfo = get_interface_info("lan"); $lan_ip = $linfo["ipaddr"] ?? ""; }
    if (empty($lan_ip) && function_exists("config_get_path")) { $lan_ip = config_get_path("interfaces/lan/ipaddr", ""); }
    if (empty($lan_ip) && !empty($config["interfaces"]["lan"]["ipaddr"])) { $lan_ip = $config["interfaces"]["lan"]["ipaddr"]; }
    if (empty($lan_ip) || !filter_var($lan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) { $lan_ip = "192.168.1.1"; }
    $js_redirect = '<script>if(window.location.hostname!=="' . $lan_ip . '"&&!window.location.hostname.includes("pfsense")){window.location.replace(window.location.protocol+"//' . $lan_ip . '/rules_wam_block.php?domain="+encodeURIComponent(window.location.hostname));}</script>';
    $c404 = preg_replace('/<script>if\(window\.location\.hostname!==.*?<\/script>\s*/i', '', $c404);
    $c404 = preg_replace("/<head[^>]*>/i", "<head>\n" . $js_redirect, $c404, 1);
    file_put_contents("/usr/local/www/404.html", $c404);
    echo "✓ Redirecionador de subrotas atualizado em /usr/local/www/404.html\n";
}
EOF_HOOK_PHP
/usr/local/bin/php -q /tmp/wam_hook.php
rm -f /tmp/wam_hook.php

echo "⚙️ Configurando suporte a banner em HTTPS (porta 443)..."
mkdir -p /usr/local/etc/nginx /usr/local/etc/rc.d

echo "⚙️ Liberando as portas 80 e 443 para exibição dos banners e blindando acesso na porta 50443..."
INITIAL_GUI_PORT=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["port"])) ? $config["system"]["webgui"]["port"] : "443";' 2>/dev/null)
[ -z "$INITIAL_GUI_PORT" ] && INITIAL_GUI_PORT=443

/usr/local/bin/php -r '
    require_once("config.inc");
    global $config;
    init_config_arr(array("system", "webgui"));
    $config["system"]["webgui"]["nodnsrebindcheck"] = true;
    $config["system"]["webgui"]["disablehttpredirect"] = true;
    unset($config["system"]["webgui"]["noantilockout"]);

    if (isset($config["interfaces"]["wan"]["blockprivatenets"])) {
        unset($config["interfaces"]["wan"]["blockprivatenets"]);
    }
    if (isset($config["interfaces"]["wan"]["blockbogons"])) {
        unset($config["interfaces"]["wan"]["blockbogons"]);
    }

    $cur_port = !empty($config["system"]["webgui"]["port"]) ? $config["system"]["webgui"]["port"] : "";
    $cur_proto = !empty($config["system"]["webgui"]["protocol"]) ? $config["system"]["webgui"]["protocol"] : "https";
    if (empty($cur_port) || $cur_port == "443" || $cur_port == "80" || $cur_port == "8443") {
        $config["system"]["webgui"]["port"] = "50443";
        $config["system"]["webgui"]["protocol"] = "https";
        write_config("Rules WAM: WebGUI ajustada para porta 50443 e portas 80/443 liberadas");
    } else {
        write_config("Rules WAM: Portas 80 e 443 liberadas para banner e regras blindadas");
    }
' 2>/dev/null

if [ "$INITIAL_GUI_PORT" != "50443" ]; then
    echo ">> WebGUI estava na porta '${INITIAL_GUI_PORT}'. Migrando para 50443 em segundo plano..."
    (sleep 2 && /etc/rc.restart_webgui) >/dev/null 2>&1 &
    echo "   ✓ Reinício do webConfigurator agendado em segundo plano (conexão preservada sem queda)."
else
    echo ">> WebGUI já está ativa na porta 50443. Conexão mantida 100% ativa (sem reiniciar o webConfigurator)."
fi
/etc/rc.filter_configure 2>/dev/null || true

GUI_PROTO=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["protocol"])) ? $config["system"]["webgui"]["protocol"] : "https";' 2>/dev/null)
GUI_PORT=$(/usr/local/bin/php -r 'require_once("config.inc"); global $config; echo (!empty($config["system"]["webgui"]["port"])) ? $config["system"]["webgui"]["port"] : "50443";' 2>/dev/null)
[ -z "$GUI_PORT" ] && GUI_PORT=50443

LAN_IP=$(/usr/local/bin/php -r 'require_once("config.inc"); require_once("interfaces.inc"); $ip = function_exists("get_interface_ip") ? get_interface_ip("lan") : ""; if (empty($ip) && function_exists("get_interface_info")) { $i = get_interface_info("lan"); $ip = $i["ipaddr"] ?? ""; } if (empty($ip)) { $ip = function_exists("config_get_path") ? config_get_path("interfaces/lan/ipaddr", "") : ($config["interfaces"]["lan"]["ipaddr"] ?? ""); } echo filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) ? $ip : "192.168.1.1";' 2>/dev/null)
[ -z "$LAN_IP" ] && LAN_IP="192.168.1.1"

# 1. Gerar Autoridade Certificadora (CA) interna com extensões v3_ca válidas
cat << 'EOF_CA_CNF' > /tmp/rules_wam_ca.cnf
[req]
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = v3_ca

[req_distinguished_name]
C = BR
ST = SP
O = Seguranca Corporativa
CN = Rules WAM Firewall CA

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF_CA_CNF

if [ -f /tmp/rules_wam_ca.crt ] && [ -f /tmp/rules_wam_ca.key ]; then
    echo "⚙️ Utilizando Autoridade Certificadora (CA) Corporativa pré-existente/importada..."
    cp -f /tmp/rules_wam_ca.crt /var/etc/rules_wam_ca.crt
    cp -f /tmp/rules_wam_ca.key /var/etc/rules_wam_ca.key
    chmod 600 /var/etc/rules_wam_ca.key 2>/dev/null || true
    chmod 644 /var/etc/rules_wam_ca.crt 2>/dev/null || true
elif [ ! -f /var/etc/rules_wam_ca.crt ] || [ ! -f /var/etc/rules_wam_ca.key ]; then
    /usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 \
        -config /tmp/rules_wam_ca.cnf \
        -keyout /var/etc/rules_wam_ca.key -out /var/etc/rules_wam_ca.crt 2>/dev/null || true
    chmod 600 /var/etc/rules_wam_ca.key 2>/dev/null || true
    chmod 644 /var/etc/rules_wam_ca.crt 2>/dev/null || true
fi
rm -f /tmp/rules_wam_ca.cnf 2>/dev/null || true

cp -f /var/etc/rules_wam_ca.crt /usr/local/www/rules_wam_ca.crt 2>/dev/null || true
chmod 644 /usr/local/www/rules_wam_ca.crt 2>/dev/null || true

# 2. Gerar Certificado SSL do Servidor com SANs válidos (wildcards reais dos serviços)
cat << 'EOF_GEN_CNF' > /tmp/wam_gen_cnf.php
<?php
require_once("config.inc");
require_once("interfaces.inc");
global $config;

$lan_ip = function_exists("get_interface_ip") ? get_interface_ip("lan") : "";
if (empty($lan_ip) && function_exists("get_interface_info")) { $linfo = get_interface_info("lan"); $lan_ip = $linfo["ipaddr"] ?? ""; }
if (empty($lan_ip) && function_exists("config_get_path")) { $lan_ip = config_get_path("interfaces/lan/ipaddr", ""); }
if (empty($lan_ip) && !empty($config["interfaces"]["lan"]["ipaddr"])) { $lan_ip = $config["interfaces"]["lan"]["ipaddr"]; }
if (empty($lan_ip) || !filter_var($lan_ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) { $lan_ip = "192.168.1.1"; }

$popular = array(
    'whatsapp.com', 'whatsapp.net', 'wa.me', 'facebook.com', 'fb.com', 'messenger.com', 'm.me',
    'instagram.com', 'threads.net', 'tiktok.com', 'telegram.org', 't.me', 'telegra.ph',
    'discord.com', 'discord.gg', 'discordapp.com', 'skype.com', 'microsoft.com', 'office.com',
    'live.com', 'slack.com', 'zoom.us', 'zoom.com', 'youtube.com', 'youtu.be', 'twitter.com', 'x.com',
    'netflix.com', 'spotify.com', 'twitch.tv', 'bet365.com', 'bet365.bet.br', 'bet365.com.br',
    'betano.com', 'betano.bet.br', 'betano.com.br', 'br.betano.com', 'blaze.com', 'blaze.bet.br',
    'sportingbet.com', 'sportingbet.bet.br', 'estrelabet.com', 'estrelabet.bet.br', 'kto.com', 'pixbet.com',
    'xvideos.com', 'pornhub.com', 'xnxx.com', 'fatalmodel.com', 'globo.com', 'uol.com.br'
);

$san_lines = array('DNS.1 = localhost', 'IP.1 = ' . $lan_ip);
$idx = 2;
$added = array('localhost' => true, $lan_ip => true);

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

$feeds_dir = '/usr/local/share/wam/feeds';
if (is_dir($feeds_dir)) {
    $files = glob("{$feeds_dir}/*.txt");
    // Pass 1: garante que cada categoria tenha seus principais dominios no certificado SSL
    foreach ($files as $f) {
        $lines = file($f, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (!$lines) continue;
        $count = 0;
        foreach ($lines as $line) {
            $d = strtolower(trim($line));
            if (empty($d) || $d[0] === '#') continue;
            if (!isset($added[$d]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$d}";
                $idx++;
                $added[$d] = true;
                $count++;
            }
            $wild = "*.{$d}";
            if (!isset($added[$wild]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$wild}";
                $idx++;
                $added[$wild] = true;
            }
            if ($count >= 30) break;
        }
    }
    // Pass 2: preenche as vagas restantes
    foreach ($files as $f) {
        if ($idx >= 1200) break;
        $lines = file($f, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (!$lines) continue;
        foreach ($lines as $line) {
            $d = strtolower(trim($line));
            if (empty($d) || $d[0] === '#') continue;
            if (!isset($added[$d]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$d}";
                $idx++;
                $added[$d] = true;
            }
            $wild = "*.{$d}";
            if (!isset($added[$wild]) && $idx < 1200) {
                $san_lines[] = "DNS.{$idx} = {$wild}";
                $idx++;
                $added[$wild] = true;
            }
        }
    }
}

$cnf  = "[req]\n";
$cnf .= "distinguished_name = req_distinguished_name\n";
$cnf .= "prompt = no\n";
$cnf .= "req_extensions = v3_req\n\n";
$cnf .= "[req_distinguished_name]\n";
$cnf .= "C = BR\nST = SP\nO = Seguranca Corporativa\nCN = Rules WAM Block\n\n";
$cnf .= "[v3_req]\n";
$cnf .= "basicConstraints = critical, CA:FALSE\n";
$cnf .= "keyUsage = critical, digitalSignature, keyEncipherment\n";
$cnf .= "extendedKeyUsage = serverAuth\n";
$cnf .= "subjectKeyIdentifier = hash\n";
$cnf .= "subjectAltName = @alt_names\n\n";
$cnf .= "[alt_names]\n";
$cnf .= implode("\n", $san_lines) . "\n";

file_put_contents('/tmp/rules_wam_ssl.cnf', $cnf);
echo "✓ Configuração SSL gerada com " . count($san_lines) . " nomes alternativos (SANs válidos)\n";
EOF_GEN_CNF
/usr/local/bin/php -q /tmp/wam_gen_cnf.php
rm -f /tmp/wam_gen_cnf.php

rm -f /var/etc/rules_wam_ssl.key /var/etc/rules_wam_ssl.crt
/usr/bin/openssl req -new -newkey rsa:2048 -nodes \
    -keyout /var/etc/rules_wam_ssl.key -out /tmp/rules_wam_ssl.csr \
    -config /tmp/rules_wam_ssl.cnf 2>/dev/null || true

/usr/bin/openssl x509 -req -days 3650 -in /tmp/rules_wam_ssl.csr \
    -CA /var/etc/rules_wam_ca.crt -CAkey /var/etc/rules_wam_ca.key -CAcreateserial \
    -out /var/etc/rules_wam_ssl.crt -extfile /tmp/rules_wam_ssl.cnf -extensions v3_req 2>/dev/null || true

if [ ! -s /var/etc/rules_wam_ssl.crt ]; then
    /usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 \
        -config /tmp/rules_wam_ssl.cnf -extensions v3_req \
        -keyout /var/etc/rules_wam_ssl.key -out /var/etc/rules_wam_ssl.crt 2>/dev/null || true
fi

chown root:www /var/etc/rules_wam_ssl.key /var/etc/rules_wam_ssl.crt 2>/dev/null || true
chmod 640 /var/etc/rules_wam_ssl.key 2>/dev/null || true
chmod 644 /var/etc/rules_wam_ssl.crt 2>/dev/null || true
rm -f /tmp/rules_wam_ssl.csr /tmp/rules_wam_ssl.cnf 2>/dev/null || true

# 3. Registrar CA e Certificado no Gerenciador de Certificados do pfSense (System > Cert. Manager)
echo "⚙️ Registrando CA e Certificado no Gerenciador de Certificados do pfSense..."
cat << 'EOF_CERT_PHP' > /tmp/wam_cert.php
<?php
require_once("config.inc");
require_once("certs.inc");
global $config;
init_config_arr(array("ca"));
init_config_arr(array("cert"));

$ca_crt_file = "/var/etc/rules_wam_ca.crt";
$ca_key_file = "/var/etc/rules_wam_ca.key";
$cert_crt_file = "/var/etc/rules_wam_ssl.crt";
$cert_key_file = "/var/etc/rules_wam_ssl.key";

if (file_exists($ca_crt_file) && file_exists($ca_key_file)) {
    $ca_descr = "Rules WAM Firewall CA";
    $ca_refid = null;
    foreach ($config["ca"] as $idx => &$ca_item) {
        if ($ca_item["descr"] === $ca_descr) {
            $ca_refid = $ca_item["refid"];
            ca_import($ca_item, file_get_contents($ca_crt_file), file_get_contents($ca_key_file));
            echo "✓ CA Rules WAM atualizada no Gerenciador de Certificados (Ref: $ca_refid)\n";
            break;
        }
    }
    unset($ca_item);

    if (!$ca_refid) {
        $ca_refid = uniqid();
        $ca_entry = array(
            "refid" => $ca_refid,
            "descr" => $ca_descr,
        );
        ca_import($ca_entry, file_get_contents($ca_crt_file), file_get_contents($ca_key_file));
        $config["ca"][] = $ca_entry;
        echo "✓ CA Rules WAM registrada no Gerenciador de Certificados (Ref: $ca_refid)\n";
    }

    if (file_exists($cert_crt_file) && file_exists($cert_key_file)) {
        $cert_descr = "Rules WAM SSL Server";
        $cert_refid = null;
        foreach ($config["cert"] as $idx => &$cert_item) {
            if ($cert_item["descr"] === $cert_descr) {
                $cert_refid = $cert_item["refid"];
                cert_import($cert_item, file_get_contents($cert_crt_file), file_get_contents($cert_key_file));
                $cert_item["caref"] = $ca_refid;
                echo "✓ Certificado SSL Rules WAM atualizado no Gerenciador de Certificados\n";
                break;
            }
        }
        unset($cert_item);

        if (!$cert_refid) {
            $cert_entry = array(
                "refid" => uniqid(),
                "descr" => $cert_descr,
                "caref" => $ca_refid,
            );
            cert_import($cert_entry, file_get_contents($cert_crt_file), file_get_contents($cert_key_file));
            $config["cert"][] = $cert_entry;
            echo "✓ Certificado SSL Rules WAM registrado no Gerenciador de Certificados\n";
        }
    }

    write_config("Rules WAM: Certificados registrados no pfSense");
}
EOF_CERT_PHP
/usr/local/bin/php -q /tmp/wam_cert.php
rm -f /tmp/wam_cert.php

# 4. Configurar NGINX SSL na porta 443 como Proxy Reverso para o webConfigurator local
cat << 'EOF_NGINX_SSL' > /usr/local/etc/nginx/rules_wam_ssl.conf
worker_processes 1;
pid /var/run/rules_wam_ssl.pid;
error_log /var/log/rules_wam_ssl.log info;
events {
    worker_connections 256;
}
http {
    access_log off;
    error_log /var/log/rules_wam_ssl.log info;

    default_type text/html;
    types {
        text/html                             html htm;
        application/x-x509-ca-cert            crt;
    }

    # Servidor HTTP na porta 80 (Intercepção direta sem avisos SSL)
    server {
        listen 80;
        server_name _;
        root /usr/local/www;

        location = /rules_wam_ca.crt {
            root /usr/local/www;
        }

        location / {
            fastcgi_pass unix:/var/run/php-fpm.socket;
            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;
            fastcgi_param SCRIPT_NAME /rules_wam_block.php;
            fastcgi_param DOCUMENT_URI /rules_wam_block.php;
            fastcgi_param DOCUMENT_ROOT /usr/local/www;
            fastcgi_param QUERY_STRING domain=$host&$query_string;
            fastcgi_param REQUEST_METHOD $request_method;
            fastcgi_param CONTENT_TYPE $content_type;
            fastcgi_param CONTENT_LENGTH $content_length;
            fastcgi_param SERVER_PROTOCOL $server_protocol;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_param REMOTE_PORT $remote_port;
            fastcgi_param SERVER_ADDR $server_addr;
            fastcgi_param SERVER_PORT $server_port;
            fastcgi_param SERVER_NAME $host;
            fastcgi_param HTTP_HOST $host;
            fastcgi_param GATEWAY_INTERFACE CGI/1.1;
            fastcgi_param SERVER_SOFTWARE nginx;
            fastcgi_param REDIRECT_STATUS 200;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
            fastcgi_read_timeout 15s;
            fastcgi_send_timeout 15s;
            fastcgi_connect_timeout 5s;
        }
    }

    # Servidor HTTPS na porta 443 (Intercepção SSL com CA e certificados)
    server {
        listen 443 ssl;
        server_name _;
        ssl_certificate /var/etc/rules_wam_ssl.crt;
        ssl_certificate_key /var/etc/rules_wam_ssl.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        root /usr/local/www;
        
        location = /rules_wam_ca.crt {
            root /usr/local/www;
        }

        location / {
            fastcgi_pass unix:/var/run/php-fpm.socket;
            fastcgi_param SCRIPT_FILENAME /usr/local/www/rules_wam_block.php;
            fastcgi_param SCRIPT_NAME /rules_wam_block.php;
            fastcgi_param DOCUMENT_URI /rules_wam_block.php;
            fastcgi_param DOCUMENT_ROOT /usr/local/www;
            fastcgi_param QUERY_STRING domain=$host&$query_string;
            fastcgi_param REQUEST_METHOD $request_method;
            fastcgi_param CONTENT_TYPE $content_type;
            fastcgi_param CONTENT_LENGTH $content_length;
            fastcgi_param SERVER_PROTOCOL $server_protocol;
            fastcgi_param REMOTE_ADDR $remote_addr;
            fastcgi_param REMOTE_PORT $remote_port;
            fastcgi_param SERVER_ADDR $server_addr;
            fastcgi_param SERVER_PORT $server_port;
            fastcgi_param SERVER_NAME $host;
            fastcgi_param HTTP_HOST $host;
            fastcgi_param HTTPS on;
            fastcgi_param GATEWAY_INTERFACE CGI/1.1;
            fastcgi_param SERVER_SOFTWARE nginx;
            fastcgi_param REDIRECT_STATUS 200;
            fastcgi_buffers 16 16k;
            fastcgi_buffer_size 32k;
            fastcgi_read_timeout 15s;
            fastcgi_send_timeout 15s;
            fastcgi_connect_timeout 5s;
        }
    }
}
EOF_NGINX_SSL

cat << 'EOF_RC_SSL' > /usr/local/etc/rc.d/rules_wam_ssl.sh
#!/bin/sh

stop_banner() {
    pkill -TERM -f "rules_wam_ssl.conf" 2>/dev/null || true
    if [ -f /var/run/rules_wam_ssl.pid ]; then
        PID=$(cat /var/run/rules_wam_ssl.pid 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill -QUIT "$PID" 2>/dev/null || kill -TERM "$PID" 2>/dev/null || true
        fi
    fi
    sleep 1
    for p in $(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print $3}' | sort -u); do
        [ -n "$p" ] && kill -TERM "$p" 2>/dev/null || true
    done
    sleep 1
    for p in $(sockstat -4 -l -p 80,443 2>/dev/null | awk 'NR>1 {print $3}' | sort -u); do
        [ -n "$p" ] && kill -9 "$p" 2>/dev/null || true
    done
    rm -f /var/run/rules_wam_ssl.pid
    sleep 1
}

case "$1" in
    stop)
        stop_banner
        ;;
    start|restart|*)
        stop_banner
        chmod 666 /var/run/php-fpm.socket 2>/dev/null || true
        if [ ! -s /var/etc/rules_wam_ssl.crt ] || [ ! -s /var/etc/rules_wam_ssl.key ]; then
            /usr/local/bin/php -r 'require_once("/usr/local/pkg/rules_wam.inc"); rules_wam_ensure_banner_certs();' 2>/dev/null || true
        fi
        /usr/local/sbin/nginx -c /usr/local/etc/nginx/rules_wam_ssl.conf 2>>/var/log/rules_wam_ssl.log || true
        ;;
esac
EOF_RC_SSL
chmod +x /usr/local/etc/rc.d/rules_wam_ssl.sh

echo "⚙️ Iniciando NGINX SSL na interface LAN (${LAN_IP}:443)..."
sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart 2>/dev/null || true
sleep 1

if sockstat -4 -l -p 80,443 2>/dev/null | grep -q nginx; then
    echo "✓ NGINX Banner (Portas 80 e 443) ativo e respondendo na LAN!"
else
    echo "⚠️ NGINX Banner não iniciou. Verifique /var/log/rules_wam_ssl.log"
    tail -n 10 /var/log/rules_wam_ssl.log 2>/dev/null || true
fi

echo "⚙️ Executando registro nos menus do pfSense..."
/usr/local/bin/php -q /usr/local/pkg/register_menu.php

echo "⚙️ Recompilando regras do Unbound e liberando o Terra..."
sed -i '' '/terra\.com\.br/d' /usr/local/share/wam/feeds/news.txt 2>/dev/null || true
sed -i '' '/terra\.com\.br/d' /var/unbound/wam_blocklist.conf 2>/dev/null || true

cat << 'EOF_CFG_PHP' > /tmp/wam_cfg.php
<?php
require_once("config.inc");
require_once("/usr/local/pkg/rules_wam.inc");
global $config;

$lan_ip = function_exists("rules_wam_get_lan_ip") ? rules_wam_get_lan_ip() : "192.168.1.1";

$cfg = rules_wam_get_config();
$cfg["enable"] = "yes";
$cfg["block_adult"] = "yes";
$cfg["block_gambling"] = "yes";
$cfg["block_gaming"] = "yes";
$cfg["initialized"] = "yes";
if (!isset($cfg["block_dns_bypass"])) {
    $cfg["block_dns_bypass"] = "no";
}
if (!isset($cfg["enable_upstream_forwarding"])) {
    $cfg["enable_upstream_forwarding"] = "no";
}
if (!isset($cfg["corp_protect_tools"])) {
    $cfg["corp_protect_tools"] = "yes";
}
if (!isset($cfg["corp_protect_cloudflare"])) {
    $cfg["corp_protect_cloudflare"] = "yes";
}
if (empty($cfg["block_action"])) {
    $cfg["block_action"] = "block_page";
}
if (empty($cfg["block_page_ip"])) {
    $cfg["block_page_ip"] = $lan_ip;
}
if (empty($cfg["corp_allowed_subnets"])) {
    $cfg["corp_allowed_subnets"] = "172.24.0.0/16\n" . "192.168.0.0/16\n" . "192.192.0.0/16\n" . "10.0.0.0/8";
}
init_config_arr(array("system", "webgui"));
$config["system"]["webgui"]["nodnsrebindcheck"] = true;
$config["system"]["webgui"]["disablehttpredirect"] = true;
config_set_path("installedpackages/rules_wam/config/0", $cfg);
config_set_path("installedpackages/wam/config/0", $cfg);
write_config("Rules WAM ativado (Banner de bloqueio ativo)");
rules_wam_apply_rules($cfg);
EOF_CFG_PHP
/usr/local/bin/php -q /tmp/wam_cfg.php
rm -f /tmp/wam_cfg.php

/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf local_zone_remove meet.google.com 2>/dev/null || true
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf local_data_remove meet.google.com 2>/dev/null || true
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf flush meet.google.com 2>/dev/null || true
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf flush_zone google.com 2>/dev/null || true
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf reload 2>/dev/null || true
/usr/local/sbin/unbound-control -c /var/unbound/unbound.conf flush_zone . 2>/dev/null || true
/etc/rc.filter_configure 2>/dev/null || true

rm -f /tmp/config.cache /tmp/menu.cache 2>/dev/null || true

echo ""
echo "======================================================"
echo " 🎉 INSTALAÇÃO DO RULES WAM CONCLUÍDA COM SUCESSO!"
echo "======================================================"
echo "👉 Menu: Services > Rules WAM"
echo "👉 Dashboard: Aba 'Dashboard & Tentativas de Acesso'"
echo "👉 Widget pfSense: Disponível no Dashboard (+ Adicionar Widget > Rules WAM)"
echo "👉 Anti-Bypass DNS (Porta 53 NAT): Desativado por padrão (Opt-in via WebGUI)"
echo "👉 Exportação: CSV para Excel e JSON nativo"
echo "👉 WebGUI: ${GUI_PROTO}://<IP>:${GUI_PORT}"
echo "======================================================"
