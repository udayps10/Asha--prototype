import '../../../core/common_widgets/aasha_surface.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/location_service.dart';
import '../../../data/models/camp.dart';
import '../../../data/repositories/camp_repository.dart';
import '../../../data/sync/sync_service.dart';
import '../data/emergency_repository.dart';
import '../data/models/disaster_zone.dart';
import '../data/models/emergency_alert.dart';
import '../data/spring_boot_emergency_repository.dart';
import '../domain/nearest_camp.dart';
import '../domain/safety_calculator.dart';
import '../domain/safety_zone.dart';

class EmergencyCenterScreen extends StatefulWidget {
  const EmergencyCenterScreen({super.key, this.repository});

  final EmergencyRepository? repository;

  @override
  State<EmergencyCenterScreen> createState() => _EmergencyCenterScreenState();
}

class _EmergencyCenterScreenState extends State<EmergencyCenterScreen> {
  late final EmergencyRepository _repository =
      widget.repository ?? SpringBootEmergencyRepository();
  final _locationService = LocationService();
  final _campRepository = CampRepository();

  List<EmergencyAlert> _alerts = [];
  List<Camp> _camps = [];
  LocationResult? _location;
  String? _locationMessage;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    final alertsFuture = _loadAlerts();
    final campsFuture = _loadCamps();
    final locationFuture = _loadLocation();
    await Future.wait([alertsFuture, campsFuture, locationFuture]);

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadAlerts() async {
    try {
      _alerts = await _repository.getActiveAlerts();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Emergency information is temporarily unavailable.';
    }
  }

  Future<void> _loadCamps() async {
    final cached = context.read<AppState>().syncService.camps;
    try {
      final remote = await _campRepository.getActiveCamps();
      _camps = remote.isNotEmpty ? remote : await cached.getActive();
    } catch (_) {
      _camps = await cached.getActive();
    }
  }

  Future<void> _loadLocation() async {
    final permission = await _locationService.checkAndRequestPermission();
    if (permission != LocationPermissionStatus.granted) {
      _location = null;
      _locationMessage = _locationError(permission);
      return;
    }
    _location = await _locationService.getCurrentLocation();
    _locationMessage = _location == null
        ? 'Your current location is unavailable.'
        : null;
  }

  String _locationError(LocationPermissionStatus status) => switch (status) {
    LocationPermissionStatus.denied => 'Location permission was denied.',
    LocationPermissionStatus.deniedForever =>
      'Location permission is disabled in app settings.',
    LocationPermissionStatus.serviceDisabled => 'Location services are off.',
    _ => 'Your current location is unavailable.',
  };

  ({SafetyResult result, DisasterZone zone})? _nearestDisaster() {
    final location = _location;
    if (location == null) return null;

    ({SafetyResult result, DisasterZone zone})? nearest;
    for (final alert in _alerts) {
      if (alert.latitude == null ||
          alert.longitude == null ||
          alert.radiusKm == null ||
          alert.radiusKm! <= 0) {
        continue;
      }
      final zone = DisasterZone(
        id: alert.id,
        disasterType: alert.disasterType,
        latitude: alert.latitude!,
        longitude: alert.longitude!,
        radiusKm: alert.radiusKm!,
        severity: alert.severity,
        title: alert.title,
        active: alert.active,
      );
      final result = SafetyCalculator.classify(
        userLatitude: location.latitude,
        userLongitude: location.longitude,
        disasterLatitude: zone.latitude,
        disasterLongitude: zone.longitude,
        radiusKm: zone.radiusKm,
      );
      if (nearest == null ||
          result.distanceFromDisasterKm! <
              nearest.result.distanceFromDisasterKm!) {
        nearest = (result: result, zone: zone);
      }
    }
    return nearest;
  }

