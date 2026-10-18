import 'dart:async';
import 'dart:typed_data';
import 'package:andi_carpeta/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

// Real ExpensePage, real parser, real form/object/save orchestration. Only
// image selection, recognition and the save boundary are synthetic.
class ExpenseDocumentFixture {
  final user = AppUser(id: 'worker', name: 'Synthetic Worker', role: UserRole.member);
  final expenses = <Expense>[];
  final attempts = <Expense>[];
  final logs = <String>[];
  final pickerRequests = <bool>[];
  int recognizes = 0;
  int changes = 0;
  bool imageCancelled = false;
  bool failRecognition = false;
  bool failSave = false;
  bool updateLocallyBeforeFailure = false;
  Uint8List? imageOverride;
  bool manager = true;
  Completer<void>? saveGate;
  String text;
  late StateSetter rebuild;
  late final Uint8List image = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
  ExpenseDocumentFixture(this.text);
  Future<XFile?> pick(bool allowNoImage) async {
    pickerRequests.add(allowNoImage);
    return imageCancelled ? null : XFile.fromData(imageOverride ?? image, name: 'synthetic.png');
  }
  Future<String> recognize(Uint8List bytes, {String? path}) async {
    recognizes++;
    expect(bytes, imageOverride ?? image); // No camera/MLKit/network boundary reached.
    if (failRecognition) throw StateError('synthetic OCR failure');
    return text;
  }
  Future<void> save(Expense expense) async {
    attempts.add(expense);
    await saveGate?.future;
    if (failSave) {
      if (updateLocallyBeforeFailure) { expenses.add(expense); rebuild(() {}); }
      throw StateError('synthetic save failure');
    }
    expenses.add(expense);
    rebuild(() {});
  }
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) {
        rebuild = setState;
        return ExpensePage(
          currentUser: user, teams: [Team(id: 'team', name: 'Synthetic Team', members: ['worker'], financialManagerId: manager ? 'worker' : 'other')],
          users: [user], expenses: expenses, perDiems: [],
          finances: [TeamFinance(teamId: 'team', managerId: manager ? 'worker' : 'other')],
          settlements: [TravelSettlement(id: 'settlement', teamId: 'team', name: 'Synthetic Trip', startDate: DateTime(2026, 10, 1), managerId: manager ? 'worker' : 'other')],
          settings: AppSettings(), canEditTeam: (_) => true,
          isAdmin: false, canEditOwnDecont: true, canViewOtherDecont: false,
          onChanged: () { changes++; }, notifyUser: (a, b, c) { fail('Unexpected notification'); },
          log: (a, b) => logs.add('$a:$b'), saveExpense: save,
          savePerDiem: (_) async { fail('Unexpected per-diem write'); },
          saveFinance: (_) async { fail('Unexpected finance write'); },
          saveSettlement: (_) async { fail('Unexpected settlement write'); },
          documentImagePicker: pick, documentTextRecognizer: recognize,
        );
      },
    ))));
    await tester.pumpAndSettle();
  }
  Future<void> scan(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Scanează bon / factură');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
  Finder field(String label) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);
  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), value);
  }
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, manager ? 'Confirmă' : 'Trimite spre confirmare'));
    await tester.pumpAndSettle();
  }
}
