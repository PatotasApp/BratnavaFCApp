# 🚀 Plano de publicação — App Store e Google Play

Plano para levar o PatotasApp (`br.com.patotasapp`) às duas lojas, cobrindo app
Flutter e API (`BratnavaFCApi`, Fly.io `production-env`). Complementa o
[ANDROID_SIGNING.md](ANDROID_SIGNING.md) e o [IOS_SETUP.md](IOS_SETUP.md), que
já resolvem assinatura e configuração nativa.

---

## 0. Ponto de partida (out/2026)

| Já pronto | Onde |
|---|---|
| Flavors `dev`/`prod` no Android, bundle IDs separados | `android/app/build.gradle.kts` |
| Assinatura de release via `key.properties` + Play App Signing documentado | `ANDROID_SIGNING.md` |
| iOS configurado sem Mac: Firebase por ambiente, entitlements, permissões, só iPhone, `ITSAppUsesNonExemptEncryption` | `IOS_SETUP.md` |
| Login e-mail/senha, Google e Apple (Apple obrigatório na App Store quando há login social ✔) | `core/auth/firebase_auth_service.dart` |
| Exclusão de conta dentro do app, com revogação do token Apple | `my_account_page.dart`, `UserService.DeleteMyAccountAsync` |
| Política de privacidade publicada e linkada no app | `https://patotasapp.com.br/privacidade.html` |
| Push FCM (Android ok; iOS depende da chave APNs) | `core/push/` |

| Falta | Fase |
|---|---|
| Contas de desenvolvedor / fichas nas lojas | 1 |
| Upload key gerada e SHAs no Firebase prod | 1 |
| Mac / CI macOS para buildar iOS | 2 |
| Chave APNs nos projetos Firebase | 2 |
| Denúncia/bloqueio de conteúdo de usuário (risco de rejeição Apple 1.2) | 3 |
| URL web de exclusão de conta (exigência Play) | 3 |
| Versão mínima / atualização forçada (API + app) | 3 |
| Conta demo para revisores com dados reais | 4 |
| Assets de loja (screenshots, textos, ícone 1024/512, feature graphic) | 4 |
| Badges/links das lojas no site e no app | 6 |

---

## Fase 1 — Contas e pré-requisitos (≈ 1 semana, maior parte espera)

1. **Google Play Console** (US$ 25, único).
   - Decidir **pessoa física x organização**. Conta pessoal nova exige *teste
     fechado com 12 testadores por 14 dias seguidos* antes de liberar produção —
     planejar isso desde já. Conta de organização exige D-U-N-S, mas pula a regra.
   - Verificação de identidade do desenvolvedor pode levar dias.
2. **Apple Developer Program** — Team `2PY7CL62VG` já existe. Confirmar que está
   ativo (US$ 99/ano) e, se for organização, que o nome legal é o desejado (vira o
   "vendedor" na loja).
3. **Criar os apps**:
   - Play Console → *Criar app* → `PatotasApp`, gratuito, pacote `br.com.patotasapp`.
   - App Store Connect → *Novo app* → bundle `br.com.patotasapp`, SKU `patotasapp`,
     idioma principal Português (Brasil).
4. **Upload key Android** — executar Parte A do `ANDROID_SIGNING.md` (gerar `.p12`,
   cofre, SHAs no Firebase `production-2153f`, novo `google-services.json` com
   `client_type: 1`).
5. **Revisar targetSdk** — conferir que `flutter.targetSdkVersion` da versão do
   Flutter em uso atende ao mínimo atual da Play (o mínimo sobe todo agosto). Se
   não, atualizar o Flutter ou fixar `targetSdk` no Gradle e testar permissões.

**Pronto quando:** os dois apps existem nos consoles e `./gradlew signingReport`
mostra `prodRelease → Config: release`.

---

## Fase 2 — Pipeline de build (≈ 3–5 dias)

Sem Mac na equipe, o iOS precisa de CI. Recomendação: **GitHub Actions com
runner macOS + fastlane** (o repo já usa Actions na API) — alternativa mais rápida
de configurar: **Codemagic** (tem plano gratuito com minutos macOS).

1. **Versionamento**: `version: X.Y.Z+N` no `pubspec.yaml` é a fonte única.
   `N` (build number) precisa subir a cada envio — gerar no CI a partir de
   `github.run_number` via `--build-number`.
2. **Workflow Android** (`.github/workflows/android-release.yml`):
   - Secrets: keystore em base64, senha, alias.
   - `flutter build appbundle --release --flavor prod --dart-define-from-file=config/prod.json --build-number=$RUN`
   - Upload para a trilha *internal* da Play via `fastlane supply` (ou
     `r0adkll/upload-google-play`) com uma *service account* do Play Console.
