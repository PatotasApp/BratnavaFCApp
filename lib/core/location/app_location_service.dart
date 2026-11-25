import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class AppLocationResult {
  const AppLocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.name,
  });

  final String address;
  final double latitude;
  final double longitude;
  final String? name;
}

class AppLocationService {
  const AppLocationService._();
  static final Geocoding _geocoding = Geocoding();

  static Future<AppLocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Ative a localização do aparelho para continuar.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Permissão de localização não concedida.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
          'Permissão de localização bloqueada. Libere-a nas configurações do aparelho.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    final marks = await _geocoding.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final address = marks.isEmpty
        ? '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'
        : formatPlacemarkAddress(marks.first);
    return AppLocationResult(
      address: address,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  static Future<AppLocationResult?> fromAddress(
    String address, {
    String? city,
  }) async {
    final results = await search(address, city: city);
    if (results.isNotEmpty) return results.first;

    final query = address.trim();
    if (query.isEmpty) return null;
    final cityContext = city?.trim();
    final contextualQuery = cityContext?.isNotEmpty == true
        ? '$query, $cityContext, Brasil'
        : '$query, Brasil';

    final locations = await _geocoding.locationFromAddress(contextualQuery);
    if (locations.isEmpty) return null;
    return AppLocationResult(
      address: contextualQuery,
      latitude: locations.first.latitude,
      longitude: locations.first.longitude,
    );
  }

  /// Pesquisa lugares e endereços reais para o usuário escolher.
  ///
  /// Diferente de [fromAddress], este método não escolhe silenciosamente o
  /// primeiro resultado nem usa o geocodificador nativo como aproximação.
  /// Assim, um texto incompleto nunca é apresentado como localização já
  /// confirmada sem uma escolha explícita.
  static Future<List<AppLocationResult>> search(
    String text, {
    String? city,
  }) async {
    final query = text.trim();
    if (query.isEmpty) return const [];
    final cityContext = city?.trim();
    final contextualQuery = cityContext?.isNotEmpty == true
        ? '$query, $cityContext, Brasil'
        : '$query, Brasil';

    // Photon é voltado a autocomplete e tolera termos ainda incompletos. O
    // usuário continua responsável por escolher uma sugestão antes de o app
    // considerar a localização confirmada.
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://photon.komoot.io',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {
          'User-Agent': 'PatotasApp/1.0 (mobile location autocomplete)',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ));
      final response = await dio.get<Map<String, dynamic>>(
        '/api/',
        queryParameters: {
          'q': contextualQuery,
          'limit': 5,
        },
      );
      final features = response.data?['features'];
      if (features is List) {
        final locations = <AppLocationResult>[];
        final seen = <String>{};
        for (final rawFeature in features) {
          if (rawFeature is! Map) continue;
          final geometry = rawFeature['geometry'];
          final properties = rawFeature['properties'];
          if (geometry is! Map || properties is! Map) continue;
          final coordinates = geometry['coordinates'];
          if (coordinates is! List || coordinates.length < 2) continue;
          final longitude = (coordinates[0] as num?)?.toDouble();
          final latitude = (coordinates[1] as num?)?.toDouble();
          if (latitude == null || longitude == null) continue;
          final address = _formatPhotonAddress(properties);
          if (address.isEmpty) continue;
          final key =
              '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
          if (!seen.add(key)) continue;
          locations.add(AppLocationResult(
            name: properties['name']?.toString(),
            address: address,
            latitude: latitude,
            longitude: longitude,
          ));
        }
        if (locations.isNotEmpty) return locations;
      }
    } catch (error, stackTrace) {
      debugPrint('Photon autocomplete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // O Nominatim abaixo mantém a pesquisa disponível se o serviço de
      // autocomplete estiver temporariamente indisponível.
    }

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://nominatim.openstreetmap.org',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: const {
          'User-Agent': 'PatotasApp/1.0 (mobile location search)',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ));
      final response = await dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'format': 'jsonv2',
          'limit': 5,
          'countrycodes': 'br',
          'addressdetails': 1,
          'dedupe': 1,
          'q': contextualQuery,
        },
      );
      final results = response.data;
      if (results == null || results.isEmpty) return const [];

      final locations = <AppLocationResult>[];
      final seen = <String>{};
      for (final rawItem in results) {
        final item = rawItem as Map<String, dynamic>;
        final latitude = double.tryParse(item['lat']?.toString() ?? '');
        final longitude = double.tryParse(item['lon']?.toString() ?? '');
        final displayName = item['display_name']?.toString().trim() ?? '';
        if (latitude == null || longitude == null || displayName.isEmpty) {
          continue;
        }
        final key =
            '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
        if (!seen.add(key)) continue;
        locations.add(AppLocationResult(
          name: item['name']?.toString(),
          address: displayName,
          latitude: latitude,
          longitude: longitude,
        ));
      }
      return locations;
    } catch (error, stackTrace) {
      debugPrint('Nominatim location search failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  static Future<void> openMap({
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final query = latitude != null && longitude != null
        ? '$latitude,$longitude'
        : address?.trim();
    if (query == null || query.isEmpty) return;
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': query},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Não foi possível abrir o mapa.');
    }
  }

  @visibleForTesting
  static String formatPlacemarkAddress(Placemark p) {
    final street = p.street?.trim() ?? '';
    final locality = p.locality?.trim() ?? '';
    final postalCode = p.postalCode?.trim() ?? '';
    final normalizedStreet = street.toLowerCase();

    // Alguns geocodificadores Android devolvem em `street` o endereço inteiro
    // já formatado. Nesse caso, acrescentar os demais campos repetiria cidade,
    // estado e CEP (como acontece na localização padrão do emulador).
    final streetIsComplete = street.isNotEmpty &&
        locality.isNotEmpty &&
        postalCode.isNotEmpty &&
        normalizedStreet.contains(locality.toLowerCase()) &&
        normalizedStreet.contains(postalCode.toLowerCase());
    if (streetIsComplete) return street;

    final parts = <String>[];
    final normalizedParts = <String>{};
    for (final value in [
      p.street,
      p.subLocality,
      p.locality,
      p.administrativeArea,
      p.postalCode,
      p.country,
    ]) {
      final part = value?.trim() ?? '';
      if (part.isEmpty) continue;
      final normalized = part.toLowerCase();
      if (normalizedParts.add(normalized)) parts.add(part);
    }
    return parts.join(', ');
  }

  static String _formatPhotonAddress(Map<dynamic, dynamic> properties) {
    final street = properties['street']?.toString().trim();
    final houseNumber = properties['housenumber']?.toString().trim();
    final district =
        (properties['district'] ?? properties['locality'])?.toString().trim();
    final city = properties['city']?.toString().trim();
    final state = properties['state']?.toString().trim();
    final postcode = properties['postcode']?.toString().trim();
    final country = properties['country']?.toString().trim();
    final name = properties['name']?.toString().trim();

    final streetWithNumber = [
      if (street?.isNotEmpty == true) street!,
      if (houseNumber?.isNotEmpty == true) houseNumber!,
    ].join(', ');
    final parts = <String>[
      if (streetWithNumber.isNotEmpty) streetWithNumber,
      if (streetWithNumber.isEmpty && name?.isNotEmpty == true) name!,
      if (district?.isNotEmpty == true) district!,
      if (city?.isNotEmpty == true) city!,
      if (state?.isNotEmpty == true) state!,
      if (postcode?.isNotEmpty == true) postcode!,
      if (country?.isNotEmpty == true) country!,
    ];
    return parts.toSet().join(', ');
  }
}
