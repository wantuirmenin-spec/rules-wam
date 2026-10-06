# 🛡️ Manual do Administrador & Guia de Implantação
## Rules WAM — Web Access Manager para pfSense
**Versão:** 1.4.0  
**Compatibilidade:** pfSense CE 2.7.x / 2.8.x / pfSense Plus  
**Plataforma Base:** FreeBSD / Unbound DNS / NGINX (banner HTTP)  

> [!WARNING]
> **Não testado ainda em pfSense real — validar em laboratório.** Veja as pendências no [CHANGELOG](CHANGELOG.md).  

---

## 📑 Sumário

1. [Visão Geral do Sistema](#1-visão-geral-do-sistema)
2. [Arquitetura Técnica & Fluxo de Bloqueio](#2-arquitetura-técnica--fluxo-de-bloqueio)
3. [Catálogo de Categorias & Feeds](#3-catálogo-de-categorias--feeds)
4. [Recursos Corporativos Avançados](#4-recursos-corporativos-avançados)
   - [Agendamento Comercial & Intervalo de Almoço](#41-agendamento-comercial--intervalo-de-almoço)
   - [Isenção de Dispositivos (Bypass IPs via Unbound Views)](#42-isenção-de-dispositivos-bypass-ips-via-unbound-views)
   - [Integração com Active Directory & NPS RADIUS (VPN IPsec)](#43-integração-com-active-directory--nps-radius-vpn-ipsec)
   - [Proteção Netskope Security Cloud & IdP](#44-proteção-netskope-security-cloud--idp)
   - [Anti-Bypass DNS (Porta 53 NAT Redirection)](#45-anti-bypass-dns-porta-53-nat-redirection---recurso-opcional--opt-in)
   - [Integração com Servidores DNS Google (8.8.8.8) & Cloudflare (1.1.1.1)](#46-integração-com-servidores-dns-google-8888--cloudflare-1111)
   - [Modo de Bloqueio: Banner Educativo (Padrão) vs Modo Silencioso](#47-modo-de-bloqueio-banner-educativo-padrão-vs-modo-silencioso)
   - [Auto-Whitelist de Ferramentas de TI e Downloads de Administrador (PuTTY, etc.)](#48-auto-whitelist-de-ferramentas-de-ti-e-downloads-de-administrador-putty-etc)
   - [Proteção da Infraestrutura Cloudflare & Ajuste Fino ZTNA](#49-proteção-da-infraestrutura-cloudflare--ajuste-fino-ztna)
   - [Auto-Whitelist & Proteção de Helpdesk, ITSM & Suporte Remoto (Zendesk, GLPI, ScreenConnect)](#410-auto-whitelist--proteção-de-helpdesk-itsm--suporte-remoto-zendesk-glpi-screenconnect)
   - [Proteção de Telefonia IP, PABX Cloud, Protocolo SIP & Aparelhos SIP Phone](#411-proteção-de-telefonia-ip-pabx-cloud-protocolo-sip--aparelhos-sip-phone)
   - [Acesso Administrativo à WebGUI & Regras de Firewall](#412-acesso-administrativo-à-webgui--regras-de-firewall)
5. [Auditoria, Logs & Dashboard Forense](#5-auditoria-logs--dashboard-forense)
6. [Guia de Implantação em Novos Firewalls (Passo a Passo)](#6-guia-de-implantação-em-novos-firewalls-passo-a-passo)
   - [Pré-Requisitos](#61-pré-requisitos)
   - [Métodos de Transferência do Instalador Standalone](#62-métodos-de-transferência-do-instalador-standalone)
   - [Execução da Instalação](#63-execução-da-instalação)
   - [Validação da Instalação](#64-validação-da-instalação)
7. [Banner Somente HTTP (Sem CA nas Estações)](#7-banner-somente-http-sem-ca-nas-estações)
8. [Operação Diária & WebGUI](#8-operação-diária--webgui)
9. [Troubleshooting & Manutenção](#9-troubleshooting--manutenção)
10. [Procedimento de Desinstalação](#10-procedimento-de-desinstalação)

---

## 1. Visão Geral do Sistema

O **Rules WAM** (*Web Access Manager*) é uma solução nativa desenvolvida para o **pfSense** que transforma o firewall em um avançado controlador de conteúdo e segurança corporativa através de filtragem DNS em alta performance no Unbound.

### Principais Benefícios:
- **Zero Dependência de Proxy Pesado:** Não utiliza Squid nem consome gigabytes de RAM com cache HTTP. Toda a filtragem ocorre em microssegundos no motor nativo do Unbound DNS.
- **Página de Bloqueio Educativa (HTTP):** Quando um usuário acessa por HTTP um domínio restrito, recebe uma tela institucional explicando o bloqueio, identificando seu computador (IP e Hostname), horário e a categoria. Acessos HTTPS recebem erro de conexão imediato (não há CA nas estações — ver [seção 7](#7-banner-somente-http-sem-ca-nas-estações)).
- **Tolerância Zero a Bypasses:** Bloqueia servidores de DoH (*DNS over HTTPS*) públicos e serviços de VPN/ZTNA que os funcionários costumam utilizar para burlar regras corporativas.
- **Autônomo & Standalone:** Empacotado em um único instalador auto-extraível (`wam-install.sh`) que executa o mesmo `install.sh` do pacote, com detecção automática da interface LAN.
- **Mínimo de alterações no firewall:** não cria regras na WAN por padrão, não desliga bogons/redes privadas/DNS rebind e não altera arquivos do núcleo do pfSense.

---

## 2. Arquitetura Técnica & Fluxo de Bloqueio

```
                                 [ Computador / Estação do Usuário ]
                                                 │
                             Consulta DNS para site restrito (ex: tiktok.com)
                                                 ▼
                                     [ pfSense - Unbound DNS ]
                                                 │
                    ┌────────────────────────────┴────────────────────────────┐
                    │                                                         │
         IP está em Bypass IPs?                                     IP Comum da Rede
                    │                                                         │
                   SIM                                                       NÃO
                    ▼                                                         ▼
          [ view wam_bypass ]                                      [ Zonas de bloqueio ]
   Resolve normalmente (host overrides                     Responde o IP do banner (ou 0.0.0.0
   e registros DHCP continuam valendo)                     no modo silencioso)
                                                                              │
                                                               ┌──────────────┴──────────────┐
                                                               │                             │
                                                          HTTP (80)                     HTTPS (443)
                                                               │                             │
                                                  NGINX do banner (só no IP        NGINX do banner recusa
                                                  do banner) → PHP-FPM             o handshake TLS
                                                               │                   (erro de conexão
                                                               ▼                    no navegador)
                                                  [ rules_wam_block.php ]
                                              Exibe Banner de Bloqueio Corporativo
                                              Registra em /var/log/wam_audit.log
```

### Componentes Internos do Pacote:
| Componente | Caminho no pfSense | Finalidade |
|---|---|---|
| **Definição de Pacote** | `/usr/local/pkg/rules_wam.xml` | Integração de menus, abas e formulários na WebGUI |
| **Motor de Regras** | `/usr/local/pkg/rules_wam.inc` | Compilador de listas, zonas do Unbound, view de bypass, regras de firewall/NAT e banner |
| **Instalação / Remoção** | `/usr/local/pkg/wam_setup.php` | Aplica e reverte as alterações no config.xml (usado por `install.sh` e `uninstall.sh`) |
| **Privilégios** | `/etc/inc/priv/rules_wam.priv.inc` | Permite delegar o acesso às telas do pacote a outros usuários/grupos |
| **Configuração do Unbound** | `/var/unbound/wam_blocklist.conf` | Zonas de bloqueio geradas (incluídas por curinga: `include: /var/unbound/wam_blocklist*.conf`) |
| **NGINX do Banner** | `/usr/local/etc/nginx/rules_wam_ssl.conf` + `/usr/local/etc/rc.d/rules_wam_ssl.sh` | Instância NGINX dedicada que escuta **só no IP do banner**: 80 → página de bloqueio; 443 → recusa o TLS |
| **Agendador Cron** | `/usr/local/pkg/wam_cron.php` | A cada 5 min aplica/suspende o bloqueio conforme horário e almoço |
| **Página de Bloqueio** | `/usr/local/www/rules_wam_block.php` | Página apresentada ao usuário bloqueado |
| **Dashboard & Auditoria**| `/usr/local/www/rules_wam_dashboard.php`| Painel com métricas e exportação CSV/JSON |
| **Listas de Bloqueio** | `/usr/local/share/wam/feeds/*.txt` | 28 arquivos de feed das 12 categorias |
| **Desinstalador** | `/usr/local/share/wam/uninstall.sh` | Remove o pacote revertendo a configuração |

---

## 3. Catálogo de Categorias & Feeds

O Rules WAM possui **12 macro-categorias** prontas para ativação imediata:

### 1. 🔞 Conteúdo Adulto & Pornografia (`block_adult`)
- Sites de conteúdo explícito, canais adultos, webcams e plataformas de assinatura: *Pornhub, XVideos, XNXX, RedTube, YouPorn, XHamster, SpankBang, Erome, Beeg, Brazzers, Chaturbate, Stripchat, OnlyFans, Fansly, Privacy, Fatal Model*, etc.
- Feed: `adult.txt` (~41 KB).

### 2. 🎲 Apostas, Bets & Cassinos Online (`block_gambling`)
- Casas de apostas esportivas, cassinos virtuais, jogos de azar: *Bet365, Betano, Sportingbet, Blaze, Stake, Pixbet, EstrelaBet, Superbet, Novibet, KTO, Betfair, 1xBet*, etc.
- Feed: `gambling.txt` (~20 KB).

### 3. 📰 Notícias, Portais & Jornalismo (`block_news`)
- Portais de notícias nacionais e internacionais: *G1, UOL, Folha de S.Paulo, Estadão, CNN Brasil, R7, Metrópoles, Jovem Pan, Gazeta do Povo, Poder360, Veja, Exame, BBC, Reuters, Bloomberg, The Guardian, El País*, etc.
- Feed: `news.txt`.

### 4. 📱 Mídias Sociais (`block_social`)
- Redes sociais e plataformas de relacionamento: *Facebook, Instagram, Threads, TikTok, Twitter/X, Kwai, LinkedIn, Pinterest, Reddit, Bluesky*, etc.
- Feed: `social-media.txt`.

### 5. ⚽ Esportes & Placares ao Vivo (`block_sports`)
- Portais de esportes, transmissões online e placares: *GE (Globo Esporte), ESPN, Lance!, TNT Sports, Flashscore, SofaScore, 365Scores, LiveScore, FIFA, UEFA, Futemax, Multicanais*, etc.
- Feed: `sports.txt`.

### 6. 🎮 Jogos Online & Plataformas (`block_gaming`)
- Lojas de jogos, launchers e jogos mobile/web: *Steam, Epic Games, Roblox, Riot Games (League of Legends, Valorant), Blizzard Battle.net, Minecraft, EA App, Ubisoft Connect, Xbox Live, PlayStation Network, Free Fire, Brawl Stars, Poki, Y8*, etc.
- Feed: `gaming.txt`.

### 7. 🎬 Streaming & Vídeo (`block_streaming`)
- Plataformas de streaming de filmes, séries e música: *YouTube, Netflix, Prime Video, Disney+, Twitch, TikTok Live, Spotify, Deezer, Pluto TV, Max (HBO)*, etc.
- Feed: `streaming.txt`.

### 8. 🛍️ Compras & E-commerce (`block_shopping`)
- Marketplaces e lojas virtuais: *Mercado Livre, Shopee, AliExpress, Shein, Amazon, Magalu, Casas Bahia, Americanas, Kabum, Pichau, OLX, Enjoei*, etc.
- Feed: `shopping.txt`.

### 9. ⚡ Torrents & Redes P2P (`block_p2p`)
- Portais de download torrent e trackers públicos: *The Pirate Bay, 1337x, YTS, Torrentz, BitTorrent, uTorrent trackers*, etc.
- Feed: `p2p.txt`.

### 10. 🚫 Anti-Bypass / Provedores DoH (`block_doh`)
- Servidores públicos de DNS-over-HTTPS utilizados por navegadores e celulares para fugir do DNS local: *Cloudflare 1.1.1.1, Google 8.8.8.8, Quad9 9.9.9.9, OpenDNS, AdGuard DoH*, etc.
- Feed: `doh-providers.txt`.
- Com esta categoria marcada, também é criada uma regra *reject* para DNS-over-TLS (porta **853**).

### 11. 🔒 VPN, ZTNA & Proxies Anônimos (`block_vpn`)
Controle modular permitindo ativar a categoria geral ou **isolar fornecedores específicos**:
- `block_vpn_fortinet`: Portais e servidores FortiClient SSL-VPN.
- `block_vpn_cisco`: Cisco AnyConnect e Cisco Secure Client.
- `block_vpn_paloalto`: Palo Alto GlobalProtect e Prisma Access.
- `block_ztna_zscaler`: Zscaler Private Access (ZPA) e nós ZIA.
- `block_ztna_netskope`: Netskope Private Access (*protegido por padrão*).
- `block_ztna_cloudflare`: Clientes Cloudflare WARP e túneis Zero Trust.
- `block_ztna_tailscale`: Tailscale, ZeroTier, Twingate, Ngrok, Localtunnel.
- `block_vpn_commercial`: NordVPN, ExpressVPN, Surfshark, CyberGhost, ProtonVPN, Tor, etc.

### 12. 💬 Mensageiros & Chat de Comunicação (`block_messaging`)
Controle granular por aplicativo:
- `block_msg_whatsapp`: WhatsApp Web, APIs e conectividade móvel. Além do DNS, cria regra *reject* nas portas **5222/4244** (a 5223, push da Apple, não é bloqueada). A opção **"Bloquear também por faixa IP"** (`block_wa_by_ip`) vem **desligada**: as faixas são da Meta e afetam Facebook/Instagram.
- `block_msg_telegram`: Telegram Web, APIs e aplicativo desktop.
- `block_msg_messenger`: Facebook Messenger e chats web.
- `block_msg_teams_skype`: Microsoft Teams e Skype.
- `block_msg_discord`: Servidores e chamadas Discord.
- `block_msg_slack`: Workspaces e chat Slack.
- `block_msg_zoom_meet`: Salas Zoom e reuniões Google Meet.
- `block_msg_others`: Signal, WeChat, Viber, LINE, KakaoTalk, Omegle.

---

## 4. Recursos Corporativos Avançados

### 4.1. Agendamento Comercial & Intervalo de Almoço
O Rules WAM implementa gestão temporal inteligente:
- **Horário de Bloqueio Ativo:** Define a faixa de horário em que as restrições devem operar (exemplo: das `08:00` às `18:00`).
- **Pausa de Almoço Automática:** Permite estipular um intervalo de liberação automática (exemplo: das `12:00` às `13:30`). Durante esse período, o Cron do firewall suspende o arquivo de bloqueio no Unbound (`wam_blocklist.conf`). Às 13:30 (no próximo ciclo de 5 min), o bloqueio volta sozinho.
- **Regras de firewall também seguem o horário:** fora do horário, as regras de WhatsApp, DoT e o NAT da porta 53 são suspensos (as regras de acesso à WebGUI permanecem).
- **Horários validados:** `8:00` vira `08:00`; janelas que passam da meia-noite (ex.: `22:00`–`06:00`) são suportadas.
- **Fins de Semana:** Opção para manter bloqueado aos sábados e domingos ou liberar a rede completamente.

### 4.2. Isenção de Dispositivos (Bypass IPs via Unbound Views)
Para computadores da Diretoria, Suporte Técnico ou servidores que não devem passar pelo filtro:
- Insira os endereços IP na caixa **IPs Isentos (Bypass IPs)**, um por linha ou separados por vírgula (ex: `192.168.1.50`, `192.168.1.100` ou até faixas CIDR como `192.168.10.0/24`).
- O sistema gera no `/var/unbound/wam_blocklist.conf` uma *view* do Unbound:
  ```
    # IPs isentos (bypass) - usam a view wam_bypass
    access-control-view: 192.168.1.50/32 "wam_bypass"
    access-control-view: 192.168.10.0/24 "wam_bypass"
  view:
    name: "wam_bypass"
    view-first: no
    local-zone: "wam-bypass.invalid." static
    include: /var/unbound/host_entries.con[f]
    include: /var/unbound/dhcpleases_entries.con[f]
  server:
  ```
- **Como funciona:** com `view-first: no`, os clientes da view **não** consultam as zonas globais (onde estão os bloqueios). Os `include` trazem para a view os host overrides e os registros DHCP do pfSense, então os nomes locais continuam resolvendo para os IPs isentos. Os curingas (`.con[f]`) evitam erro se os arquivos não existirem.
- **Validação:** a configuração passa pelo `unbound-checkconf`. Se a view for rejeitada, o bloqueio é aplicado sem ela e o erro fica em `/var/log/wam_checkconf_err.log`.

### 4.3. Integração com Active Directory & NPS RADIUS (VPN IPsec)
Em ambientes corporativos e filiais conectadas via túnel IPsec com a Matriz:
- **Split-DNS Automático:** O Rules WAM cria entradas em **Services > DNS Resolver > Domain Overrides** (descrição `Rules WAM: ...`) para os domínios do AD apontando para os controladores de domínio (ex: `empresa.local` → `10.0.0.10`, `10.0.0.11`). O pfSense gera a partir delas as `forward-zone` do Unbound. Overrides manuais existentes são preservados.
- **Prevenção de Falhas de Logon & GPO:** A proteção global contra DNS rebind do pfSense **não é desligada**. O Rules WAM adiciona exceções somente para os domínios do AD informados:
  ```
  private-domain: "empresa.local"
  domain-insecure: "empresa.local"
  private-domain: "in-addr.arpa"
  domain-insecure: "in-addr.arpa"
  ```
- **Redes Autorizadas:** o campo de redes corporativas gera `access-control: <rede> allow` no Unbound. Padrão: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- **NPS RADIUS & Zonas Reversas (`in-addr.arpa`):** Servidores RADIUS (como o Microsoft NPS para 802.1X em Wi-Fi e switches gerenciados) dependem fortemente de consultas DNS reversas (`PTR`) para identificar nomes de computadores e validar políticas de acesso. O encaminhamento condicional de zonas `in-addr.arpa` impede atrasos (timeouts de 5 a 10 segundos) e quedas na autenticação de rede.
- **Whitelist Automática:** O domínio corporativo é automaticamente blindado e inserido na lista branca do Rules WAM, impossibilitando qualquer bloqueio acidental de serviços internos (Kerberos porta 88, LDAP porta 389/636, Global Catalog porta 3268, SMB porta 445).

### 4.4. Proteção Netskope Security Cloud & IdP
- A opção **Auto-Whitelist Netskope & IdP** vem habilitada por padrão e garante que os agentes Netskope Client (`goskope.com`, `netskope.com`, `netskopedns.com`, ...) nunca sejam bloqueados.
- **IdP restrito aos endpoints de login:** `login.microsoftonline.com`, `login.microsoft.com`, `login.live.com`, `login.windows.net`, `device.login.microsoftonline.com`, `autologon.microsoftazuread-sso.com`, `msftauth.net`, `msauth.net`, `aadcdn.msftauthimages.net`, `msftidentity.com`, `msidentity.com`, `okta.com`, `oktacdn.com`, `okta-emea.com`, `accounts.google.com`. Domínios inteiros como `microsoft.com`, `office.com` e `windows.net` **não** são liberados (isso anulava o bloqueio de Teams/Skype).

### 4.5. Anti-Bypass DNS (Porta 53 NAT Redirection - Recurso Opcional / Opt-in)
- **Status Padrão:** **Desativado por padrão (Opt-in).** Qualquer modificação em regras de redirecionamento NAT afeta diretamente o fluxo de pacotes da rede local, devendo ser ativada apenas após validação consciente do administrador.
- **O Problema do Bypass:** Quando um colaborador altera manualmente o servidor DNS na placa de rede para `8.8.8.8` ou `1.1.1.1`, as consultas deixam de passar pelo Unbound do pfSense.
- **Como Opera quando Ativado:** O sistema cria, em cada interface interna, uma regra em **Firewall > NAT > Port Forward** capturando consultas na porta 53 (UDP/TCP) destinadas a outros servidores e redirecionando para `127.0.0.1:53` (Unbound local). Fora do horário de bloqueio, o NAT é suspenso.
- **Exceção Automática para Controladores de Domínio (`WAM_Corp_AD_DNS`):** Quando a integração corporativa estiver ativa, o Rules WAM cria uma regra de exceção no NAT (`nordr`) e uma regra *pass* na porta 53 para os IPs configurados em `corp_ad_dns_ips` (alias `WAM_Corp_AD_DNS`). Assim, consultas ao AD e registros dinâmicos (RFC 2136 / Netlogon) continuam passando direto sem interceptação.

#### Checklist de Homologação antes de Ativar em Produção:
Antes de marcar a opção **"Forçar DNS Local (Porta 53 Anti-Bypass)"** na WebGUI em uma unidade produtiva, realize os seguintes testes em uma estação piloto:
1. `[ ]` **Resolução Interna:** Executar `nslookup` para o controlador de domínio da Matriz.
2. `[ ]` **Logon e Políticas de Domínio:** Executar `gpupdate /force` no Windows e verificar se as diretivas aplicam sem erros.
3. `[ ]` **Autenticação NPS RADIUS:** Conectar um dispositivo no Wi-Fi corporativo (802.1X) e validar se a autenticação é imediata.
4. `[ ]` **Navegação Normal:** Testar acesso a sites institucionais e ferramentas de trabalho corporativas.
5. `[ ]` **Teste de Bloqueio de Bypass:** Na estação de testes, configure manualmente o DNS da placa de rede para `8.8.8.8` e tente acessar um domínio restrito. A consulta deve retornar o IP do banner (ou 0.0.0.0 no modo silencioso).

### 4.6. Integração com Servidores DNS Google (8.8.8.8) & Cloudflare (1.1.1.1)
É muito comum em ambientes corporativos o uso dos servidores DNS Anycast do Google (`8.8.8.8`, `8.8.4.4`) e Cloudflare (`1.1.1.1`, `1.0.0.1`). O Rules WAM trata esses servidores em duas frentes complementares:

1. **Proteção Anti-Bypass de Clientes (Dispositivos com 8.8.8.8 / 1.1.1.1 fixos na placa de rede):**
   - Ao ativar a opção **"Anti-Bypass DNS (Porta 53)"** na WebGUI do WAM, o firewall intercepta automaticamente via NAT Port Forward qualquer consulta UDP/TCP enviada a servidores externos como 8.8.8.8 ou 1.1.1.1 e a redireciona para o Unbound local (`127.0.0.1:53`).
   - O dispositivo recebe a resposta normalmente como se tivesse vindo do 8.8.8.8, mas todas as políticas e bloqueios de categorias do WAM são aplicados.
   - Com a categoria **Anti-Bypass DoH** marcada, o Rules WAM bloqueia DoH (por DNS, ex.: `dns.google`, `cloudflare-dns.com`) e DoT (regra *reject* na porta 853), forçando a queda para a porta 53 interceptada.
   - Inclui o canário oficial da Mozilla (`use-application-dns.net`) que instrui o Firefox e outros navegadores a desligar o DoH e obedecer ao firewall da rede.

2. **Forwarding Upstream (Google & Cloudflare):**
   - A opção **"Forwarding Upstream (Google & Cloudflare)"** foi removida na versão 1.4.0: ela nunca configurou encaminhamento de fato (só aparecia na aba Status).
   - Para encaminhar as consultas a 8.8.8.8 / 1.1.1.1, use os recursos nativos do pfSense: servidores em **System > General Setup > DNS Servers** e **Enable Forwarding Mode** em **Services > DNS Resolver**. Os bloqueios do WAM e os Domain Overrides do AD continuam valendo.

### 4.7. Modo de Bloqueio: Banner Educativo (Padrão) vs Modo Silencioso

O Rules WAM oferece dois modos de bloqueio configuráveis em **Ação de Bloqueio**:

1. 👉 **Exibir Banner de Bloqueio da Empresa (HTTP) (`block_page`) — [PADRÃO]**
   - **Como Opera:** o Unbound responde com o **IP do banner** (campo *IP do Firewall para o Banner*, que precisa ser o IP de uma interface interna; padrão: IP da LAN).
   - Conexões **HTTP (80)** chegam ao NGINX dedicado do banner, que escuta **só nesse IP**, e são encaminhadas ao `rules_wam_block.php`.
   - Conexões **HTTPS (443)** têm o handshake TLS recusado na hora (`ssl_reject_handshake`): o navegador mostra erro de conexão, sem aviso de certificado. Ver [seção 7](#7-banner-somente-http-sem-ca-nas-estações).
   - **Requisito:** WebGUI fora das portas 80/443 e com o redirecionamento HTTP desativado. Se houver conflito, o pacote **não mexe na WebGUI**: o bloqueio passa automaticamente para o modo silencioso (0.0.0.0) e a aba **Status & Teste de Bloqueio** mostra um aviso. Para resolver, mova a porta em **System > Advanced > Admin Access** ou reinstale com `--move-gui`.
   - **Proteções do NGINX do banner:** roda como o NGINX da WebGUI (`user root wheel`), limita requisições por cliente (5 req/s), aceita só GET/HEAD e não repassa cabeçalhos do cliente. A página usa apenas `REMOTE_ADDR` e o `Host` validado; `X-Forwarded-*` e `?domain=` são ignorados.
   - **E-mail do Suporte (Banner):** se preenchido, o banner mostra o botão "Contatar Suporte TI" (mailto com domínio, host e IP). Em branco, o botão não aparece.
   - **Vantagem:** o usuário vê a política corporativa, a categoria, o horário e a identificação do dispositivo.

2. **Retornar 0.0.0.0 (Silencioso — `always_null`)**
   - O Unbound responde diretamente com `0.0.0.0` (IPv4) ou `::` (IPv6).
   - O navegador recebe recusa de conexão imediata (`ERR_CONNECTION_REFUSED`).
   - **Vantagem:** dispensa o banner e a liberação das portas 80/443.

### 4.8. Auto-Whitelist de Ferramentas de TI e Downloads de Administrador (PuTTY, etc.)

Equipes de TI e administradores de rede frequentemente precisam baixar e atualizar utilitários essenciais de diagnóstico, acesso remoto e desenvolvimento. Para evitar que feeds amplos ou regras de downloads afetem a operação técnica:

- **Configuração:** Opção **"Auto-Whitelist Ferramentas TI & Admin (PuTTY, etc.)"** (`corp_protect_tools`), ativada por padrão (`yes`).
- **Escopo Protegido:**
  - **PuTTY & Utilitários SSH:** `putty.org`, `chiark.greenend.org.uk`, `the.earth.li`, `tartarus.org`.
  - **Transferência de Arquivos & Diagnóstico:** `winscp.net`, `filezilla-project.org`, `wireshark.org`, `nmap.org`, `dbeaver.io`.
  - **Utilitários de Sistema & Compactação:** `7-zip.org`, `notepad-plus-plus.org`, `sysinternals.com`.
  - **Repositórios e Código:** `github.com`, `githubusercontent.com`, `githubassets.com`, `gitlab.com`, `git-scm.com`, `sourceforge.net`, `osdn.net`, `python.org`, `pypi.org`, `pythonhosted.org`.
  - **Outros:** `postman.com`, `curl.se`, `mobatek.net`.
- **Funcionamento:** O motor de compilação do Rules WAM remove automaticamente esses domínios de qualquer feed de bloqueio antes de aplicar ao Unbound DNS.

### 4.9. Proteção da Infraestrutura Cloudflare & Ajuste Fino ZTNA

Muitos sites legítimos e mirrors de download utilizam a rede da Cloudflare para Content Delivery Network (CDN), proteção anti-DDoS e verificação por Captcha (Cloudflare Turnstile). Um bloqueio genérico de Cloudflare causaria falsos positivos severos em downloads e navegação:

- **Configuração:** Opção **"Proteger Infraestrutura Cloudflare (CDN & Captcha)"** (`corp_protect_cloudflare`), ativada por padrão (`yes`).
- **O que é Blindado Permanentemente:**
  - `cdnjs.cloudflare.com` (bibliotecas JavaScript e CSS usadas por milhares de portais)
  - `challenges.cloudflare.com` (Cloudflare Turnstile - validação de segurança para downloads e portais)
  - `static.cloudflareinsights.com`, `cloudflareinsights.com`, `cf-assets.net`
- **Bloqueio Cirúrgico de VPN/ZTNA (`block_ztna_cloudflare`):**
  - Quando a categoria de bloqueio Cloudflare WARP estiver ativada, ela bloqueia **exclusivamente** os pontos de conexão do cliente WARP (`cloudflareclient.com`, `warp.plus`, `zero-trust.cloudflare.com`, `teams.cloudflare.com`, `warp-svc.*`).
  - Domínios de túneis compartilhados como `cftunnel.com` e `cloudflareaccess.com` foram removidos do feed para garantir que aplicações corporativas publicadas atrás de túneis Cloudflare permaneçam 100% acessíveis.

### 4.10. Auto-Whitelist & Proteção de Helpdesk, ITSM & Suporte Remoto (Zendesk, GLPI, ScreenConnect)

Plataformas de atendimento ao cliente, centrais de serviços de TI (ITSM) e ferramentas de assistência remota são vitais para a operação corporativa. Para garantir que nenhuma regra de mensageiros, chat ou bloqueio de conexões remotas afete estes serviços:

- **Configuração:** Opção **"Liberar Helpdesk & Suporte Remoto (Zendesk, GLPI, ScreenConnect)"** (`corp_protect_helpdesk`), ativada por padrão (`yes`).
- **Escopo Blindado Permanentemente:**
  - **Zendesk & Chat Integrado:** `zendesk.com`, `zdassets.com`, `zdstatic.com`, `zdusercontent.com`, `zopim.com`, `zopim.io`, `zopim.net`.
  - **GLPI (ITSM & Gestão de Ativos):** `glpi-project.org`, `glpi-network.cloud`, `glpi-network.com`, `teclib.com`, `teclib-edition.com`.
  - **ConnectWise ScreenConnect (Suporte Remoto):** `screenconnect.com`, `screenconnect.net`, `connectwise.com`, `connectwise.net`, `hostedrmm.com`.
- **Garantia Técnica:** Mesmo que administradores ativem bloqueio integral de mensageiros ou feeds restritivos de VPN/ZTNA, o Rules WAM remove automaticamente estes domínios do banco de bloqueio e garante resolução limpa no Unbound DNS.

### 4.11. Proteção de Telefonia IP, PABX Cloud, Protocolo SIP & Aparelhos SIP Phone

O tráfego de voz sobre IP (VoIP) e sinalização SIP corporativa não pode sofrer nenhuma forma de bloqueio ou redirecionamento involuntário no DNS, sob risco de interrupção em ramais IP, call centers e centrais PABX:

- **Configuração:** Opção **"Liberar Telefonia IP, Protocolo SIP & Aparelhos SIP Phone"** (`corp_protect_voip`), ativada por padrão (`yes`).
- **Escopo Blindado Permanentemente:**
  - **Servidores STUN / TURN (Travessia de NAT e Sinalização WebRTC/VoIP):** `stun.l.google.com`, `stun1` a `stun4.l.google.com`, `stun.sipgate.net`, `stun.voipbuster.com`, `stun.ekiga.net`, `stun.counterpath.com`, `stun.counterpath.net`.
  - **Softphones e Clientes de Voz:** `zoiper.com`, `linphone.org`, `microsip.org`, `micro-sip.org`, `counterpath.com`, `bria.com`, `sip.audio`.
  - **Fabricantes de Telefones IP & Provisionamento Zero-Touch (RPS / TR-069):** `yealink.com`, `yealinkphones.com`, `grandstream.com`, `gdms.cloud`, `intelbras.com.br`, `intelbras.com`, `fanvil.com`, `poly.com`, `polycom.com`, `snom.com` (subdomínios incluídos).
  - **Operadoras VoIP, Troncos SIP e PABX Cloud:** `3cx.com`, `3cx.net`, `3cx.eu`, `3cx.us`, `sipgate.de`, `sipgate.com`, `sipgate.net`, `twilio.com`, `telnyx.com`, `plivo.com`, `ringcentral.com`, `vonage.com`, `nexmo.com`, `8x8.com`, `voip.ms`, `callcentric.com`, `didlogic.com`, `flowroute.com`, `jive.com`, `gotoconnect.com`, `dialpad.com`, `totalvoice.com.br`, `zenvia.com`.
- **Compatibilidade com Anti-Bypass DNS:** Ao ativar o Anti-Bypass DNS (redirecionamento da porta 53 para o Unbound local), telefones IP físicos e softphones continuam resolvendo seus proxies e registradores SIP normalmente e sem degradação.

### 4.12. Acesso Administrativo à WebGUI & Regras de Firewall

Painel **Acesso Administrativo à WebGUI** em **Services > Rules WAM**:
- **Origens Internas Autorizadas** (`gui_admin_sources`, alias `WAM_GUI_Admins`): IPs/redes que podem acessar a WebGUI pelas redes internas. Em branco = qualquer origem interna. Recomendado: só as redes da TI.
- **Origens Autorizadas pela WAN** (`gui_wan_sources`, alias `WAM_GUI_WAN_Sources`): em branco = **nenhuma regra na WAN** (recomendado). Preencha só com IPs públicos fixos da TI.

Regras criadas automaticamente (descrição começando com `Rules WAM - `, inseridas no topo):

| Regra | Onde | Quando |
|---|---|---|
| *pass* TCP → `(self)` na porta da WebGUI, origem `WAM_GUI_Admins` (ou qualquer) | Cada interface interna | Sempre |
| *pass* TCP de `WAM_GUI_WAN_Sources` → `(self)` na porta da WebGUI | WAN | Só se *Origens Autorizadas pela WAN* estiver preenchido |
| *pass* TCP → IP do banner, portas 80/443 (`WAM_Banner_Ports`) | Floating (interfaces internas) | Modo Banner ativo e sem conflito de porta |
| *reject* TCP/UDP porta 853 (DoT) | Floating | Categoria Anti-Bypass DoH marcada |
| *reject* TCP/UDP portas 5222/4244 (`WAM_WhatsApp_Ports`) | Floating | WhatsApp bloqueado |
| *reject* para `WAM_WhatsApp_Nets` (faixas Meta) | Floating | WhatsApp bloqueado **e** "Bloquear também por faixa IP" marcado |
| NAT porta 53 → `127.0.0.1` (+ exceção/pass para `WAM_Corp_AD_DNS`) | Cada interface interna | Anti-Bypass DNS (porta 53) marcado |

As regras de bloqueio só existem durante o horário de bloqueio. O pacote **não** altera bogons, redes privadas na WAN, DNS rebind nem a porta da WebGUI (exceto no instalador, com `--move-gui`). O config.xml só é regravado quando há mudança.

**Privilégios:** o arquivo `/etc/inc/priv/rules_wam.priv.inc` permite delegar as telas do pacote em **System > User Manager** sem dar acesso total.

---

## 5. Auditoria, Logs & Dashboard Forense

O Rules WAM registra em `/var/log/wam_audit.log` os acessos que chegam ao banner (HTTP). Formato: `data|IP|domínio|categoria|hostname`.

```
2026-09-09 11:15:32|192.168.1.115|bet365.com|Apostas & Bets|DESKTOP-FINANC01
2026-09-09 11:18:04|192.168.1.142|xvideos.com|Conteúdo Adulto|NOTE-DIRETORIA
```

- Campos sanitizados; linhas malformadas são descartadas; rotação a partir de 10 MB (`wam_audit.log.1`).
- Acessos HTTPS são recusados antes de chegar à página e não geram registro.
- Testes feitos na aba Status e a prévia do banner (que exige login) não entram na auditoria.

### Recursos do Dashboard (`rules_wam_dashboard.php`):
1. **Cards em Tempo Real:** Total de bloqueios hoje, quantidade de hosts bloqueados, principais categorias violadas.
2. **Resolução Automática de Nomes de Host:** O Rules WAM varre a tabela ARP do FreeBSD, mapeamentos DHCP estáticos do pfSense e aliases personalizados para exibir o nome amigável do computador (ex: `DESKTOP-RH-02`) além do IP.
3. **Indicador Online/Offline:** Mostra visualmente se a estação infratora está conectada e ligada na rede naquele momento.
4. **Exportação de Relatórios:**
   - Botão **Exportar CSV (Excel)**: Gera arquivo `.csv` em UTF-8, protegido contra injeção de fórmula. A exportação "sem limite" tem teto de 20.000 eventos.
   - Botão **Exportar JSON**: Ideal para integração com SIEM (Splunk, Graylog, Elastic, Grafana).

---

## 6. Guia de Implantação em Novos Firewalls (Passo a Passo)

O instalador `wam-install.sh` é um shell **auto-extraível** de ~130 KB que contém o pacote inteiro (scripts, PHP, páginas web e os 28 arquivos de feed) e executa o mesmo `install.sh` do pacote. O passo a passo detalhado está no [Guia de Instalação](MANUAL_DE_INSTALACAO.md).

```text
sh wam-install.sh [--move-gui] [--gui-port=50443] [--wan-gui-sources=IP1,IP2|none]
```

### 6.1. Pré-Requisitos
1. Firewall com **pfSense 2.7.x, 2.8.x ou pfSense Plus** instalado.
2. Serviço **DNS Resolver (Unbound)** habilitado em **Services > DNS Resolver**.
3. Acesso de administrador (root via SSH ou Console Web).
4. Para o modo Banner: WebGUI fora das portas 80/443 e sem redirecionamento HTTP — configure em **System > Advanced > Admin Access** ou use `--move-gui` na instalação.
5. **Validar primeiro em laboratório** (a 1.4.0 ainda não foi testada em pfSense real).

---

### 6.2. Métodos de Transferência do Instalador Standalone

Obtenha o `wam-install.sh` (ou o `rules-wam-pacote.zip`) por um canal confiável e confira o **SHA-256** no pfSense antes de executar: `sha256 /tmp/wam-install.sh`.

#### Opção A: Transferência Direta via SCP (Recomendado)
```bash
scp wam-install.sh root@<IP_DO_NOVO_FIREWALL>:/tmp/
```

#### Opção B: Upload pela WebGUI do pfSense (Sem terminal externo)
1. No navegador, acesse a interface web do pfSense.
2. Vá ao menu **Diagnostics > Command Prompt**.
3. Na seção **Upload File**, clique em **Choose File** e selecione o arquivo `wam-install.sh`.
4. Clique em **Upload**. O arquivo será salvo em `/tmp/wam-install.sh`.

---

### 6.3. Execução da Instalação

Você pode executar o script por qualquer um dos dois métodos:

#### Método A: Via Terminal / SSH do pfSense
Acesse o terminal do pfSense (via SSH ou no menu do console opção `8) Shell`):
```bash
sh /tmp/wam-install.sh --move-gui
```
Em terminal interativo, o instalador pergunta o que faltar (mover a WebGUI `[s/N]`; origens da WAN na atualização da 1.3).

#### Método B: Diretamente pela WebGUI do pfSense (Sem terminal)
No menu **Diagnostics > Command Prompt**:
1. Na caixa **Execute Shell Command**, digite, por exemplo: `sh /tmp/wam-install.sh --move-gui`
2. Clique no botão **Execute** e acompanhe a saída na tela. Não há perguntas interativas aqui: passe as opções na linha de comando.

> [!WARNING]
> **Porta da WebGUI:** a WebGUI **só é movida** com `--move-gui` (ou resposta `s` na pergunta interativa) — para `50443` ou a porta de `--gui-port` — e o redirecionamento HTTP é desativado. Sem isso, se a WebGUI usar 80/443 (ou o redirecionamento HTTP estiver ativo), o bloqueio funciona em modo silencioso (0.0.0.0) e a aba Status mostra um aviso.

> [!CAUTION]
> **Atualização a partir da 1.3:** é obrigatório informar `--wan-gui-sources=IP1,IP2` (IPs públicos da TI) ou `--wan-gui-sources=none`. Sem isso, o instalador **aborta sem alterar nada**. A regra antiga da 1.3 (WebGUI na WAN para qualquer origem) é substituída. Os domínios da empresa que eram fixos no código vão para a whitelist editável. Porta 50443, DNS rebind desativado e bogons/redes privadas liberados na WAN continuam como a 1.3 deixou: revise em *System > Advanced > Admin Access* e *Interfaces > WAN*.

#### O que o instalador realiza automaticamente:
1. Verificações prévias (sem alterar nada): regra antiga da WAN e conflito de portas da WebGUI.
2. Copia os arquivos PHP/XML para `/usr/local/pkg/` e `/usr/local/www/`, os feeds para `/usr/local/share/wam/feeds/`, os privilégios para `/etc/inc/priv/` e o `uninstall.sh` para `/usr/local/share/wam/`.
3. Remove sobras da 1.3 (`wam.inc`, `wam.xml`, `wam_sync.php`, `rules_wam_hook.inc`, `wam_status.php`, CA pública) e desfaz as alterações da 1.3 em `index.php`, `404.php` e `404.html`. Remove a CA e o certificado do banner HTTPS da 1.3 do Gerenciador de Certificados.
4. Registra os menus **Services > Rules WAM** e **Firewall > Rules WAM**, o cron (`wam_cron.php` a cada 5 min) e o widget.
5. Move a WebGUI somente se autorizado (`--move-gui`).
6. Compila as regras, adiciona o include do Unbound, sobe o NGINX do banner (se não houver conflito) e cria as regras de firewall descritas na [seção 4.12](#412-acesso-administrativo-à-webgui--regras-de-firewall).

O instalador **não** apaga `/var/crash`, não altera bogons, redes privadas na WAN nem a proteção contra DNS rebind.

---

### 6.4. Validação da Instalação

Após a mensagem `Rules WAM instalado.`, valide:

1. **Verificar o NGINX do banner (modo Banner):**
   ```bash
   sockstat -4 -l -p 80,443
   ```
   *O `nginx` do banner deve aparecer **só no IP do banner** (ex.: `192.168.1.1:80` e `192.168.1.1:443`), nunca em `*:80`/`*:443`.*

2. **Verificar o Unbound com a lista ativa e sem erros:**
   ```bash
   ls -lh /var/unbound/wam_blocklist.conf
   cat /var/log/wam_checkconf_err.log
   ```

3. **Verificar resolução de teste no próprio pfSense:**
   ```bash
   drill @127.0.0.1 xvideos.com
   ```
   *Deverá retornar o IP do banner (ou `0.0.0.0` no modo silencioso).*

4. **Testar de uma estação:** `http://xvideos.com` deve mostrar o banner; `https://xvideos.com` deve falhar na hora com erro de conexão.

---

## 7. Banner Somente HTTP (Sem CA nas Estações)

As máquinas clientes **não recebem nenhuma CA** do Rules WAM. Sem uma CA confiável instalada, qualquer página HTTPS servida pelo firewall no lugar do site original geraria um aviso de certificado no navegador (e o HSTS de muitos sites nem permitiria continuar). Por isso, a partir da 1.4.0:

1. O Unbound responde o IP do banner para os domínios bloqueados.
2. **HTTP (80):** o NGINX do banner entrega a página institucional (`rules_wam_block.php`) e registra o acesso na auditoria.
3. **HTTPS (443):** o NGINX do banner recusa o handshake TLS imediatamente (`ssl_reject_handshake on`). O navegador mostra um erro de conexão (ex.: `ERR_SSL_PROTOCOL_ERROR` / `ERR_CONNECTION_CLOSED`), sem aviso de certificado e sem espera de timeout.

Consequência prática: como a maioria dos sites usa HTTPS, a maior parte dos bloqueios aparece como erro de conexão; o banner aparece quando o usuário digita o endereço sem `https://` ou acessa links HTTP.

Não há certificados, GPO nem `rules_wam_ca.crt` para distribuir. Na atualização a partir da 1.3, a CA e o certificado do banner HTTPS são removidos do **System > Cert. Manager** (exceto se o certificado estiver em uso pela WebGUI; nesse caso ele é mantido e o instalador avisa).

---

## 8. Operação Diária & WebGUI

### Painel Principal: `Services > Rules WAM`
- **Habilitar Serviço:** Ativa ou desativa a filtragem globalmente com um clique.
- **Seleção de Categorias:** Marque ou desmarque qualquer uma das 12 categorias.
- **Ação de Bloqueio:**
  - `block_page` (Padrão): HTTP mostra o banner e registra no log; HTTPS falha na hora.
  - `always_null`: Bloqueio silencioso (responde `0.0.0.0`).
- **IP do Firewall para o Banner:** IP de uma interface interna onde o NGINX do banner escuta (validado no Save).
- **E-mail do Suporte (Banner):** endereço do botão "Contatar Suporte TI". Em branco, o botão não aparece.
- **Origens Internas Autorizadas / Origens Autorizadas pela WAN:** ver [seção 4.12](#412-acesso-administrativo-à-webgui--regras-de-firewall).
- **Lista Branca (Custom Whitelist):** Domínios que **nunca** devem ser bloqueados (um por linha).
- **Lista Negra (Custom Blacklist):** Domínios específicos da empresa a bloquear adicionalmente.
- **Nomes Personalizados (Hosts):** Mapeie `IP = Nome do Colaborador` para visualização clara no Dashboard.
- **Validação:** IPs, CIDRs, e-mail, horários e IP do banner são validados ao salvar.

### Painel de Teste: Aba `Status & Teste de Bloqueio`
- Digite qualquer domínio (ex: `betano.com`, `instagram.com`, `uol.com.br`) e clique em **Verificar**.
- O sistema informa imediatamente se o domínio está bloqueado e qual categoria o identificou. Esses testes não entram no log de auditoria.
- Se a WebGUI estiver em 80/443 (ou com redirecionamento HTTP), esta aba mostra o aviso de que o banner está desligado e o bloqueio usa 0.0.0.0.

---

## 9. Troubleshooting & Manutenção

### Comandos de Diagnóstico no Console do pfSense:

```bash
# 1. Verificar o NGINX do banner (deve aparecer só no IP do banner, portas 80 e 443):
sockstat -4 -l -p 80,443

# 2. Visualizar logs de erros do NGINX do banner:
tail -n 30 /var/log/rules_wam_ssl.log

# 2b. Erros de validação da configuração do Unbound (unbound-checkconf):
cat /var/log/wam_checkconf_err.log

# 3. Acompanhar bloqueios de usuários em tempo real:
tail -f /var/log/wam_audit.log

# 4. Forçar ressincronização manual do agendador de horário:
/usr/local/bin/php -q /usr/local/pkg/wam_cron.php

# 5. Reiniciar o NGINX do banner:
sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart

# 6. Recarregar as configurações do Unbound DNS:
unbound-control -c /var/unbound/unbound.conf reload
```

### Problemas Comuns & Soluções:

| Sintoma | Causa Provável | Solução |
|---|---|---|
| Usuários veem erro de conexão em sites HTTPS bloqueados | Comportamento esperado (banner só HTTP, sem CA) | Nada a fazer. Teste com `http://` para ver o banner. |
| O banner não abre em HTTP | WebGUI em 80/443 ou redirecionamento HTTP ativo (bloqueio caiu para 0.0.0.0) | Veja o aviso na aba Status. Mova a WebGUI em **System > Advanced > Admin Access** (porta ≠ 80/443 e redirecionamento desativado) e salve o Rules WAM. |
| O banner não abre e não há conflito de porta | NGINX do banner parado | Confira `sockstat -4 -l -p 80,443` e `/var/log/rules_wam_ssl.log`; rode `sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart`. |
| IPs isentos continuam bloqueados | View `wam_bypass` rejeitada pelo `unbound-checkconf` | Veja `/var/log/wam_checkconf_err.log` e a aba Status (contagem de bypass). |
| Perdi o acesso à WebGUI por uma rede interna | Origem fora de *Origens Internas Autorizadas* | Acesse pela LAN (anti-lockout) ou pelo console e ajuste o campo. |
| Regras não aplicaram após salvar | Cache do Unbound retendo registros antigos | Execute `unbound-control flush_zone .` no terminal ou clique em Salvar novamente. |
| Um site legítimo foi bloqueado por engano | Falso positivo no feed de categorias | Adicione o domínio em **Exceções & Personalização > Domínios Liberados (Whitelist)** e salve. |

---

## 10. Procedimento de Desinstalação

Caso precise remover completamente o Rules WAM de um firewall, execute como root (o desinstalador é copiado durante a instalação):

```bash
sh /usr/local/share/wam/uninstall.sh
```

O script:
1. **Reverte a configuração antes de apagar os arquivos:** remove o include do Unbound, os domain overrides, as regras de firewall, o NAT e os aliases; restaura o `log_queries`; remove menus, cron e widget.
2. **Restaura a porta e o redirecionamento da WebGUI** se foi o pacote que os alterou. Em instalações atualizadas da 1.3, a porta **não** é restaurada automaticamente: revise em *System > Advanced > Admin Access* (porta, redirecionamento HTTP e DNS rebind).
3. Para o NGINX do banner e remove os arquivos do pacote.
4. **Mantém o log de auditoria** em `/var/log/wam_audit.log` (apague se não precisar).

---

**Rules WAM — Desenvolvido para Segurança e Conformidade Corporativa.**  
*Documentação técnica e operacional do Rules WAM para pfSense.*
