import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import 'interceptors/auth_interceptor.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

Dio buildDio({required AuthInterceptor authInterceptor}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(_RetryOnTransientNetworkErrorInterceptor(dio));
  dio.interceptors.add(authInterceptor);

  // Em debug, ignora certificado autoassinado do servidor local.
  assert(() {
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (_, __, ___) => true;
      return client;
    };
    return true;
  }());

  // Log only in debug builds.
  assert(() {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: false,
        error: true,
        logPrint: (obj) => _log.d(obj),
      ),
    );
    return true;
  }());

  return dio;
}

class _RetryOnTransientNetworkErrorInterceptor extends Interceptor {
  final Dio _dio;

  const _RetryOnTransientNetworkErrorInterceptor(this._dio);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final retryCount = (options.extra['transientRetryCount'] as int?) ?? 0;

    if (retryCount >= 2 || !_canRetry(options.method) || !_isTransient(err)) {
      handler.next(err);
      return;
    }

    try {
      await Future<void>.delayed(
          Duration(milliseconds: 700 * (retryCount + 1)));
      final response = await _dio.fetch<dynamic>(
        options.copyWith(
          extra: {...options.extra, 'transientRetryCount': retryCount + 1},
        ),
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _canRetry(String method) {
    final normalized = method.toUpperCase();
    return normalized == 'GET' ||
        normalized == 'HEAD' ||
        normalized == 'OPTIONS';
  }

  bool _isTransient(DioException err) {
    final error = err.error;
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        error is HandshakeException ||
        error is SocketException;
  }
}
