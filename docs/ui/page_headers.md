# Padrão de cabeçalhos

Toda tela autenticada, exceto o Dashboard, usa `AppPageHeader`. A tela não
deve recriar localmente cores, alturas, `SafeArea`, botão de voltar ou borda.

## Abas principais

`Partidas`, `Minha patota` e `Histórico` usam `AppPageHeader.main`. A linha de
identidade contém somente ícone e título e não exibe voltar. Ações indispensáveis
devem ser compactadas em um único menu para não competir com o título.

`Minha patota` é a exceção permitida: pode mostrar a logo, o nome da patota e o
atalho de configurações porque a identidade e a troca de contexto fazem parte da
própria tela.

## Telas internas

As demais telas usam `AppPageHeader`, com:

1. voltar;
2. ícone da funcionalidade;
3. título curto;
4. explicação de até duas linhas;
5. no máximo duas ações visíveis.

Filtros, abas e seletores relacionados à navegação da página usam `footer`.
Ações importantes com texto usam `AppPageHeaderActionBar` e
`AppPageHeaderButton` no mesmo `footer`: criação é primária e ações auxiliares
são secundárias. Ações excedentes ficam em um menu “Ações”. Ícones isolados com
`AppPageHeaderAction` ficam reservados a atalhos universais e óbvios.

O conteúdo abaixo do cabeçalho não repete o ícone nem o título da página. Cards
internos devem nomear somente sua seção ou seu conteúdo.

O componente usa exclusivamente `ThemeData`, `ColorScheme` e os tokens do tema.
Assim, alterações futuras na paleta e tipografia são propagadas sem editar cada
tela.
