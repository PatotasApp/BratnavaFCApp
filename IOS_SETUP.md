# 🍎 Configuração do iOS

Guia para gerar o app iOS. A primeira parte lista o que **já está no repositório**
(feito sem Mac, só editando arquivos); a segunda, o que **precisa do Xcode**.

Team da Apple: `2PY7CL62VG`. Bundle IDs: `br.com.patotasapp` (prod) e
`br.com.patotasapp.dev` (dev). Os dois App IDs já existem no Apple Developer com
**Sign in with Apple** e **Push Notifications** habilitados.

---

## ✅ Já está no repositório

| O quê | Onde | Por quê |
|---|---|---|
| `GoogleService-Info.plist` de dev e prod | `ios/Runner/Firebase/{dev,prod}/` | Configuração do Firebase de cada ambiente. |
| Build phase **Copy GoogleService-Info.plist** | `project.pbxproj`, logo após o "Run Script" do Flutter | Copia o plist certo para dentro do app. Configuration terminada em `-dev` usa dev; qualquer outra, prod. Sem ele, `Firebase.initializeApp()` não acha configuração e o app **fecha ao abrir**. O script também **falha o build** se o `BUNDLE_ID` do plist não bater com o bundle do build — evita autenticar no projeto errado. |
| URL Types do Google (`REVERSED_CLIENT_ID` de dev e prod) | `ios/Runner/Info.plist` | Retorno do login com Google. Sem eles o app fecha ao tocar em "Google". |
| `Runner.entitlements` (Sign in with Apple + `aps-environment`) | `ios/Runner/Runner.entitlements`, ligado em `CODE_SIGN_ENTITLEMENTS` | Login com Apple e push. Sem eles o login com Apple falha e o token de push nunca é emitido. |
| Team e assinatura automática | `DEVELOPMENT_TEAM` / `CODE_SIGN_STYLE` no target Runner | O Xcode assina sem precisar escolher o time na mão. |
| `ITSAppUsesNonExemptEncryption = false` | `Info.plist` | Dispensa o questionário de criptografia a cada build enviado ao App Store Connect. |
| Só iPhone (`TARGETED_DEVICE_FAMILY = 1`) | `project.pbxproj` | Sem iPad, a App Store não exige screenshots de iPad e a revisão não testa em iPad. |
| Textos de permissão de câmera, galeria e "salvar na galeria" | `Info.plist` | A Apple recusa texto que não descreve o uso real (perfil, logo da patota, comprovantes, enquetes). O de salvar evita que o app feche em "Salvar imagem" ao compartilhar a escalação. |
| Widget da home só no Android | `match_home_widget_service.dart` | O widget não existe no iOS; chamá-lo lá lançava erro no logout e na exclusão de conta. |

Com isso, **o ambiente de prod já funciona** com as configurations atuais
(`Debug`, `Release`, `Profile` — nenhuma termina em `-dev`, então todas usam prod).

---

## 🛠️ Precisa do Mac

### 1. Primeiro build (prod)

```bash
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```

No Xcode, target **Runner → Signing & Capabilities**: confirme que o Team é
`2PY7CL62VG` e que aparecem **Sign in with Apple**, **Push Notifications** e
**Background Modes** (com *Remote notifications* e *Background fetch*). Elas já
vêm do `Runner.entitlements` e do `Info.plist`; se alguma faltar, adicione pelo `+`.

Rodar num iPhone, apontando para prod:

```bash
flutter run --release --dart-define-from-file=config/prod.json
```

> Sem `--flavor` aqui: no iOS ainda não existem os schemes `dev`/`prod`
> (passo 2). O `--dart-define-from-file` continua obrigatório — sem ele o app
> lança `StateError: API_URL não definida`.

### 2. Ambiente dev (flavors)

Criar configurations e schemes por arquivo, sem Xcode, é arriscado demais; no
Xcode leva poucos minutos.

1. Projeto **Runner → Info → Configurations**: duplique cada uma (`+` → *Duplicate*)
   criando `Debug-dev`, `Release-dev`, `Profile-dev` e `Debug-prod`,
   `Release-prod`, `Profile-prod`. Mantenha as originais.
2. Target **Runner → Build Settings → Product Bundle Identifier**: nas três
   `-dev`, use `br.com.patotasapp.dev`. As demais continuam `br.com.patotasapp`.
3. Ainda em Build Settings, **APP_DISPLAY_NAME** (em *User-Defined*): defina
   `PatotasApp Dev` nas `-dev`. O `CFBundleDisplayName` do `Info.plist` lê esse
   valor, então os dois apps não ficam com o mesmo nome no iPhone.
4. **Product → Scheme → Manage Schemes**: duplique o `Runner` duas vezes,
   nomeando `dev` e `prod` e marcando **Shared**. Em cada scheme, aponte Run/Test/
   Analyze para `Debug-<flavor>`, Profile para `Profile-<flavor>` e Archive para
   `Release-<flavor>`. O `--flavor` do Flutter procura o scheme por esse nome.
5. No `ios/Podfile`, adicione as configurations novas ao mapa do topo e rode
   `pod install` de novo:

   ```ruby
   project 'Runner', {
     'Debug' => :debug,
     'Profile' => :release,
     'Release' => :release,
     'Debug-dev' => :debug,
     'Debug-prod' => :debug,
     'Profile-dev' => :release,
     'Profile-prod' => :release,
     'Release-dev' => :release,
     'Release-prod' => :release,
   }
   ```

Depois disso:

```bash
flutter run --flavor dev  --dart-define-from-file=config/dev.json
flutter run --flavor prod --dart-define-from-file=config/prod.json
```

O build phase de cópia do plist já reconhece o sufixo `-dev` — não precisa mexer nele.

### 3. Push notifications (APNs)

Feito no navegador, mas sem ele o push não chega no iPhone:

1. developer.apple.com → **Keys → +** → *Apple Push Notifications service (APNs)*.
   Baixe o `.p8` e anote o Key ID. (Key separada da do Sign in with Apple.)
2. Firebase Console, **nos dois projetos** → Configurações → **Cloud Messaging**
   → app iOS → *APNs Authentication Key*: envie o `.p8`, o Key ID e o Team ID.

### 4. Enviar para a App Store

```bash
flutter build ipa --flavor prod --dart-define-from-file=config/prod.json
```

(Antes do passo 2, sem `--flavor`.) Envie o `.ipa` pelo **Transporter** ou pelo
Organizer do Xcode. O `aps-environment` do entitlements é trocado para
`production` automaticamente no export para a loja.

### 5. Commitar

O que o Xcode e o CocoaPods alterarem: `project.pbxproj`, os schemes em
`Runner.xcodeproj/xcshareddata/xcschemes/`, `Podfile` e `Podfile.lock`.
