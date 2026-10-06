# 🚀 Guia Prático de Instalação do Rules WAM no pfSense
## Procedimento de Implantação a partir de um Notebook / Estação de Trabalho

Este guia detalha o passo a passo para implantar o pacote **Rules WAM 1.4.3 (versão em testes)** em qualquer firewall **pfSense (versões 2.7.x, 2.8.x ou pfSense Plus)** utilizando apenas o seu notebook.

> [!WARNING]
> **Versão em testes.** Até agora o Rules WAM só foi executado em ambiente de laboratório (um pfSense de testes). Não use em produção sem antes validar no seu próprio laboratório. Use por sua conta e risco.

---

## 📑 Sumário
1. [Preparação no Notebook](#1-preparação-no-notebook)
2. [Método 1: Instalação 100% pelo Navegador (WebGUI)](#2-método-1-instalação-100-pelo-navegador-webgui---recomendado)
3. [Método 2: Instalação via Terminal / SSH do Notebook](#3-método-2-instalação-via-terminal--ssh-do-notebook)
4. [⚠️ Importante: Porta da WebGUI e Banner HTTP](#4-️-importante-porta-da-webgui-e-banner-http)
5. [Configuração Inicial no Painel Rules WAM](#5-configuração-inicial-no-painel-rules-wam)
6. [Comandos Rápidos de Validação e Teste](#6-comandos-rápidos-de-validação-e-teste)
7. [Desinstalação / Remoção Limpa](#7-desinstalação--remoção-limpa)

---

## 1. Preparação no Notebook

Antes de iniciar, tenha em mãos o instalador **`wam-install.sh`** no seu notebook (ele também está dentro do `rules-wam-pacote.zip`).

> [!NOTE]
> O `wam-install.sh` (~130 KB) é um auto-extraível: contém o pacote inteiro (código PHP, formulários XML da WebGUI e os 28 arquivos de feed das 12 categorias) e executa o mesmo `install.sh` do pacote. Você só precisa enviar este arquivo para o pfSense.

> [!TIP]
> Obtenha o arquivo por um canal confiável e confira o **SHA-256** antes de executar. No notebook: `sha256sum wam-install.sh` (Linux) ou `Get-FileHash wam-install.sh` (PowerShell). No pfSense: `sha256 /tmp/wam-install.sh`. Os dois valores devem ser iguais ao hash publicado junto ao arquivo.

### Opções do instalador

```text
sh wam-install.sh [--move-gui] [--gui-port=50443] [--wan-gui-sources=IP1,IP2|none]
```

| Opção | Quando usar |
|---|---|
| `--move-gui` | A WebGUI está nas portas 80/443 (ou com redirecionamento HTTP ativo) e você quer o banner. Move a WebGUI para `--gui-port` e desativa o redirecionamento HTTP. |
| `--gui-port=50443` | Porta nova da WebGUI quando usar `--move-gui` (padrão `50443`). |
| `--wan-gui-sources=IP1,IP2` ou `none` | **Obrigatório ao atualizar da 1.3.** IPs públicos que podem acessar a WebGUI pela WAN, ou `none` para não liberar a WAN. Sem esta opção (e sem terminal interativo), a instalação é **interrompida sem alterar nada**. |

Em um terminal SSH interativo, o instalador pergunta na tela o que faltar.

---

## 2. Método 1: Instalação 100% pelo Navegador (WebGUI - Recomendado)

Este método não requer programas adicionais (como PuTTY ou clientes SCP). Tudo é feito diretamente pelo navegador do seu notebook.

### Passo 2.1: Enviar o instalador para o firewall
1. No navegador do seu notebook, acesse a interface web do pfSense:
   `https://<IP_DO_PFSENSE>`
2. Faça login com o usuário administrador (`admin`).
3. No menu superior, clique em **Diagnostics** > **Command Prompt**.
4. Role a página até a seção **Upload File**.
5. Clique em **Escolher arquivo** (ou *Browse*) e selecione o arquivo `wam-install.sh` do seu notebook.
6. Clique no botão **Upload**.
7. O pfSense salvará o arquivo em `/tmp/wam-install.sh`.

### Passo 2.2: Executar o comando de instalação
1. Na mesma tela, localize a caixa **Execute Shell Command**.
2. Confira o hash: `sha256 /tmp/wam-install.sh` e clique em **Execute**.
3. Digite o comando de instalação com as opções desejadas. Exemplos:
   ```bash
   # Instalação nova, liberando as portas 80/443 para o banner:
   sh /tmp/wam-install.sh --move-gui

   # Atualização a partir da 1.3, sem acesso à WebGUI pela WAN:
   sh /tmp/wam-install.sh --move-gui --wan-gui-sources=none

   # Atualização a partir da 1.3, mantendo a WAN só para IPs da TI:
   sh /tmp/wam-install.sh --wan-gui-sources=203.0.113.10,198.51.100.0/24
   ```
   > Pelo **Command Prompt** não há terminal interativo: informe as opções na linha de comando.
4. Clique em **Execute** e aguarde (cerca de 15 a 30 segundos).
5. Ao final, a saída mostra:
   ```text
   ======================================================
    Rules WAM instalado.
   ======================================================
    Menu:   Services > Rules WAM
    Desinstalar: sh /usr/local/share/wam/uninstall.sh
    WebGUI: https://<IP-do-firewall>:50443
   ======================================================
   ```
   Se a WebGUI foi movida, ela reinicia em segundo plano: recarregue o navegador na nova porta.

---

## 3. Método 2: Instalação via Terminal / SSH do Notebook

Se você preferir utilizar linha de comando a partir do Windows PowerShell, Terminal do macOS ou Linux:

### Passo 3.1: Enviar o arquivo via SCP
Abra o terminal do seu notebook na pasta onde está o arquivo `wam-install.sh`:
```bash
scp wam-install.sh root@<IP_DO_PFSENSE>:/tmp/
```

### Passo 3.2: Acessar o firewall via SSH
```bash
ssh root@<IP_DO_PFSENSE>
```
> [!TIP]
> Se ao conectar o pfSense exibir o menu textual de opções numeradas, digite **`8`** e tecle Enter para acessar o **Shell**.

### Passo 3.3: Executar o instalador
```bash
sha256 /tmp/wam-install.sh
sh /tmp/wam-install.sh --move-gui
```
Sem as opções, o instalador pergunta interativamente se deve mover a WebGUI (`[s/N]`) e, na atualização da 1.3, quais IPs podem acessar pela WAN.

---

## 4. ⚠️ Importante: Porta da WebGUI e Banner HTTP

* **Por que a porta 80 precisa estar livre?**
  O banner de bloqueio é servido por um NGINX dedicado que escuta **somente no IP do banner**, nas portas **80** e **443**. Se a WebGUI do pfSense usar 80/443 (ou o redirecionamento HTTP estiver ativo), o banner não sobe.
* **O que o instalador faz?**
  * Com `--move-gui` (ou resposta `s` na pergunta interativa): move a WebGUI para `50443` (ou a porta de `--gui-port`) e desativa o redirecionamento HTTP.
  * Sem autorização: **não altera a WebGUI**. O bloqueio funciona em **modo silencioso (0.0.0.0)** e a aba **Status & Teste de Bloqueio** mostra um aviso até a porta ser liberada.
* **O que o instalador NÃO faz:**
  * Não cria regras na WAN (exceto a regra restrita às origens de `--wan-gui-sources` / *Origens Autorizadas pela WAN*).
  * Não desliga bogons, redes privadas na WAN nem a proteção contra DNS rebind.
  * Não altera arquivos do núcleo do pfSense.
* **Acesso administrativo:** em cada interface interna é criada uma regra liberando a porta da WebGUI com destino ao próprio firewall (`(self)`). A regra anti-lockout nativa da LAN continua valendo.
* **Banner somente HTTP (sem CA):** as máquinas clientes não recebem CA. Por isso, acessos **HTTP (80)** mostram a página institucional e acessos **HTTPS (443)** ao IP do banner têm o handshake TLS recusado na hora: o navegador mostra um erro de conexão, sem aviso de certificado. Como quase todos os sites usam HTTPS, a maioria dos bloqueios aparecerá como erro de conexão.
* **Como acessar o pfSense depois de `--move-gui`:**
  👉 **`https://<IP_DO_PFSENSE>:50443`**

> [!CAUTION]
> **Atualização a partir da 1.3:** os ajustes que a 1.3 fez no config.xml (porta 50443, DNS rebind desativado, bogons/redes privadas liberados na WAN) **continuam como estavam**. Revise manualmente em *System > Advanced > Admin Access* e em *Interfaces > WAN*. A CA e o certificado do banner HTTPS da 1.3 são removidos do Gerenciador de Certificados.

---

## 5. Configuração Inicial no Painel Rules WAM

Após a instalação, acesse a WebGUI administrativa do pfSense:

1. Vá ao menu superior **Services** > **Rules WAM**.
2. **Habilitar Serviço:** Verifique se a caixa **"Habilitar Rules WAM"** está marcada.
3. **Ação de Bloqueio:**
   * **Exibir Banner de Bloqueio da Empresa (HTTP) — Padrão:**
     O Unbound responde com o IP do banner. HTTP mostra a página institucional; HTTPS falha na hora com erro de conexão. Exige a WebGUI fora de 80/443.
   * **Retornar 0.0.0.0 (Silencioso):**
     O Unbound responde `0.0.0.0` e o navegador recusa a conexão imediatamente.
   * Em nenhum dos modos é preciso instalar certificados nas estações.
4. **Categorias de Bloqueio:**
   Marque as categorias que deseja bloquear (Adulto, Apostas, Jogos, Mídias Sociais, Mensageiros, VPN/ZTNA, etc.).
   - **WhatsApp:** bloqueia por DNS e pelas portas 5222/4244. A opção **"Bloquear também por faixa IP"** vem desligada: as faixas são da Meta e o bloqueio afeta Facebook e Instagram.
   - **Anti-Bypass DoH:** marcando esta categoria, o DNS-over-TLS (porta 853) também é bloqueado.
5. **Isenção de Dispositivos (Bypass IPs):**
   Adicione os IPs/redes que não devem sofrer bloqueio (Diretoria, TI, Servidores).
6. **Integração Corporativa (Se aplicável):**
   Preencha o domínio do Active Directory (ex: `empresa.local`) e os IPs dos DNS/Controladores de Domínio. As **redes autorizadas** padrão são `10.0.0.0/8`, `172.16.0.0/12` e `192.168.0.0/16`.
7. **E-mail do Suporte (Banner):** usado no botão "Contatar Suporte TI" do banner. Em branco, o botão não aparece.
8. **Acesso Administrativo à WebGUI:**
   * **Origens Internas Autorizadas:** IPs/redes da TI que podem acessar a WebGUI pelas redes internas. Em branco = qualquer origem interna.
   * **Origens Autorizadas pela WAN:** em branco = nenhuma regra na WAN (recomendado).
9. Clique no botão **Salvar e Aplicar Regras** no rodapé da página.

### 5.1. Adicionar o Widget do Rules WAM na Página Inicial (Dashboard)

Para acompanhar o status em tempo real sem precisar navegar até os menus:
1. No menu superior do pfSense, clique em **Status** > **Dashboard**.
2. Clique no botão **`+`** (**Available Widgets**) no canto superior direito.
3. Clique em **Rules WAM - Web Access Manager**.
4. O widget exibe:
   * **Status do Serviço:** Estado geral (Ativo / Pausado / Desativado), DNS Unbound, Banner NGINX e total de domínios bloqueados.
   * **Categorias Filtradas:** Badges com as categorias ativas.
   * **Resumo Macro de Hosts por Rede:** hosts online (ARP), dispositivos que tentaram acessar domínios bloqueados, volume de bloqueios e dispositivos em Bypass por interface.
   * **Atalhos Rápidos:** Configurações, Status e Auditoria/Exportação CSV.
5. Clique em **Save Settings** no topo do Dashboard.

## 6. Comandos Rápidos de Validação e Teste

No terminal ou no menu **Diagnostics > Command Prompt** do pfSense:

1. **Testar se o Unbound está interceptando domínios bloqueados:**
   ```bash
   drill @127.0.0.1 xvideos.com
   ```
   *Deve responder com o IP do banner (modo Banner) ou `0.0.0.0` (modo silencioso).*

2. **Testar se o domínio corporativo continua resolvendo normalmente:**
   ```bash
   drill @127.0.0.1 <dominio_corporativo.local>
   ```

3. **Verificar o NGINX do banner (modo Banner):**
   ```bash
   sockstat -4 -l -p 80,443
   ```
   *O `nginx` do banner deve aparecer só no IP do banner (ex.: `192.168.1.1:80` e `192.168.1.1:443`), nunca em `*:80`.*

4. **Verificar erros da configuração do Unbound:**
   ```bash
   cat /var/log/wam_checkconf_err.log
   ```
   *Vazio ou inexistente = sem erros.*

5. **Acompanhar os logs de auditoria em tempo real:**
   ```bash
   tail -f /var/log/wam_audit.log
   ```
   *Só acessos HTTP ao banner geram registro (HTTPS é recusado antes de chegar à página).*

---

## 7. Desinstalação / Remoção Limpa

O desinstalador é copiado para o firewall durante a instalação. Para remover o Rules WAM:

```bash
sh /usr/local/share/wam/uninstall.sh
```

O script:
- **reverte a configuração primeiro**: include do Unbound, domain overrides, regras de firewall, NAT, aliases, menus, cron e widget; restaura o `log_queries`;
- restaura a porta e o redirecionamento da WebGUI **se foi o pacote que os alterou** (em instalações atualizadas da 1.3, a porta não é restaurada automaticamente; revise em *System > Advanced > Admin Access*);
- depois para o banner e apaga os arquivos do pacote;
- **mantém** o log de auditoria em `/var/log/wam_audit.log` (apague se não precisar).
