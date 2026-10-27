# Progresso — telas do Modo Campeonato

Branch: `feature/campeonato-telas`

Último commit de implementação: `515a2bd` (`Implementa telas do modo campeonato com mock`)

Contrato da API: **v6** de 27/10/2026 (antes: v3).

| # | Etapa | Status |
|---|---|---|
| 1 | Mapear arquitetura, navegação, tema e baseline | ✅ |
| 2 | Contrato Dart, JSON e datasources Mock/API | ✅ |
| 3 | Providers e seleção centralizada do datasource | ✅ |
| 4 | Entrada no menu e lista de campeonatos | ✅ |
| 5 | Wizard de criação e resumo das regras | ✅ |
| 6 | Detalhe/ao vivo, ações e polling | ✅ |
| 7 | Votação de MVP | ✅ |
| 8 | Testes, análise estática e revisão de isolamento | ✅ |
| 9 | Commits finais | ✅ |

## Decisões de UI

- A feature seguirá a mesma separação `data/domain/presentation` já usada pelo app.
- Enums serão serializados pelos valores inteiros exatos do contrato, sem nomes em JSON.
- O mock será mutável em memória para permitir navegar pelo fluxo e testar ações sem backend.
- A troca entre mock e API ficará concentrada em um provider/configuração da feature.
- A flag será um `dart-define` explícito: ligada em `config/dev.json` e desligada em `config/prod.json`.
- O datasource API contém todas as rotas da v3; o mock usa os mesmos DTOs e oferece exemplos nos sete status.
- `CHAMPIONSHIPS_USE_MOCK` é lido apenas pelo provider do datasource; páginas e notifiers não conhecem a origem dos dados.
- A entrada de Campeonatos fica no agrupamento Organização do menu Mais e a rota também é condicionada por `CHAMPIONSHIPS_ENABLED`, evitando acesso acidental em produção.
- A listagem usa os `ruleBadges` entregues pela API/mock como fonte de verdade e não tenta reconstruí-los no cliente.
- O wizard expõe todos os campos de `ChampionshipRulesDto`, aplica apenas os dois presets definidos pelo contrato e valida as combinações antes do POST.
- A ordem dos desempates é editável por subir/descer, mantendo os cinco critérios sem criar valores fora do contrato.

## Divergências ou dúvidas sobre o contrato

- A v2 corrigiu `InviteResponse` de 0/1/2 para 1/2/3 enquanto a etapa de contrato estava em andamento. Os modelos e o mock foram atualizados antes da UI; não ficou compatibilidade com os valores antigos.
- A v3 tornou `myInviteResponse` anulável e moveu goleiro para `PATCH /{id}/goalkeeper`, por time e para os próximos jogos. O modelo, os dois datasources e o provider foram alinhados antes da tela ao vivo.

## Dúvidas para o Luis

- O contrato de convidado recebe apenas `playerId` e não oferece endpoint de busca nesta feature; no mock, a tela pede o ID do jogador já cadastrado. Quando houver um seletor oficial de jogadores, ele pode substituir apenas esse campo sem alterar o contrato.

## Atualização para o contrato v6 (27/10/2026)

| # | Etapa | Status |
|---|---|---|
| 10 | Contrato v6 no wizard/modelos/mock | ✅ |
| 11 | Cores dos times (v5): sortear cores e editar nome/cor | ✅ |
| 12 | Histórico com campeonatos (v4) | ⏳ outra IA (prompt entregue ao Luis) |
| 13 | `ChampionshipApiDataSource` completo + testes com JSON do contrato | ✅ |
| 14 | Seletor de jogadores da patota para convidado | ✅ |

O que mudou:
- Removidos o formato mata-mata (3), `ChampionshipEndMode` e `championshipEnd` (modelos, wizard e mock). O wizard explica que o campeonato termina em "Encerrar campeonato".
- Novo `WinnerStaysLimitRule` (`winnerStays.limitRule`): "Ao atingir o limite" aparece quando o limite de vitórias é maior que 0, com o aviso "Com 3 times não dá para saírem os dois; sai só o vencedor." Os presets usam `limitRule` 1. Se o JSON não trouxer `limitRule`, o app assume 1.
- Desempate: "Pontos" fica travado em 1º (cadeado; os outros só se reordenam entre si). A validação exige `tiebreakers[0] == 1`.
- `minGamesForPlacementResult` aparece no wizard com o texto "Quem jogou menos que isso conta só presença" (padrão 1; aceita >= 0, como o servidor).
- `placementResults` nulo vira lista vazia (o servidor declara o campo como anulável).
- `ChampionshipTeam.colorHex` passou a ser anulável (time sem cor, v5); a tela mostra o ícone "sem cor".
- "Encerrar campeonato" (`POST /{id}/finish`) pede confirmação e avisa "Votação do MVP aberta." quando o campeonato tem MVP.
- Times: botão "Sortear cores" (`POST /{id}/teams/colors/draw`) e editar nome/cor (`PATCH /{id}/teams/{teamId}`), com as cores de `teamColorsProvider` (as mesmas da tela Cores dos times; só as ativas). O `message` de `teams/draw` aparece em vermelho na confirmação dos times; o de `colors/draw` aparece num SnackBar.
- Convidado: um seletor lista os jogadores da patota via `GET /api/Groups/{id}` (o mesmo do team builder), sem os inativos nem quem já está no campeonato. No mock, a lista é fixa.
- `ChampionshipApiDataSource`: todas as rotas da v6, envelope `ApiResponse` pelos helpers `unwrapMap`/`unwrapList` do core. Erros 4xx `{ error }` e `success: false` viram `ServerException` com a mensagem do servidor. Testes em `test/features/championships/data/championship_api_datasource_test.dart` com um adapter Dio falso e JSONs do contrato.

## Divergências encontradas no backend (avisadas ao Luis)

- `POST /{id}/teams/colors/draw`: o serviço gera o `message` (aviso de poucas cores), mas o controller usa o `ToResponse(Result)` do `GroupAuthorizedController`, que responde **204 sem corpo**. O aviso nunca chega. O app lê `message` se vier e, sem ele, mostra "Cores sorteadas.". Nota em `side-session-notes/.../app-flutter-para-backend.md`.

## O que falta

- Etapa 12 (histórico com `includeChampionships=true`, cards 🏆 e `playerResult`) foi passada para outra IA, nos arquivos de `history/`, `player_history/` e `dashboard/`.
- Testar contra a API real (`CHAMPIONSHIPS_USE_MOCK=false`), ainda não rodado.

## Baseline

- `flutter test`: 107 testes aprovados.
- `flutter analyze`: 201 avisos/informações preexistentes, sem erro; o projeto já retorna código 1 por esses lints. A validação final comparará o resultado para garantir nenhum erro novo.

## Validação final

- `flutter test --no-pub -j 1`: 115 testes aprovados (8 novos), 0 falhas.
- `flutter analyze` focal de todos os arquivos novos/modificados: nenhum erro novo; somente 2 warnings preexistentes de placeholders sem uso no roteador.
- A tentativa de `flutter analyze` completo foi interrompida pelo próprio analisador com falta de memória. A análise focal da feature completa passou limpa, e a suíte compila o app inteiro.
- `git diff --check`: limpo.
