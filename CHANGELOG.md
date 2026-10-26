# Changelog

> **Versão em testes:** até agora o Rules WAM só foi executado em ambiente de laboratório.

## 1.6.0 — Modo de Contingência

### Novidades
- **Modo de Contingência.** Nova aba *Modo de Contingência*, com botão para ligar e desligar (manual). Para quando a unidade estiver no link reserva (ex.: Starlink) ou numa operação crítica.
  - Ligado, **tudo fica bloqueado no DNS**, menos a lista de serviços liberados. Vale para **todas as redes**: os perfis por rede ficam suspensos e os IPs isentos (bypass) continuam livres.
  - Conjuntos prontos para liberar: Microsoft 365, Google Workspace, TOTVS, Governo (gov.br), WhatsApp e antivírus Bitdefender, além de um campo para domínios próprios e a opção de incluir a whitelist geral.
  - **Sempre liberados:** domínio do Active Directory, proteções corporativas (Netskope, login Microsoft/Google, ferramentas de TI, helpdesk, telefonia), verificação de conectividade do Windows e dos celulares, validação de certificados (OCSP/CRL) e hora (NTP). Sem eles o Windows considera a rede "sem internet" e aplicativos como Teams e Outlook param.
  - O agendamento por horário não pausa o modo.
  - Sites `http://` mostram o banner "Modo de Contingência", com a lista do que está disponível; sites `https://` mostram erro de conexão.
  - Avisos do modo ligado nas abas Configuração, Status e Dashboard e no widget; tentativas registradas no Dashboard com a categoria "Modo de Contingência".
  - Implementado com uma zona raiz (`local-zone: "."`) que bloqueia tudo e zonas `transparent` para cada domínio liberado.
  - A aba fica no privilégio de configuração (`page-services-ruleswam`).
- **Apostas: domínios inteiros.** O feed passa a bloquear tudo o que termina em `.bet`, `.casino`, `.poker`, `.bingo` e `.bet.br` (domínio exigido das casas licenciadas no Brasil), pegando casas que não estão na lista.
- **Apostas: bloqueio automático por marca.** As casas criam domínios-espelho o tempo todo (ex.: `betano.fyi`). O cron lê as consultas novas do `resolver.log` a cada 5 minutos e bloqueia sozinho os domínios com nome de marca de apostas (lista editável, 5+ caracteres por marca), gravando em `gambling-auto.txt`. Ligado por padrão; a tela mostra a lista automática e permite limpá-la; a whitelist geral libera falsos positivos.

- **Aviso de bloqueio em HTTPS, sem instalar nada nas máquinas (opcional, desligado por padrão).** Nova opção *Aviso de Bloqueio em HTTPS* no painel do banner. Ligada, a porta 443 do banner passa a responder com um certificado autoassinado gerado no firewall, cujo nome é a mensagem (padrão `acesso-bloqueado-pela-ti`, editável).
  - O navegador mostra o aviso vermelho *"Sua conexão não é particular"* em vez do erro de conexão; o texto aparece nos detalhes do certificado (no Firefox, direto no aviso).
  - Em sites sem HSTS o usuário pode clicar em *Avançado > Continuar* e vê o banner da empresa (o acesso entra no Dashboard). Em sites com HSTS o navegador não deixa continuar.
  - Certificado em `/usr/local/etc/nginx/rules_wam_notice.crt` (EC P-256, 10 anos), refeito quando o texto muda. Se a geração falhar, a 443 volta a recusar a conexão.

### Correções
- **Zonas duplicadas com o pfSense 2.8.** O pfSense já declara zonas como `mask.icloud.com`, `mask-h2.icloud.com` e `doh.dns.apple.com`, que também estão no feed *Anti-Bypass DoH*. Declarar a mesma zona de novo gerava "duplicate local-zone", e o `unbound-checkconf` recusava a configuração (os perfis por rede caíam). Agora a política geral e o Modo de Contingência pulam as zonas que o pfSense já declara.

### Limitações
- Host overrides do DNS Resolver em domínios diferentes do domínio do próprio pfSense deixam de resolver enquanto o modo estiver ligado (inclua o domínio deles na lista de liberados).
- Bloqueio só por DNS: aplicativos que conectam direto por IP podem escapar.

## 1.5.0 — políticas por rede (perfil obrigatório) e sites liberados por categoria

