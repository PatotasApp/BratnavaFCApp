# Migração do protótipo aprovado

Última atualização: 27/07/2026

## Progresso geral: 100%

Etapa atual: **Concluída**

O percentual considera apenas trabalho aplicado e validado no app Flutter. A criação
do protótipo não entra neste cálculo.

| Etapa | Peso | Progresso | Situação |
|---|---:|---:|---|
| 1. Auditoria e mapeamento | 5% | 100% | Concluída |
| 2. Design system e componentes-base | 15% | 100% | Concluída |
| 3. Shell, navegação e autenticação | 10% | 100% | Concluída |
| 4. Dashboard, partidas e histórico | 25% | 100% | Concluída |
| 5. Patota, Mais e telas auxiliares | 25% | 100% | Concluída |
| 6. Ícones configuráveis e estados reais | 10% | 100% | Concluída |
| 7. Testes e validação visual | 10% | 100% | Concluída |

Fórmula: soma de `peso × progresso da etapa`.

## Etapa 1 — Auditoria e mapeamento

- [x] Confirmar diretório e branch do app.
- [x] Remover, com autorização, as alterações locais anteriores.
- [x] Inventariar telas, providers, modelos e fontes de dados.
- [x] Registrar a correspondência completa entre rotas do app e telas do protótipo.
- [x] Registrar a linha de base de análise e testes.

## Etapa 2 — Design system e componentes-base

- [x] Paleta clara e escura fiel ao protótipo.
- [x] Tipografia, espaçamentos, raios, bordas e elevações.
- [x] Cabeçalhos, cards, linhas, badges, botões e campos.
- [x] Bottom sheets, modais, estados vazios, loading e erro.
- [x] Componente único de nome com ícone de jogador/goleiro.
- [x] Componentes para gol, assistência, gol contra, MVP e pódio.

## Etapa 3 — Shell, navegação e autenticação

- [x] Login e cadastro; recuperação não existe na API/app atual e não foi simulada.
- [x] Cabeçalho global.
- [x] Navegação inferior com cinco destinos.
- [x] Menu Mais reorganizado.
- [x] Minha conta separada de Usuários.
- [x] Alvos de toque e áreas seguras.

## Etapa 4 — Dashboard, partidas e histórico

- [x] Dashboard e card do jogador.
- [x] Próxima partida e confirmação de presença.
- [x] Fluxo simplificado das sete etapas.
- [x] Formação, cores, campo e geração de times.
- [x] Jogo ao vivo, gols e assistência.
- [x] Pós-jogo, MVP e resultado final.
- [x] Histórico e detalhes da partida.

## Etapa 5 — Patota, Mais e telas auxiliares

- [x] Minha patota: mensalistas, convidados e inativos.
- [x] Nota em estrelas dos convidados.
- [x] Pendências financeiras dos mensalistas.
- [x] Avaliações dos jogadores.
- [x] Configurações da patota nas quatro abas aprovadas.
- [x] Pagamentos e caixa.
- [x] Estatísticas e histórico pessoal.
- [x] Calendário, votações, ausências e aniversários.
- [x] Replays, Bet, cores, convites e montagem de times.
- [x] Usuários e permissões.

## Etapa 6 — Ícones configuráveis e estados reais

- [x] Jogador e goleiro ao lado de todos os nomes aplicáveis.
- [x] Gol, assistência, gol contra e MVP.
- [x] 1º, 2º e 3º lugares.
- [x] Persistência e atualização após salvar configurações.
- [x] Auditoria para remover símbolos esportivos fixos em dados configuráveis.

## Etapa 7 — Testes e validação visual

- [x] `flutter analyze` sem novos problemas.
- [x] Testes unitários e de widgets.
- [x] Fluxos críticos com providers, modelos e chamadas reais preservados.
- [x] Comparação visual em Pixel 5 físico lógico (1080 × 2340, DPR 2,75).
- [x] Tema claro e escuro.
- [x] Rolagem, teclado, safe areas e acessibilidade.
- [x] Revisão final de rotas e telas.