3. **Workflow iOS** (`.github/workflows/ios-release.yml`):
   - Secrets: chave da **App Store Connect API** (`.p8`, Key ID, Issuer ID).
   - `fastlane match` (certificados num repo privado) **ou** assinatura automática
     via API key.
   - `flutter build ipa --release --dart-define-from-file=config/prod.json` →
     `fastlane pilot` envia ao TestFlight.
   - Antes disso, alguém com Mac (ou o próprio CI) precisa fazer o 1º `pod install`
     e commitar `Podfile.lock` — passo 1 do `IOS_SETUP.md`.
4. **Flavors iOS** (passo 2 do `IOS_SETUP.md`) — opcional para a 1ª publicação:
   as configurations atuais já são prod. Fazer quando houver acesso a Xcode.
5. **APNs** (passo 3 do `IOS_SETUP.md`): gerar `.p8` e subir nos dois projetos
   Firebase. Sem isso o push não chega no iPhone e o revisor pode notar.
6. **Crashlytics** (recomendado): adicionar `firebase_crashlytics` antes do
   lançamento para enxergar crashes dos primeiros usuários e dos revisores.

**Pronto quando:** um push na branch `release/*` gera AAB na trilha interna da
Play e build no TestFlight sem passo manual.

---

## Fase 3 — Adequações de app e backend para revisão (≈ 1–2 semanas)

### 3.1 Conteúdo gerado por usuário — Apple 1.2 (app + API)
Fotos de perfil, logos de patota, imagens de enquete, replays e nomes são UGC.
A Apple exige: filtro de conteúdo impróprio, **denunciar** conteúdo, **bloquear**
usuário e contato publicado. Hoje não há denúncia/bloqueio.
- API: `ReportEntity` (alvo: usuário/imagem/replay/enquete, motivo, autor),
  `POST /api/reports`; `UserBlockEntity` + `POST/DELETE /api/users/{id}/block`;
  filtrar bloqueados em listagens/feeds. Notificação para o admin (e-mail ou
  painel) e compromisso de agir em até 24h.
- App: ação "Denunciar" nos menus de foto/replay/enquete/perfil público e
  "Bloquear jogador" no perfil público.
- Termos de uso com política de tolerância zero (página no site + aceite no cadastro).

### 3.2 Apostas com "Bratnava Coins"
É **aposta simulada** (moeda virtual, sem dinheiro real). Permitido, mas:
- Declarar *simulated gambling* na classificação etária (Apple e IARC) — deve
  resultar em 16+/18+ na Apple e classificação maior na Play.
- Garantir no app e na API que coins **não podem ser compradas nem resgatadas**
  por dinheiro. Se um dia forem vendidas, vira compra in-app obrigatória (IAP).
- Alternativa: esconder o módulo por *feature flag* na 1ª versão para
  simplificar a revisão e ligar depois.

### 3.3 Pagamentos (CHAPPO-070, pausada)
Mensalidade/rateio de jogo de futebol é **serviço físico** → pode usar Mercado
Pago fora do IAP. Mas qualquer recurso digital pago (premium, coins) teria de
usar IAP/Play Billing. Manter fora da 1ª versão.

### 3.4 Exclusão de conta pela web — exigência Play
O Data Safety exige uma **URL** onde o usuário peça a exclusão sem o app.
- Site: página `patotasapp.com.br/excluir-conta.html` explicando o caminho no app
  e oferecendo formulário/e-mail de solicitação.
- API (opcional): endpoint autenticado por e-mail com link de confirmação,
  reaproveitando `DeleteMyAccountAsync`.

### 3.5 Atualização forçada (API + app)
Usuários de loja demoram a atualizar; a API passa a precisar de compatibilidade
com versões antigas.
- API: `GET /api/app/version` → `{ minSupported: {android, ios}, latest: {...},
  storeUrls }`, valores por variável de ambiente no Fly.
- App: `package_info_plus`; ao abrir, se `build < minSupported` mostra tela
  bloqueante com botão para a loja; se `< latest`, aviso dispensável.
- Regra de equipe: mudanças de contrato na API sempre aditivas; remoções só
  depois de subir `minSupported`.

### 3.6 Backend em produção
- Reativar `AddApplicationHealthChecks`/`MapHealthProbes` no `Program.cs` (estão
  comentados) e configurar o health check do Fly.
