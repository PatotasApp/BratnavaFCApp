import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../auth/presentation/providers/auth_provider.dart';

/// Planilhas antigas da patota (histórico de jogos e pagamentos) enviadas para a
/// equipe do PatotasApp importar. Não há importação automática: o arquivo só fica
/// guardado, e a patota acompanha a situação aqui.
///
/// API: `POST|GET /api/groups/{groupId}/spreadsheets`,
/// `DELETE /api/groups/{groupId}/spreadsheets/{id}` — só admin da patota.

/// Espelha `GroupSpreadsheetKind` da API.
enum SpreadsheetKind {
  matches(0, 'Histórico de jogos', 'jogos'),
  payments(1, 'Pagamentos', 'pagamentos');

  const SpreadsheetKind(this.apiValue, this.label, this.shortLabel);
  final int apiValue;
  final String label;
  final String shortLabel;

  static SpreadsheetKind fromApi(dynamic v) =>
      SpreadsheetKind.values.firstWhere((k) => k.apiValue == _asInt(v),
          orElse: () => SpreadsheetKind.matches);
}

/// Espelha `GroupSpreadsheetStatus` da API.
enum SpreadsheetStatus {
  received(0, 'Recebida', 'A equipe ainda vai analisar.'),
  inProgress(1, 'Em andamento', 'A equipe está importando os dados.'),
  finished(2, 'Finalizada', 'Os dados já estão no app.');

  const SpreadsheetStatus(this.apiValue, this.label, this.description);
  final int apiValue;
  final String label;
  final String description;

  static SpreadsheetStatus fromApi(dynamic v) =>
      SpreadsheetStatus.values.firstWhere((s) => s.apiValue == _asInt(v),
          orElse: () => SpreadsheetStatus.received);
}

int? _asInt(dynamic v) => v is int ? v : int.tryParse('$v');

class GroupSpreadsheet {
  final String id;
  final String groupId;
  final SpreadsheetKind kind;
  final String fileName;
  final int sizeBytes;
  final String? note;
  final SpreadsheetStatus status;
  final String? adminNote;
  final String uploadedByName;
  final DateTime createdAt;
  final DateTime? statusChangedAt;

  const GroupSpreadsheet({
    required this.id,
    required this.groupId,
    required this.kind,
    required this.fileName,
    required this.sizeBytes,
    required this.note,
    required this.status,
    required this.adminNote,
    required this.uploadedByName,
    required this.createdAt,
    required this.statusChangedAt,
  });

  /// A patota só desiste do envio enquanto a importação não começou.
  bool get canDelete => status == SpreadsheetStatus.received;

  factory GroupSpreadsheet.fromJson(Map<dynamic, dynamic> j) {
    dynamic f(String k) => j[k] ?? j[k[0].toUpperCase() + k.substring(1)];
    String? s(String k) {
      final v = f(k);
      return v == null || '$v'.trim().isEmpty ? null : '$v';
    }

    return GroupSpreadsheet(
      id: '${f('id')}',
      groupId: '${f('groupId')}',
      kind: SpreadsheetKind.fromApi(f('kind')),
      fileName: s('fileName') ?? 'planilha',
      sizeBytes: _asInt(f('sizeBytes')) ?? 0,
      note: s('note'),
      status: SpreadsheetStatus.fromApi(f('status')),
      adminNote: s('adminNote'),
      uploadedByName: s('uploadedByName') ?? '',
      createdAt: DateTime.tryParse('${f('createdAt')}')?.toLocal() ?? DateTime.now(),
      statusChangedAt: DateTime.tryParse('${f('statusChangedAt') ?? ''}')?.toLocal(),
    );
  }
}

/// Regras do arquivo — as mesmas da API, conferidas antes para não gastar o envio.
class SpreadsheetFileRules {
  static const maxSizeBytes = 10 * 1024 * 1024;
  static const allowedExtensions = ['xlsx', 'xls', 'csv', 'ods', 'pdf'];

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  /// Mensagem de erro, ou null quando o arquivo pode ser enviado.
  static String? validate(String fileName, int sizeBytes) {
    if (!allowedExtensions.contains(extensionOf(fileName))) {
      return 'Envie a planilha em .xlsx, .xls, .csv, .ods ou .pdf.';
    }
    if (sizeBytes <= 0) return 'O arquivo está vazio.';
    if (sizeBytes > maxSizeBytes) return 'A planilha deve ter no máximo 10 MB.';
    return null;
  }

  static MediaType contentTypeOf(String fileName) {
    switch (extensionOf(fileName)) {
      case 'xlsx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      case 'csv':
        return MediaType('text', 'csv');
      case 'ods':
        return MediaType('application', 'vnd.oasis.opendocument.spreadsheet');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).round();
      return '${kb < 1 ? 1 : kb} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
}

/// Arquivo escolhido no aparelho, pronto para enviar.
class PickedSpreadsheet {
  final String name;
  final Uint8List bytes;
  const PickedSpreadsheet(this.name, this.bytes);
}

class GroupSpreadsheetsDataSource {
  GroupSpreadsheetsDataSource(this._dio);
  final Dio _dio;

  static String _base(String groupId) => '/api/groups/$groupId/spreadsheets';

  Future<List<GroupSpreadsheet>> list(String groupId) async {
    final res = await _dio.get(_base(groupId));
    final body = res.data;
    final list = body is Map ? (body['data'] ?? body['Data']) : body;
    if (list is! List) return const [];
    return [for (final e in list.whereType<Map>()) GroupSpreadsheet.fromJson(e)];
  }

  Future<GroupSpreadsheet?> upload({
    required String groupId,
    required SpreadsheetKind kind,
    required PickedSpreadsheet file,
    String? note,
  }) async {
    final form = FormData.fromMap({
      'kind': kind.apiValue,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'file': MultipartFile.fromBytes(
        file.bytes,
        filename: file.name,
        contentType: SpreadsheetFileRules.contentTypeOf(file.name),
      ),
    });
    final res = await _dio.post(
      _base(groupId),
      data: form,
      // Planilha de até 10 MB em rede móvel: mais folga que o padrão.
      options: Options(sendTimeout: const Duration(minutes: 3)),
    );
    final body = res.data;
    final data = body is Map ? (body['data'] ?? body['Data']) : null;
    return data is Map ? GroupSpreadsheet.fromJson(data) : null;
  }

  Future<void> delete(String groupId, String id) => _dio.delete('${_base(groupId)}/$id');
}

final groupSpreadsheetsDsProvider = Provider<GroupSpreadsheetsDataSource>(
    (ref) => GroupSpreadsheetsDataSource(ref.watch(dioProvider)));

final groupSpreadsheetsProvider = FutureProvider.autoDispose
    .family<List<GroupSpreadsheet>, String>(
        (ref, groupId) => ref.watch(groupSpreadsheetsDsProvider).list(groupId));

/// Id da patota recém-criada na resposta do `POST /api/Groups`
/// (`{ success, data: "<guid>" }`); null se o formato não for esse.
String? createdGroupIdFrom(dynamic body) {
  final data = body is Map ? (body['data'] ?? body['Data']) : body;
  final id = data is Map ? (data['id'] ?? data['Id']) : data;
  final s = id?.toString().trim() ?? '';
  return RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(s) ? s : null;
}
