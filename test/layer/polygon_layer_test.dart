import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../test_utils/test_app.dart';

void main() {
  testWidgets('test polygon layer', (tester) async {
    final polygons = <Polygon>[
      for (int i = 0; i < 1; ++i)
        Polygon(
          color: Colors.purple,
          borderColor: Colors.purple,
          borderStrokeWidth: 4,
          label: '$i',
          points: const [
            LatLng(55.5, -0.09),
            LatLng(54.3498, -6.2603),
            LatLng(52.8566, 2.3522),
          ],
        ),
    ];

    await tester.pumpWidget(TestApp(polygons: polygons));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolygonLayer), findsOneWidget);

    // Assert that batching works and all polygons are drawn into the same
    // CustomPaint/Canvas.
    expect(
        find.descendant(
            of: find.byType(PolygonLayer), matching: find.byType(CustomPaint)),
        findsOneWidget);
  });

  test('polygon normal/rotation', () {
    const clockwise = [
      LatLng(30, 20),
      LatLng(30, 30),
      LatLng(20, 30),
      LatLng(20, 20),
    ];
    expect(Polygon.isClockwise(clockwise), isTrue);
    expect(Polygon.isClockwise(clockwise.reversed.toList()), isFalse);
  });

  group('semantics', () {
    const northWest = LatLng(45.5281, -122.6815);
    const southEast = LatLng(45.5181, -122.6715);

    Polygon square({
      String? semanticsIdentifier,
      String? semanticsValue,
      double latitudeShift = 0,
    }) {
      final north = northWest.latitude + latitudeShift;
      final south = southEast.latitude + latitudeShift;
      return Polygon(
        points: [
          LatLng(north, northWest.longitude),
          LatLng(north, southEast.longitude),
          LatLng(south, southEast.longitude),
          LatLng(south, northWest.longitude),
        ],
        color: Colors.purple,
        semanticsIdentifier: semanticsIdentifier,
        semanticsValue: semanticsValue,
      );
    }

    FinderBase<SemanticsNode> byIdentifier(String identifier) =>
        find.semantics.byPredicate((node) => node.identifier == identifier);

    FinderBase<SemanticsNode> anyIdentified() =>
        find.semantics.byPredicate((node) => node.identifier.isNotEmpty);

    SemanticsNode layerNode(WidgetTester tester) => tester.getSemantics(
          find.descendant(
            of: find.byType(PolygonLayer),
            matching: find.byType(CustomPaint),
          ),
        );

    testWidgets('an identified polygon has one node over its box',
        (tester) async {
      final controller = MapController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        TestApp(
          controller: controller,
          polygons: [
            square(semanticsIdentifier: 'shape.a', semanticsValue: 'v'),
          ],
        ),
      );

      final node = byIdentifier('shape.a').evaluate().single;
      expect(
        node,
        matchesSemantics(
          identifier: 'shape.a',
          value: 'v',
          textDirection: TextDirection.ltr,
        ),
      );
      expect(
        node.rect,
        rectMoreOrLessEquals(
          Rect.fromPoints(
            controller.camera.latLngToScreenOffset(northWest),
            controller.camera.latLngToScreenOffset(southEast),
          ),
        ),
      );
    });

    testWidgets('an unidentified polygon adds no node', (tester) async {
      await tester.pumpWidget(
        TestApp(
          polygons: [
            square(semanticsIdentifier: 'shape.a'),
            square(latitudeShift: -0.004),
          ],
        ),
      );

      expect(anyIdentified(), findsOne);
      expect(layerNode(tester).childrenCount, 1);
    });

    testWidgets('an off-screen polygon has no node', (tester) async {
      await tester.pumpWidget(
        TestApp(
          polygons: [
            square(semanticsIdentifier: 'shape.a', latitudeShift: 1),
          ],
        ),
      );

      expect(byIdentifier('shape.a'), findsNothing);
    });

    testWidgets('a polygon larger than the map is clipped to it',
        (tester) async {
      await tester.pumpWidget(
        TestApp(
          polygons: [
            Polygon(
              points: const [
                LatLng(46, -123),
                LatLng(46, -122),
                LatLng(45, -122),
                LatLng(45, -123),
              ],
              color: Colors.purple,
              semanticsIdentifier: 'shape.a',
            ),
          ],
        ),
      );

      expect(
        byIdentifier('shape.a').evaluate().single.rect,
        Offset.zero & tester.getSize(find.byType(FlutterMap)),
      );
    });

    testWidgets('a layer without identifiers adds no node', (tester) async {
      await tester.pumpWidget(TestApp(polygons: [square()]));

      expect(anyIdentified(), findsNothing);
    });

    testWidgets('nodes follow identifiers across rebuilds', (tester) async {
      await tester.pumpWidget(TestApp(polygons: [square()]));
      expect(anyIdentified(), findsNothing);

      await tester.pumpWidget(
        TestApp(polygons: [square(semanticsIdentifier: 'shape.a')]),
      );
      expect(byIdentifier('shape.a'), findsOne);

      await tester.pumpWidget(TestApp(polygons: [square()]));
      expect(anyIdentified(), findsNothing);
    });

    test('semantics take part in equality but not in batching', () {
      expect(
        square(semanticsIdentifier: 'shape.a', semanticsValue: 'v'),
        square(semanticsIdentifier: 'shape.a', semanticsValue: 'v'),
      );
      expect(square(semanticsIdentifier: 'shape.a'), isNot(square()));
      expect(square(semanticsValue: 'v'), isNot(square()));
      expect(
        square(semanticsIdentifier: 'shape.a').renderHashCode,
        square().renderHashCode,
      );
    });
  });
}
