# 🔐 Assinatura Android — chaves, SHA e build de produção

Este guia cobre como assinar builds de release e fazer o **login com Google
funcionar em produção**. A parte de dev já está resolvida e não exige nada de
ninguém — o keystore de debug é versionado.

---

## Por que existem três chaves

| Chave | Onde vive | Assina | SHA registrado no Firebase |
|---|---|---|---|
| **Debug compartilhado** | `android/keystores/debug.keystore`, versionado | builds de dev e qualquer debug | Só no projeto de **dev** (`development-d04ef`) |
| **Upload key** | fora do repo, no cofre | AAB enviado à Play e APKs de release locais | No projeto de **prod** (`production-2153f`) |
| **App signing key** | servidores do Google | o que o usuário instala da Play | No projeto de **prod**, após o 1º upload |

O debug keystore é versionado de propósito: sem ele cada máquina geraria um SHA
diferente e o login com Google exigiria uma impressão digital por dev no console.
Ele não é segredo — a senha `android` e o alias `androiddebugkey` são os padrões
públicos do Android SDK. O que limita o risco é o SHA dele estar registrado
**apenas em dev**.

O Play App Signing separa a upload key da app signing key: vocês assinam o AAB
com a de vocês, a Play confere, remove essa assinatura e re-assina com a do
Google. Por isso os **dois** SHAs precisam estar registrados — o build local usa
um, o app publicado usa o outro.

> ⚠️ **O SHA não é derivado dos dados que você digita ao gerar a chave.** Ele vem
> da chave privada, que é aleatória. Dois keystores gerados com a mesma senha e o
> mesmo nome têm SHAs diferentes. Não existe "replicar a geração" — o que se
> compartilha é o **arquivo**.

---

## Parte A — o que o responsável faz (uma vez)

### A1. Gerar a upload key

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.p12 \
  -storetype PKCS12 \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias upload
```

O comando pergunta a senha e os dados do certificado interativamente. É melhor
assim do que passar `-storepass` na linha de comando, que ficaria no histórico do
shell.

- **PKCS12**, não JKS: é o padrão do `keytool` desde o Java 9. JKS funciona mas o
  próprio keytool avisa que é legado.
- **`-validity 10000`** (~27 anos). A Play exige validade longa.
- **Em PKCS12 existe uma senha só.** A senha da chave é a mesma do keystore.

### A2. Guardar

1. Mova o `.p12` para uma pasta **fora do repositório**.
2. Suba o arquivo **e** a senha para o cofre da equipe (1Password, Bitwarden).
3. Confirme que não sobrou cópia dentro do projeto. O `android/.gitignore`
   bloqueia `*.p12`, `*.jks`, `*.keystore` e `key.properties`, mas conferir custa
   nada.

Perder este arquivo não é fatal — a Play tem procedimento de reset de upload key
— mas dá trabalho e invalida os SHAs registrados.

### A3. Pegar os SHAs

```bash
keytool -list -v -keystore upload-keystore.p12 -alias upload
```

Anote o **SHA-1** e o **SHA-256**.

### A4. Registrar no Firebase de produção

1. Console do Firebase → projeto **`production-2153f`**.
2. Configurações do projeto → app Android **`br.com.patotasapp`**.
3. Adicionar impressão digital: **SHA-1** e **SHA-256**.
4. Baixar o `google-services.json` novo e substituir
   **`android/app/src/prod/google-services.json`**.
5. Confirme que o arquivo passou a ter um `oauth_client` com
   `"client_type": 1`. Hoje ele só tem o `client_type: 3` (web). Esse bloco novo
   é a prova de que deu certo.
6. Commite o `google-services.json` — ele **não** é segredo (é extraível de
   qualquer APK publicado).

**Não registre o SHA do debug compartilhado neste projeto.** Ele está no
repositório; registrá-lo em prod deixaria qualquer pessoa com acesso ao código
assinar um app que o Firebase de produção aceita para login com Google.

### A5. Criar o `key.properties`

Em `android/key.properties` (não versionado):

```properties
storePassword=<a senha escolhida em A1>
keyPassword=<a MESMA senha — PKCS12 tem só uma>
keyAlias=upload
storeFile=C:/caminho/fora/do/repo/upload-keystore.p12
```

### A6. Conferir

```bash
cd android && ./gradlew signingReport
```

A variante `prodRelease` deve mostrar `Config: release` e apontar para o seu
`.p12`. Se mostrar `Config: debug`, o `key.properties` não foi encontrado — o
Gradle cai no debug de propósito, para não quebrar o build de quem não tem a
chave.

---

## Parte B — o que passar para o outro dev

Mande **três coisas**, as duas primeiras pelo cofre:

1. O arquivo `upload-keystore.p12`
2. A senha
3. O link deste documento

E ele faz:

```
1. Salvar o .p12 numa pasta fora do repositório
2. Criar android/key.properties com a MESMA senha e alias `upload`,
   mudando só o storeFile para o caminho da máquina dele
3. cd android && ./gradlew signingReport   → prodRelease deve dizer Config: release
```

Nada além disso. Ele **não** gera chave nenhuma — se gerar, o SHA será diferente
e o login com Google falhará no build dele.

---

## Como buildar

Sempre **dois** parâmetros. O `--flavor` decide o projeto Firebase, o
`--dart-define-from-file` decide a API. Rodar com metade do par autentica num
ambiente e chama a API do outro, e tudo responde 401.

```bash
# desenvolvimento
flutter build apk --release --flavor dev  --dart-define-from-file=config/dev.json

# produção
flutter build apk --release --flavor prod --dart-define-from-file=config/prod.json

# AAB para a Play
flutter build appbundle --release --flavor prod --dart-define-from-file=config/prod.json
```

Sem o arquivo de config o app lança `StateError: API_URL não definida` — falha
explícita em vez de apontar para o ambiente errado em silêncio.

Dev e prod têm applicationId diferente (`br.com.patotasapp.dev` e
`br.com.patotasapp`), então **convivem no mesmo aparelho**.

---

## Parte C — depois do primeiro upload na Play

Falta o SHA da chave que o Google usa para re-assinar. Sem ele o login com Google
funciona na máquina de vocês e **falha para quem instalou da Play** — o build
local nunca revela esse problema.

1. Play Console → sua app → **Test and release → App integrity** (o nome dessa
   seção já mudou algumas vezes; procure por "App signing").
2. Copie o **SHA-1** e o **SHA-256** do *app signing key certificate*.
3. Registre no mesmo app Firebase de prod e rebaixe o `google-services.json`.

---

## O que nunca fazer

- Versionar `upload-keystore.p12`, `*.jks` ou `key.properties`
- Mandar a chave ou a senha por chat, e-mail ou issue
- Registrar o SHA do debug compartilhado no projeto de produção
- Gerar uma chave por dev
- Publicar um APK/AAB assinado com a chave de debug (a Play recusa)

---

## Se algo falhar

| Sintoma | Causa provável |
|---|---|
| `signingReport` diz `Config: debug` em `prodRelease` | `key.properties` ausente ou com `storeFile` errado |
| Login com Google falha só em prod | SHA da upload key não registrado, ou `google-services.json` de prod sem `client_type: 1` |
| Login com Google falha só para quem baixou da Play | Falta o SHA da app signing key (Parte C) |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` ao instalar | Assinatura diferente da versão já instalada — desinstale antes |
| Tudo responde 401 | `--flavor` e `--dart-define-from-file` de ambientes diferentes |
| `keystore password was incorrect` | Em PKCS12, `keyPassword` tem de ser igual a `storePassword` |
