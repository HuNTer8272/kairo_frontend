import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_tablet_ui/models/apollo_state.dart';
import 'package:vehicle_tablet_ui/services/apollo/apollo_service.dart';
import 'package:vehicle_tablet_ui/theme/app_theme.dart';
import 'package:vehicle_tablet_ui/widgets/apollo/apollo_navigation_view.dart';
import 'package:vehicle_tablet_ui/widgets/apollo/autopilot_card.dart';
import 'package:vehicle_tablet_ui/widgets/apollo/autopilot_settings.dart';
import 'package:vehicle_tablet_ui/widgets/apollo/body_controls.dart';
import 'package:vehicle_tablet_ui/widgets/apollo/vehicle_controls_settings.dart';
import 'package:vehicle_tablet_ui/widgets/top_bar.dart';

/// Fixtures are real payloads captured from kairo_gateway while Apollo
/// (Carla Town05, Sim Control) was driving a route.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> sent;
  late ApolloService apollo;
  late ApolloState driving;
  late HdMap hdMap;

  /// When set, POST /api/body answers 409 with this message.
  String? refuseBody;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    refuseBody = null;
    driving = ApolloState.fromJson(_fixture('apollo_state_driving.json'));
    hdMap = HdMap.fromJson(_fixture('apollo_map.json'));
    final client = MockClient((request) async {
      sent.add(request);
      if (request.url.path == '/api/snap') {
        // Every tap lands 1 m from a lane: snapped onto it.
        final x = double.parse(request.url.queryParameters['x']!);
        final y = double.parse(request.url.queryParameters['y']!);
        return http.Response(
          jsonEncode({
            'x': x,
            'y': y + 1,
            'heading': 0.0,
            'lane_id': 'test_lane',
            'distance': 1.0,
          }),
          200,
        );
      }
      if (request.url.path == '/api/route') {
        return http.Response(
          jsonEncode({
            'rev': 7,
            'route': [
              [1.0, 2.0],
              [3.0, 4.0],
            ],
          }),
          200,
        );
      }
      if (request.url.path == '/api/body' && refuseBody != null) {
        return http.Response(jsonEncode({'detail': refuseBody}), 409);
      }
      return http.Response(
        jsonEncode(
            {'ok': true, 'state': _fixture('apollo_state_driving.json')}),
        200,
      );
    });
    apollo = ApolloService(
      client: client,
      prefs: await SharedPreferences.getInstance(),
    );
    apollo.debugSetLive(driving, map: hdMap);
  });

  tearDown(() => apollo.dispose());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ));
    await tester.pump();
  }

  group('ApolloState', () {
    test('parses a live gateway payload', () {
      expect(driving.cyberConnected, isTrue);
      expect(driving.dreamviewConnected, isTrue);
      expect(driving.autopilot.phase, AutopilotPhase.driving);
      expect(driving.autopilot.engaged, isTrue);
      expect(driving.autopilot.destination?.label, 'Work');
      expect(driving.vehicle.gear, 'D');
      expect(driving.vehicle.speedKph, greaterThan(0));
      expect(driving.vehicle.pose, isNotNull);
      expect(driving.dreamview.map, 'Carla Town05');
      expect(driving.dreamview.simControl, isTrue);
      expect(driving.dreamview.modules['Planning'], isTrue);
      expect(driving.scene.route, isNotEmpty);
      expect(driving.scene.trajectory, isNotEmpty);
    });

    test('parses the HD map', () {
      expect(hdMap.name, 'carla_town05');
      expect(hdMap.lanes, isNotEmpty);
      expect(hdMap.lanes.every((l) => l.points.length >= 2), isTrue);
    });

    test('tolerates an empty payload', () {
      final empty = ApolloState.fromJson(const {});
      expect(empty.autopilot.phase, AutopilotPhase.offline);
      expect(empty.vehicle.pose, isNull);
      expect(empty.places, isEmpty);
    });
  });

  group('AutopilotCard', () {
    testWidgets('shows live speed and stops the car', (tester) async {
      await pump(
        tester,
        Center(
          child: AutopilotCard(
            apollo: apollo,
            onOpenNavigation: () {},
            onOpenSettings: () {},
          ),
        ),
      );

      expect(find.text('${driving.vehicle.speedKph.round()}'), findsOneWidget);
      expect(find.text('Autopilot engaged'), findsOneWidget);

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(sent.single.url.path, '/api/autopilot/stop');
    });
  });

  group('ApolloNavigationView', () {
    testWidgets('dropping a pin and tapping Go sends a route', (tester) async {
      await pump(
        tester,
        ApolloNavigationView(apollo: apollo, onShowStreetMap: () {}),
      );

      await tester.tapAt(const Offset(760, 300));
      await tester.pumpAndSettle(); // lane check
      expect(find.text('Dropped pin'), findsOneWidget);
      expect(find.textContaining('On lane'), findsOneWidget);

      await tester.tap(find.text('Go here'));
      await tester.pumpAndSettle();

      final request = sent.lastWhere((r) => r.method == 'POST');
      expect(request.url.path, '/api/autopilot/go');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['x'], isA<num>());
      expect(body['y'], isA<num>());
      expect(body['target_speed_kph'], apollo.cruiseKph);
      expect(find.text('Dropped pin'), findsNothing);
    });

    testWidgets('saving a pin as Home stores it on the gateway',
        (tester) async {
      await pump(
        tester,
        ApolloNavigationView(apollo: apollo, onShowStreetMap: () {}),
      );
      await tester.tapAt(const Offset(760, 300));
      await tester.pumpAndSettle(); // lane check
      await tester.tap(find.widgetWithText(TextButton, 'Home'));
      await tester.pumpAndSettle();

      final put = sent.lastWhere((r) => r.method == 'PUT');
      expect(put.url.path, '/api/places/home');
    });
  });

  group('AutopilotSettings', () {
    testWidgets('lists Apollo modules and toggles Sim Control', (tester) async {
      await pump(tester, AutopilotSettings(apollo: apollo));

      expect(find.text('Planning'), findsOneWidget);
      expect(find.text('Carla Town05'), findsOneWidget);

      await tester.ensureVisible(find.text('Sim Control'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sim Control'));
      await tester.pumpAndSettle();
      final request = sent.single;
      expect(request.url.path, '/api/dreamview/sim_control');
      expect(jsonDecode(request.body), {'enabled': false});
    });
  });

  group('Live stream', () {
    test('fetches the route once when its revision changes', () async {
      final json = _fixture('apollo_state_driving.json');
      final scene = json['scene'] as Map<String, dynamic>;
      scene.remove('route'); // the /ws stream sends only route_rev
      scene['route_rev'] = 7;
      apollo.debugSetLive(ApolloState.fromJson(json));
      apollo.debugReceive(jsonEncode(json));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sent.where((r) => r.url.path == '/api/route'), hasLength(1));
      expect(apollo.state!.scene.route, const [Offset(1, 2), Offset(3, 4)]);

      // Same revision again: reuses the cached points, no new request.
      apollo.debugReceive(jsonEncode(json));
      expect(sent.where((r) => r.url.path == '/api/route'), hasLength(1));
      expect(apollo.state!.scene.route, hasLength(2));
    });
  });

  group('Body controls', () {
    testWidgets('lock toggle updates at once and tells the gateway',
        (tester) async {
      await pump(tester, Center(child: LockToggle(apollo: apollo)));
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.lock_rounded));
      // Optimistic: applied before the gateway has answered.
      expect(apollo.state!.body.locked, isFalse);
      await tester.pumpAndSettle();

      expect(sent.single.url.path, '/api/body');
      expect(jsonDecode(sent.single.body), {'locked': false});
    });

    testWidgets('a refused change is rolled back and explained',
        (tester) async {
      refuseBody = "Can't open that while the car is moving";
      await pump(
        tester,
        Center(
          child: ClosureLabel(
            apollo: apollo,
            field: 'frunk_open',
            name: 'Frunk',
            alignRight: false,
          ),
        ),
      );
      await tester.tap(find.textContaining('Frunk'));
      await tester.pumpAndSettle();

      expect(apollo.state!.body.frunkOpen, isFalse);
      expect(
          find.text("Can't open that while the car is moving"), findsOneWidget);
    });

    testWidgets('Lights page sets the light mode and signals', (tester) async {
      await pump(
        tester,
        VehicleControlsSettings(apollo: apollo, category: 'Lights'),
      );
      await tester.tap(find.text('On'));
      await tester.pumpAndSettle();
      expect(jsonDecode(sent.last.body), {'lights': 'ON'});

      await tester.tap(find.text('Left Signal'));
      await tester.pumpAndSettle();
      expect(jsonDecode(sent.last.body), {'turn_signal': 'LEFT'});
    });
  });

  group('Driving', () {
    testWidgets('tapping a gear in the top bar shifts', (tester) async {
      await pump(
        tester,
        TopBar(
          compact: false,
          onProfileTap: () {},
          isDarkMode: false,
          onThemeChanged: (_) {},
          apollo: apollo,
          onAutopilotTap: () {},
        ),
      );
      await tester.tap(find.text('P'));
      await tester.pumpAndSettle();

      expect(sent.single.url.path, '/api/drive/gear');
      expect(jsonDecode(sent.single.body), {'gear': 'P'});
    });

    testWidgets('Drive manually hands the car to the tablet', (tester) async {
      final json = _fixture('apollo_state_driving.json');
      json['autopilot'] = {
        ...json['autopilot'] as Map,
        'state': 'READY',
        'engaged': false,
        'destination': null
      };
      apollo.debugSetLive(ApolloState.fromJson(json));
      await pump(
        tester,
        ApolloNavigationView(apollo: apollo, onShowStreetMap: () {}),
      );
      await tester.tap(find.text('Drive manually'));
      await tester.pumpAndSettle();

      expect(sent.single.url.path, '/api/drive/manual');
      expect(jsonDecode(sent.single.body), {'enabled': true});
    });
  });

  group('Lane snapping', () {
    testWidgets('a pin off any road cannot be driven to', (tester) async {
      final offRoad = ApolloService(
        client: MockClient((request) async => request.url.path == '/api/snap'
            ? http.Response(
                jsonEncode({
                  'x': 0,
                  'y': 0,
                  'heading': 0,
                  'lane_id': 'far',
                  'distance': 20.0,
                }),
                200)
            : http.Response('{}', 200)),
        prefs: await SharedPreferences.getInstance(),
      )..debugSetLive(driving, map: hdMap);
      addTearDown(offRoad.dispose);
      await pump(
        tester,
        ApolloNavigationView(apollo: offRoad, onShowStreetMap: () {}),
      );
      await tester.tapAt(const Offset(760, 300));
      await tester.pumpAndSettle();

      expect(find.text('Not on a road — tap on a lane'), findsOneWidget);
      final go = tester.widget<FilledButton>(find.ancestor(
          of: find.text('Go here'),
          matching: find.byWidgetPredicate((w) => w is FilledButton)));
      expect(go.onPressed, isNull);
    });
  });
}