### Novidades
- **Políticas por Rede.** Novo painel na tela de configuração com perfis por rede (ex.: GUEST, CORP, ADMIN).
  - Cada perfil escolhe as interfaces/VLANs (a sub-rede é obtida automaticamente) e, se preciso, redes CIDR extras.
  - Cada perfil marca as próprias categorias bloqueadas e tem listas próprias de sites liberados e bloqueados.
  - Exemplo: o perfil GUEST sem Mídias Sociais libera Facebook e YouTube para os visitantes, e o perfil CORP bloqueia.
  - Implementado com *views* do Unbound (`wam_p_<nome>`), o mesmo mecanismo do bypass por IP. Um IP isento dentro da rede de um perfil continua isento, porque o Unbound usa a rede mais específica.
- **Perfil obrigatório.** As categorias saíram da política geral e existem só nos perfis.
  - Toda interface interna com IP precisa estar marcada num perfil ativo; sem isso a tela não salva e mostra quais faltam.
  - Rede que não cair em nenhum perfil (VLAN criada depois, sub-rede roteada ou VPN não informada) recebe o **bloqueio máximo**: todas as categorias, exceto Mensageiros e VPN. As abas Status e Dashboard listam essas redes.
  - **Migração automática:** na atualização, as categorias marcadas na política geral viram o perfil **PADRAO**, com as interfaces que ainda não tinham perfil e as *Redes Corporativas Autorizadas* (sub-redes roteadas/VPN). Nenhuma rede muda de bloqueio no dia da atualização.
  - O painel de cima virou o **Catálogo de Categorias**: *Gerenciar sites*, fornecedores de VPN e Mensageiros e as opções de firewall.
- **Firewall por perfil.** As regras de DoT 853 e do WhatsApp (portas e faixas Meta) passam a valer só nas interfaces cujo perfil bloqueia *Anti-Bypass DoH* e *Mensageiros*.
- **Sites por categoria.** Cada categoria ganhou o link *Gerenciar sites*, com a lista dos domínios em caixas de seleção, busca e marcar/desmarcar exibidos.
  - O site desmarcado fica liberado em todos os perfis que bloqueiam a categoria.
  - A lista é montada no navegador e só os desmarcados são enviados, o que evita o limite de campos do PHP nas categorias grandes (Adulto, Apostas).
  - A exceção vale só dentro da categoria: se o mesmo site estiver em outra categoria ativa (ex.: YouTube em Mídias Sociais e Streaming), ele continua bloqueado por ela.
- **Status:** a aba Status mostra os perfis ativos, com redes, total de domínios e categorias.
- **Página de boas-vindas da GUEST.** Nova pasta `captive-portal/` com a página do Portal Cativo do pfSense (regras da rede e botão "Aceitar e navegar") e o passo a passo. Avisa os visitantes das regras sem certificado e sem instalar nada nos aparelhos.

### Correções
- **Máscara das interfaces.** Quando o pfSense informava o IP pela `get_interface_ip`, a máscara não era consultada e ficava em `/24` (ex.: GUEST `192.168.60.0/26` aparecia como `/24`).
- **View mais ampla que a interface não era aplicada.** O Unbound guarda `access-control` e `access-control-view` na mesma árvore e usa a entrada mais específica. O pfSense cria `access-control` para a sub-rede real de cada interface, e uma view numa rede mais ampla era ignorada. Agora a sub-rede de toda interface contida numa rede de perfil (ou numa faixa isenta) também recebe a view.
- **Perfis gravados em `net_profiles/item`.** Uma versão de teste da 1.5.0 gravava os perfis numa tag que o pfSense convertia em `<0>`, `<1>`… (XML inválido): o pfSense descartava o `config.xml` e restaurava o backup.

### Mudanças de comportamento
- **Liberar um subdomínio de um domínio bloqueado agora funciona.** Antes, liberar `m.youtube.com` com `youtube.com` bloqueado não tinha efeito.
  - Isso vale para a whitelist, as proteções corporativas, os sites liberados dos perfis e as exceções de categoria.
  - É feito com uma zona `transparent` mais específica.
  - Efeito colateral esperado: endpoints protegidos (ex.: `login.live.com`) passam a ser liberados mesmo quando o domínio pai está numa categoria ativa.
- O teste de domínio da aba Status ganhou o campo opcional *IP do cliente*: sem ele testa a política padrão; com ele, a política da rede desse IP (perfil, IP isento ou padrão).
- O Dashboard identifica a política de cada cliente ao ler o `resolver.log`: tentativas bloqueadas só num perfil por rede também aparecem.

