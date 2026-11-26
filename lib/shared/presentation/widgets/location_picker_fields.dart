import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/location/app_location_service.dart';

typedef LocationChanged = void Function(
  double? latitude,
  double? longitude,
);

/// Campo único de local usado nas configurações e nos formulários de partida.
/// Mantém a busca, o GPS e a seleção das sugestões com o mesmo comportamento.
class LocationPickerFields extends StatefulWidget {
  const LocationPickerFields({
    super.key,
    required this.nameController,
    required this.addressController,
    required this.onLocationChanged,
    this.city,
    this.initialLatitude,
    this.initialLongitude,
    this.nameRequired = false,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final LocationChanged onLocationChanged;
  final String? city;
  final double? initialLatitude;
  final double? initialLongitude;
  final bool nameRequired;

  @override
  State<LocationPickerFields> createState() => _LocationPickerFieldsState();
}

class _LocationPickerFieldsState extends State<LocationPickerFields> {
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<AppLocationResult> _suggestions = const [];
  String? _message;
  bool _searching = false;
  bool _locating = false;
  bool _settingAddress = false;
  int _generation = 0;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
  }

  @override
  void didUpdateWidget(covariant LocationPickerFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLatitude != widget.initialLatitude ||
        oldWidget.initialLongitude != widget.initialLongitude) {
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _queryChanged(String value) {
    if (!_settingAddress) {
      _latitude = null;
      _longitude = null;
      widget.onLocationChanged(null, null);
    }
    _debounce?.cancel();
    setState(() {
      _suggestions = const [];
      _message = null;
    });
    final query = value.trim();
    if (query.length < 3) {
      setState(() => _searching = false);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _search(query),
    );
  }

  Future<void> _search([String? requestedQuery]) async {
    final query = (requestedQuery ?? widget.addressController.text).trim();
    if (query.length < 3) return;
    final generation = ++_generation;
    setState(() => _searching = true);
    try {
      final results = await AppLocationService.search(
        query,
        city: widget.city,
        nearLatitude: _latitude ?? widget.initialLatitude,
        nearLongitude: _longitude ?? widget.initialLongitude,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _suggestions = results;
        _message = results.isEmpty
            ? 'Nenhum local encontrado. Tente incluir a cidade.'
            : null;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _suggestions = const [];
        _message = 'Não foi possível buscar agora.';
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  void _select(AppLocationResult result) {
    _settingAddress = true;
    widget.addressController.text = result.address;
    _settingAddress = false;
    final resultName = (result.name ?? '').trim();
    if (resultName.isNotEmpty) {
      widget.nameController.text = resultName;
    } else if (widget.nameController.text.trim().isEmpty) {
      widget.nameController.text = result.address.split(',').first.trim();
    }
    _latitude = result.latitude;
    _longitude = result.longitude;
    widget.onLocationChanged(_latitude, _longitude);
    setState(() {
      _suggestions = const [];
      _message = null;
    });
    _focusNode.unfocus();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final result = await AppLocationService.current();
      if (mounted) _select(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.nameController,
          decoration: InputDecoration(
            labelText:
                widget.nameRequired ? 'Nome do local *' : 'Nome do local',
            hintText: 'Ex: Arena Municipal',
            prefixIcon: const Icon(Icons.stadium_outlined),
            helperText: 'É o nome que ficará registrado na partida.',
            border: const OutlineInputBorder(),
          ),
          validator: widget.nameRequired
              ? (value) => (value?.trim().isEmpty ?? true)
                  ? 'Informe o nome do local'
                  : null
              : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.addressController,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onChanged: _queryChanged,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Endereço',
            hintText: 'Digite um lugar ou endereço',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Usar minha localização',
              onPressed: _locating ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        if (_suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final option = _suggestions[index];
                final name = (option.name ?? '').trim();
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    name.isEmpty ? option.address.split(',').first : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    option.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _select(option),
                );
              },
            ),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _message!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else if (_latitude != null && _longitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Localização selecionada',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
