# Changelog

> **Versão em testes:** até agora o Rules WAM só foi executado em ambiente de laboratório.

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
