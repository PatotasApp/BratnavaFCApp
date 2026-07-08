import 'package:dio/dio.dart';
import '../../../../core/api/api_constants.dart';
import '../../domain/entities/poll_detail.dart';
import '../../domain/entities/poll_summary.dart';

class PollsRemoteDataSource {
  final Dio _dio;
  const PollsRemoteDataSource(this._dio);

  // ── List ──────────────────────────────────────────────────────────────────

  Future<List<PollSummary>> getPolls(String groupId) async {
    final all = <String, PollSummary>{};
    for (final type in ['event', 'poll']) {
      for (final status in ['open', 'closed']) {
        final section = await getPollsPage(
          groupId,
          page: 1,
          pageSize: 5,
          type: type,
          status: status,
        );
        for (final poll in section.items) {
          all[poll.id] = poll;
        }
      }
    }

    if (all.isEmpty) {
      final res = await _dio.get(
        ApiConstants.polls(groupId),
        queryParameters: const {'page': 1, 'pageSize': 200},
      );
      for (final poll in _parsePollList(res.data)) {
        all[poll.id] = poll;
      }
    }

    return all.values.toList();
  }

  Future<PagedPolls> getPollsPage(
    String groupId, {
    required int page,
    required int pageSize,
    required String type,
    required String status,
  }) async {
    final res = await _dio.get(
      ApiConstants.polls(groupId),
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'type': type,
        'status': status,
      },
    );
    final items = _parsePollList(res.data);
    return PagedPolls(
      items: items,
      total: _extractTotal(res.data) ?? items.length,
      page: _extractPage(res.data) ?? page,
      pageSize: _extractPageSize(res.data) ?? pageSize,
    );
  }

  List<PollSummary> _parsePollList(dynamic data) => _unwrapList(data)
      .whereType<Map<String, dynamic>>()
      .map(PollSummary.fromJson)
      .toList();

  // ── Detail ────────────────────────────────────────────────────────────────

  Future<PollDetail> getPoll(String groupId, String pollId) async {
    final res = await _dio.get(ApiConstants.pollById(groupId, pollId));
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<PollDetail> createPoll(
      String groupId, Map<String, dynamic> dto) async {
    final res = await _dio.post(ApiConstants.polls(groupId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> createEventPoll(
      String groupId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.createEventPoll(groupId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> closePoll(
      String groupId, String pollId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.closePoll(groupId, pollId), data: dto);
    _throwIfError(res.data);
  }

  Future<void> reopenPoll(String groupId, String pollId) async {
    final res = await _dio.put(ApiConstants.reopenPoll(groupId, pollId));
    _throwIfError(res.data);
  }

  Future<void> deletePoll(String groupId, String pollId) async {
    final res = await _dio.delete(ApiConstants.deletePoll(groupId, pollId));
    _throwIfError(res.data);
  }

  // ── Options ───────────────────────────────────────────────────────────────

  Future<PollDetail> addOption(
      String groupId, String pollId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.pollOptions(groupId, pollId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> updateOption(String groupId, String pollId, String optId,
      Map<String, dynamic> dto) async {
    final res = await _dio
        .put(ApiConstants.pollOptionById(groupId, pollId, optId), data: dto);
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> deleteOption(
      String groupId, String pollId, String optId) async {
    final res =
        await _dio.delete(ApiConstants.pollOptionById(groupId, pollId, optId));
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Deadline ──────────────────────────────────────────────────────────────

  Future<void> updateDeadline(
    String groupId,
    String pollId, {
    String? deadlineDate,
    String? deadlineTime,
    bool clearDeadline = false,
  }) async {
    final res = await _dio.patch(
      ApiConstants.pollDeadline(groupId, pollId),
      data: {
        'deadlineDate': deadlineDate,
        'deadlineTime': deadlineTime,
        'clearDeadline': clearDeadline,
      },
    );
    _throwIfError(res.data);
  }

  Future<PollDetail> updatePollDetails(
    String groupId,
    String pollId,
    Map<String, dynamic> dto,
  ) async {
    final res = await _dio.patch(
      '/api/Polls/group/$groupId/$pollId/details',
      data: dto,
    );
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Show-votes toggle ─────────────────────────────────────────────────────

  Future<void> toggleShowVotes(String groupId, String pollId, bool show) async {
    final res = await _dio.patch(ApiConstants.pollShowVotes(groupId, pollId),
        data: {'showVotes': show});
    _throwIfError(res.data);
  }

  // ── Voting ────────────────────────────────────────────────────────────────

  Future<PollDetail> castVote(
      String groupId, String pollId, List<String> optionIds) async {
    final res = await _dio.post(
      ApiConstants.castVote(groupId, pollId),
      data: {'optionIds': optionIds},
    );
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> removeVote(String groupId, String pollId) async {
    final res = await _dio.delete(ApiConstants.castVote(groupId, pollId));
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  Future<PollDetail> adminCastVote(String groupId, String pollId,
      String playerId, List<String> optionIds) async {
    final res = await _dio.post(
      ApiConstants.adminVote(groupId, pollId),
      data: {'playerId': playerId, 'optionIds': optionIds},
    );
    return PollDetail.fromJson(_unwrapMap(res.data)!);
  }

  // ── Guests ────────────────────────────────────────────────────────────────

  Future<PollGuest> addGuest(
      String groupId, String pollId, Map<String, dynamic> dto) async {
    final res =
        await _dio.post(ApiConstants.pollGuests(groupId, pollId), data: dto);
    return PollGuest.fromJson(
        _unwrapMap(res.data) ?? dto.map((k, v) => MapEntry(k, v)));
  }

  Future<void> removeGuest(
      String groupId, String pollId, String guestId) async {
    final res =
        await _dio.delete(ApiConstants.pollGuestById(groupId, pollId, guestId));
    _throwIfError(res.data);
  }

  Future<void> setAllowGuests(
      String groupId, String pollId, bool allowGuests) async {
    final res = await _dio.patch(
      '/api/Polls/group/$groupId/$pollId/allow-guests',
      data: {'allowGuests': allowGuests},
    );
    _throwIfError(res.data);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _throwIfError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] as String?;
      if (msg != null && msg.isNotEmpty) throw Exception(msg);
    }
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final d = data['data'] ?? data['Data'];
      if (d is List) return d;
      if (d is Map) {
        final items = d['items'] ?? d['Items'];
        if (items is List) return items;
      }
      final items = data['items'] ?? data['Items'];
      if (items is List) return items;
    }
    return [];
  }

  int? _extractTotal(dynamic data) {
    if (data is! Map) return null;
    final node = data['data'] ?? data['Data'] ?? data;
    if (node is! Map) return null;
    final total = node['total'] ??
        node['Total'] ??
        node['totalCount'] ??
        node['TotalCount'];
    return (total as num?)?.toInt();
  }

  int? _extractPage(dynamic data) {
    if (data is! Map) return null;
    final node = data['data'] ?? data['Data'] ?? data;
    if (node is! Map) return null;
    final value = node['page'] ?? node['Page'];
    return (value as num?)?.toInt();
  }

  int? _extractPageSize(dynamic data) {
    if (data is! Map) return null;
    final node = data['data'] ?? data['Data'] ?? data;
    if (node is! Map) return null;
    final value = node['pageSize'] ?? node['PageSize'];
    return (value as num?)?.toInt();
  }

  Map<String, dynamic>? _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final d = data['data'] ?? data['Data'];
      if (d is Map<String, dynamic>) return d;
      return data;
    }
    return null;
  }
}

class PagedPolls {
  final List<PollSummary> items;
  final int total;
  final int page;
  final int pageSize;

  const PagedPolls({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
}
