/// Patotas com câmeras de replay no campo. Só elas veem os botões de replay da
/// partida em jogo, a página de Replays e as abas/seções de vídeo; nas outras
/// patotas tudo isso some, porque nunca haveria vídeo para mostrar.
///
/// Hoje é só a Bratnava FC. Quando outra patota instalar câmeras, entra aqui
/// (ou vira uma configuração da patota na API).
const _replayGroupIds = <String>{
  '3f401edf-d309-4bae-97d8-28eae0da7a8a', // Bratnava FC
};

bool groupHasReplays(String? groupId) =>
    groupId != null && _replayGroupIds.contains(groupId.toLowerCase());

/// O atalho global de Replays é exclusivo da patota Bratnava FC. O nome é
/// usado de propósito: o ID técnico legado também existe em bases onde a
/// patota foi renomeada (por exemplo, Resenha FC).
bool isBratnavaFcGroup(String? groupName) =>
    groupName?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ==
    'bratnava fc';