  Camp? _nearestCamp() {
    final location = _location;
    if (location == null) return null;
    return findNearestCamp(
      userLatitude: location.latitude,
      userLongitude: location.longitude,
      camps: _camps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<AppState>().syncService;
    final disaster = _nearestDisaster();
    final camp = _nearestCamp();

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Center')),
      body: AashaSurface(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _connectionBanner(sync),
                      _statusCard(disaster, camp),
                      if (_locationMessage != null) ...[
                        const SizedBox(height: 12),
                        _infoCard(
                          Icons.location_off_outlined,
                          'Location unavailable',
                          'Safety distance and geographic relevance cannot be calculated.',
                        ),
                      ],
                      if (_errorMessage != null &&
                          !_repository.lastFetchUsedCache) ...[
                        const SizedBox(height: 12),
                        _infoCard(
                          Icons.error_outline,
                          'Emergency information unavailable',
                          _errorMessage!,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _alertsSection(),
                      const SizedBox(height: 20),
                      _campSection(camp),
                      const SizedBox(height: 20),
                      _actionsSection(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _connectionBanner(SyncService sync) {
    final offline = sync.online == false;
    final cached = _repository.lastFetchUsedCache;
    if (!offline && !cached) {
      return const _StatusBanner(
        icon: Icons.cloud_done_outlined,
        text: 'Connected',
        color: Colors.green,
      );
    }
    return const _StatusBanner(
      icon: Icons.cloud_off_outlined,
      text: 'Offline • Showing cached emergency information',
      color: Colors.orange,
    );
  }

  Widget _statusCard(
    ({SafetyResult result, DisasterZone zone})? disaster,
    Camp? camp,
  ) {
    final result = disaster?.result;
    final zone = result?.zone ?? SafetyZone.unknown;
    final color = _zoneColor(zone);
    final label = _zoneLabel(zone);
    return Card(
      color: color.withAlpha(18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR SAFETY STATUS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .8),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.shield_outlined, color: color, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_statusDescription(zone)),
            if (_location == null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.my_location),
                label: const Text('Enable Location'),
              ),
            ],
            if (disaster != null) ...[
              const SizedBox(height: 14),
              Text(
                'Affected area: ${_disasterName(disaster.zone)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Distance from disaster: ${result!.distanceFromDisasterKm!.toStringAsFixed(1)} km',
              ),
              Text(
                'Affected radius: ${result.radiusKm!.toStringAsFixed(1)} km',
              ),
            ],
            if (camp != null) ...[
              const SizedBox(height: 10),
              Text('Nearest safe camp: ${camp.name}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Emergency Alerts',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_alerts.isEmpty)
          _infoCard(
            Icons.notifications_none,
            'No active emergency alerts',
            'Verified government warnings will appear here.',
          ),
        for (final alert in _alerts.take(3)) _alertCard(alert),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/emergency_alerts'),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('View all emergency alerts'),
        ),
      ],
    );
  }

  Widget _alertCard(EmergencyAlert alert) {
    final distance = _distance(alert);
    final relevant =
        distance != null &&
        alert.radiusKm != null &&
        distance <= alert.radiusKm!;
    final color = _severityColor(alert.severity);
    return Card(
      child: ListTile(
        leading: Icon(Icons.warning_amber_rounded, color: color),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${alert.severity.name.toUpperCase()} • ${alert.disasterType}\n${alert.message}${distance == null ? '' : '\n${distance.toStringAsFixed(1)} km away${relevant ? ' • Relevant to your location' : ''}'}',
        ),
        isThreeLine: true,
        onTap: () => Navigator.pushNamed(
          context,
          '/emergency_alert_detail',
          arguments: alert,
        ),
      ),
    );
  }

  Widget _campSection(Camp? camp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nearest Verified Safe Location',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (camp == null)
          _infoCard(
            Icons.home_work_outlined,
            'No safe camps are currently available nearby.',
            'Verified active camps with coordinates will appear here.',
          ),
        if (camp != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.home_work_outlined, color: Colors.teal),
              title: Text(camp.name),
              subtitle: Text(
                '${_campDistance(camp).toStringAsFixed(1)} km away\n${camp.address}',
              ),
              trailing: IconButton(
                tooltip: 'View on Safety Map',
                icon: const Icon(Icons.map_outlined),
                onPressed: () => Navigator.pushNamed(context, '/safety_map'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Emergency Actions',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/safety_map'),
        icon: const Icon(Icons.map_outlined),
        label: const Text('Open Safety Map'),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: AppTheme.accentColor),
        onPressed: () => Navigator.pushNamed(context, '/sos'),
        icon: const Icon(Icons.sos),
        label: const Text('SEND SOS'),
      ),
      const SizedBox(height: 10),
      const Text(
        'SOS sends an emergency request to responders. Government alerts are warnings about hazards.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.blueGrey, fontSize: 12),
      ),
    ],
  );

  Widget _infoCard(IconData icon, String title, String message) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppTheme.secondaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message),
    ),
  );

  double? _distance(EmergencyAlert alert) {
    final location = _location;
    if (location == null || alert.latitude == null || alert.longitude == null) {
      return null;
    }
    return SafetyCalculator.distanceKmBetween(
      location.latitude,
      location.longitude,
      alert.latitude!,
      alert.longitude!,
    );
  }

  double _campDistance(Camp camp) {
    final location = _location!;
    return SafetyCalculator.distanceKmBetween(
      location.latitude,
      location.longitude,
      camp.latitude!,
      camp.longitude!,
    );
  }

  String _disasterName(DisasterZone zone) =>
      zone.title.isEmpty ? zone.disasterType : zone.title;
  String _zoneLabel(SafetyZone zone) => switch (zone) {
    SafetyZone.red => 'DANGER',
    SafetyZone.yellow => 'CAUTION',
    SafetyZone.green => 'RELATIVELY SAFE',
    SafetyZone.safe => 'SAFE',
    SafetyZone.unknown => 'LOCATION UNKNOWN',
  };
  String _statusDescription(SafetyZone zone) => switch (zone) {
    SafetyZone.red => 'You are inside the high-risk zone.',
    SafetyZone.yellow => 'Use caution near the affected area.',
    SafetyZone.green => 'You are in a safer part of the affected area.',
    SafetyZone.safe => 'You are outside the affected radius.',
    SafetyZone.unknown =>
      'Allow location access to calculate your safety status.',
  };
  Color _zoneColor(SafetyZone zone) => switch (zone) {
    SafetyZone.red => Colors.red.shade700,
    SafetyZone.yellow => Colors.amber.shade800,
    SafetyZone.green => Colors.green.shade700,
    SafetyZone.safe => Colors.teal,
    SafetyZone.unknown => AppTheme.secondaryColor,
  };
  Color _severityColor(EmergencySeverity severity) => switch (severity) {
    EmergencySeverity.critical => Colors.red.shade900,
    EmergencySeverity.severe => Colors.red.shade700,
    EmergencySeverity.moderate => Colors.amber.shade800,
    EmergencySeverity.low => Colors.blueGrey,
  };
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.text,
    required this.color,
  });
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
