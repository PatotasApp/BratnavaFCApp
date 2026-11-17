import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/core_providers.dart';

enum NewGroupTourStage { settings, uniforms, firstMatch }

class PendingNewGroupTour {
  final String creatorUserId;
  final String groupId;
  final NewGroupTourStage stage;
  final int settingsTab;

  const PendingNewGroupTour({
    required this.creatorUserId,
    required this.groupId,
    required this.stage,
    this.settingsTab = 0,
  });

  String get location => switch (stage) {
        NewGroupTourStage.settings =>
          '/app/settings?tour=true&tab=${settingsTab.clamp(0, 4)}',
        NewGroupTourStage.uniforms => '/app/team-colors?tour=true',
        NewGroupTourStage.firstMatch => '/app/matches?tour=true',
      };

  String get path => switch (stage) {
        NewGroupTourStage.settings => '/app/settings',
        NewGroupTourStage.uniforms => '/app/team-colors',
        NewGroupTourStage.firstMatch => '/app/matches',
      };

  Map<String, dynamic> toJson() => {
        'creatorUserId': creatorUserId,
        'groupId': groupId,
        'stage': stage.name,
        'settingsTab': settingsTab.clamp(0, 4),
      };

  static PendingNewGroupTour? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final creatorUserId = value['creatorUserId']?.toString() ?? '';
    final groupId = value['groupId']?.toString() ?? '';
    final stageName = value['stage']?.toString();
    final stage = NewGroupTourStage.values
        .where((candidate) => candidate.name == stageName)
        .firstOrNull;
    if (creatorUserId.isEmpty || groupId.isEmpty || stage == null) return null;

    return PendingNewGroupTour(
      creatorUserId: creatorUserId,
      groupId: groupId,
      stage: stage,
      settingsTab: ((value['settingsTab'] as num?)?.toInt() ?? 0).clamp(0, 4),
    );
  }
}

class NewGroupTourStorage {
  static const _storageKey = 'pending_new_group_tour_v1';

  final SharedPreferences _preferences;

  const NewGroupTourStorage(this._preferences);

  PendingNewGroupTour? read() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PendingNewGroupTour.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  PendingNewGroupTour? readFor({
    required String? userId,
    required String? groupId,
  }) {
    final pending = read();
    if (pending == null || userId == null || groupId == null) return null;
    if (pending.creatorUserId.toLowerCase() != userId.toLowerCase() ||
        pending.groupId.toLowerCase() != groupId.toLowerCase()) {
      return null;
    }
    return pending;
  }

  PendingNewGroupTour? readForCreator(String? userId) {
    final pending = read();
    if (pending == null || userId == null) return null;
    return pending.creatorUserId.toLowerCase() == userId.toLowerCase()
        ? pending
        : null;
  }

  Future<void> start({
    required String creatorUserId,
    required String groupId,
  }) =>
      _write(PendingNewGroupTour(
        creatorUserId: creatorUserId,
        groupId: groupId,
        stage: NewGroupTourStage.settings,
      ));

  Future<void> updateSettingsTab(int tab) async {
    final pending = read();
    if (pending == null) return;
    await _write(PendingNewGroupTour(
      creatorUserId: pending.creatorUserId,
      groupId: pending.groupId,
      stage: NewGroupTourStage.settings,
      settingsTab: tab.clamp(0, 4),
    ));
  }

  Future<void> moveTo(NewGroupTourStage stage) async {
    final pending = read();
    if (pending == null) return;
    await _write(PendingNewGroupTour(
      creatorUserId: pending.creatorUserId,
      groupId: pending.groupId,
      stage: stage,
      settingsTab: pending.settingsTab,
    ));
  }

  Future<void> clear() => _preferences.remove(_storageKey);

  Future<void> _write(PendingNewGroupTour pending) =>
      _preferences.setString(_storageKey, jsonEncode(pending.toJson()));
}

final newGroupTourStorageProvider = Provider<NewGroupTourStorage>(
  (ref) => NewGroupTourStorage(ref.watch(sharedPreferencesProvider)),
);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
