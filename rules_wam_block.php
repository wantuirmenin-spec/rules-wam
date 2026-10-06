<?php
/*
 * rules_wam_block.php
 * Rules WAM - Web Access Manager para pfSense
 * Banner / Tela de Bloqueio Corporativa para Hosts Interceptados
 *
 * Dois modos:
 *  - Banner real: servido pelo NGINX dedicado do Rules WAM (fastcgi_param WAM_BANNER=1).
 *    Não exige login, usa apenas REMOTE_ADDR/HTTP_HOST definidos pelo NGINX e registra a auditoria.
 *  - Prévia: aberta pela WebGUI. Exige login e não grava nada no log.
 */

$is_banner = (getenv('WAM_BANNER') === '1') || (($_SERVER['WAM_BANNER'] ?? '') === '1');

if (!$is_banner) {
    // Prévia na WebGUI: exige autenticação do pfSense
    require_once("guiconfig.inc");
}
require_once("/usr/local/pkg/rules_wam.inc");

$wam_cfg = rules_wam_get_config();
$support_email = '';
if (!empty($wam_cfg['support_email']) && filter_var(trim($wam_cfg['support_email']), FILTER_VALIDATE_EMAIL)) {
    $support_email = trim($wam_cfg['support_email']);
}

if ($is_banner) {
    // Somente valores definidos pelo NGINX (cabeçalhos do cliente não são repassados)
    $client_ip = $_SERVER['REMOTE_ADDR'] ?? '';
    if (!filter_var($client_ip, FILTER_VALIDATE_IP)) {
        $client_ip = '0.0.0.0';
    }
    $cache_hn = array();
    $client_host = rules_wam_resolve_hostname($client_ip, $cache_hn);

    $req_host = rules_wam_clean_domain(preg_replace('/:\d+$/', '', $_SERVER['HTTP_HOST'] ?? ''));
    $is_fw_direct = empty($req_host) || filter_var($req_host, FILTER_VALIDATE_IP) || $req_host === 'localhost';
    if ($is_fw_direct) {
        $req_host = 'website-bloqueado.com';
    }
    $category = rules_wam_get_domain_category($req_host);

    // Só registra domínios que estão de fato na lista de bloqueio (evita poluir a auditoria com Hosts arbitrários)
    if (!$is_fw_direct && $category !== 'Regra Personalizada / Outros') {
        rules_wam_audit_write($client_ip, $req_host, $category, $client_host);
    }
    header('Cache-Control: no-store');
    header('X-Content-Type-Options: nosniff');
    header('X-Frame-Options: DENY');
} else {
    // Dados de exemplo para a prévia
    $client_ip = $_SERVER['REMOTE_ADDR'] ?? '192.0.2.10';
    $client_host = 'Estação de exemplo';
    $req_host = 'exemplo-bloqueado.com';
    $category = 'Apostas & Bets';
}

$block_time = date('d/m/Y - H:i:s');
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
        </div>
        <div>
            <button onclick="window.history.back();" class="btn btn-secondary">
                &larr; Voltar à página anterior
            </button>
            <?php if ($support_email !== ''): ?>
            <a href="mailto:<?=htmlspecialchars($support_email)?>?subject=Solicitacao%20de%20Liberacao%20de%20Acesso%20-%20<?=rawurlencode($req_host)?>&body=Ola%20Suporte%20TI,%0A%0ASolicito%20revisao%20do%20bloqueio%20do%20dominio:%20<?=rawurlencode($req_host)?>%0AHost:%20<?=rawurlencode($client_host)?>%20(IP:%20<?=rawurlencode($client_ip)?>)%0ACategoria:%20<?=rawurlencode($category)?>%0A%0AJustificativa:%20" class="btn btn-primary">
                ✉️ Contatar Suporte TI
            </a>
            <?php endif; ?>
        </div>
    </div>
</div>

</body>
</html>
