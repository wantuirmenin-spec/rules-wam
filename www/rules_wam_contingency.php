<?php
/*
 * rules_wam_contingency.php
 * Rules WAM - Web Access Manager para pfSense
 * Modo de Contingência: liga/desliga e lista de serviços liberados
 *
 * Ligado, tudo fica bloqueado no DNS para todas as redes (os perfis ficam suspensos e os IPs isentos
 * continuam livres), menos a lista de liberados. O agendamento não pausa o modo.
 */

require_once("guiconfig.inc");
require_once("/usr/local/pkg/rules_wam.inc");

$input_errors = array();
$save_msg = null;
$wam_cfg = rules_wam_get_config();
$presets = rules_wam_contingency_presets();

if ($_POST && isset($_POST['wam_action'])) {
    $action = (string)$_POST['wam_action'];

    $sel = array();
    foreach ((array)($_POST['presets'] ?? array()) as $pk) {
        if (isset($presets[$pk])) {
            $sel[] = $pk;
        }
    }
    $custom = rules_wam_list_to_store($_POST['contingency_allow'] ?? '');
    foreach (rules_wam_parse_list($custom) as $item) {
        if (!rules_wam_clean_domain($item)) {
            $input_errors[] = sprintf(gettext("Domínio inválido: '%s'. Use só o domínio (ex.: sistema.empresa.com.br)."), htmlspecialchars($item));
        }
    }

    if (empty($input_errors)) {
        $wam_cfg['contingency_presets'] = implode(' ', $sel);
        $wam_cfg['contingency_allow'] = $custom;
        $wam_cfg['contingency_include_whitelist'] = isset($_POST['include_whitelist']) ? 'yes' : 'no';

        $user = preg_replace('/[^A-Za-z0-9_.@-]/', '', (string)($_SESSION['Username'] ?? 'admin'));
        if ($action === 'on') {
            $wam_cfg['contingency_enable'] = 'yes';
            $wam_cfg['contingency_since'] = date('d/m/Y H:i');
            $wam_cfg['contingency_by'] = $user;
            $desc = "MODO DE CONTINGENCIA LIGADO por {$user}";
            $save_msg = gettext("Modo de Contingência LIGADO. Só os serviços liberados estão disponíveis em todas as redes.");
        } elseif ($action === 'off') {
            $wam_cfg['contingency_enable'] = 'no';
            $wam_cfg['contingency_since'] = '';
            $wam_cfg['contingency_by'] = '';
            $desc = "Modo de contingencia desligado por {$user}";
            $save_msg = gettext("Modo de Contingência DESLIGADO. A navegação voltou às regras normais de cada perfil.");
        } else {
            $desc = "Lista do modo de contingencia atualizada por {$user}";
            $save_msg = rules_wam_contingency_active($wam_cfg)
                ? gettext("Lista de serviços liberados salva e aplicada.")
                : gettext("Lista de serviços liberados salva. Ela vale quando o modo for ligado.");
        }

        config_set_path('installedpackages/rules_wam/config/0', $wam_cfg);
        write_config("Rules WAM: {$desc}");
        log_error("[Rules WAM] {$desc}");
        if (rules_wam_is_checked($wam_cfg['enable'] ?? null)) {
            rules_wam_resync();
        }
        $wam_cfg = rules_wam_get_config();
    }
}

$active = rules_wam_contingency_active($wam_cfg);
$service_on = rules_wam_is_checked($wam_cfg['enable'] ?? null);
$sel_presets = rules_wam_parse_list($wam_cfg['contingency_presets'] ?? '');
$allow_count = count(rules_wam_contingency_allowlist($wam_cfg));

$pgtitle = array(gettext("Services"), gettext("Rules WAM"), gettext("Modo de Contingência"));
include("head.inc");

$tab_array = array();
$tab_array[] = array(gettext("Configurações de Bloqueio"), false, "/rules_wam.php");
$tab_array[] = array(gettext("Status & Teste de Bloqueio"), false, "/rules_wam_status.php");
$tab_array[] = array(gettext("Dashboard & Tentativas de Acesso"), false, "/rules_wam_dashboard.php");
$tab_array[] = array(gettext("Modo de Contingência"), true, "/rules_wam_contingency.php");
$tab_array[] = array(gettext("Banner de Bloqueio (Prévia)"), false, "/rules_wam_block.php");
display_top_tabs($tab_array);
?>

<?php if (!empty($input_errors)) { print_input_errors($input_errors); } ?>
<?php if ($save_msg): ?>
    <div class="alert alert-success alert-dismissible" role="alert">
        <button type="button" class="close" data-dismiss="alert"><span aria-hidden="true">&times;</span></button>
        <i class="fa fa-check-circle"></i> <strong><?=htmlspecialchars($save_msg)?></strong>
    </div>
<?php endif; ?>

<?php if ($active): ?>
    <div class="alert alert-danger" style="font-size: 15px;">
        <h4 style="margin-top: 0;"><i class="fa fa-exclamation-triangle"></i> <strong><?=gettext("MODO DE CONTINGÊNCIA LIGADO")?></strong></h4>
        <?=gettext("Toda a navegação está bloqueada, exceto os serviços liberados abaixo")?>
        (<strong><?=number_format($allow_count, 0, ',', '.')?></strong> <?=gettext("domínios")?>).
        <?php if (!empty($wam_cfg['contingency_since'])): ?>
            <br/><?=gettext("Ligado em")?> <strong><?=htmlspecialchars($wam_cfg['contingency_since'])?></strong>
            <?php if (!empty($wam_cfg['contingency_by'])): ?><?=gettext("por")?> <strong><?=htmlspecialchars($wam_cfg['contingency_by'])?></strong><?php endif; ?>.
        <?php endif; ?>
        <?php if (!$service_on): ?>
            <br/><span class="text-warning"><strong><?=gettext("Atenção: o serviço Rules WAM está desabilitado, então o modo não tem efeito até o serviço ser habilitado.")?></strong></span>
        <?php endif; ?>
    </div>
