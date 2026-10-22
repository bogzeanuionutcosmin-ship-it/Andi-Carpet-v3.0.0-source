import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:andi_carpeta/main.dart' as app;

void main() {
  for (final manual in [true, false]) {
    for (final boundary in ['picker', 'ocr']) {
      testWidgets('${manual ? 'manual' : 'scan'} ignores $boundary result after ExpensePage disposal', (tester) async {
        tester.view.physicalSize = const Size(1440, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = app.AppSettings();
        settings.learning['ocr']!.mode = app.LearningMode.automatic;
        final picker = Completer<XFile?>();
        final recognition = Completer<String>();
        final enteredRecognition = Completer<void>();
        var recognized = 0, saved = 0, logged = 0;
        final image = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'receipt.png');
        final user = app.AppUser(id: 'editor', name: 'Editor', role: app.UserRole.member);
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: app.ExpensePage(
          currentUser: user, users: [user],
          teams: [app.Team(id: 'team', name: 'Team', members: ['editor'])],
          expenses: [], perDiems: [], finances: [],
          settlements: [app.TravelSettlement(id: 'settlement', teamId: 'team',
            name: 'Trip', startDate: DateTime(2026, 10, 21), managerId: 'editor')],
          settings: settings, canEditTeam: (_) => true, isAdmin: true,
          canEditOwnDecont: true, canViewOtherDecont: false,
          onChanged: () {}, notifyUser: (_, _, _) {}, log: (_, _) { logged++; },
          saveExpense: (_) async { saved++; }, savePerDiem: (_) async {},
          saveFinance: (_) async {}, saveSettlement: (_) async {},
          pickDocumentImage: ({bool allowNoImage = false}) async =>
            boundary == 'picker' ? await picker.future : image,
          recognizeExpenseText: (_, {path}) {
            recognized++; enteredRecognition.complete(); return recognition.future;
          },
        ))));
        await tester.pumpAndSettle();
        final action = find.text(manual ? 'Introducere manuală' : 'Scanează bon / factură');
        await tester.ensureVisible(action);
        await tester.tap(action);
        for (var turn = 0; turn < 10; turn++) {
          await tester.pump(const Duration(milliseconds: 10));
          if (boundary == 'picker' || enteredRecognition.isCompleted) break;
        }
        if (boundary == 'ocr') expect(enteredRecognition.isCompleted, isTrue);
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Other session'))));
        if (boundary == 'picker') {
          picker.complete(image);
        } else {
          recognition.complete('BON FISCAL TOTAL 12,34');
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Other session'), findsOneWidget);
        expect(recognized, boundary == 'picker' ? 0 : 1);
        expect(saved, 0);
        expect(logged, 0);
      });
    }
  }
}
