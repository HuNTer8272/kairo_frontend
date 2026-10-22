import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_tablet_ui/screens/navigation_screen.dart';
import 'package:vehicle_tablet_ui/services/navigation/geocoding_service.dart';
import 'package:vehicle_tablet_ui/services/navigation/navigation_launcher.dart';
import 'package:vehicle_tablet_ui/services/navigation/recent_destinations_service.dart';
import 'package:vehicle_tablet_ui/services/navigation/saved_places_service.dart';
import 'package:vehicle_tablet_ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SavedPlacesService places;
  late RecentDestinationsService recents;
  late _FakeLauncher launcher;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    places = SavedPlacesService();
    recents = RecentDestinationsService();
    launcher = _FakeLauncher();
  });

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await places.load();
    await recents.load();
    await tester.pumpWidget(MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: NavigationScreen(
        places: places,
        recents: recents,
        launcher: launcher,
        geocoder: const _NoopGeocodingService(),
        onClose: () {},
      ),
    ));
    await tester.pump();
  }

  for (final dark in [false, true]) {
    testWidgets('renders with no saved places (${dark ? 'dark' : 'light'})',
        (tester) async {
      await pump(tester, dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Add a place'), findsOneWidget);
      expect(find.text('Tap to set'), findsNWidgets(2));
    });
  }

  testWidgets('tapping an unset place opens the edit dialog and saves it',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Label field first, address field second.
    await tester.enterText(find.byType(TextField).last, '1 Main Street');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(places.addressFor('home'), '1 Main Street');
    expect(find.text('1 Main Street'), findsOneWidget);
    expect(launcher.calls, isEmpty);
  });

  testWidgets('renaming Home updates its saved label', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Casa');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(places.byId('home')!.label, 'Casa');
    expect(find.text('Casa'), findsOneWidget);
  });

  testWidgets('tapping a place with a saved address launches navigation',
      (tester) async {
    await places.load();
    await places.setAddress('work', '200 Market Street');
    await pump(tester);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(launcher.calls, ['200 Market Street']);
    expect(recents.recents, ['200 Market Street']);
  });

  testWidgets('adding a place creates a new entry with a settable address',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Add a place'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Gym');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // The address editor for the new place opens automatically.
    await tester.enterText(find.byType(TextField).last, '5 Fitness Lane');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(places.places.any((p) => p.label == 'Gym'), isTrue);
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('5 Fitness Lane'), findsOneWidget);
  });

  testWidgets('deleting a custom place removes it', (tester) async {
    await places.addPlace('Gym');
    await pump(tester);
    expect(find.text('Gym'), findsOneWidget);

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Gym'), findsNothing);
    expect(places.places.any((p) => p.label == 'Gym'), isFalse);
  });

  testWidgets('search panel launches navigation and records a recent',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Golden Gate Bridge');
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, 'Golden Gate Bridge'));
    await tester.pumpAndSettle();

    expect(launcher.calls, ['Golden Gate Bridge']);
    expect(find.text('Golden Gate Bridge'), findsOneWidget);
  });
}

class _FakeLauncher extends NavigationLauncher {
  final calls = <String>[];

  @override
  Future<bool> launch(String destination) async {
    calls.add(destination);
    return true;
  }
}

/// A geocoder that never hits the network, so widget tests stay fast and
/// deterministic — used implicitly wherever the default const
/// [GeocodingService] would otherwise attempt a real HTTP call.
class _NoopGeocodingService extends GeocodingService {
  const _NoopGeocodingService();

  @override
  Future<List<PlaceSuggestion>> suggest(String query) async => const [];
}
