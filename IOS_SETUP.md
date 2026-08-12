# 🍎 Configuração de Ambientes e Firebase no iOS

Este guia documenta como configurar os ambientes (`dev` e `prod`) no iOS usando o Xcode. Isso é necessário para gerenciar os arquivos `GoogleService-Info.plist` do Firebase dinamicamente e fazer o Google Sign-In e Push Notifications funcionarem.

## 1. Estrutura de Pastas (Finder/VS Code)
Crie a estrutura abaixo dentro de `ios/Runner/` e coloque os respectivos arquivos do Firebase:

    ios/
    └── Runner/
        ├── Firebase/
        │   ├── dev/
        │   │   └── GoogleService-Info.plist
        │   └── prod/
        │       └── GoogleService-Info.plist

## 2. Configurações (Configurations) no Xcode
1. Abra `ios/Runner.xcworkspace` no Xcode.
2. Clique no projeto **Runner** > aba **Info**.
3. Em **Configurations**, clique no `+` e duplique as originais para criar:
   - `Debug-dev` e `Debug-prod`
   - `Release-dev` e `Release-prod`
   - `Profile-dev` e `Profile-prod`
*(Depois pode apagar as originais sem sufixo).*

## 3. Bundle Identifier (IDs Separados)
1. Clique no target **Runner** > aba **Build Settings**.
2. Busque por `Product Bundle Identifier`.
3. Altere os valores conforme o ambiente:
   - Tudo que terminar em `-dev`: `br.com.patotasapp.dev`
   - Tudo que terminar em `-prod`: `br.com.patotasapp`

## 4. O Script Mágico de Cópia (Build Phases)
Para o iOS saber qual Firebase usar ao rodar `flutter run --flavor dev`:

1. No target **Runner**, vá na aba **Build Phases**.
2. Clique no `+` > **New Run Script Phase**.
3. Arraste esse script para ficar **antes** de *Copy Bundle Resources*.
4. Cole o seguinte código Shell:

    if [[ $CONFIGURATION =~ -dev$ ]]; then
      ENVIRONMENT="dev"
    else
      ENVIRONMENT="prod"
    fi

    echo "🔥 Copiando GoogleService-Info.plist para o ambiente: $ENVIRONMENT"

    SRC_PATH="${PROJECT_DIR}/Runner/Firebase/${ENVIRONMENT}/GoogleService-Info.plist"
    DEST_PATH="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

    cp "$SRC_PATH" "$DEST_PATH"

## 5. Google Sign-In (URL Types)
Para o Google Sign-In funcionar, o iOS precisa conhecer os `REVERSED_CLIENT_ID` dos dois ambientes.

1. Abra os dois `GoogleService-Info.plist` (dev e prod) no VS Code e copie o valor da chave `REVERSED_CLIENT_ID` de cada um.
2. No Xcode, vá na aba **Info** (do target) > **URL Types**.
3. Clique no `+` duas vezes.
4. Adicione o `REVERSED_CLIENT_ID` de DEV no primeiro, e o de PROD no segundo. O iOS testará ambos automaticamente na hora do login.