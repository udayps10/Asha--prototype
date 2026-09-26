import 'package:flutter/material.dart';
import '../../../core/common_widgets/aasha_surface.dart';
import '../../../core/common_widgets/app_button.dart';
import '../../../core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: AashaSurface(
      maxWidth: 1140,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: 42),
                child: AashaBrand(),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final intro = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PEOPLE BELONG TOGETHER',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        letterSpacing: 1.6,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Reunite families\nafter disasters.',
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 760 ? 54 : 40,
                        height: 1.08,
                        letterSpacing: -1.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Hope begins with knowing where to look.',
                      style: TextStyle(
                        fontSize: 21,
                        color: AppTheme.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Aasha connects missing and found persons through records from disaster-response officials, shelters and relief teams.',
                      style: TextStyle(height: 1.6, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    const AashaBenefit(
                      Icons.manage_search_outlined,
                      'Search response records with the details you know.',
                    ),
                    const AashaBenefit(
                      Icons.shield_outlined,
                      'Connect with officials to confirm possible matches.',
                    ),
                    const AashaBenefit(
                      Icons.favorite_border,
                      'Helping families find their way back together.',
                    ),
                  ],
                );
                final entry = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AashaMapHeader(),
                        const SizedBox(height: 20),
                        const Text(
                          'Find your way back.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sign in to search for a loved one or access emergency information.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.muted, height: 1.5),
                        ),
                        const SizedBox(height: 26),
                        AppButton(
                          text: 'Login as Normal User',
                          onPressed: () =>
                              Navigator.pushNamed(context, '/login_normal'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/login_official'),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Login as Official'),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/register'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Account'),
                        ),
                      ],
                    ),
                  ),
                );
                return constraints.maxWidth > 760
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: intro),
                          const SizedBox(width: 64),
                          Expanded(child: entry),
                        ],
                      )
                    : Column(
                        children: [intro, const SizedBox(height: 28), entry],
                      );
              },
            ),
            const SizedBox(height: 36),
            const Divider(),
            const Text(
              'AASHA  /  Every connection brings hope.',
              style: TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
