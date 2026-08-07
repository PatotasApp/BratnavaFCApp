import 'package:dio/dio.dart';
import '../../domain/entities/transaction_entities.dart';

class TransactionsRemoteDataSource {
  final Dio _dio;
  const TransactionsRemoteDataSource(this._dio);

  static String _base(String gid) => '/api/groups/$gid/transactions';
  static String _byId(String gid, String id) =>
      '/api/groups/$gid/transactions/$id';
  static String _summary(String gid) => '/api/groups/$gid/transactions/summary';
  static String _pendingTotals(String gid) =>
      '/api/groups/$gid/transactions/pending-totals';
  static String _sync(String gid) => '/api/groups/$gid/transactions/sync';
  static String _clearAll(String gid) => '/api/groups/$gid/transactions/all';

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    dynamic d = data;
    if (d is Map && d.containsKey('data')) d = d['data'];
    if (d is! List) return [];
    return d.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map && data.containsKey('data')) return data['data'];
    return data;
  }

  Future<List<TransactionDto>> getByMonth(
      String groupId, int year, int month) async {
    final res = await _dio
        .get(_base(groupId), queryParameters: {'year': year, 'month': month});
    return _list(res.data, TransactionDto.fromJson);
  }

  Future<List<TransactionMonthSummaryDto>> getMonthlySummaries(
      String groupId) async {
    final res = await _dio.get(_summary(groupId));
    return _list(res.data, TransactionMonthSummaryDto.fromJson);
  }

  Future<PendingTotalsDto?> getPendingTotals(String groupId) async {
    try {
      final res = await _dio.get(_pendingTotals(groupId));
      final data = _unwrap(res.data);
      if (data is Map<String, dynamic>) return PendingTotalsDto.fromJson(data);
    } catch (_) {}
    return null;
  }

  Future<void> syncTransactions(String groupId) async {
    await _dio.post(_sync(groupId));
  }

  Future<void> clearAllTransactions(String groupId) async {
    await _dio.delete(_clearAll(groupId));
  }

  Future<void> createTransaction(
      String groupId, CreateTransactionDto dto) async {
    await _dio.post(_base(groupId), data: dto.toJson());
  }

  Future<void> deleteTransaction(String groupId, String transactionId) async {
    await _dio.delete(_byId(groupId, transactionId));
  }
}
