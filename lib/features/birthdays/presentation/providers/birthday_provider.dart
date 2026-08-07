import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/birthday_remote_datasource.dart';
import '../../domain/entities/birthday_status.dart';

final birthdayDsProvider = Provider<BirthdayRemoteDataSource>(
  (ref) => BirthdayRemoteDataSource(ref.watch(dioProvider)),
);

final birthdayStatusProvider =
    FutureProvider.autoDispose.family<List<BirthdayStatus>, String>(
  (ref, groupId) => ref.watch(birthdayDsProvider).fetchBirthdayStatus(groupId),
);
