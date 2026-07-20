import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/payment_entities.dart';

class PaymentsRemoteDataSource {
  final Dio _dio;
  const PaymentsRemoteDataSource(this._dio);

  // ── Helpers ───────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data')) return data['data'];
    if (data is Map && data.containsKey('Data')) return data['Data'];
    return data;
  }

  List<dynamic> _unwrapList(dynamic data) {
    final d = _unwrap(data);
    if (d is List) return d;
    return [];
  }

  Map<String, dynamic>? _unwrapMap(dynamic data) {
    final d = _unwrap(data);
    if (d is Map<String, dynamic>) return d;
    return null;
  }

  /// Extrai o campo "message" da resposta de forma segura.
  /// Suporta: Map { "message": "..." }, String direta, ou null.
  String? _message(dynamic data) {
    if (data is Map)    return data['message'] as String?;
    if (data is String) return data.isNotEmpty ? data : null;
    return null;
  }

  // ── Mensalidades (admin) ──────────────────────────────────────────────────

  Future<MonthlyGrid> getMonthlyGrid(String groupId, int year) async {
    final res = await _dio.get(ApiConstants.monthlyGrid(groupId, year));
    return MonthlyGrid.fromJson(_unwrapMap(res.data)!);
  }

  Future<String?> upsertMonthly(String groupId, Map<String, dynamic> dto) async {
    final res = await _dio.put(ApiConstants.upsertMonthly(groupId), data: dto);
    _throwIfError(res.data);
    return _message(res.data);
  }

  Future<Map<String, dynamic>?> getMonthlyProof(
      String groupId, String playerId, int year, int month) async {
    final res = await _dio.get(
        ApiConstants.monthlyProof(groupId, playerId, year, month));
    return _unwrapMap(res.data);
  }

  // ── Mensalidades (usuário) ────────────────────────────────────────────────

  Future<PlayerRow?> getMyMonthlyRow(String groupId, int year) async {
    final res = await _dio.get(ApiConstants.myMonthlyRow(groupId, year));
    final d = _unwrapMap(res.data);
    if (d == null) return null;
    return PlayerRow.fromJson(d);
  }

  // ── Cobranças extras (admin) ──────────────────────────────────────────────

  Future<List<ExtraCharge>> getExtraCharges(String groupId) async {
    final res = await _dio.get(ApiConstants.extraCharges(groupId));
    return _unwrapList(res.data)
        .map((e) => ExtraCharge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> createExtraCharge(
      String groupId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.extraCharges(groupId), data: dto);
    _throwIfError(res.data);
    return _message(res.data);
  }

  Future<String?> cancelExtraCharge(String groupId, String chargeId) async {
    final res =
        await _dio.delete(ApiConstants.extraChargeById(groupId, chargeId));
    _throwIfError(res.data);
    return _message(res.data);
  }

  Future<String?> bulkDiscountExtraCharge(
      String groupId, String chargeId, Map<String, dynamic> dto) async {
    final res = await _dio.post(
        ApiConstants.extraChargeBulkDiscount(groupId, chargeId), data: dto);
    _throwIfError(res.data);
    return _message(res.data);
  }

  Future<String?> upsertExtraChargePayment(
      String groupId, String chargeId, String playerId,
      Map<String, dynamic> dto) async {
    final res = await _dio.put(
        ApiConstants.extraChargePayment(groupId, chargeId, playerId),
        data: dto);
    _throwIfError(res.data);
    return _message(res.data);
  }

  Future<Map<String, dynamic>?> getExtraChargeProof(
      String groupId, String chargeId, String playerId) async {
    final res = await _dio.get(
        ApiConstants.extraChargeProof(groupId, chargeId, playerId));
    return _unwrapMap(res.data);
  }

  // ── Cobranças extras (usuário) ────────────────────────────────────────────

  Future<List<ExtraCharge>> getMyExtraCharges(String groupId) async {
    final res = await _dio.get(ApiConstants.myExtraCharges(groupId));
    return _unwrapList(res.data)
        .map((e) => ExtraCharge.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Resumo (dashboard) ────────────────────────────────────────────────────

  Future<PaymentSummary?> getMySummary(String groupId) async {
    final res = await _dio.get(ApiConstants.myPaymentSummary(groupId));
    final d = _unwrapMap(res.data);
    if (d == null) return null;
    return PaymentSummary.fromJson(d);
  }

  // ── Iniciar mês ───────────────────────────────────────────────────────────

  // Initiate monthly payment collection for a given month
  // POST /api/groups/{groupId}/payments/monthly/{year}/{month}/initiate
  Future<Map<String, dynamic>?> initiateMonth(String groupId, int year, int month) async {
    final res = await _dio.post(ApiConstants.initiateMonth(groupId, year, month));
    _throwIfError(res.data);
    return _unwrapMap(res.data);
  }

  // Check if month has been initiated
  // GET /api/groups/{groupId}/payments/monthly/{year}/{month}/is-initiated
  Future<bool> isMonthInitiated(String groupId, int year, int month) async {
    final res = await _dio.get(ApiConstants.isMonthInitiated(groupId, year, month));
    final d = _unwrapMap(res.data);
    return d?['isInitiated'] as bool? ?? false;
  }

  // Get pending payment items for current user
  // GET /api/groups/{groupId}/payments/my-pending-items
  Future<List<Map<String, dynamic>>> getMyPendingItems(String groupId) async {
    final res = await _dio.get(ApiConstants.myPendingItems(groupId));
    final d = _unwrap(res.data);
    return (d is List ? d : []).cast<Map<String, dynamic>>();
  }

  // Pay selected items (batch)
  // POST /api/groups/{groupId}/payments/pay-selected
  Future<void> paySelected(String groupId, Map<String, dynamic> dto) async {
    final res = await _dio.post(ApiConstants.paySelected(groupId), data: dto);
    _throwIfError(res.data);
  }

  Future<Map<String, dynamic>?> getExitPending(String groupId) async {
    final res = await _dio.get(ApiConstants.exitPending(groupId));
    return _unwrapMap(res.data);
  }

  Future<List<Map<String, dynamic>>> getExitDebtAlerts(String groupId) async {
    final res = await _dio.get(ApiConstants.exitDebtAlerts(groupId));
    final d = _unwrap(res.data);
    return (d is List ? d : []).cast<Map<String, dynamic>>();
  }

  Future<void> keepExitDebtAlert(String groupId, String notificationId) async {
    final res = await _dio.post(ApiConstants.keepExitDebtAlert(groupId, notificationId));
    _throwIfError(res.data);
  }

  Future<void> markExitDebtAlertAsPaid(String groupId, String notificationId) async {
    final res = await _dio.post(ApiConstants.markExitDebtAlertAsPaid(groupId, notificationId));
    _throwIfError(res.data);
  }

  // Get payment summary for a specific player (admin/financeiro)
  // GET /api/groups/{groupId}/payments/summary/{playerId}
  Future<PaymentSummary?> getPlayerSummary(String groupId, String playerId) async {
    final res = await _dio.get(ApiConstants.paymentSummaryByPlayer(groupId, playerId));
    final d = _unwrapMap(res.data);
    if (d == null) return null;
    return PaymentSummary.fromJson(d);
  }

  // ── Avaliação do jogador (estrelas) ──────────────────────────────────────

  /// Salva a avaliação (1–5 estrelas) de um jogador via PUT /api/Players/{id}.
  Future<void> updatePlayerRating(String playerId, int starRating) async {
    final res = await _dio.put(
      ApiConstants.playerOps(playerId),
      data: {'guestStarRating': starRating},
    );
    _throwIfError(res.data);
  }

  // ── Utilitário: converte arquivo para base64 ──────────────────────────────

  static Future<({String base64, String fileName, String mimeType})>
      fileToBase64(String path, String name) async {
    final bytes = await File(path).readAsBytes();
    final b64   = base64Encode(bytes);
    final mime  = _guessMime(name);
    return (base64: b64, fileName: name, mimeType: mime);
  }

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  static String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'pdf':  return 'application/pdf';
      default:     return 'image/jpeg';
    }
  }
}
