import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../test_utils/test_app.dart';

void main() {
  testWidgets('test polyline layer', (tester) async {
    final polylines = <Polyline>[
      for (int i = 0; i < 10; i++)
        Polyline(
          points: [
            LatLng(50.5 + i, -0.09),
            LatLng(51.3498 + i, -6.2603),
            LatLng(53.8566 + i, 2.3522),
          ],
          strokeWidth: 4,
          color: Colors.amber,
        ),
    ];

    await tester.pumpWidget(TestApp(polylines: polylines));
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsWidgets);

    // Assert that batching works and all Polylines are drawn into the same
    // CustomPaint/Canvas.
    expect(
        find.descendant(
            of: find.byType(PolylineLayer), matching: find.byType(CustomPaint)),
        findsOneWidget);
  });

  group('effects', () {
    const lineColor = Color(0xFF2196F3);
    const glowColor = Color(0xFFFF9800);
    const shadowColor = Color(0x80000000);

    RenderObject paintedLayer(WidgetTester tester) => tester.renderObject(
          find.descendant(
            of: find.byType(PolylineLayer),
            matching: find.byType(CustomPaint),
          ),
        );

    Polyline line({ShapeGlow? glow, ShapeShadow? shadow}) => Polyline(
          points: const [
            LatLng(45.5231, -122.6865),
            LatLng(45.5231, -122.6665)
          ],
          strokeWidth: 4,
          color: lineColor,
          glow: glow,
          shadow: shadow,
        );

    testWidgets('paints shadow, then glow, then the line', (tester) async {
      await tester.pumpWidget(
        TestApp(
          polylines: [
            line(
              glow: const ShapeGlow(color: glowColor),
              shadow: const ShapeShadow(color: shadowColor),
            ),
          ],
        ),
      );

      expect(
        paintedLayer(tester),
        paints
          ..save()
          ..translate(x: 0, y: 2)
          ..path(color: shadowColor, strokeWidth: 4)
          ..restore()
          ..path(color: glowColor, strokeWidth: 4)
          ..path(color: lineColor, strokeWidth: 4),
      );
    });

    testWidgets('paints only the line without effects', (tester) async {
      await tester.pumpWidget(TestApp(polylines: [line()]));

      expect(paintedLayer(tester), paintsExactlyCountTimes(#drawPath, 1));
    });

    test('effects take part in equality and batching', () {
      const glow = ShapeGlow(color: glowColor);

      expect(line(glow: glow), line(glow: glow));
      expect(line(glow: glow), isNot(line()));
      expect(line(glow: glow).renderHashCode, isNot(line().renderHashCode));
    });
  });

  group('semantics', () {
    const start = LatLng(45.5231, -122.6865);
    const end = LatLng(45.5281, -122.6665);
    const strokeWidth = 4.0;
    const borderStrokeWidth = 2.0;

    Polyline line({
      List<LatLng> points = const [start, end],
      String? semanticsIdentifier,
      String? semanticsValue,
    }) =>
        Polyline(
          points: points,
          strokeWidth: strokeWidth,
          borderStrokeWidth: borderStrokeWidth,
          color: Colors.amber,
          semanticsIdentifier: semanticsIdentifier,
          semanticsValue: semanticsValue,
        );

    FinderBase<SemanticsNode> byIdentifier(String identifier) =>
        find.semantics.byPredicate((node) => node.identifier == identifier);

    FinderBase<SemanticsNode> anyIdentified() =>
        find.semantics.byPredicate((node) => node.identifier.isNotEmpty);

    SemanticsNode layerNode(WidgetTester tester) => tester.getSemantics(
          find.descendant(
            of: find.byType(PolylineLayer),
            matching: find.byType(CustomPaint),
          ),
        );

    testWidgets('an identified polyline has one node over its stroke',
        (tester) async {
      final controller = MapController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        TestApp(
          controller: controller,
          polylines: [
            line(semanticsIdentifier: 'shape.a', semanticsValue: 'v')
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
            controller.camera.latLngToScreenOffset(start),
            controller.camera.latLngToScreenOffset(end),
          ).inflate(strokeWidth / 2 + borderStrokeWidth / 2),
        ),
      );
    });

    testWidgets('an unidentified polyline adds no node', (tester) async {
      await tester.pumpWidget(
        TestApp(
          polylines: [
            line(semanticsIdentifier: 'shape.a'),
            line(points: const [start, LatLng(45.5181, -122.6665)]),
          ],
        ),
      );

      expect(anyIdentified(), findsOne);
      expect(layerNode(tester).childrenCount, 1);
    });

    testWidgets('an off-screen polyline has no node', (tester) async {
      await tester.pumpWidget(
        TestApp(
          polylines: [
            line(
              points: const [LatLng(55.5, -0.09), LatLng(54.3498, -6.2603)],
              semanticsIdentifier: 'shape.a',
            ),
          ],
        ),
      );

      expect(byIdentifier('shape.a'), findsNothing);
    });

    testWidgets('a horizontal polyline has a node as tall as its stroke',
        (tester) async {
      await tester.pumpWidget(
        TestApp(
          polylines: [
            line(
              points: const [start, LatLng(45.5231, -122.6665)],
              semanticsIdentifier: 'shape.a',
            ),
          ],
        ),
      );

      expect(
        byIdentifier('shape.a').evaluate().single.rect.height,
        moreOrLessEquals(strokeWidth + borderStrokeWidth),
      );
    });

    testWidgets('a layer without identifiers adds no node', (tester) async {
      await tester.pumpWidget(TestApp(polylines: [line()]));

      expect(anyIdentified(), findsNothing);
    });

    test('semantics take part in equality but not in batching', () {
      expect(
        line(semanticsIdentifier: 'shape.a', semanticsValue: 'v'),
        line(semanticsIdentifier: 'shape.a', semanticsValue: 'v'),
      );
      expect(line(semanticsIdentifier: 'shape.a'), isNot(line()));
      expect(line(semanticsValue: 'v'), isNot(line()));
      expect(
        line(semanticsIdentifier: 'shape.a').renderHashCode,
        line().renderHashCode,
      );
    });
  });
}
