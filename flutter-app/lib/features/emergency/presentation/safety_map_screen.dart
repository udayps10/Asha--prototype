import '../../../core/common_widgets/aasha_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/location_service.dart';
import '../../../data/models/camp.dart';
import '../../../data/repositories/camp_repository.dart';
import '../data/emergency_repository.dart';
import '../data/models/disaster_zone.dart';
import '../data/spring_boot_emergency_repository.dart';
import '../domain/nearest_camp.dart';
import '../domain/safety_calculator.dart';
import '../domain/safety_zone.dart';

class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key, this.repository, this.initialDisaster});

  final EmergencyRepository? repository;
  final DisasterZone? initialDisaster;

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  final _mapController = MapController();
  late final LocationService _locationService = LocationService();
  final _campRepository = CampRepository();
  late final EmergencyRepository _emergencyRepository =
      widget.repository ?? SpringBootEmergencyRepository();

  LocationResult? _location;
  List<DisasterZone> _disasters = [];
  List<Camp> _camps = [];
  bool _loading = true;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _loadSafetyData();
  }

  Future<void> _loadSafetyData() async {
    setState(() => _loading = true);
    final cachedCamps = context.read<AppState>().syncService.camps;
    List<DisasterZone> zones;
    try {
      zones = (await _emergencyRepository.getActiveDisasterZones())
          .where(_isValidZone)
          .toList();
    } catch (_) {
      zones = [];
    }
    List<Camp> camps;
    try {
      final remoteCamps = await _campRepository.getActiveCamps();
      camps = remoteCamps.isNotEmpty
          ? remoteCamps
          : await cachedCamps.getActive();
    } catch (_) {
      camps = await cachedCamps.getActive();
    }

    final permission = await _locationService.checkAndRequestPermission();
    LocationResult? location;
    if (permission == LocationPermissionStatus.granted) {
      location = await _locationService.getCurrentLocation();
    }
    if (!mounted) return;
    setState(() {
      _location = location;
      _disasters = [
        if (widget.initialDisaster != null &&
            _isValidZone(widget.initialDisaster!))
          widget.initialDisaster!,
        ...zones.where((zone) => zone.id != widget.initialDisaster?.id),
      ];
      _camps = camps;
      _loading = false;
      _locationMessage = location == null ? _locationError(permission) : null;
    });
  }

  String _locationError(LocationPermissionStatus status) {
    return switch (status) {
      LocationPermissionStatus.denied => 'Location permission was denied.',
      LocationPermissionStatus.deniedForever =>
        'Location permission is disabled in app settings.',
      LocationPermissionStatus.serviceDisabled => 'Location services are off.',
      _ => 'Your current location is unavailable.',
    };
  }

  bool _isValidZone(DisasterZone zone) {
    return zone.active &&
        zone.radiusKm.isFinite &&
        zone.radiusKm > 0 &&
        zone.latitude.isFinite &&
        zone.latitude >= -90 &&
        zone.latitude <= 90 &&
        zone.longitude.isFinite &&
        zone.longitude >= -180 &&
        zone.longitude <= 180;
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;
    final disasterResult = location == null
        ? null
        : _nearestDisasterResult(location);
    final nearestCamp = location == null
        ? null
        : findNearestCamp(
            userLatitude: location.latitude,
            userLongitude: location.longitude,
            camps: _camps,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Safety Map')),
      body: AashaSurface(
        maxWidth: 1000,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSafetyData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _statusCard(disasterResult, nearestCamp),
                    const SizedBox(height: 16),
                    if (location != null) ...[
                      _map(location),
                      const SizedBox(height: 10),
                      _legend(),
                    ],
                    if (_locationMessage != null) _locationUnavailable(),
                    if (location != null && _disasters.isEmpty)
                      _infoCard(
                        Icons.check_circle_outline,
                        'No active disaster information',
                        'No verified active disaster information is available right now.',
                      ),
                    if (nearestCamp != null) ...[
                      const SizedBox(height: 16),
                      _campCard(nearestCamp, location!),
                    ],
                    if (location != null && nearestCamp == null) ...[
                      const SizedBox(height: 16),
                      _infoCard(
                        Icons.home_work_outlined,
                        'No verified safe locations nearby',
                        'Active camps with geographic coordinates will appear here when available.',
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/emergency_alerts'),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('View emergency alerts'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  SafetyResult? _nearestDisasterResult(LocationResult location) {
    SafetyResult? nearest;
    for (final disaster in _disasters) {
      final result = SafetyCalculator.classify(
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        disasterLatitude: disaster.latitude,
        disasterLongitude: disaster.longitude,
        radiusKm: disaster.radiusKm,
      );
      if (nearest == null ||
          result.distanceFromDisasterKm! < nearest.distanceFromDisasterKm!) {
        nearest = result;
      }
    }
    return nearest;
  }

  Widget _statusCard(SafetyResult? result, Camp? camp) {
    final zone = result?.zone ?? SafetyZone.unknown;
    final color = _zoneColor(zone);
    final label = switch (zone) {
      SafetyZone.red => 'DANGER',
      SafetyZone.yellow => 'CAUTION',
      SafetyZone.green => 'RELATIVELY SAFE',
      SafetyZone.safe => 'SAFE',
      SafetyZone.unknown => 'LOCATION UNKNOWN',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR SAFETY STATUS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.shield_outlined, color: color, size: 30),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text('Nearest affected area: ${_nearestDisasterName()}'),
              Text(
                'Affected radius: ${result.radiusKm!.toStringAsFixed(1)} km',
              ),
            ],
            if (result?.distanceFromDisasterKm != null) ...[
              const SizedBox(height: 8),
              Text(
                'You are ${result!.distanceFromDisasterKm!.toStringAsFixed(1)} km from the affected area.',
              ),
            ],
            if (camp != null) ...[
              const SizedBox(height: 6),
              Text('Nearest verified safe location: ${camp.name}'),
            ],
          ],
        ),
      ),
    );
  }

  String _nearestDisasterName() {
    if (_disasters.isEmpty) return 'Unavailable';
    var nearest = _disasters.first;
    var distance = SafetyCalculator.distanceKmBetween(
      _location!.latitude,
      _location!.longitude,
      nearest.latitude,
      nearest.longitude,
    );
    for (final disaster in _disasters.skip(1)) {
      final candidate = SafetyCalculator.distanceKmBetween(
        _location!.latitude,
        _location!.longitude,
        disaster.latitude,
        disaster.longitude,
      );
      if (candidate < distance) {
        nearest = disaster;
        distance = candidate;
      }
    }
    return nearest.title.isEmpty ? nearest.disasterType : nearest.title;
  }

  Widget _map(LocationResult location) {
    final userPoint = LatLng(location.latitude, location.longitude);
    final markers = [
      Marker(
        point: userPoint,
        width: 84,
        height: 52,
        child: _marker(Icons.person_pin_circle, 'YOU', AppTheme.primaryColor),
      ),
    ];
    final circles = <CircleMarker>[];
    for (final disaster in _disasters) {
      final point = LatLng(disaster.latitude, disaster.longitude);
      markers.add(
        Marker(
          point: point,
          width: 110,
          height: 52,
          child: _marker(
            Icons.warning_amber_rounded,
            'DISASTER',
            AppTheme.accentColor,
          ),
        ),
      );
      circles.addAll([
        CircleMarker(
          point: point,
          radius: disaster.radiusKm * 1000,
          useRadiusInMeter: true,
          color: Colors.green.withAlpha(35),
          borderColor: Colors.green,
          borderStrokeWidth: 1,
        ),
        CircleMarker(
          point: point,
          radius: disaster.radiusKm * .7 * 1000,
          useRadiusInMeter: true,
          color: Colors.amber.withAlpha(35),
          borderColor: Colors.amber.shade800,
          borderStrokeWidth: 1,
        ),
        CircleMarker(
          point: point,
          radius: disaster.radiusKm * .3 * 1000,
          useRadiusInMeter: true,
          color: Colors.red.withAlpha(45),
          borderColor: Colors.red,
          borderStrokeWidth: 1,
        ),
      ]);
    }
    for (final camp in _camps.where(
      (camp) => camp.latitude != null && camp.longitude != null && camp.active,
    )) {
      markers.add(
        Marker(
          point: LatLng(camp.latitude!, camp.longitude!),
          width: 90,
          height: 48,
          child: _marker(Icons.home_work_outlined, 'CAMP', Colors.teal),
        ),
      );
    }
    return SizedBox(
      height: 360,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: userPoint, initialZoom: 11),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.aasha.disasterconnect',
                ),
                CircleLayer(circles: circles),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'recenter-map',
                tooltip: 'Center on my location',
                onPressed: _recenter,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: const [
          _LegendItem(color: Colors.red, label: 'RED = Danger'),
          _LegendItem(color: Colors.amber, label: 'YELLOW = Caution'),
          _LegendItem(color: Colors.green, label: 'GREEN = Safer area'),
          _LegendItem(color: Colors.teal, label: 'SAFE = Outside radius'),
        ],
      ),
    ),
  );

  void _recenter() {
    final location = _location;
    if (location == null) return;
    _mapController.move(LatLng(location.latitude, location.longitude), 11);
  }

  Widget _marker(IconData icon, String label, Color color) => Column(
    children: [
      Icon(icon, color: color, size: 30),
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    ],
  );

  Widget _locationUnavailable() => _infoCard(
    Icons.location_off_outlined,
    'Location unavailable',
    '$_locationMessage GPS is needed to calculate your safety status.',
  );

  Widget _infoCard(IconData icon, String title, String message) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message),
    ),
  );

  Widget _campCard(Camp camp, LocationResult location) {
    final distance = SafetyCalculator.distanceKmBetween(
      location.latitude,
      location.longitude,
      camp.latitude!,
      camp.longitude!,
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.home_work_outlined, color: Colors.teal),
        title: Text(camp.name),
        subtitle: Text(
          '${distance.toStringAsFixed(1)} km away\n${camp.address}',
        ),
      ),
    );
  }

  Color _zoneColor(SafetyZone zone) => switch (zone) {
    SafetyZone.red => Colors.red.shade700,
    SafetyZone.yellow => Colors.amber.shade800,
    SafetyZone.green => Colors.green.shade700,
    SafetyZone.safe => Colors.teal,
    SafetyZone.unknown => AppTheme.secondaryColor,
  };
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
