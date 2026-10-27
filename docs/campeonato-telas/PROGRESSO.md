# Progresso — telas do Modo Campeonato

Branch: `feature/campeonato-telas`

Último commit de implementação: `515a2bd` (`Implementa telas do modo campeonato com mock`)

Contrato da API: v3 de 27/10/2026.

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

## O que falta

- Nada. Trabalho concluído e mantido sem push na branch `feature/campeonato-telas`.

## Baseline

- `flutter test`: 107 testes aprovados.
- `flutter analyze`: 201 avisos/informações preexistentes, sem erro; o projeto já retorna código 1 por esses lints. A validação final comparará o resultado para garantir nenhum erro novo.

## Validação final

- `flutter test --no-pub -j 1`: 115 testes aprovados (8 novos), 0 falhas.
- `flutter analyze` focal de todos os arquivos novos/modificados: nenhum erro novo; somente 2 warnings preexistentes de placeholders sem uso no roteador.
- A tentativa de `flutter analyze` completo foi interrompida pelo próprio analisador com falta de memória. A análise focal da feature completa passou limpa, e a suíte compila o app inteiro.
- `git diff --check`: limpo.