## Critério para marcar uma tela como concluída

Uma tela só conta como concluída quando:

1. usa os providers, modelos e chamadas reais existentes;
2. reproduz estrutura, hierarquia e estados do protótipo;
3. respeita os ícones configuráveis;
4. funciona em largura equivalente ao Pixel 5;
5. passa por análise/teste proporcional ao risco;
6. não perde ações ou informações da implementação anterior.

## Registro de decisões

- O protótipo em `BratnavaFCPrototype` é a especificação visual aprovada.
- A lógica, os dados, as permissões e as integrações do app Flutter devem ser preservados.
- Alterações locais anteriores foram descartadas por solicitação do usuário em 27/07/2026.
- Linha de base: `flutter analyze` sem erros e com 80 avisos/informações preexistentes em 27/07/2026.
- Shell: navegação inferior, menu Mais agrupado e Minha conta separados de Usuários em 27/07/2026.
- Dashboard: histórico anual, presença, financeiro, votações e agenda ligados aos providers reais em 27/07/2026.
- Validação após o Dashboard: `flutter analyze` sem novos problemas e 25 testes aprovados.
- Partidas: cabeçalho compacto, sete etapas resumidas e lista completa em bottom sheet em 27/07/2026.
- Ícones configuráveis aplicados a nomes, papéis, gols, assistências e gols contra nas etapas principais da partida.
- Build Android validado: `build/app/outputs/flutter-apk/app-debug.apk` gerado com sucesso.
- Histórico: listagem, filtros, estados, carregamento incremental e detalhes migrados para o padrão visual aprovado.
- Detalhes da partida: ícones de jogador/goleiro aplicados em escalações, gols, assistências e MVP.
- Minha patota: cabeçalho, filtros de jogadores, estrelas de convidados e situação financeira ligados aos dados reais.
- Validação após Histórico e Minha patota: `flutter analyze` sem novos problemas e 25 testes aprovados.
- Configurações da patota: quatro abas funcionais preservadas, cabeçalho interno com retorno, alvos de toque ampliados e menos níveis de cards.
- O emulador Pixel 5 foi iniciado em 27/07/2026, mas não conectou ao ADB nesta rodada; a comparação visual permanece pendente.
- APK Android recompilado com sucesso após a migração de Histórico, Patota e Configurações.
- Estatísticas: jogadores, goleiros, métricas, MVP e pódio usam os ícones configurados; navegação e abas foram ajustadas para telas estreitas.
- Monte seu time: campo, seleção, nomes, gols e assistências usam os ícones atuais da patota.
- Histórico pessoal: seletor, cabeçalho, resumo e eventos por partida usam os mesmos ícones configurados.
- Validação após a auditoria de ícones: 77 avisos/informações preexistentes, nenhum erro novo e 25 testes aprovados.
- Pagamentos e Caixa: cabeçalho móvel, retorno, troca de visão e alvos de toque atualizados sem remover mensalidades, cobranças, descontos ou transações.
- Corrigida a quantidade de abas no modo de pagamento por partida, evitando divergência entre `TabController`, `TabBar` e `TabBarView`.
- Função de goleiro adicionada às cobranças extras quando fornecida pela API, com testes de parsing; suíte ampliada para 27 testes.
- Usuários passou a abrir a gestão administrativa; Minha conta permanece dedicada ao próprio perfil, contas, patotas e segurança.
- Rotas auxiliares receberam retorno consistente e alvos mínimos de toque de 48 px.
- Ícones configuráveis auditados também em Spotlight, Bet, aniversários, ausências, enquetes, pagamentos e seletores de jogadores.
- Validação final: análise estática sem erros, 28 testes aprovados e APK debug gerado.
- Pixel 5 reiniciado com boot limpo, APK instalado e telas clara/escura e comportamento com teclado/rolagem inspecionados em 27/07/2026.
