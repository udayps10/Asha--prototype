import 'package:flutter/material.dart';
// Test-only native platform stub; no real geocoding or location request.
// ignore: depend_on_referenced_packages
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as geo;
import 'package:flutter_test/flutter_test.dart';
import 'package:aasha/core/theme/app_theme.dart';
import 'package:aasha/features/auth/presentation/welcome_screen.dart';
import 'package:aasha/features/user/presentation/home_screen.dart';
import 'package:aasha/features/user/presentation/search_form_screen.dart';
import 'package:aasha/features/emergency/presentation/sos_screen.dart';

Widget app(Widget home) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: home,
  routes: {
    for (final route in [
      '/login_normal',
      '/login_official',
      '/register',
      '/profile',
      '/search_form',
      '/emergency_center',
      '/sos',
      '/safety_map',
      '/emergency_alerts',
    ])
      route: (_) => Scaffold(appBar: AppBar(), body: Text('Opened $route')),
  },
);

void main() {
  setUp(() => geo.GeocodingPlatformFactory.instance = _GeocodingFactory());
  for (final size in [const Size(360, 800), const Size(1280, 900)]) {
    testWidgets('Welcome navigation at $size', (tester) async {
      tester.view.reset();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final entry in [
        ('Login as Normal User', '/login_normal'),
        ('Login as Official', '/login_official'),
        ('Create Account', '/register'),
      ]) {
        await tester.pumpWidget(app(const WelcomeScreen()));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(entry.$1));
        await tester.tap(find.text(entry.$1));
        await tester.pumpAndSettle();
        expect(find.text('Opened ${entry.$2}'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }
  testWidgets('Home search, account and menu routes work', (tester) async {
    await tester.pumpWidget(app(const UserHomeScreen()));
    await tester.tap(find.text('Start Search  →'));
    await tester.pumpAndSettle();
    expect(find.text('Opened /search_form'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Your account'));
    await tester.pumpAndSettle();
    expect(find.text('Opened /profile'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    for (final entry in [
      ('Safety Map', '/safety_map'),
      ('Emergency Alerts', '/emergency_alerts'),
      ('Emergency Center', '/emergency_center'),
    ]) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text(entry.$1)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Opened ${entry.$2}'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('Search retains required-field validation without a request', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SearchFormScreen()));
    await tester.ensureVisible(find.text('Search verified records  →'));
    await tester.tap(find.text('Search verified records  →'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Age is required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('SOS fits small displays and does not send on entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const SosScreen()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SEND SOS'));
    expect(find.text('Need immediate help?'), findsOneWidget);
    expect(find.text('SOS SENT'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _GeocodingFactory extends geo.GeocodingPlatformFactory {
  @override
  geo.Geocoding createGeocoding(geo.GeocodingCreationParams params) =>
      _Geocoding(params);
}

class _Geocoding extends geo.Geocoding {
  _Geocoding(super.params) : super.implementation();
}
