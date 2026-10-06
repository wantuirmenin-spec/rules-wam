# Rules WAM - Web Access Manager para pfSense 🛡️

**Versão 1.4.0** — veja o [CHANGELOG](CHANGELOG.md).

Pacote corporativo nativo para **pfSense 2.7.x / 2.8.x / Plus** projetado para controle corporativo de acesso à internet, **bloqueio de categorias de sites**, **página de bloqueio institucional (HTTP)**, **agendamento por horário comercial**, **isenção por dispositivo (Bypass IPs)** e **integração com Active Directory, NPS RADIUS e Netskope** via Unbound DNS.

📖 **Consulte o manual completo:** [Manual do Administrador & Guia de Implantação](MANUAL_DO_ADMINISTRADOR.md) · [Guia de Instalação](MANUAL_DE_INSTALACAO.md)

> [!WARNING]
> A versão 1.4.0 ainda **não foi testada em um pfSense real**. Valide primeiro em uma unidade de laboratório.

---

## 📋 12 Categorias Prontas para Bloqueio

Você pode ativar ou desativar qualquer categoria individualmente pelo painel web do pfSense:

1. 🔞 **Conteúdo Adulto & Pornografia (`block_adult`):**
   - Sites adultos e explícitos: Pornhub, XVideos, XNXX, RedTube, YouPorn, XHamster, SpankBang, Erome, Beeg, Brazzers, RealityKings, etc.
   - Cams, transmissões e plataformas de assinatura: Chaturbate, Stripchat, OnlyFans, Fansly, Privacy, etc.

2. 📰 **Notícias, Portais & Jornalismo (`block_news`):**
   - Nacionais: G1, Globo.com, O Globo, UOL, Folha, Estadão, CNN Brasil, R7, Metrópoles, Terra, Jovem Pan, Gazeta do Povo, Poder360, Veja, Exame, etc.
   - Internacionais: CNN, BBC, Reuters, Bloomberg, The New York Times, The Guardian, El País, etc.

3. ⚽ **Esportes, Futebol & Placares ao Vivo (`block_sports`):**
   - Portais: GE (Globo Esporte), ESPN, Lance!, TNT Sports, Gazeta Esportiva, Trivela, Goal.com, etc.
   - Placares e estatísticas: Flashscore, SofaScore, 365Scores, LiveScore, WhoScored, etc.
   - Ligas e transmissões/streamings de jogos (incluindo piratas): FIFA, UEFA, CBF, NBA, NFL, UFC, F1, Futemax, Multicanais, etc.

4. 🎮 **Jogos Online & Games (`block_gaming`):**
   - Plataformas: Steam, Epic Games, Roblox, Riot Games (LoL, Valorant), Blizzard/Battle.net, Minecraft, EA/Origin, Ubisoft, Xbox Live, PlayStation Network, etc.
   - Jogos casuais e mobile: Free Fire, Brawl Stars, Clash of Clans, Supercell, Poki, Y8, etc.

5. 🛍️ **Compras & E-commerce (`block_shopping`):**
   - Mercado Livre, Shopee, AliExpress, Shein, Amazon Brasil, Magalu, Casas Bahia, Americanas, Kabum, Pichau, OLX, Enjoei, etc.

6. 📱 **Mídias Sociais (`block_social`):**
   - Facebook, Instagram, Threads, TikTok, Twitter/X, Kwai, LinkedIn, Pinterest, Snapchat, Reddit, Discord, Bluesky, etc.

7. 🎬 **Streaming & Vídeo (`block_streaming`):**
   - YouTube, Netflix, Prime Video, Disney+, Twitch, TikTok Live, Spotify, Deezer, Pluto TV, etc.

8. 🎲 **Apostas, Bets & Cassinos (`block_gambling`):**
   - Bet365, Betano, Sportingbet, Blaze, Stake, Pixbet, EstrelaBet, Superbet, Novibet, etc.

9. ⚡ **Torrents & P2P (`block_p2p`):**
   - The Pirate Bay, 1337x, YTS, Torrentz, BitTorrent, uTorrent, trackers públicos, etc.

10. 🚫 **Anti-Bypass / Bloqueio DoH (`block_doh`):**
    - Bloqueio de servidores DNS-over-HTTPS públicos (Cloudflare, Google, Quad9) para impedir que navegadores e celulares burlem o filtro.
    - Com esta categoria marcada, também é bloqueado o DNS-over-TLS (porta 853).

11. 🔒 **VPN, ZTNA & Proxies Anônimos (`block_vpn`):**
    - Controle granular com opção de desativar fornecedores específicos individualmente:
      - 🛡️ **Fortinet / FortiGate SSL-VPN (`block_vpn_fortinet`)**
      - 🛡️ **Cisco AnyConnect & Secure Client (`block_vpn_cisco`)**
      - 🛡️ **Palo Alto GlobalProtect (`block_vpn_paloalto`)**
      - ☁️ **Zscaler Cloud (`block_ztna_zscaler`)**
      - ☁️ **Netskope Security Cloud (`block_ztna_netskope`)**
      - ☁️ **Cloudflare WARP & Zero Trust (`block_ztna_cloudflare`)**
      - ☁️ **Tailscale & Mesh Tunnels (`block_ztna_tailscale`)**
      - 🌐 **VPNs Comerciais & Proxies Web (`block_vpn_commercial`)**