- Conferir `FIREBASE_SERVICE_ACCOUNT_JSON` do projeto **prod** no Fly.
- Rate limiting nos endpoints de login/cadastro/denúncia (`AddRateLimiter`).
- Backup do Postgres de produção verificado antes de abrir para o público.

### 3.7 iOS — privacy manifest
Adicionar `ios/Runner/PrivacyInfo.xcprivacy` declarando os dados coletados e os
*required reason APIs* (ex.: `UserDefaults` via `shared_preferences`). Os plugins
trazem os seus, mas o do app evita aviso no envio.

**Pronto quando:** checklist de revisão Apple/Google (Fase 5) passa sem
pendências conhecidas e a API responde `/api/app/version` em prod.

---

## Fase 4 — Fichas das lojas (≈ 3–4 dias, paralelo à Fase 3)

| Item | Google Play | App Store |
|---|---|---|
| Nome / subtítulo | "PatotasApp" (30) / descrição curta (80) | Nome (30) / subtítulo (30) |
| Descrição | até 4000 | até 4000 + palavras-chave (100) |
| Ícone | 512×512 PNG | 1024×1024 sem transparência (já no asset catalog) |
| Screenshots | 2–8 de telefone; feature graphic 1024×500 | iPhone 6.9" (1320×2868) obrigatório |
| Classificação | Questionário IARC | Questionário de idade (2025) |
| Privacidade | Formulário *Data safety* | *App Privacy* (rótulos) |
| Contato | e-mail, site, política | URL de suporte, marketing, política |
| Categoria | Esportes | Esportes |

Dados a declarar (ambas): e-mail, nome, foto, ID de usuário, token de push,
conteúdo do usuário (fotos/vídeos/enquetes), dados de uso no app. Sem rastreio
para publicidade → sem ATT.

**Conta demo para revisores:** criar em **prod** um usuário e-mail/senha com uma
patota cheia (jogadores, partidas finalizadas, estatísticas, uma partida
agendada). Informar login/senha nas notas de revisão das duas lojas e não
apagá-la. Sem isso a revisão costuma ser recusada por "não foi possível testar".

---

## Fase 5 — Testes e revisão (≈ 2–3 semanas)

1. **Trilha interna / TestFlight interno**: equipe valida login (os 3 métodos),
   push, exclusão de conta, upload de imagens, compartilhamento.
2. **Pegar o SHA da app signing key** na Play e registrar no Firebase prod
   (Parte C do `ANDROID_SIGNING.md`) — sem isso o login Google falha para quem
   instala da loja.
3. **Teste fechado Play** com ≥ 12 testadores por 14 dias (se conta pessoal) e
   **TestFlight externo** (exige revisão beta curta).
4. Checklist pré-envio:
   - [ ] Login Apple e Google funcionando em build de loja
   - [ ] Exclusão de conta acessível em ≤ 3 toques a partir do perfil
   - [ ] Denunciar/bloquear funcionando
   - [ ] Links de privacidade, termos e exclusão abrindo
   - [ ] Nenhuma tela "em construção" ou botão morto
   - [ ] Push chegando no iPhone
   - [ ] App funciona sem permissão de notificação/câmera concedida
5. Enviar para produção: Play com **lançamento gradual** (10% → 50% → 100%);
   Apple com **liberação manual** após aprovação, para sincronizar as duas lojas.

---

## Fase 6 — Pós-lançamento

- **Site** (`patotasapp.com.br`): trocar os botões por badges oficiais com os
  links reais (skill `patotasapp-site`).
- **App**: botão "Avaliar o app" (`in_app_review`) depois de algumas partidas
  finalizadas; link de convite de patota com fallback para a loja certa.
- **Links de convite**: avaliar *App Links* (Android) e *Universal Links* (iOS)
  apontando `patotasapp.com.br/convite/...` para o app — exige
  `assetlinks.json` e `apple-app-site-association` no site.
- Monitorar Crashlytics, vitals da Play e avaliações; rotina de release a cada
  2–4 semanas pelo mesmo pipeline.

---

## Cronograma resumido

| Semana | Entregas |
|---|---|
| 1 | Fase 1 completa; início Fase 2 |
| 2 | CI Android + iOS; Fase 4 (textos, screenshots) |
| 3–4 | Fase 3 (denúncia/bloqueio, versão mínima, exclusão web, health checks) |
| 4 | Trilha interna + TestFlight; teste fechado começa |
| 5–6 | Teste fechado (14 dias) → envio para revisão |
| 6–7 | Aprovação e lançamento gradual |

Caminho crítico: **verificação da conta Play + 14 dias de teste fechado** e
**implementação de denúncia/bloqueio**. Começar ambos na semana 1.
