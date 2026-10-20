import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  Future<Completer<XFile?>> openPicker(
    WidgetTester tester, {
    required bool allowNoImage,
    required Future<XFile?> Function(
      ImageSource source, {
      required int imageQuality,
      required double maxWidth,
      required double maxHeight,
    }) requestImage,
    required void Function(Object error) onError,
  }) async {
    final result = Completer<XFile?>();
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          key: const ValueKey('open-picker'),
          onPressed: () async => result.complete(await app.pickExpenseDocumentImage(
            context: context,
            allowNoImage: allowNoImage,
            requestImage: requestImage,
            onError: onError,
          )),
          child: const Text('Open'),
        ),
      )),
    ));
    await tester.tap(find.byKey(const ValueKey('open-picker')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('gallery keeps the current quality and size limits', (tester) async {
    ImageSource? source;
    int? quality;
    double? width, height;
    final result = await openPicker(tester, allowNoImage: false, requestImage: (picked, {
      required imageQuality, required maxWidth, required maxHeight,
    }) async {
      source = picked; quality = imageQuality; width = maxWidth; height = maxHeight;
      return XFile('receipt.jpg');
    }, onError: fail);
    expect(find.text('Fără fotografie'), findsNothing);
    await tester.tap(find.text('Alege din galerie'));
    await tester.pumpAndSettle();
    expect(await result.future, isA<XFile>());
    expect(source, ImageSource.gallery);
    expect(quality, 92);
    expect(width, 2400);
    expect(height, 2400);
  });

  testWidgets('camera and optional no-image choice keep their meanings', (tester) async {
    ImageSource? source;
    var calls = 0;
    final result = await openPicker(tester, allowNoImage: true, requestImage: (picked, {
      required imageQuality, required maxWidth, required maxHeight,
    }) async { source = picked; calls++; return XFile('camera.jpg'); }, onError: fail);
    expect(find.text('Fără fotografie'), findsOneWidget);
    await tester.tap(find.text('Fotografiază acum'));
    await tester.pumpAndSettle();
    expect(await result.future, isA<XFile>());
    expect(source, ImageSource.camera);
    expect(calls, 1);
  });

  testWidgets('no-image choice returns null without platform I/O', (tester) async {
    var calls = 0;
    final result = await openPicker(tester, allowNoImage: true, requestImage: (source, {
      required imageQuality, required maxWidth, required maxHeight,
    }) async { calls++; return null; }, onError: fail);
    await tester.tap(find.text('Fără fotografie'));
    await tester.pumpAndSettle();
    expect(await result.future, isNull);
    expect(calls, 0);
  });

  testWidgets('picker errors are returned as null and reported', (tester) async {
    Object? reported;
    final result = await openPicker(tester, allowNoImage: false, requestImage: (source, {
      required imageQuality, required maxWidth, required maxHeight,
    }) async => throw StateError('platform failure'), onError: (error) => reported = error);
    await tester.tap(find.text('Fotografiază acum'));
    await tester.pumpAndSettle();
    expect(await result.future, isNull);
    expect(reported, isA<StateError>());
    expect(reported.toString(), contains('platform failure'));
  });

  testWidgets('dismissing chooser does not start platform I/O', (tester) async {
    var calls = 0;
    final result = await openPicker(tester, allowNoImage: false, requestImage: (source, {
      required imageQuality, required maxWidth, required maxHeight,
    }) async { calls++; return null; }, onError: fail);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await result.future, isNull);
    expect(calls, 0);
  });
}
