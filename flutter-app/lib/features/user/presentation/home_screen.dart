import 'package:flutter/material.dart';
import '../../../core/common_widgets/aasha_surface.dart';
import '../../../core/common_widgets/app_button.dart';
import '../../../core/theme/app_theme.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Aasha'),
      actions: [
        IconButton(
          tooltip: 'Your account',
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
        ),
      ],
    ),
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(padding: EdgeInsets.all(24), child: AashaBrand()),
            for (final item in [
              (Icons.search, 'Find Your Loved One', '/search_form'),
              (Icons.shield_outlined, 'Emergency Center', '/emergency_center'),
              (Icons.map_outlined, 'Safety Map', '/safety_map'),
              (
                Icons.notifications_outlined,
                'Emergency Alerts',
                '/emergency_alerts',
              ),
              (Icons.person_outline, 'Your Account', '/profile'),
            ])
              ListTile(
                leading: Icon(item.$1),
                title: Text(item.$2),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, item.$3);
                },
              ),
          ],
        ),
      ),
    ),
    body: AashaSurface(
      maxWidth: 1040,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PEOPLE BELONG TOGETHER',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                color: AppTheme.secondaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Find Your Loved One',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'A little information can bring you closer.',
              style: TextStyle(fontSize: 17, color: AppTheme.muted),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, box) {
                final search = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 46,
                          backgroundColor: Color(0xFFE6F4FC),
                          child: Icon(
                            Icons.person_search_outlined,
                            size: 54,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Provide the details you know. Our system will compare them with verified records from disaster-response officials.',
                          textAlign: TextAlign.center,
                          style: TextStyle(height: 1.6),
                        ),
                        const SizedBox(height: 22),
                        AppButton(
                          text: 'Start Search  →',
                          onPressed: () =>
                              Navigator.pushNamed(context, '/search_form'),
                        ),
                      ],
                    ),
                  ),
                );
                final emergency = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 44,
                          color: AppTheme.secondaryColor,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Here when you need help.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Safety status, verified alerts and nearby safe locations.',
                          textAlign: TextAlign.center,
                          style: TextStyle(height: 1.6, color: AppTheme.muted),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/emergency_center'),
                          icon: const Icon(Icons.shield_outlined),
                          label: const Text('Emergency Center'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accentColor,
                          ),
                          onPressed: () => Navigator.pushNamed(context, '/sos'),
                          icon: const Icon(Icons.sos),
                          label: const Text('Emergency SOS'),
                        ),
                      ],
                    ),
                  ),
                );
                return box.maxWidth > 720
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: search),
                          const SizedBox(width: 20),
                          Expanded(child: emergency),
                        ],
                      )
                    : Column(
                        children: [
                          search,
                          const SizedBox(height: 12),
                          emergency,
                        ],
                      );
              },
            ),
            const SizedBox(height: 28),
            const Text(
              'How it works',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const AashaBenefit(
              Icons.edit_outlined,
              'Share the details you know.',
            ),
            const AashaBenefit(
              Icons.manage_search,
              'Compare with verified response records.',
            ),
            const AashaBenefit(
              Icons.contact_phone_outlined,
              'Contact officials to confirm a possible match.',
            ),
          ],
        ),
      ),
    ),
  );
}
