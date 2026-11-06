# Compartilhamento por link

## Links

Base: `SHARE_URL` (config/*.json) — o site do sistema no Cloudflare Pages.
dev = `https://develop.app-frontend-web.pages.dev`, prod = `https://app-frontend-web.pages.dev`.

| Conteúdo | Caminho | Quem vê |
|---|---|---|
| Perfil | `/perfil/{userId}` | Vitrine, conforme a privacidade da pessoa (nível novo "Qualquer pessoa com o link") e bloqueios |
| Patota | `/patota/{groupId}` | Vitrine, se o admin deixou a página pública ligada (padrão) |
| Partida | `/partida/{matchId}` | Só integrante |
| Votação de MVP | `/votacao/{matchId}` | Só integrante |
| Campeonato | `/campeonato/{id}` | Só integrante |
| Enquete/evento | `/enquete/{pollId}` | Só integrante |

Os caminhos são os mesmos no site (`src/share/shareLinks.ts`) e no app (`lib/core/share/share_links.dart`).

## Abrir no app

- **Android (App Links):** `AndroidManifest.xml` tem um intent-filter `autoVerify` com o host do flavor
  (`manifestPlaceholders["shareHost"]` no `build.gradle.kts`). O site publica
  `/.well-known/assetlinks.json` (BratnavaFCFront `public/.well-known`). Hoje ele tem só o SHA-256 da chave
  de debug versionada (`android/keystores/debug.keystore`) para `br.com.patotasapp.dev`.
  **Falta:** acrescentar, para `br.com.patotasapp`, o SHA-256 da chave de assinatura da Play
  (Play Console → Integridade do app → Assinatura do app) e o da upload key.
- **iOS (Universal Links):** o site publica `/.well-known/apple-app-site-association`
  (appID `2PY7CL62VG.br.com.patotasapp`). **Falta:** ligar *Associated Domains* no App ID (Apple Developer)
  e adicionar `applinks:app-frontend-web.pages.dev` em `ios/Runner/Runner.entitlements`. Não foi feito
  para não quebrar a assinatura do próximo build antes de a capability existir.
- Sem o app (ou antes da verificação), o link abre o site, que mostra a mesma página.
- Domínio próprio (opcional): `app.patotasapp.com.br` como CNAME para `app-frontend-web.pages.dev`
  (DNS na HostGator + domínio personalizado no Pages). Ao trocar, mudar `SHARE_URL`, `shareHost` e o
  `applinks:` do iOS.

## No app

- Link aberto sem login fica guardado (`PendingShareLink`) e abre depois do login.
- Integrante: o app troca para a patota do link e abre a tela interna. Os demais veem só o aviso.
