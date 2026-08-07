# Alinhamento do app com o protótipo

Comparação entre `BratnavaFCPrototype` (fonte da verdade) e este app.

---

## 1. Feito nesta rodada

### `/current` eliminado — carregamento da partida

O app pedia `/api/matches/group/{id}/current`, que devolve o `MatchDetailsDto`
inteiro (escalação, gols, times, aceitação, pós-jogo). Era a requisição mais
lenta da abertura.

O site **nunca chama esse endpoint** — `MatchesApi.getCurrent` está declarado em
`endpoints.ts` e não tem nenhum uso. O caminho dele é `upcoming` (headers leves)
→ escolhe a partida → carrega só a etapa atual.

| Lugar | Antes | Agora |
|---|---|---|
| `match_provider.loadInitial` | `/current` **+** `upcoming` em paralelo | só `upcoming` |
| `dashboard_remote_datasource` | `/current` **+** `/details` | `upcoming` + `/details` |
| `history_remote_datasource` | `/current` para pegar o id | `upcoming` |

O `match_provider` já tinha `_loadStepPayload`, que carrega apenas a etapa
corrente — a metade cara era só o `/current` redundante, já que o `upcoming`
vinha no mesmo `Future.wait` trazendo `matchId`, `stepKey`, `placeName`,
`canRewind` e o placar.

`fetchCurrentMatchStub` ficou marcado `@Deprecated` em vez de removido.

### Status bar — 5 telas

O shell só coloca AppBar na Dashboard (`appBar: selected == 0 ? AppTopBar() : null`).
As demais desenhavam a partir de y=0, sob o relógio e os ícones do sistema.

- **Partidas** e **Histórico**: inset somado ao banner (o fundo segue até o topo, só o conteúdo desce)
- **Ausências**, **Votações**, **God Mode**: `SafeArea(bottom: false)`
- **Minha patota** já se protegia

### Tokens e primitivos

- 7 tokens que faltavam: `onAccent`, `successBackground`, `dangerBackground`, `neutral`, `borderDashed`, `teamBlue` e a variante clara de `notification` (o valor escuro sobre branco não passava em contraste)
- Resolvedores por brilho (`AppColors.successOf(brightness)`) para eliminar o `isDark ? X : Y` repetido
- `PrototypeLayout` foi de 7 para 18 constantes, com o CSS de origem comentado em cada uma
- `labelSmall` 10px → **11px** com `letter-spacing .07em` (é o "ETAPA 1 DE 7", presente em quase toda tela)
- `minimumTouchTarget` 48 → 44, igual ao protótipo

### Avatar — a maior divergência visual

| | Protótipo | App (antes) |
|---|---|---|
| forma | quadrado arredondado, raio 12 | **círculo** |
| fundo | `--accent-bg` sólido | **gradiente por nome** |
| texto | `--accent-text` | branco |
| lado | 34 | 36 |
| peso | 800 | 700 |

Alinhado ao protótipo. O visual antigo continua acessível via
`AvatarWidget.gradient(...)`. **É a mudança mais visível e a mais fácil de
reverter** se a preferência for o gradiente.

---

## 2. Proporções — onde o app se afasta

Medi a distribuição real de raios, espaçamentos e tipografia nas 32 páginas.

### Raios

Protótipo usa **5 valores**: 12 (controles), 13 (list row), 16 (card), 22 (sheet), 999 (chip).

| Raio | Ocorrências no app | No protótipo? |
|---|---|---|
| 12 | 132 | ✅ |
| **10** | **112** | ❌ |
| **8** | **108** | ❌ |
| 14 | 44 | ❌ |
| 20 | 29 | ❌ |
| 16 | 27 | ✅ |
| 2 | 27 | ❌ |
| **13** | **0** | ✅ — o raio da list row não é usado em lugar nenhum |

Raio 10 e 8 aparecem **220 vezes** e não existem no protótipo. O 13 da list row,
que é o que dá o toque macio das listas, não é usado nenhuma vez.

### Espaçamento vertical

Protótipo: 12 (stack) e 10 (row), com padding de card 14.

| Valor | Ocorrências |
|---|---|
| 12 | 193 ✅ |
| 8 | 101 ❌ |
| 16 | 75 ✅ |
| 6 | 74 ❌ |
| 4 | 59 ❌ |
| 2 | 56 ❌ |
| 10 | 56 ✅ |

O 12 domina, o que é bom sinal. Mas há uma cauda de 2/4/6/8 com **290
ocorrências** que não pertence à escala.

### Tipografia

Protótipo (camada base, após os ajustes): 11 · 12 · 13 · 14 · 18.

| Tamanho | Ocorrências | |
|---|---|---|
| 13 | 254 | ✅ |
| 12 | 223 | ✅ |
| 11 | 201 | ✅ |
| **10** | **100** | ❌ abaixo do piso |
| 14 | 92 | ✅ |
| **9** | **23** | ❌ abaixo do piso |

**123 declarações abaixo de 11px.** Referência: iOS usa 11pt como piso para
texto secundário; Material usa 12sp.

### Telas com maior desvio

| Tela | raio | gap | fonte | cor fixa |
|---|---|---|---|---|
| `groups_page` | 38 | 27 | 9 | **240** |
| `group_settings_page` | 45 | 32 | 8 | 43 |
| `match_details_page` | 16 | 12 | 20 | 34 |
| `visual_stats_page` | 14 | 5 | 15 | 28 |
| `team_colors_page` | 15 | 15 | 6 | 22 |
| `members_page` | 29 | 12 | 11 | 7 |
| `payments_page` | 17 | 16 | 6 | 8 |

`groups_page.dart` sozinho concentra **240 das 660 cores fixas** do app.

---

## 3. Por que parei aqui

As correções acima são centrais: mudam o token ou a constante e propagam.
O que resta é volume distribuído — 660 cores fixas, 220 raios fora de escala,
123 fontes abaixo do piso, espalhados por 32 arquivos.

Trocar isso em lote é arriscado sem conseguir rodar o app: subir uma fonte de
10 para 11 muda a altura da linha e pode estourar um `Row` que já estava no
limite. Não tenho o SDK Flutter aqui para compilar nem para tirar screenshot.

**Ordem sugerida**, uma tela por vez com verificação visual entre elas:

1. `groups_page` — 240 cores fixas, 36% da dívida total, e é a tela mais usada
2. `group_settings_page` — o pior desvio de raio e espaçamento
3. `match_details_page` — 20 fontes fora de escala
4. `visual_stats_page` e `team_colors_page`
5. Varredura final das fontes < 11px

---

## 4. Verificação

Nada aqui foi compilado — o sandbox não tem o SDK Dart. Validei balanceamento de
parênteses e chaves nos arquivos tocados, e confirmei que os campos usados
existem (`MatchState.copyWith`, `MatchHeaderDto`).

Antes de commitar:

```bash
flutter analyze
dart format lib/
```

O `analyze` importa em especial porque mudei assinatura pública em dois métodos
da datasource de auth (`fetchGroupRoles` e `fetchMyGroupRoles` agora retornam
tipos anuláveis) e o `AvatarWidget`, que tem 10 usos.
