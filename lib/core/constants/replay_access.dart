/// Toda referência visual a Replays é exclusiva da patota Bratnava FC.
/// O ID é estável mesmo quando o nome de exibição da patota muda.
const _bratnavaFcGroupId = '3f401edf-d309-4bae-97d8-28eae0da7a8a';

bool groupHasReplays(String? groupId) =>
    groupId?.trim().toLowerCase() == _bratnavaFcGroupId;
