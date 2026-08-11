import 'package:dio/dio.dart';
import '../../domain/entities/conquista_models.dart';

class ConquistasRemoteDataSource {
  final Dio _dio;
  const ConquistasRemoteDataSource(this._dio);

  Future<GroupConquistas> fetchGroup(String groupId) async {
    final response = await _dio.get('/api/Conquistas/group/$groupId');
    return GroupConquistas.fromJson(_unwrap(response.data));
  }

  Future<UserPublicProfile> fetchProfile(String userId) async {
    final response = await _dio.get('/api/Profile/user/$userId');
    return UserPublicProfile.fromJson(_unwrap(response.data));
  }

  Future<ProfilePrivacy> fetchPrivacy() async {
    final response = await _dio.get('/api/Profile/me/privacy');
    return ProfilePrivacy.fromJson(_unwrap(response.data));
  }

  Future<ProfilePrivacy> updatePrivacy(ProfilePrivacy privacy) async {
    final response = await _dio.put(
      '/api/Profile/me/privacy',
      data: privacy.toJson(),
    );
    return ProfilePrivacy.fromJson(_unwrap(response.data));
  }

  Map<String, dynamic> _unwrap(dynamic body) {
    if (body is Map) {
      final map = body.cast<String, dynamic>();
      final data = map['data'];
      if (data is Map) return data.cast<String, dynamic>();
      return map;
    }
    throw const FormatException('Resposta inesperada da API');
  }
}
