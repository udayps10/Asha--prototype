import '../../../core/common_widgets/aasha_surface.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/utils/location_service.dart';
import '../data/emergency_repository.dart';
import '../data/models/user_sos.dart';
import '../data/spring_boot_emergency_repository.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key, this.repository});

  final EmergencyRepository? repository;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final _locationService = LocationService();
  late final EmergencyRepository _repository =
      widget.repository ?? SpringBootEmergencyRepository();
  LocationResult? _location;
  SosSubmissionResult? _submission;
  bool _loading = false;
  String? _error;

  Future<void> _prepareSos() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final permission = await _locationService.checkAndRequestPermission();
    if (permission != LocationPermissionStatus.granted) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Location permission or GPS is unavailable.';
        });
      }
      return;
    }
    final location = await _locationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    if (location == null) {
      setState(() {
        _loading = false;
        _error = 'Could not get your current location.';
      });
      return;
    }
    setState(() {
      _location = location;
      _loading = false;
    });
    if (mounted) _showConfirmation();
  }

  Future<void> _showConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send emergency SOS?'),
        content: Text(
          'Your location (${_location!.latitude.toStringAsFixed(6)}, ${_location!.longitude.toStringAsFixed(6)}) will be prepared for emergency responders. Accuracy: ${_location!.accuracy.toStringAsFixed(0)} m.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
            ),
            child: const Text('SEND SOS'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submitSos();
  }

  Future<void> _submitSos() async {
    final location = _location!;
    final appState = context.read<AppState>();
    final sos = UserSos(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: appState.uid,
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: location.accuracy,
      createdAt: DateTime.now(),
      status: UserSosStatus.pending,
    );
    setState(() => _loading = true);
    final submission = await _repository.submitSos(sos);
    if (!mounted) return;
    setState(() {
      _submission = submission;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final submission = _submission;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency SOS')),
      body: AashaSurface(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFFFD9DE), Color(0xFFFFF1F3)],
                  ),
                ),
                child: const CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.accentColor,
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                submission == null
                    ? 'Need immediate help?'
                    : submission.state == SosDeliveryState.submitted
                    ? 'SOS SENT'
                    : 'SOS REQUEST SAVED',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                submission?.message ??
                    'Your current location will be shared with emergency responders after you confirm.',
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 28),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    children: [
                      AashaBenefit(
                        Icons.location_on_outlined,
                        'Share your current location with responders.',
                      ),
                      AashaBenefit(
                        Icons.verified_user_outlined,
                        'Confirm before sending an emergency request.',
                      ),
                      AashaBenefit(
                        Icons.info_outline,
                        'Delivery status will appear here after submission.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                ),
                onPressed: _loading || submission != null ? null : _prepareSos,
                icon: const Icon(Icons.sos),
                label: Text(_loading ? 'PREPARING...' : 'SEND SOS'),
              ),
              const SizedBox(height: 12),
              const Text(
                'SOS is separate from government emergency alerts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