<?php else: ?>
    <div class="alert alert-success">
        <i class="fa fa-check-circle"></i> <strong><?=gettext("Modo de Contingência desligado.")?></strong>
        <?=gettext("A navegação segue as regras normais de cada perfil de rede.")?>
    </div>
<?php endif; ?>

<form action="/rules_wam_contingency.php" method="post" class="form-horizontal" id="wam_cont_form">
    <input type="hidden" name="wam_action" id="wam_action" value="save" />

    <div class="panel panel-default">
        <div class="panel-heading">
            <h2 class="panel-title"><?=gettext("Como funciona")?></h2>
        </div>
        <div class="panel-body">
            <ul class="text-muted" style="margin-bottom: 0;">
                <li><?=gettext("Para usar quando a unidade estiver no link reserva (ex.: Starlink) ou numa operação crítica: só o essencial fica disponível.")?></li>
                <li><?=gettext("Vale para todas as redes. Os perfis por rede ficam suspensos enquanto o modo estiver ligado; os IPs isentos (bypass) continuam livres.")?></li>
                <li><?=gettext("O bloqueio é no DNS. Sites com http:// mostram o banner de contingência; sites com https:// mostram erro de conexão no navegador.")?></li>
                <li><?=gettext("O agendamento por horário não desliga o modo: ele só é desligado por aqui.")?></li>
                <li><?=gettext("Sempre liberados (não precisa marcar): domínio do Active Directory, proteções corporativas (Netskope, login Microsoft/Google, ferramentas de TI, helpdesk, telefonia), verificação de conectividade do Windows e celulares, validação de certificados e hora (NTP).")?></li>
            </ul>
        </div>
    </div>

    <div class="panel panel-default">
        <div class="panel-heading">
            <h2 class="panel-title"><?=gettext("Serviços liberados durante a contingência")?></h2>
        </div>
        <div class="panel-body">
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Conjuntos prontos")?></label>
                <div class="col-sm-9">
                    <?php foreach ($presets as $pk => $pinfo): ?>
                        <div class="checkbox">
                            <label>
                                <input type="checkbox" name="presets[]" value="<?=htmlspecialchars($pk)?>" <?=in_array($pk, $sel_presets, true) ? 'checked' : ''?> />
                                <strong><?=htmlspecialchars($pinfo['label'])?></strong>
                                <span class="text-muted small">(<?=htmlspecialchars(implode(', ', $pinfo['domains']))?>)</span>
                            </label>
                        </div>
                    <?php endforeach; ?>
                </div>
            </div>
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Outros sites e sistemas liberados")?></label>
                <div class="col-sm-6">
                    <textarea name="contingency_allow" rows="6" class="form-control" placeholder="Ex.: sistema.empresa.com.br&#10;banco.com.br"><?=htmlspecialchars(rules_wam_list_to_text($wam_cfg['contingency_allow'] ?? ''))?></textarea>
                    <span class="help-block"><?=gettext("Um domínio por linha. Liberar um domínio libera também os subdomínios (ex.: empresa.com.br libera sistema.empresa.com.br).")?></span>
                </div>
            </div>
            <div class="form-group">
                <label class="col-sm-3 control-label"><?=gettext("Whitelist geral")?></label>
                <div class="col-sm-9">
                    <div class="checkbox">
                        <label>
                            <input type="checkbox" name="include_whitelist" value="yes" <?=rules_wam_is_checked($wam_cfg['contingency_include_whitelist'] ?? null) ? 'checked' : ''?> />
                            <?=gettext("Liberar também os domínios da whitelist geral (painel Exceções & Personalização)")?>
                        </label>
                    </div>
                </div>
            </div>
            <div class="form-group">
                <div class="col-sm-9 col-sm-offset-3">
                    <p class="text-muted"><?=gettext("Total liberado com a seleção atual (inclui os sempre liberados)")?>: <strong><?=number_format($allow_count, 0, ',', '.')?></strong> <?=gettext("domínios")?>.</p>
                    <button type="submit" class="btn btn-primary" onclick="document.getElementById('wam_action').value='save';">
                        <i class="fa fa-save"></i> <?=$active ? gettext("Salvar lista e aplicar") : gettext("Salvar lista")?>
                    </button>
                    <?php if ($active): ?>
                        <button type="submit" class="btn btn-success btn-lg" style="margin-left: 10px;"
                            onclick="if (!confirm('Desligar o Modo de Contingência? A navegação volta às regras normais de cada perfil.')) return false; document.getElementById('wam_action').value='off';">
                            <i class="fa fa-power-off"></i> <?=gettext("DESLIGAR MODO DE CONTINGÊNCIA")?>
                        </button>
                    <?php else: ?>
                        <button type="submit" class="btn btn-danger btn-lg" style="margin-left: 10px;"
                            onclick="if (!confirm('Ligar o Modo de Contingência? Toda a navegação de todas as redes ficará bloqueada, exceto os serviços liberados.')) return false; document.getElementById('wam_action').value='on';">
                            <i class="fa fa-exclamation-triangle"></i> <?=gettext("LIGAR MODO DE CONTINGÊNCIA")?>
                        </button>
                    <?php endif; ?>
                </div>
            </div>
        </div>
    </div>
</form>

<?php include("foot.inc"); ?>
