# Rules WAM - Web Access Manager para pfSense 🛡️

Pacote corporativo nativo para **pfSense 2.7.x / 2.8.x / Plus** projetado para controle corporativo de acesso à internet, **bloqueio de categorias de sites**, **página de bloqueio institucional com suporte HTTPS**, **agendamento por horário comercial**, **isenção por dispositivo (Bypass IPs)** e **integração com Active Directory, NPS RADIUS e Netskope** via Unbound DNS.

📖 **Consulte o manual completo:** [Manual do Administrador & Guia de Implantação](file:///home/hermes/pfsense-wam/MANUAL_DO_ADMINISTRADOR.md)

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
      - 💬 **WhatsApp (`block_msg_whatsapp`)**
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
- Cron nativo no pfSense verifica o horário a cada 5 minutos sem reiniciar serviços bruscamente.

---

## 🛡️ Isenção de Dispositivos (Bypass IPs)

- Permite definir uma lista de endereços IP da rede local (TI, Diretoria, Servidores).
- O Unbound cria automaticamente uma `access-control-view` separada para esses IPs.
- Dispositivos isentos navegam com resolução direta sem overhead ou regras de NAT.

---

## 🏢 Integração Corporativa: Active Directory, NPS (RADIUS) & Netskope

- **Split-DNS Automático para AD e NPS RADIUS:** Encaminha consultas para o domínio corporativo (ex: `madeiramadeira.local`, registros SRV do Kerberos/LDAP e autenticação RADIUS) diretamente aos servidores da Matriz pela VPN IPsec através de **Domain Overrides** sincronizados no pfSense.
- **Bypass de Anti-Rebinding e DNSSEC:** Configura automaticamente diretivas `private-domain` e `domain-insecure` no Unbound para garantir que respostas com endereços IP privados (RFC 1918) não sejam bloqueadas pelo firewall.
- **Auto-Whitelist para Netskope Security Cloud:** Protege permanentemente todos os domínios da Netskope (`goskope.com`, `netskope.com`, gateways ZTNA/NPA e IdPs como Microsoft Entra ID / Okta), impedindo quedas acidentais no agente Netskope.
- **Auto-Whitelist de Ferramentas de TI & Downloads de Admin:** Libera downloads essenciais de ferramentas como PuTTY (`putty.org`, `chiark.greenend.org.uk`, `the.earth.li`), WinSCP, 7-Zip, Notepad++, Git, GitHub, GitLab, SourceForge, Sysinternals, Wireshark, Nmap, DBeaver e Python, impedindo que feeds gerais interrompam o trabalho das equipes de suporte e infraestrutura.
- **Auto-Whitelist de Helpdesk & Suporte Remoto (Zendesk, GLPI, ScreenConnect):** Garante imunidade absoluta contra bloqueios acidentais para plataformas de chamados e atendimento (Zendesk e chat Zopim), ITSM/inventário (GLPI) e sessões de suporte e assistência remota (ConnectWise ScreenConnect).
- **Proteção de Telefonia IP, Protocolo SIP & Aparelhos SIP Phone:** Assegura que servidores SIP, softphones (Zoiper, Linphone, MicroSIP), PABX em nuvem (3CX, Twilio, Telnyx, etc.), servidores STUN/TURN e provisionamento de telefones IP corporativos (Yealink, Grandstream, Intelbras) permaneçam 100% operacionais.
- **Proteção da Infraestrutura Cloudflare:** Garante que a CDN mundial (`cdnjs.cloudflare.com`), validações de Captcha Turnstile (`challenges.cloudflare.com`) e APIs necessárias para navegação e downloads continuem funcionando perfeitamente, mesmo com o bloqueio opcional do cliente Cloudflare WARP ativado.
- **Banner de Bloqueio Educativo Nativo (HTTP/HTTPS):** Pré-configurado como ação padrão (`block_page`), com geração automática de certificados SSL e migração da WebGUI administrativa para a porta 50443, deixando as portas 80 e 443 livres para a exibição imediata da tela de bloqueio institucional.

---

## 📊 Widget Nativo para o Dashboard do pfSense

O Rules WAM acompanha um **Widget exclusivo para a tela inicial do pfSense** (`Status > Dashboard`):
* **Status do Serviço:** Estado em tempo real (Ativo / Pausado / Desativado), status do Unbound DNS Resolver e do NGINX Banner.
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

O instalador `wam-install.sh` embute todos os 12 feeds, as telas da WebGUI, a lógica PHP, a CA SSL, a instância NGINX e o agendador Cron em um único arquivo autônomo de ~277 KB.

### Passo 1: Enviar o Instalador para o Firewall
```bash
scp /home/hermes/pfsense-wam/wam-install.sh root@<IP_DO_PFSENSE>:/tmp/
```

### Passo 2: Executar no Terminal do pfSense
```bash
ssh root@<IP_DO_PFSENSE>
chmod +x /tmp/wam-install.sh
sh /tmp/wam-install.sh
```

### Passo 3: Acessar a Interface Web
1. No menu superior do pfSense, acesse: **Services > Rules WAM** (ou **Firewall > Rules WAM**).
2. Marque as categorias desejadas, configure os horários e IPs isentos.
3. Clique em **Save**.
4. Acesse a aba **Status & Teste de Bloqueio** ou a aba **Dashboard & Tentativas de Acesso**.

---

## 📄 Documentação Completa

Para detalhes de arquitetura, distribuição de certificados via GPO no Active Directory, comandos de manutenção e resolução de problemas, leia:
👉 [Manual do Administrador & Guia de Implantação](file:///home/hermes/pfsense-wam/MANUAL_DO_ADMINISTRADOR.md)
