# Página de boas-vindas da rede GUEST (Portal Cativo do pfSense)

Ao conectar no Wi-Fi da GUEST, o celular ou notebook do visitante abre sozinho uma página com as regras da rede, como no Wi-Fi de hotel ou aeroporto. Depois de clicar em **Aceitar e navegar**, a navegação é liberada (com os bloqueios do perfil GUEST do Rules WAM).

- **Não precisa de certificado** nem de instalar nada nos aparelhos. A página é aberta por HTTP; Android, iPhone e Windows detectam o portal sozinhos.
- É um recurso **nativo do pfSense** (Services > Captive Portal). O Rules WAM não precisa ser alterado.
- Arquivo da página: `portal-guest.html` (nesta pasta). Os textos e a lista de categorias podem ser editados; **não altere o formulário** (`action`, `redirurl`, `zone` e o botão `accept`).

## Passo a passo (pfSense 2.7 / 2.8)

1. Acesse **Services > Captive Portal** e clique em **Add**.
2. **Zone name:** `guest` (só letras minúsculas, números e `_`). **Zone description:** `Rede de visitantes`. Clique em **Save & Continue**.
3. Na configuração da zona:

| Campo | Valor |
|---|---|
| **Enable** | marcado |
| **Interfaces** | `GUEST` (só a rede de visitantes) |
| **Idle timeout** | vazio |
| **Hard timeout** | `1440` (minutos: o visitante vê a página de novo a cada 24 h) |
| **Pre-authentication redirect URL** | vazio |
| **After authentication Redirection URL** | `https://www.suaempresa.com.br/` (o site da empresa; precisa estar liberado no perfil GUEST). Sem isso, o Windows abre a tela padrão "The portal session is connected / Disconnect", que confunde o visitante. |
| **Logout popup window** | **desmarcado** |
| **Use custom captive portal page** | **marcado** (sem isso o pfSense usa a página padrão dele e o campo de envio não aparece) |
| **Portal page contents** | aparece depois de marcar a opção acima: clique em **Escolher arquivo** e envie o `portal-guest.html` |
| **Authentication Method** | **None, don't authenticate users** |
| **Enable HTTPS login** | **desmarcado** (é o que dispensa certificado) |

4. Clique em **Save**.
5. (Opcional) Em **Allowed IP Addresses** da zona, cadastre os aparelhos da GUEST que não têm navegador e precisam de internet sem aceitar a página (ex.: impressora, TV). Em **MACs** dá para fazer o mesmo pelo endereço MAC.

## Teste

1. Conecte um celular no Wi-Fi da GUEST (esqueça a rede antes, se ele já estava conectado).
2. Deve aparecer **"Fazer login na rede"** (Android), a janela do portal (iPhone) ou o navegador abrindo sozinho (Windows).
3. Marque **Li e aceito** e toque em **Aceitar e navegar**.
4. Confira em **Status > Captive Portal** que o aparelho aparece como conectado.
5. Tente abrir um site bloqueado: o Rules WAM continua bloqueando normalmente.

## Observações

- **Aparelhos já conectados** são desconectados da internet ao ativar o portal e precisam aceitar a página uma vez.
- Se o aparelho não abrir a página sozinho, abra no navegador qualquer endereço `http://` (ex.: `http://neverssl.com`): o portal é exibido.
- A tela "The portal session is connected" com o botão **Disconnect** só aparece para quem **já aceitou** o portal (o portal está funcionando). Para ver a página de boas-vindas de novo, clique em **Disconnect** (ou remova o aparelho em **Status > Captive Portal**) e abra `http://neverssl.com`.
- Se aparecer a página padrão do pfSense (fundo azul, campos de login) em vez da página de boas-vindas, confira se **Use custom captive portal page** está marcado e se o `portal-guest.html` foi enviado.
- O Captive Portal não interfere no Rules WAM: o DNS continua no pfSense, e os bloqueios por perfil, o Dashboard e o banner em HTTP seguem funcionando.
- **Para desligar:** em **Services > Captive Portal**, desmarque **Enable** na zona `guest` e salve.
- **Para alterar os textos:** edite o `portal-guest.html`, envie de novo em **Portal page contents** e salve.
