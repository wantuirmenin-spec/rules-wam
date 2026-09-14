# 🚀 Guia Prático de Instalação do Rules WAM no pfSense
## Procedimento de Implantação a partir de um Notebook / Estação de Trabalho

Este guia detalha o passo a passo para implantar o pacote **Rules WAM** em qualquer firewall **pfSense (versões 2.7.x, 2.8.x ou pfSense Plus)** utilizando apenas o seu notebook.

---

## 📑 Sumário
1. [Preparação no Notebook](#1-preparação-no-notebook)
2. [Método 1: Instalação 100% pelo Navegador (WebGUI)](#2-método-1-instalação-100-pelo-navegador-webgui---recomendado)
3. [Método 2: Instalação via Terminal / SSH do Notebook](#3-método-2-instalação-via-terminal--ssh-do-notebook)
4. [⚠️ Importante: Alteração da Porta da WebGUI (8443)](#4-️-importante-alteração-da-porta-da-webgui-8443)
5. [Configuração Inicial no Painel Rules WAM](#5-configuração-inicial-no-painel-rules-wam)
6. [Comandos Rápidos de Validação e Teste](#6-comandos-rápidos-de-validação-e-teste)
7. [Desinstalação / Remoção Limpa](#7-desinstalação--remoção-limpa)

---

## 1. Preparação no Notebook

Antes de iniciar, tenha em mãos o instalador standalone **`wam-install.sh`** no seu notebook.

- Se estiver na rede interna onde o servidor de arquivos está rodando:
  👉 Baixe diretamente em: `http://172.24.60.32:8000/wam-install.sh`
- Ou extraia o arquivo `wam-install.sh` de dentro do `rules-wam-pacote.zip`.

> [!NOTE]
> O arquivo `wam-install.sh` é totalmente autossuficiente (~300 KB). Ele contém todos os códigos PHP, formulários XML da WebGUI, certificados SSL e todas as 28 bases de domínios corporativos embutidos. Você só precisa enviar este arquivo único para o pfSense.

---

## 2. Método 1: Instalação 100% pelo Navegador (WebGUI - Recomendado)

Este método não requer programas adicionais (como PuTTY ou clientes SCP). Tudo é feito diretamente pelo navegador do seu notebook.

### Passo 2.1: Enviar o instalador para o firewall
1. No navegador do seu notebook, acesse a interface web do pfSense:
   `https://<IP_DO_PFSENSE>`
2. Faça login com o usuário administrador (`admin`).
3. No menu superior, clique em **Diagnostics** > **Command Prompt**.
4. Role a página até a seção **Upload File**.
5. Clique em **Escolher arquivo** (ou *Browse* / *Selecionar arquivo*) e selecione o arquivo `wam-install.sh` do seu notebook.
6. Clique no botão **Upload**.
7. O pfSense salvará o arquivo automaticamente no caminho `/tmp/wam-install.sh`.

### Passo 2.2: Executar o comando de instalação
1. Na mesma tela de **Diagnostics > Command Prompt**, localize a caixa **Execute Shell Command**.
2. Digite ou cole o seguinte comando:
   ```bash
   sh /tmp/wam-install.sh
   ```
3. Clique no botão **Execute**.
4. Aguarde cerca de 15 a 30 segundos enquanto o script é processado.
5. Na saída do comando exibida na tela, você verá o progresso e a mensagem final:
   ```text
   ======================================================
    🎉 INSTALAÇÃO DO RULES WAM CONCLUÍDA COM SUCESSO!
   ======================================================
   👉 Menu: Services > Rules WAM
   👉 Dashboard: Aba 'Dashboard & Tentativas de Acesso'
   👉 Anti-Bypass DNS (Porta 53 NAT): Desativado por padrão
   👉 Exportação: CSV para Excel e JSON nativo
   👉 WebGUI: https://<IP>:50443
   ======================================================
   ```

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
> Se ao conectar o pfSense exibir o menu textual de opções numeradas (de 0 a 16), digite **`8`** e tecle Enter para acessar o **Shell**.

### Passo 3.3: Executar o instalador
```bash
chmod +x /tmp/wam-install.sh
sh /tmp/wam-install.sh
```

---

## 4. ⚠️ Importante: Porta da WebGUI (50443) e Blindagem de Acesso

Durante o processo de instalação ou atualização, o script analisa a configuração da interface web do pfSense:

* **Por que a porta 443 é liberada?**  
  A página de bloqueio visual HTTPS (Banner) necessita escutar na porta padrão **443** (e **80**) para interceptar as requisições dos usuários aos sites bloqueados.
* **O que o instalador faz?**  
  Se a WebGUI administrativa do firewall estiver configurada na porta 443 (ou se você desejar padronizar), o script **define a porta de administração para `50443` com HTTPS**.
* **Como garantimos que o acesso ao firewall NUNCA é perdido:**  
  1. Cria regras automáticas permanentes de `Pass` para a porta `50443` na interface **WAN** e na interface **LAN**.
  2. Garante a regra nativa **Anti-Lockout** sempre ativa no pfSense.
  3. Desativa o descarte de redes privadas (RFC 1918) na WAN para que conexões de gerência de outras filiais e laboratórios não sejam bloqueadas.
  4. Desativa a checagem de DNS Rebind (`nodnsrebindcheck`) e desativa o redirecionamento HTTP nativo (`disablehttpredirect`), liberando a porta 80 para o Banner.
* **Como acessar o pfSense a partir de agora:**  
  👉 **`https://<IP_DO_PFSENSE>:50443`**

---

## 5. Configuração Inicial no Painel Rules WAM

Após a instalação, acesse a WebGUI administrativa do pfSense (`https://<IP>:50443`):

1. Vá ao menu superior **Services** > **Rules WAM**.
2. **Habilitar Serviço:** Verifique se a caixa **"Habilitar Rules WAM"** está marcada como **Ativo**.
3. **Ação de Bloqueio:**
   * **Retornar 0.0.0.0 (Silencioso - Padrão / Recomendado):**  
     O Unbound responde com endereço nulo `0.0.0.0`. O navegador recusa a conexão instantaneamente. **Não requer instalação de certificados em nenhum computador, celular ou tablet da rede.**
   * **Exibir Banner:**  
     Exibe a tela institucional com aviso da empresa. *(Para navegação HTTPS sem alertas de segurança no navegador, requer a distribuição do certificado raiz corporativo via GPO).*
4. **Categorias de Bloqueio:**  
   Marque as categorias que deseja bloquear na empresa:
   - Conteúdo Adulto & Pornografia
   - Apostas, Bets & Cassinos
   - Jogos Online & Games
   - Mídias Sociais (Facebook, Instagram, TikTok, etc.)
   - Mensageiros (WhatsApp, Telegram, etc.)
   - VPNs, ZTNA e Proxies Anônimos
5. **Isenção de Dispositivos (Bypass IPs):**  
   Adicione os IPs de computadores que não devem sofrer bloqueio (Diretoria, TI, Servidores).
6. **Integração Corporativa (Se aplicável):**  
   Preencha o domínio do Active Directory (ex: `empresa.local`) e os IPs dos DNS/Controladores de Domínio para garantir encaminhamento contínuo e resolução de autenticação NPS RADIUS.
7. Clique no botão **Salvar e Aplicar** no rodapé da página.

### 5.1. Adicionar o Widget do Rules WAM na Página Inicial (Dashboard)

Para acompanhar o status em tempo real sem precisar navegar até os menus:
1. No menu superior do pfSense, clique em **Status** > **Dashboard** (ou clique no logotipo do pfSense).
2. Se o widget ainda não estiver visível na sua tela, clique no botão **`+`** (**Available Widgets**) localizado no canto superior direito do Dashboard.
3. Na lista suspensa, clique em **Rules WAM - Web Access Manager**.
4. O widget será adicionado instantaneamente, exibindo:
   * **Status do Serviço:** Estado geral (Ativo / Pausado / Desativado), DNS Unbound (Online / Parado), Banner NGINX (80/443) e total de domínios em quarentena.
   * **Categorias Filtradas:** Badges visuais com todas as categorias ativas em tempo real.
   * **Resumo Macro de Hosts por Rede:** Tabela consolidada com total de hosts online (ARP), dispositivos que tentaram acessar domínios bloqueados, volume acumulado de bloqueios e dispositivos em Bypass por interface/sub-rede.
   * **Atalhos Rápidos:** Botões diretos para Configurações, Status e Auditoria/Exportação CSV.
5. Clique no botão **Save Settings** no topo do Dashboard para fixar a sua visualização preferida.

## 6. Comandos Rápidos de Validação e Teste

No terminal ou no menu **Diagnostics > Command Prompt** do pfSense:

1. **Testar se o Unbound está interceptando domínios bloqueados:**
   ```bash
   drill @127.0.0.1 xvideos.com
   ```
   *Deve responder com `0.0.0.0` (ou o IP LAN do pfSense, dependendo do modo escolhido).*

2. **Testar se o domínio corporativo continua resolvendo normalmente:**
   ```bash
   drill @127.0.0.1 <dominio_corporativo.local>
   ```

3. **Verificar os logs de auditoria em tempo real:**
   ```bash
   tail -f /var/log/wam_audit.log
   ```

4. **Verificar processo NGINX na porta 443 (caso use modo Banner):**
   ```bash
   sockstat -4 -l -p 443
   ```

---

## 7. Desinstalação / Remoção Limpa

Se por qualquer motivo for necessário desinstalar o Rules WAM do firewall:

1. Baixe ou envie o script `uninstall.sh` para o pfSense (ou extraia do pacote).
2. Execute no terminal:
   ```bash
   sh /tmp/uninstall.sh
   ```
3. O script remove os arquivos do pacote, restaura a WebGUI para a porta padrão, remove as zonas do Unbound e limpa os menus administrativos sem deixar resíduos.