### Limitações
- O redirecionamento da porta 53 (Anti-Bypass DNS) continua valendo para todas as redes.
- Os fornecedores de VPN e de Mensageiros seguem as subopções do catálogo em todos os perfis.
- Se o `unbound-checkconf` recusar os perfis, o pacote aplica o bloqueio máximo (com bypass) em todas as redes e mostra o aviso na aba Status.
- Uma VLAN nova dentro das *Redes Corporativas Autorizadas* herda o perfil que contém essas redes (ex.: PADRAO) até ser marcada num perfil; a tela não salva enquanto ela não for marcada.

## 1.4.3
- Projeto preparado para divulgação: licença MIT, aviso de versão em testes e remoção das referências específicas da empresa (domínios na migração da 1.3 e IPs internos nos exemplos).

## 1.4.2
- Corrigido: o config.xml do pfSense descarta as quebras de linha dos campos de lista, e as entradas ficavam grudadas (ex.: `10.0.0.0/8172.16.0.0/12`). Agora redes, IPs, whitelist, blacklist e domínios são gravados numa linha só, separados por espaço. O mapeamento de hosts usa ` | ` entre as entradas. Na tela continuam aparecendo um por linha.
- Valores que já foram gravados grudados não podem ser recuperados automaticamente: revise e digite de novo os campos de lista depois de atualizar.

## 1.4.1
- Corrigido: a regra do banner era criada como IPv4+IPv6 com destino IPv4, e o pfSense recusava carregar o conjunto de regras ("rule expands to no valid combination"). Agora é só IPv4.

## 1.4.0 — revisão de segurança e correções

### Segurança
- **WAN fechada.** O pacote não cria mais regras na WAN. A WebGUI só é liberada pela WAN se o administrador informar as origens em *Origens Autorizadas pela WAN* (alias `WAM_GUI_WAN_Sources`).
- **Configurações da WAN preservadas.** O pacote não desliga mais `blockbogons`, `blockprivatenets` nem a proteção contra DNS rebind.
- **Fim da regra `pass quick` de 80/443 para qualquer destino.** Ela passava por cima das restrições já existentes entre VLANs. Agora a regra libera só o IP do banner nas portas 80/443.
- **WebGUI limitada ao próprio firewall.** As regras de acesso à WebGUI nas redes internas têm destino `(self)`. A origem pode ser restringida no campo *Origens Internas Autorizadas* (alias `WAM_GUI_Admins`).
- **NGINX do banner restrito:**
  - escuta só no IP do banner, não em todas as interfaces;
  - roda como o NGINX da própria WebGUI (`user root wheel`), sem `chmod 666` no socket do PHP-FPM;
  - limita as requisições por cliente;
  - não repassa cabeçalhos do cliente.
- **Página de bloqueio sem confiar no cliente.** Usa apenas `REMOTE_ADDR` e o `Host` validado pelo NGINX; `X-Real-IP`, `X-Forwarded-*` e `?domain=` são ignorados.
- **Log de auditoria protegido:**
  - campos sanitizados;
  - linhas malformadas descartadas;
  - rotação a partir de 10 MB.
- **Prévia do banner exige login.** Aberta pela WebGUI, a prévia passa por autenticação e não grava log.
- **Exportação CSV protegida** contra injeção de fórmula.
- **Sem alterações nos arquivos do núcleo do pfSense.** `index.php`, `404.php` e `404.html` não são mais alterados, e as alterações da 1.3 são removidas na atualização.
- **`/var/crash` não é mais apagado** durante a instalação.
- **CA do banner HTTPS removida.** A porta 443 do banner recusa o handshake TLS (falha imediata em vez de aviso de certificado). A CA e o certificado da 1.3 são removidos do Gerenciador de Certificados.
- **Privilégios próprios.** Novo arquivo de privilégios (`/etc/inc/priv/rules_wam.priv.inc`) permite delegar o acesso às telas.

### Correções
- **Bypass por IP agora funciona.** É feito por uma *view* do Unbound. Os IPs isentos continuam resolvendo os host overrides e os registros DHCP.
- **O agendamento volta a bloquear sozinho.** Antes, depois da primeira pausa (almoço ou fim do expediente), o bloqueio só voltava ao clicar em Save.
- **Agendamento também nas regras de firewall.** Fora do horário, as regras de WhatsApp, DoT e NAT da porta 53 também são suspensas.
- **Horários normalizados e validados.** `8:00` vira `08:00`, e janelas que passam da meia-noite são suportadas.
- **Formulário com validação.** IPs, CIDRs, e-mail, horários e IP do banner são validados.
- **Whitelist de IdP restrita.** Deixou de liberar `microsoft.com`, `office.com` e `windows.net` inteiros, o que anulava o bloqueio de Teams/Skype.
- **Bloqueio do WhatsApp sem efeitos colaterais:**
  - a porta 5223 (push da Apple) saiu do bloqueio;
  - o bloqueio por faixa IP da Meta virou opcional e vem desligado;
  - o `pfctl -k` não derruba mais toda a `157.240.0.0/16`.
