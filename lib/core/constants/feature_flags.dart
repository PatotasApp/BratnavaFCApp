/// Funcionalidades implementadas que estão temporariamente fora do produto.
///
/// Manter a decisão em um único ponto permite reativar o fluxo sem recuperar
/// código removido e evita que uma tela isolada exponha uma ação indevida.
abstract final class FeatureFlags {
  static const externalPlayerInteractionsEnabled = false;
}