12. 💬 **Mensageiros & Ferramentas de Comunicação (`block_messaging`):**
    - Controle granular por aplicativo:
      - 💬 **WhatsApp (`block_msg_whatsapp`)** — DNS + portas 5222/4244; bloqueio por faixa IP opcional (desligado por padrão, afeta Facebook/Instagram)
      - 💬 **Telegram (`block_msg_telegram`)**
      - 💬 **Facebook Messenger (`block_msg_messenger`)**
      - 💬 **Microsoft Teams & Skype (`block_msg_teams_skype`)**
      - 💬 **Discord (`block_msg_discord`)**
      - 💬 **Slack (`block_msg_slack`)**
      - 💬 **Zoom & Google Meet (`block_msg_zoom_meet`)**
      - 💬 **Outros Mensageiros (`block_msg_others`)**

---

## ⏰ Agendamento por Horário Comercial (Time Schedule)

- **Horário de início e fim** (ex: das `08:00` às `18:00`).
- **Intervalo de almoço liberado** (ex: das `12:00` às `13:30` liberado automaticamente).
- **Fins de semana:** Opção de liberar o acesso aos sábados e domingos ou manter bloqueado.
- Cron nativo no pfSense verifica o horário a cada 5 minutos e volta a bloquear sozinho após cada pausa.
- Fora do horário, as regras de firewall do pacote (WhatsApp, DoT, NAT da porta 53) também são suspensas.
- Horários são normalizados (`8:00` → `08:00`) e janelas que passam da meia-noite são aceitas.

---

## 🛡️ Isenção de Dispositivos (Bypass IPs)

- Permite definir uma lista de endereços IP da rede local (TI, Diretoria, Servidores).
- O Unbound associa esses IPs à *view* `wam_bypass`, que ignora as zonas de bloqueio.
- Os IPs isentos continuam resolvendo os host overrides e os registros DHCP do pfSense.

---

## 🏢 Integração Corporativa: Active Directory, NPS (RADIUS) & Netskope

- **Split-DNS Automático para AD e NPS RADIUS:** Encaminha consultas para o domínio corporativo (ex: `empresa.local`, registros SRV do Kerberos/LDAP e autenticação RADIUS) diretamente aos servidores da Matriz pela VPN IPsec através de **Domain Overrides** sincronizados no pfSense.
- **Bypass de Anti-Rebinding e DNSSEC:** Configura `private-domain` e `domain-insecure` no Unbound **somente para os domínios do AD informados**. A proteção global contra DNS rebind do pfSense não é desligada.
- **Auto-Whitelist para Netskope Security Cloud & IdP:** Protege os domínios da Netskope (`goskope.com`, `netskope.com`, ...) e **apenas os endpoints de login** dos IdPs (ex.: `login.microsoftonline.com`, `login.live.com`, `okta.com`, `accounts.google.com`). Não libera `microsoft.com`/`office.com` inteiros, para não anular o bloqueio de Teams/Skype.
- **Auto-Whitelist de Ferramentas de TI & Downloads de Admin:** Libera downloads essenciais de ferramentas como PuTTY (`putty.org`, `chiark.greenend.org.uk`, `the.earth.li`), WinSCP, 7-Zip, Notepad++, Git, GitHub, GitLab, SourceForge, Sysinternals, Wireshark, Nmap, DBeaver e Python, impedindo que feeds gerais interrompam o trabalho das equipes de suporte e infraestrutura.
- **Auto-Whitelist de Helpdesk & Suporte Remoto (Zendesk, GLPI, ScreenConnect):** Garante imunidade absoluta contra bloqueios acidentais para plataformas de chamados e atendimento (Zendesk e chat Zopim), ITSM/inventário (GLPI) e sessões de suporte e assistência remota (ConnectWise ScreenConnect).
- **Proteção de Telefonia IP, Protocolo SIP & Aparelhos SIP Phone:** Assegura que servidores SIP, softphones (Zoiper, Linphone, MicroSIP), PABX em nuvem (3CX, Twilio, Telnyx, etc.), servidores STUN/TURN e provisionamento de telefones IP corporativos (Yealink, Grandstream, Intelbras) permaneçam 100% operacionais.
- **Proteção da Infraestrutura Cloudflare:** Garante que a CDN (`cdnjs.cloudflare.com`), validações de Captcha Turnstile (`challenges.cloudflare.com`) e APIs necessárias para navegação e downloads continuem funcionando perfeitamente, mesmo com o bloqueio opcional do cliente Cloudflare WARP ativado.
- **Banner de Bloqueio Educativo (somente HTTP):** Ação padrão (`block_page`). Acessos **HTTP (80)** mostram a página institucional; acessos **HTTPS (443)** ao IP do banner têm o handshake TLS recusado na hora (o navegador mostra erro de conexão, sem aviso de certificado). Não há CA para instalar nas máquinas.
- **Sem CA nas estações:** como as máquinas clientes não recebem nenhuma CA, qualquer página HTTPS servida pelo firewall geraria um aviso de certificado. Por isso o banner é só HTTP e a 443 falha rápido.
- **WebGUI fora das portas 80/443:** o banner só funciona com a WebGUI em outra porta e sem redirecionamento HTTP. O instalador só move a WebGUI com `--move-gui` (ou confirmação interativa); caso contrário o bloqueio funciona no modo silencioso (0.0.0.0) e a aba Status mostra um aviso.

