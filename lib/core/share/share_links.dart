import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';

/// Tipos de link compartilhável. Os caminhos são os mesmos do site
/// (BratnavaFCFront: src/share/shareLinks.ts) — mantenha os dois iguais.
enum ShareKind {
  profile('perfil'),
  group('patota'),
  match('partida'),
  mvp('votacao'),
  championship('campeonato'),
  poll('enquete');

  const ShareKind(this.path);

  /// Primeiro segmento do link (`/perfil/{id}`).
  final String path;

  /// Nome do tipo na API (`/api/public/share/{apiKind}/{id}`). Só os internos.
  String get apiKind => switch (this) {
        ShareKind.match => 'match',
        ShareKind.mvp => 'mvp',
        ShareKind.championship => 'championship',
        ShareKind.poll => 'poll',
        ShareKind.profile || ShareKind.group => name,
      };

  bool get isInternal =>
      this != ShareKind.profile && this != ShareKind.group;

  static ShareKind? fromPath(String segment) {
    for (final kind in ShareKind.values) {
      if (kind.path == segment.toLowerCase()) return kind;
    }
    return null;
  }
}

/// Link de compartilhamento já entendido: tipo e id.
class ShareTarget {
  final ShareKind kind;
  final String id;

  const ShareTarget(this.kind, this.id);

  /// Reconhece `https://<site>/perfil/{id}` (ou só o caminho, como o GoRouter
  /// entrega o App Link). Devolve null para qualquer outra coisa.
  static ShareTarget? parse(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 2) return null;
    final kind = ShareKind.fromPath(segments[0]);
    final id = segments[1];
    if (kind == null || !_guid.hasMatch(id)) return null;
    return ShareTarget(kind, id);
  }

  static final _guid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  bool operator ==(Object other) =>
      other is ShareTarget && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

class ShareLinks {
  ShareLinks._();

  /// Base dos links. Vem de SHARE_URL (config/*.json); sem ela, o site de produção.
  static String get baseUrl => AppConstants.shareUrl;

  static String build(ShareKind kind, String id, {String? base}) =>
      '${(base ?? baseUrl).replaceAll(RegExp(r'/+$'), '')}/${kind.path}/${Uri.encodeComponent(id)}';

  static String profile(String userId) => build(ShareKind.profile, userId);
  static String group(String groupId) => build(ShareKind.group, groupId);
  static String match(String matchId) => build(ShareKind.match, matchId);
  static String mvp(String matchId) => build(ShareKind.mvp, matchId);
  static String championship(String id) => build(ShareKind.championship, id);
  static String poll(String pollId) => build(ShareKind.poll, pollId);
}

/// Abre a folha de compartilhamento do sistema com o texto e o link.
Future<void> shareLink(BuildContext context, String url, {String? text}) async {
  final box = context.findRenderObject() as RenderBox?;
  await Share.share(
    text == null || text.isEmpty ? url : '$text\n$url',
    sharePositionOrigin:
        box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}
