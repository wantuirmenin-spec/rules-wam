# 🛡️ Manual do Administrador & Guia de Implantação
## Rules WAM — Web Access Manager para pfSense
**Versão:** 1.3.0  
**Compatibilidade:** pfSense CE 2.7.x / 2.8.x / pfSense Plus  
**Plataforma Base:** FreeBSD / Unbound DNS / NGINX SSL  

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
   - [Gestão Multi-Unidades & CA Centralizada (Opcional)](#412-gestão-multi-unidades-bulkylog--ca-centralizada-opcional)
5. [Auditoria, Logs & Dashboard Forense](#5-auditoria-logs--dashboard-forense)
6. [Guia de Implantação em Novos Firewalls (Passo a Passo)](#6-guia-de-implantação-em-novos-firewalls-passo-a-passo)
   - [Pré-Requisitos](#61-pré-requisitos)
   - [Métodos de Transferência do Instalador Standalone](#62-métodos-de-transferência-do-instalador-standalone)
   - [Execução da Instalação](#63-execução-da-instalação)
   - [Validação da Instalação](#64-validação-da-instalação)
7. [Interceptação HTTPS & Distribuição da CA Corporativa](#7-interceptação-https--distribuição-da-ca-corporativa)
   - [Como Funciona a Interceptação SSL](#71-como-funciona-a-interceptação-ssl)
   - [Distribuição da CA via GPO no Active Directory](#72-distribuição-da-ca-via-gpo-no-active-directory)
   - [Instalação Manual do Certificado](#73-instalação-manual-do-certificado)
8. [Operação Diária & WebGUI](#8-operação-diária--webgui)
9. [Troubleshooting & Manutenção](#9-troubleshooting--manutenção)
10. [Procedimento de Desinstalação](#10-procedimento-de-desinstalação)

---

## 1. Visão Geral do Sistema

O **Rules WAM** (*Web Access Manager*) é uma solução nativa desenvolvida para o **pfSense** que transforma o firewall em um avançado controlador de conteúdo e segurança corporativa através de filtragem DNS em alta performance no Unbound.

### Principais Benefícios:
- **Zero Dependência de Proxy Pesado:** Não utiliza Squid nem consome gigabytes de RAM com cache HTTP. Toda a filtragem ocorre em microssegundos no motor nativo do Unbound DNS.
- **Página de Bloqueio Educativa (HTTP & HTTPS):** Quando um usuário tenta acessar um domínio restrito, recebe uma tela institucional moderna e responsiva explicando o bloqueio, identificando seu computador (IP e Hostname), horário e a política infringida.
- **Tolerância Zero a Bypasses:** Bloqueia servidores de DoH (*DNS over HTTPS*) públicos e serviços de VPN/ZTNA que os funcionários costumam utilizar para burlar regras corporativas.
- **Autônomo & Standalone:** Empacotado em um único instalador (`wam-install.sh`) com detecção automática da interface de rede LAN e portas do sistema.

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
        [ wam_bypass_view ]                                        [ Unbound Blocklist ]
   Resolve DNS público real (Livre)                               Redireciona para o IP LAN
                                                                              │
                                                               ┌──────────────┴──────────────┐
                                                               │                             │
                                                          HTTP (80)                     HTTPS (443)
                                                               │                             │
                                                    webConfigurator Interceptor      NGINX SSL Reverso
                                                               │                             │
                                                               └──────────────┬──────────────┘
                                                                              ▼
                                                                  [ rules_wam_block.php ]
                                                              Exibe Banner de Bloqueio Corporativo
                                                              Registra em /var/log/wam_audit.log
```

### Componentes Internos do Pacote:
| Componente | Caminho no pfSense | Finalidade |
|---|---|---|
| **Definição de Pacote** | `/usr/local/pkg/rules_wam.xml` | Integração nativa de menus, abas e formulários na WebGUI |
| **Motor de Regras** | `/usr/local/pkg/rules_wam.inc` | Compilador de listas, geração de zonas Unbound, resolução de IPs |
| **Hook de Interceptação**| `/usr/local/pkg/rules_wam_hook.inc` | Captura conexões na porta 80 e encaminha para o banner |
| **Proxy SSL do Banner** | `/usr/local/etc/nginx/rules_wam_ssl.conf` | Instância NGINX dedicada na 443 para responder requisições HTTPS |
| **Agendador Cron** | `/usr/local/pkg/wam_cron.php` | Script a cada 5 min que alterna regras conforme o horário e almoço |
| **Página de Bloqueio** | `/usr/local/www/rules_wam_block.php` | Interface web apresentada ao usuário bloqueado |
| **Dashboard & Auditoria**| `/usr/local/www/rules_wam_dashboard.php`| Painel com gráficos, métricas e exportação CSV/JSON |
| **Listas de Bloqueio** | `/usr/local/share/wam/feeds/*.txt` | Bases de domínios organizadas por categoria |

---

## 3. Catálogo de Categorias & Feeds

O Rules WAM possui **12 macro-categorias** prontas para ativação imediata:

### 1. 🔞 Conteúdo Adulto & Pornografia (`block_adult`)
- Sites de conteúdo explícito, canais adultos, webcams e plataformas de assinatura: *Pornhub, XVideos, XNXX, RedTube, YouPorn, XHamster, SpankBang, Erome, Beeg, Brazzers, Chaturbate, Stripchat, OnlyFans, Fansly, Privacy, Fatal Model*, etc.
- Feed: `adult.txt` (~41 KB).

### 2. 🎲 Apostas, Bets & Cassinos Online (`block_gambling`)
- Casas de apostas esportivas, cassinos virtuais, jogos de azar: *Bet365, Betano, Sportingbet, Blaze, Stake, Pixbet, EstrelaBet, Superbet, Novibet, KTO, Betfair, 1xBet*, etc.
- Feed: `gambling.txt` (~19 KB).

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
- `block_msg_whatsapp`: WhatsApp Web, APIs e conectividade móvel.
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
- **Pausa de Almoço Automática:** Permite estipular um intervalo de liberação automática (exemplo: das `12:00` às `13:30`). Durante esse período, o Cron do firewall suspende silenciosamente o arquivo de bloqueio no Unbound (`wam_blocklist.conf`) e recarrega a tabela de cache. Às 13:30, o bloqueio é restaurado instantaneamente.
- **Fins de Semana:** Opção para manter bloqueado aos sábados e domingos ou liberar a rede completamente.

### 4.2. Isenção de Dispositivos (Bypass IPs via Unbound Views)
Para computadores da Diretoria, Suporte Técnico ou servidores que não devem passar pelo filtro:
- Insira os endereços IP na caixa **IPs Isentos (Bypass IPs)**, um por linha ou separados por vírgula (ex: `192.168.1.50`, `192.168.1.100` ou até faixas CIDR como `192.168.10.0/24`).
- O sistema compila uma diretiva nativa no Unbound:
  ```
  access-control-view: 192.168.1.50/32 wam_bypass_view
  view:
    name: "wam_bypass_view"
  ```
- **Vantagem arquitetural:** O Unbound processa as consultas desses IPs de forma isolada, sem carregar a lista de domínios bloqueados, garantindo 0% de impacto e sem necessidade de regras complexas de Firewall / NAT.

### 4.3. Integração com Active Directory & NPS RADIUS (VPN IPsec)
Em ambientes corporativos e filiais conectadas via túnel IPsec com a Matriz:
- **Split-DNS Automático:** O Rules WAM configura automaticamente diretivas `forward-zone` no Unbound e entradas em `Domain Overrides` nativas do pfSense para os controladores de domínio (ex: `madeiramadeira.local`, `madeiramadeira.com.br`).
- **Prevenção de Falhas de Logon & GPO:** O pfSense possui por padrão proteção contra DNS Rebinding (`rebind_protect`) e validação DNSSEC. O Rules WAM injeta automaticamente as seguintes diretivas:
  ```
  private-domain: "madeiramadeira.local"
  domain-insecure: "madeiramadeira.local"
  private-domain: "in-addr.arpa"
  domain-insecure: "in-addr.arpa"
  forward-zone:
    name: "madeiramadeira.local"
    forward-addr: 10.0.0.10
    forward-addr: 10.0.0.11
  ```
- **NPS RADIUS & Zonas Reversas (`in-addr.arpa`):** Servidores RADIUS (como o Microsoft NPS para 802.1X em Wi-Fi e switches gerenciados) dependem fortemente de consultas DNS reversas (`PTR`) para identificar nomes de computadores e validar políticas de acesso. O encaminhamento condicional de zonas `in-addr.arpa` impede atrasos (timeouts de 5 a 10 segundos) e quedas na autenticação de rede.
- **Whitelist Automática:** O domínio corporativo é automaticamente blindado e inserido na lista branca do Rules WAM, impossibilitando qualquer bloqueio acidental de serviços internos (Kerberos porta 88, LDAP porta 389/636, Global Catalog porta 3268, SMB porta 445).

### 4.4. Proteção Netskope Security Cloud & IdP
- A opção **Auto-Whitelist Netskope & IdP** vem habilitada por padrão e garante que os agentes Netskope Client (`goskope.com`, `netskope.com`, gateways NPA/ZTNA) e provedores de identidade corporativos (*Microsoft Entra ID*, *Okta*, *Google Accounts*) nunca sejam bloqueados, evitando desautenticação de colaboradores.

### 4.5. Anti-Bypass DNS (Porta 53 NAT Redirection - Recurso Opcional / Opt-in)
- **Status Padrão:** **Desativado por padrão (Opt-in).** Qualquer modificação em regras de redirecionamento NAT afeta diretamente o fluxo de pacotes da rede local, devendo ser ativada apenas após validação consciente do administrador.
- **O Problema do Bypass:** Quando um colaborador altera manualmente o servidor DNS na placa de rede para `8.8.8.8` ou `1.1.1.1`, as consultas deixam de passar pelo Unbound do pfSense.
- **Como Opera quando Ativado:** O sistema cria uma regra de redirecionamento no **Firewall > NAT > Port Forward** capturando qualquer consulta externa na porta 53 (UDP/TCP) vinda da rede local e redirecionando para `127.0.0.1:53` (Unbound local).
- **Exceção Automática para Controladores de Domínio (`WAM_Corp_AD_DNS`):** Quando a integração corporativa estiver ativa, o Rules WAM cria uma regra de exceção no NAT (`nordr`) e liberação imediata (`pass quick`) no firewall para os IPs configurados em `corp_ad_dns_ips`. Assim, consultas ao AD e registros dinâmicos (RFC 2136 / Netlogon) continuam passando direto sem interceptação.

#### Checklist de Homologação antes de Ativar em Produção:
Antes de marcar a opção **"Forçar DNS Local (Porta 53 Anti-Bypass)"** na WebGUI em uma unidade produtiva, realize os seguintes testes em uma estação piloto:
1. `[ ]` **Resolução Interna:** Executar `nslookup` para o controlador de domínio da Matriz.
2. `[ ]` **Logon e Políticas de Domínio:** Executar `gpupdate /force` no Windows e verificar se as diretivas aplicam sem erros.
3. `[ ]` **Autenticação NPS RADIUS:** Conectar um dispositivo no Wi-Fi corporativo (802.1X) e validar se a autenticação é imediata.
4. `[ ]` **Navegação Normal:** Testar acesso a sites institucionais e ferramentas de trabalho corporativas.
5. `[ ]` **Teste de Bloqueio de Bypass:** Na estação de testes, configure manualmente o DNS da placa de rede para `8.8.8.8` e tente acessar um domínio restrito. O acesso deve retornar 0.0.0.0.

### 4.6. Integração com Servidores DNS Google (8.8.8.8) & Cloudflare (1.1.1.1)
É muito comum em ambientes corporativos o uso dos servidores DNS Anycast do Google (`8.8.8.8`, `8.8.4.4`) e Cloudflare (`1.1.1.1`, `1.0.0.1`). O Rules WAM trata esses servidores em duas frentes complementares:

1. **Proteção Anti-Bypass de Clientes (Dispositivos com 8.8.8.8 / 1.1.1.1 fixos na placa de rede):**
   - Ao ativar a opção **"Anti-Bypass DNS (Porta 53)"** na WebGUI do WAM, o firewall intercepta automaticamente via NAT Port Forward qualquer consulta UDP/TCP enviada a servidores externos como 8.8.8.8 ou 1.1.1.1 e a redireciona para o Unbound local (`127.0.0.1:53`).
   - O dispositivo recebe a resposta normalmente como se tivesse vindo do 8.8.8.8, mas todas as políticas e bloqueios de categorias do WAM são aplicados.
   - Para computadores ou celulares que tentam usar DNS Seguro (DoT porta 853 ou DoH porta 443 via `dns.google` ou `cloudflare-dns.com`), o Rules WAM bloqueia as conexões, forçando a queda para a porta 53 interceptada.
   - Inclui o canário oficial da Mozilla (`use-application-dns.net`) que instrui o Firefox e outros navegadores a desligar o DoH e obedecer ao firewall da rede.

2. **Forwarding Upstream de Alta Performance (pfSense resolvendo via Google e Cloudflare):**
   - Ao ativar a opção **"Forwarding Upstream (Google & Cloudflare)"** na WebGUI do Rules WAM, o Unbound cria automaticamente uma diretiva `forward-zone` para a raiz (`.`):
     - As categorias bloqueadas no WAM continuam respondendo instantaneamente `0.0.0.0` localmente na LAN (sem gerar tráfego externo).
     - As zonas corporativas do Active Directory e NPS Matriz continuam sendo encaminhadas exclusivamente aos controladores de domínio via VPN IPsec.
     - Todas as demais consultas liberadas para a internet são encaminhadas e aceleradas diretamente pelos clusters mundiais do Google (`8.8.8.8`, `8.8.4.4`) e Cloudflare (`1.1.1.1`, `1.0.0.1`).

### 4.7. Modo de Bloqueio: Banner Educativo (Padrão) vs Modo Silencioso

O Rules WAM oferece dois modos de bloqueio configuráveis em **Ação de Bloqueio**:

1. 👉 **Exibir Banner Educativo (`block_page`) — [PADRÃO ATIVO]**
   - **Como Opera:** Quando um usuário tenta acessar um domínio bloqueado (ex: rede social ou site de apostas), o Unbound DNS responde com o endereço IP da interface LAN do pfSense (ex: `192.168.1.1`).
   - Conexões na porta **80 (HTTP)** são interceptadas pelo hook local e redirecionadas para a tela de bloqueio.
   - Conexões na porta **443 (HTTPS)** são recebidas pela instância dedicada do **NGINX SSL** na porta 443 do firewall, que apresenta o certificado corporativo (`rules_wam_ssl.crt`) e encaminha para `/rules_wam_block.php`.
   - **Geração e Validação Automática de Certificados:** A função `rules_wam_ensure_banner_certs()` garante que tanto a CA quanto o certificado SSL do banner existam antes de iniciar o NGINX. Mesmo em instalações de pfSense com RAM Disk (onde `/var/etc` é limpo na reinicialização), os certificados são gerados e restaurados dinamicamente na inicialização do sistema e a cada sincronização.
   - **Porta da WebGUI e Anti-Lockout:** A WebGUI administrativa do pfSense é movida automaticamente para a porta `50443`, liberando as portas 80 e 443 exclusivamente para o banner de bloqueio. Regras de firewall (`WAM_Banner_Ports`) são criadas para garantir o tráfego local sem bloqueios.
   - **Vantagem:** O usuário vê claramente a política de segurança corporativa, categoria do site, horário e identificação do seu dispositivo, evitando que abra chamados de "internet fora do ar".

2. **Retornar 0.0.0.0 (Silencioso — `always_null`)**
   - O Unbound responde diretamente com `0.0.0.0` (IPv4) ou `::` (IPv6).
   - O navegador ou sistema operacional recebe recusa de conexão imediata (`ERR_CONNECTION_REFUSED`).
   - **Vantagem:** Não requer nenhum certificado nas estações de trabalho e dispensa a exibição de página web.

### 4.8. Auto-Whitelist de Ferramentas de TI e Downloads de Administrador (PuTTY, etc.)

Equipes de TI e administradores de rede frequentemente precisam baixar e atualizar utilitários essenciais de diagnóstico, acesso remoto e desenvolvimento. Para evitar que feeds amplos ou regras de downloads afetem a operação técnica:

- **Configuração:** Opção **"Auto-Whitelist Ferramentas TI & Admin (PuTTY, etc.)"** (`corp_protect_tools`), ativada por padrão (`yes`).
- **Escopo Protegido:**
  - **PuTTY & Utilitários SSH:** `putty.org`, `chiark.greenend.org.uk`, `greenend.org.uk`, `the.earth.li`, `tartarus.org`.
  - **Transferência de Arquivos & Diagnóstico:** `winscp.net`, `filezilla-project.org`, `wireshark.org`, `nmap.org`, `dbeaver.io`.
  - **Utilitários de Sistema & Compactação:** `7-zip.org`, `notepad-plus-plus.org`, `sysinternals.com`.
  - **Repositórios e Código:** `github.com`, `githubusercontent.com`, `raw.githubusercontent.com`, `objects.githubusercontent.com`, `gitlab.com`, `git-scm.com`, `sourceforge.net`, `python.org`.
- **Funcionamento:** O motor de compilação do Rules WAM remove automaticamente esses domínios de qualquer feed de bloqueio antes de aplicar ao Unbound DNS.

### 4.9. Proteção da Infraestrutura Cloudflare & Ajuste Fino ZTNA

Muitos sites legítimos e mirrors de download utilizam a rede da Cloudflare para Content Delivery Network (CDN), proteção anti-DDoS e verificação por Captcha (Cloudflare Turnstile). Um bloqueio genérico de Cloudflare causaria falsos positivos severos em downloads e navegação:

- **Configuração:** Opção **"Proteger Infraestrutura Cloudflare (CDN & Captcha)"** (`corp_protect_cloudflare`), ativada por padrão (`yes`).
- **O que é Blindado Permanentemente:**
  - `cloudflare.com` (portal e APIs institucionais)
  - `cdnjs.cloudflare.com` (bibliotecas JavaScript e CSS usadas por milhares de portais)
  - `challenges.cloudflare.com` (Cloudflare Turnstile - validação de segurança para downloads e portais)
  - `static.cloudflareinsights.com`, `cf-assets.net`
- **Bloqueio Cirúrgico de VPN/ZTNA (`block_ztna_cloudflare`):**
  - Quando a categoria de bloqueio Cloudflare WARP estiver ativada, ela bloqueia **exclusivamente** os pontos de conexão do cliente WARP (`cloudflareclient.com`, `warp.plus`, `zero-trust.cloudflare.com`, `teams.cloudflare.com`, `warp-svc.*`).
  - Domínios de túneis compartilhados como `cftunnel.com` e `cloudflareaccess.com` foram removidos do feed para garantir que aplicações corporativas publicadas atrás de túneis Cloudflare permaneçam 100% acessíveis.

### 4.10. Auto-Whitelist & Proteção de Helpdesk, ITSM & Suporte Remoto (Zendesk, GLPI, ScreenConnect)

Plataformas de atendimento ao cliente, centrais de serviços de TI (ITSM) e ferramentas de assistência remota são vitais para a operação corporativa. Para garantir que nenhuma regra de mensageiros, chat ou bloqueio de conexões remotas afete estes serviços:

- **Configuração:** Opção **"Liberar Helpdesk & Suporte Remoto (Zendesk, GLPI, ScreenConnect)"** (`corp_protect_helpdesk`), ativada por padrão (`yes`).
- **Escopo Blindado Permanentemente:**
  - **Zendesk & Chat Integrado:** `zendesk.com`, `zdassets.com`, `zdstatic.com`, `zdusercontent.com`, `zopim.com`, `zopim.io`, `zopim.net`.
  - **GLPI (ITSM & Gestão de Ativos):** `glpi-project.org`, `glpi-network.cloud`, `glpi-network.com`, `services.glpi-network.com`, `teclib.com`, `teclib-edition.com`.
  - **ConnectWise ScreenConnect (Suporte Remoto):** `screenconnect.com`, `screenconnect.net`, `connectwise.com`, `connectwise.net`, `hostedrmm.com`.
- **Garantia Técnica:** Mesmo que administradores ativem bloqueio integral de mensageiros ou feeds restritivos de VPN/ZTNA, o Rules WAM remove automaticamente estes domínios do banco de bloqueio e garante resolução limpa no Unbound DNS.

### 4.11. Proteção de Telefonia IP, PABX Cloud, Protocolo SIP & Aparelhos SIP Phone

O tráfego de voz sobre IP (VoIP) e sinalização SIP corporativa não pode sofrer nenhuma forma de bloqueio ou redirecionamento involuntário no DNS, sob risco de interrupção em ramais IP, call centers e centrais PABX:

- **Configuração:** Opção **"Liberar Telefonia IP, Protocolo SIP & Aparelhos SIP Phone"** (`corp_protect_voip`), ativada por padrão (`yes`).
- **Escopo Blindado Permanentemente:**
  - **Servidores STUN / TURN (Travessia de NAT e Sinalização WebRTC/VoIP):** `stun.l.google.com`, `stun1` a `stun4.l.google.com`, `stun.sipgate.net`, `stun.voipbuster.com`, `stun.ekiga.net`, `stun.counterpath.com`, `stun.counterpath.net`.
  - **Softphones e Clientes de Voz:** `zoiper.com`, `linphone.org`, `microsip.org`, `micro-sip.org`, `counterpath.com`, `bria.com`, `sip.audio`.
  - **Fabricantes de Telefones IP & Provisionamento Zero-Touch (RPS / TR-069):** `yealink.com`, `yealinkphones.com`, `ycs.yealink.com`, `rps.yealink.com`, `grandstream.com`, `gdms.cloud`, `gaps.grandstream.com`, `intelbras.com.br`, `intelbras.com`, `fanvil.com`, `fdms.fanvil.com`, `poly.com`, `polycom.com`, `snom.com`.
  - **Operadoras VoIP, Troncos SIP e PABX Cloud:** `3cx.com`, `3cx.net`, `3cx.eu`, `3cx.us`, `sipgate.de`, `sipgate.com`, `sipgate.net`, `twilio.com`, `telnyx.com`, `plivo.com`, `ringcentral.com`, `vonage.com`, `nexmo.com`, `8x8.com`, `voip.ms`, `callcentric.com`, `didlogic.com`, `flowroute.com`, `jive.com`, `goto.com`, `gotoconnect.com`, `dialpad.com`, `totalvoice.com.br`, `zenvia.com`, `locaweb.com.br`, `webex.com`.
- **Compatibilidade com Anti-Bypass DNS:** Ao ativar o Anti-Bypass DNS (redirecionamento da porta 53 para o Unbound local), telefones IP físicos e softphones continuam resolvendo seus proxies e registradores SIP normalmente e sem degradação.

### 4.12. Gestão Multi-Unidades (Bulkylog) & CA Centralizada (Opcional)
Para padronizar o certificado do Banner entre múltiplas filiais:
1. **Autoridade Certificadora (CA) Única:** Copie os arquivos `rules_wam_ca.crt` e `rules_wam_ca.key` da Matriz para a pasta `/tmp/` da filial antes de rodar o `wam-install.sh`.
2. O instalador detecta os arquivos e utiliza a mesma CA corporativa existente.
3. **Vantagem:** Uma **única GPO** configurada no Active Directory corporativo atende todas as filiais e notebooks em trânsito entre as unidades da Bulkylog.

---

## 5. Auditoria, Logs & Dashboard Forense

O Rules WAM registra todas as tentativas de acesso bloqueadas em tempo real em `/var/log/wam_audit.log`:

```
[2026-09-09 11:15:32] CLIENT=192.168.1.115 HOSTNAME=DESKTOP-FINANC01 DOMAIN=bet365.com CATEGORY="Apostas & Bets" ACTION=BLOCK_PAGE
[2026-09-09 11:18:04] CLIENT=192.168.1.142 HOSTNAME=NOTE-DIRETORIA DOMAIN=xvideos.com CATEGORY="Conteúdo Adulto & Pornografia" ACTION=BLOCK_PAGE
```

### Recursos do Dashboard (`rules_wam_dashboard.php`):
1. **Cards em Tempo Real:** Total de bloqueios hoje, quantidade de hosts bloqueados, principais categorias violadas.
2. **Resolução Automática de Nomes de Host:** O Rules WAM varre a tabela ARP do FreeBSD, mapeamentos DHCP estáticos do pfSense e aliases personalizados para exibir o nome amigável do computador (ex: `DESKTOP-RH-02`) além do IP.
3. **Indicador Online/Offline:** Mostra visualmente se a estação infratora está conectada e ligada na rede naquele momento.
4. **Exportação de Relatórios:**
   - Botão **Exportar CSV (Excel)**: Gera arquivo `.csv` formatado em UTF-8 com separador e colunas para relatórios de conformidade e auditoria interna.
   - Botão **Exportar JSON**: Ideal para integração com SIEM (Splunk, Graylog, Elastic, Grafana).

---

## 6. Guia de Implantação em Novos Firewalls (Passo a Passo)

O instalador `wam-install.sh` é um executável shell **autossuficiente** (standalone) de ~277 KB que contém todos os scripts, arquivos PHP, páginas web, certificados SSL, instâncias NGINX e feeds de domínios compactados.

### 6.1. Pré-Requisitos
1. Firewall com **pfSense 2.7.x, 2.8.x ou pfSense Plus** instalado.
2. Serviço **DNS Resolver (Unbound)** habilitado em **Services > DNS Resolver**.
3. Acesso de administrador (root via SSH ou Console Web).

> [!TIP]
> **Porta da WebGUI:** Recomenda-se configurar a porta da WebGUI do pfSense para **50443** (HTTPS) em **System > Advanced > Admin Access**, para que a porta 443 e 80 fiquem livres exclusivamente para a exibição dos banners HTTP/HTTPS do Rules WAM.

---

### 6.2. Métodos de Transferência do Instalador Standalone

O arquivo `wam-install.sh` localiza-se na raiz do projeto:
`/home/hermes/pfsense-wam/wam-install.sh`

#### Opção A: Transferência Direta via SCP (Recomendado)
A partir do terminal do servidor onde está o projeto:
```bash
scp /home/hermes/pfsense-wam/wam-install.sh root@<IP_DO_NOVO_FIREWALL>:/tmp/
```

#### Opção B: Transferência via WebGUI do pfSense (Sem terminal externo)
1. No navegador, acesse a interface web do pfSense novo.
2. Vá ao menu **Diagnostics > Command Prompt**.
3. Na seção **Upload File**, clique em **Choose File** e selecione o arquivo `wam-install.sh`.
4. Clique em **Upload**. O arquivo será salvo em `/tmp/wam-install.sh`.

#### Opção C: Servidor Web Interno com curl
Se você disponibilizar o arquivo em um servidor HTTP da sua rede:
```bash
# No console/SSH do pfSense:
curl -k -o /tmp/wam-install.sh http://<servidor-interno>/wam-install.sh
```

---

### 6.3. Execução da Instalação

Você pode executar o script por qualquer um dos dois métodos:

#### Método A: Via Terminal / SSH do pfSense
Acesse o terminal do pfSense (via SSH ou no menu do console opção `8) Shell`):
```bash
chmod +x /tmp/wam-install.sh
sh /tmp/wam-install.sh
```

#### Método B: Diretamente pela WebGUI do pfSense (Sem terminal)
No menu **Diagnostics > Command Prompt**:
1. Na caixa **Execute Shell Command**, digite: `sh /tmp/wam-install.sh`
2. Clique no botão **Execute** e acompanhe a saída na tela.

> [!WARNING]
> **Ajuste e Blindagem Automática da Porta da WebGUI (50443):**
> Se a WebGUI do pfSense estiver operando na porta 443 (HTTPS padrão), o instalador reconfigura automaticamente a porta administrativa para `50443` (HTTPS) para liberar as portas 80 e 443 ao Banner de Bloqueio. Regras de firewall permanentes de liberação são injetadas na WAN e na LAN com Anti-Lockout garantido, impedindo qualquer perda de acesso ao firewall. O acesso administrativo será através de `https://<IP_DO_PFSENSE>:50443`.

#### O que o instalador realiza automaticamente:
1. Extrai todos os arquivos PHP e XML do pacote em `/usr/local/pkg/` e `/usr/local/www/`.
2. Cria o diretório `/usr/local/share/wam/feeds/` e descompacta todas as bases de domínios.
3. Detecta dinamicamente o IP da interface LAN do pfSense (independente de ser 192.168.x.x, 10.x.x.x ou 172.x.x.x).
4. Gera uma Autoridade Certificadora Corporativa (CA) válida por 10 anos (`/var/etc/rules_wam_ca.crt`).
5. Gera um Certificado SSL de Servidor com SANs (*Subject Alternative Names*) cobrindo os principais domínios populares e wildcards.
6. Registra a CA e o Certificado no **System > Cert. Manager** do pfSense.
7. Configura e inicia o **NGINX SSL** na porta 443 como interceptor reverso.
8. Insere os hooks de captura HTTP na WebGUI local (`index.php` e `404.html`).
9. Registra os menus **Services > Rules WAM** e **Firewall > Rules WAM**.
10. Cria o agendador periódico no Cron nativo do pfSense (`wam_cron.php` a cada 5 min).
11. Compila as regras iniciais e recarrega o Unbound DNS.

---

### 6.4. Validação da Instalação

Após a mensagem de sucesso `🎉 INSTALAÇÃO DO RULES WAM CONCLUÍDA COM SUCESSO!`, valide:

1. **Verificar processo NGINX na porta 443:**
   ```bash
   sockstat -4 -l -p 443
   ```
   *Deverá exibir o processo `nginx` escutando em `*:443`.*

2. **Verificar o Unbound com a lista ativa:**
   ```bash
   ls -lh /var/unbound/conf.d/wam_blocklist.conf
   ```

3. **Verificar resolução de teste no próprio pfSense:**
   ```bash
   drill @127.0.0.1 xvideos.com
   ```
   *Deverá retornar o IP da LAN do pfSense como resposta!*

---

## 7. Interceptação HTTPS & Distribuição da CA Corporativa

### 7.1. Como Funciona a Interceptação SSL
Quando um usuário tenta acessar um site seguro por HTTPS (ex: `https://www.tiktok.com`):
1. O Unbound resolve o nome retornando o IP da LAN do firewall.
2. O navegador da estação conecta na porta 443 do firewall.
3. O serviço NGINX SSL do Rules WAM responde à conexão TLS utilizando o certificado assinado pela **Rules WAM Firewall CA**.
4. O NGINX reescreve a URL internamente para `/rules_wam_block.php?domain=tiktok.com`.
5. A estação renderiza a página de aviso institucional vermelha com todos os detalhes do bloqueio.

### 7.2. Distribuição da CA via GPO no Active Directory
Para que as estações Windows da rede corporativa confiem na página de bloqueio sem exibir alertas de segurança SSL:

1. **Baixar o Certificado da CA:**
   - Acesse pelo navegador: `http://<IP_DO_FIREWALL>/rules_wam_ca.crt` (ou baixe diretamente de `/usr/local/www/rules_wam_ca.crt`).
2. **Abrir o Gerenciador de Diretiva de Grupo (GPMC):**
   - No Controlador de Domínio (Windows Server), abra o `gpmc.msc`.
3. **Criar ou Editar uma GPO:**
   - Crie uma nova GPO (ex: *GPO-Certificado-Rules-WAM*) vinculada à OU das estações de trabalho.
4. **Navegar até a pasta de Certificados:**
   - `Configuração do Computador > Políticas > Configurações do Windows > Configurações de Segurança > Políticas de Chave Pública > Autoridades de Certificação Raiz Confiáveis`.
5. **Importar o Certificado:**
   - Clique com o botão direito em *Autoridades de Certificação Raiz Confiáveis* > **Importar**.
   - Selecione o arquivo `rules_wam_ca.crt`.
   - Conclua o assistente selecionando o repositório padrão.
6. **Forçar atualização nas estações:**
   - As máquinas receberão o certificado automaticamente no próximo ciclo de diretiva ou executando:
     ```cmd
     gpupdate /force
     ```

### 7.3. Instalação Manual do Certificado

#### No Windows:
1. Dê um duplo clique no arquivo `rules_wam_ca.crt`.
2. Clique em **Instalar Certificado...**
3. Selecione **Computador Local** (ou Usuário Atual) e avance.
4. Escolha **Colocar todos os certificados no repositório a seguir** > **Procurar...**
5. Selecione **Autoridades de Certificação Raiz Confiáveis** e confirme.

#### No Linux (Ubuntu / Debian):
```bash
sudo cp rules_wam_ca.crt /usr/local/share/ca-certificates/rules_wam_ca.crt
sudo update-ca-certificates
```

#### No macOS:
1. Abra o arquivo no aplicativo **Acesso às Chaves** (*Keychain Access*).
2. Adicione ao chaveiro **Sistema**.
3. Dê um duplo clique no certificado *Rules WAM Firewall CA*, expanda **Confiar** (*Trust*) e defina **Ao usar este certificado: Confiar Sempre**.

---

## 8. Operação Diária & WebGUI

### Painel Principal: `Services > Rules WAM`
- **Habilitar Serviço:** Ativa ou desativa a filtragem globalmente com um clique.
- **Seleção de Categorias:** Marque ou desmarque qualquer uma das 12 categorias.
- **Ação de Bloqueio:**
  - `block_page` (Padrão): Redireciona para o banner informativo e registra no log.
  - `always_null`: Bloqueio silencioso (responde `0.0.0.0` / NXDOMAIN para o cliente).
- **IP do Firewall para o Banner:** Endereço da interface LAN onde os clientes chegam para ver o banner.
- **Lista Branca (Custom Whitelist):** Domínios que **nunca** devem ser bloqueados (um por linha).
- **Lista Negra (Custom Blacklist):** Domínios específicos da empresa a bloquear adicionalmente.
- **Nomes Personalizados (Hosts):** Mapeie `IP = Nome do Colaborador` para visualização clara no Dashboard.

### Painel de Teste: Aba `Status & Teste de Bloqueio`
- Digite qualquer domínio (ex: `betano.com`, `instagram.com`, `uol.com.br`) e clique em **Verificar**.
- O sistema informa imediatamente se o domínio está bloqueado, qual categoria o identificou e em qual linha do feed ele consta.

---

## 9. Troubleshooting & Manutenção

### Comandos de Diagnóstico no Console do pfSense:

```bash
# 1. Verificar se a porta 443 está ativa pelo Rules WAM:
sockstat -4 -l -p 443

# 2. Visualizar logs de erros do NGINX SSL:
tail -n 30 /var/log/rules_wam_ssl.log

# 3. Acompanhar bloqueios de usuários em tempo real:
tail -f /var/log/wam_audit.log

# 4. Forçar ressincronização manual do agendador de horário:
/usr/local/bin/php -q /usr/local/pkg/wam_cron.php

# 5. Reiniciar o serviço NGINX SSL do Rules WAM:
sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart

# 6. Recarregar as configurações do Unbound DNS:
unbound-control reload
```

### Problemas Comuns & Soluções:

| Sintoma | Causa Provável | Solução |
|---|---|---|
| O banner não abre em HTTPS | NGINX SSL parado ou conflito de porta 443 | Rode `sh /usr/local/etc/rc.d/rules_wam_ssl.sh restart` e verifique se a WebGUI do pfSense não está na porta 443. |
| Usuários recebem erro SSL no navegador | CA não instalada na estação | Distribua a CA corporativa (`rules_wam_ca.crt`) via GPO do Active Directory. |
| Regras não aplicaram após salvar | Cache do Unbound retendo registros antigos | Execute `unbound-control flush_zone .` no terminal ou clique em Salvar novamente. |
| Um site legítimo foi bloqueado por engano | Falso positivo no feed de categorias | Adicione o domínio em **Exceções & Personalização > Domínios Liberados (Whitelist)** e salve. |

---

## 10. Procedimento de Desinstalação

Caso precise remover completamente o Rules WAM de um firewall:

1. Transfira o script `uninstall.sh` para o firewall (ou execute diretamente se o diretório estiver montado):
   ```bash
   scp /home/hermes/pfsense-wam/uninstall.sh root@<IP_DO_FIREWALL>:/tmp/
   ```
2. No terminal do pfSense, execute como root:
   ```bash
   sh /tmp/uninstall.sh
   ```
3. O script:
   - Encerra o NGINX SSL e remove suas regras de inicialização.
   - Remove o arquivo `/var/unbound/conf.d/wam_blocklist.conf` e recarrega o Unbound.
   - Remove todos os scripts PHP, XMLs e páginas web do Rules WAM.
   - Limpa as entradas do pacote, dos menus e do Cron no `config.xml`.
   - Restaura o firewall ao seu estado original limpo.

---

**Rules WAM — Desenvolvido para Segurança e Conformidade Corporativa.**  
*Documentação técnica e operacional do Rules WAM para pfSense.*