---

## 📊 Widget Nativo para o Dashboard do pfSense

O Rules WAM acompanha um **Widget exclusivo para a tela inicial do pfSense** (`Status > Dashboard`):
* **Status do Serviço:** Estado em tempo real (Ativo / Pausado / Desativado), status do Unbound DNS Resolver e do NGINX do banner.
* **Categorias Ativas:** Tags visuais coloridas com ícones mostrando exatamente quais categorias estão sob filtro.
* **Resumo Macro de Hosts por Rede:** Tabela executiva com coleta direta das interfaces e descrições cadastradas no pfSense (WAN, LAN, OPTs, VLANs, OpenVPN), exibindo identificador lógico, nome amigável da rede e porta física (ex: `LAN — Rede Corporativa (igb1)`, `OPT1 — WiFi Visitantes (igb2)`, `OpenVPN — Acesso Remoto (ovpns1)`):
  * Identificação automática do nome amigável e sub-redes ativas no firewall.
  * Hosts Online ativos na rede (descoberta via ARP / NDP por sub-rede).
  * Quantidade de computadores que tentaram acessar domínios bloqueados.
  * Volume acumulado de requisições bloqueadas.
  * Dispositivos em Bypass (isenção de filtro).
* **Auto-refresh & Botão de Atualização Instantânea:** Atualização automática em segundo plano via AJAX a cada 60s sem recarregar o navegador.

---

## 🚀 Como Instalar em Qualquer pfSense

O instalador `wam-install.sh` (~130 KB) é um auto-extraível que contém o pacote inteiro (28 arquivos de feed das 12 categorias, telas da WebGUI, lógica PHP, configuração do NGINX do banner e agendador Cron) e executa o mesmo `install.sh` do pacote.

```text
sh wam-install.sh [--move-gui] [--gui-port=50443] [--wan-gui-sources=IP1,IP2|none]
```

| Opção | Efeito |
|---|---|
| `--move-gui` | Se a WebGUI estiver em 80/443 (ou com redirecionamento HTTP), move para `--gui-port` e desativa o redirecionamento, liberando a porta 80 para o banner. |
| `--gui-port=` | Porta nova da WebGUI (padrão `50443`). |
| `--wan-gui-sources=` | **Obrigatório na atualização a partir da 1.3**: IPs públicos que podem acessar a WebGUI pela WAN, ou `none`. Sem ele, a instalação é abortada sem alterações. |

O instalador **não** altera bogons, redes privadas na WAN nem a proteção contra DNS rebind.

### Passo 1: Enviar o Instalador para o Firewall
Por `scp` ou pelo upload em **Diagnostics > Command Prompt > Upload File** (salva em `/tmp/wam-install.sh`). Confira o SHA-256 antes de executar:
```bash
scp wam-install.sh root@<IP_DO_PFSENSE>:/tmp/
sha256 /tmp/wam-install.sh   # no pfSense; compare com o hash publicado junto ao arquivo
```

### Passo 2: Executar no pfSense
Via SSH (opção `8) Shell`) ou em **Diagnostics > Command Prompt > Execute Shell Command**:
```bash
sh /tmp/wam-install.sh --move-gui
```

### Passo 3: Acessar a Interface Web
1. Acesse a WebGUI (na nova porta, se usou `--move-gui`: `https://<IP>:50443`).
2. No menu superior, acesse **Services > Rules WAM** (ou **Firewall > Rules WAM**).
3. Marque as categorias, horários, IPs isentos e as origens autorizadas da WebGUI.
4. Clique em **Salvar e Aplicar Regras**.
5. Confira a aba **Status & Teste de Bloqueio** (avisos de conflito de porta aparecem ali).

### Desinstalar
```bash
sh /usr/local/share/wam/uninstall.sh
```
Reverte a configuração antes de apagar os arquivos e mantém o log de auditoria.

---

## 📄 Documentação Completa

Para detalhes de arquitetura, regras de firewall criadas, comandos de manutenção e resolução de problemas, leia:
👉 [Manual do Administrador & Guia de Implantação](MANUAL_DO_ADMINISTRADOR.md)
👉 [Guia Prático de Instalação](MANUAL_DE_INSTALACAO.md)
👉 [CHANGELOG](CHANGELOG.md)