- **DoT (853) bloqueado só com a categoria Anti-Bypass DoH marcada.**
- **Redes autorizadas padrão** passaram a ser RFC1918 (`10/8`, `172.16/12`, `192.168/16`). A faixa pública `192.192.0.0/16` e uma faixa interna específica da empresa saíram do padrão.
- **Sem reescrita do config.xml a cada Save.** O pacote não reescreve mais o config.xml nem recarrega o filtro quando não há mudança.
- **Unbound resiliente:**
  - `include` com curinga, para o Unbound subir mesmo sem o arquivo (`/var` em RAM disk);
  - as regras são regeneradas no boot;
  - validação com `unbound-checkconf` e fallback.
- **Página de bloqueio mais leve.** Usa um índice de categorias pré-calculado, em vez de ler todos os feeds a cada acesso.
- **Dashboard e widget mais leves.** Leem só o final do log, e a exportação "sem limite" passou a ter teto de 20.000 eventos.
- **Testes do administrador fora da auditoria.** Testes na aba Status não entram mais no log de auditoria; a simulação do Dashboard valida o IP e marca o registro como simulação.
- **Bug corrigido em `rules_wam_get_audit_events`** (variáveis indefinidas).
- **Multi-WAN:** interfaces com gateway ou endereço de provedor (DHCP/PPPoE) não são mais tratadas como internas (antes uma WAN secundária recebia a regra de WebGUI).
- **Regras de WebGUI no final da lista:** ficam depois das regras do administrador, então um bloqueio já existente (ex.: visitantes → firewall) continua valendo.
- **Banner registra só domínios bloqueados:** acessos ao IP do banner com Host arbitrário não entram na auditoria.
- **Opção "Forwarding Upstream" removida:** nunca configurou encaminhamento de fato.
- **Tela de configuração pelo XML desativada:** `pkg_edit.php?xml=rules_wam.xml` podia sobrescrever a configuração sem validação.
- **Limpar/simular no Dashboard exige o privilégio de configuração.**

### Instalação / desinstalação
- **Um único fluxo de instalação.** `install.sh` é a única lógica de instalação; o `wam-install.sh` é só um auto-extraível que executa o mesmo `install.sh`.
- **Socket do PHP-FPM:** se ainda estiver gravável por outros usuários (herança da 1.3), o instalador corrige.
- **A WebGUI só é movida com autorização.** Com `--move-gui` ou confirmação interativa. Sem isso, se a WebGUI estiver em 80/443, o bloqueio funciona em modo silencioso (0.0.0.0).
- **Atualização a partir da 1.3:**
  - exige `--wan-gui-sources=` (IPs ou `none`) antes de remover a regra antiga da WAN, e aborta sem alterar nada se não for informado;
- **Desinstalação reverte a configuração antes de apagar os arquivos:**
  - remove o include do Unbound, os domain overrides, as regras, o NAT e os aliases;
  - restaura a porta e o redirecionamento da WebGUI quando foi o pacote que os alterou;
  - restaura o `log_queries`;
  - remove menus, cron e widget.
- **Arquivos removidos:**
  - cópias duplicadas: `wam.inc`, `wam.xml`, `wam_status.php`;
  - código sem uso: `wam_sync.php`, `rules_wam_hook.inc`;
  - scripts de correção da 1.3: `wam-fix-50443-banner.sh`, `build_fix_script.py`.

### Pendências conhecidas
- **Não testado em um pfSense real.** O código foi testado com Unbound 1.19, NGINX 1.24 e PHP 8.3 em Linux, usando stubs das funções do pfSense. Valide primeiro em uma unidade de laboratório.
- **Feeds estáticos.** Continuam sendo listas próprias, sem atualização automática.
- **pfSense 2.8 com Kea DHCP:** os IPs em bypass podem não resolver nomes de hosts registrados dinamicamente pelo DHCP (host overrides continuam funcionando).
- **Ajustes da 1.3 que continuam no config.xml.** Na atualização, porta 50443, DNS rebind desativado e bogons/redes privadas liberados na WAN continuam como a 1.3 deixou. Revise manualmente em *System > Advanced > Admin Access* e em *Interfaces > WAN*.
