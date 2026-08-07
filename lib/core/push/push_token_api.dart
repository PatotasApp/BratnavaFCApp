import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../api/api_constants.dart';
import '../api/interceptors/auth_interceptor.dart';

/// Responsável por registrar o token FCM no backend.
/// Recebe um [Dio] já configurado (com AuthInterceptor) de fora.
class PushTokenApi {
  PushTokenApi(this._dio);

  final Dio _dio;
  final _log = Logger();

  /// Envia o token ao endpoint POST /api/push/register-token.
  /// Retorna `true` em sucesso, `false` em falha (sem lançar exceção).
  Future<bool> registerToken({
    required String token,
    required String platform,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.pushRegisterToken,
        data: {
          'token': token,
          'platform': platform,
        },
        options: Options(extra: {AuthInterceptor.skipUnauthorizedKey: true}),
      );
      return response.statusCode != null && response.statusCode! < 300;
    } on DioException catch (e) {
      _log.w('[PushTokenApi] Falha ao registrar token: ${e.message}');
      return false;
    } catch (e) {
      _log.e('[PushTokenApi] Erro inesperado: $e');
      return false;
    }
  }
}
