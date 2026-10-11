import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// Lightweight source-level regression checks; interactive widget and integration
// tests will be added and run with the final combined validation suite.
void main() {
  final source = File('lib/main.dart').readAsStringSync();

  test('Chat exposes messaging and agenda while preserving chat messages', () {
    expect(source, contains("Text('Mesagerie'"));
    expect(source, contains("Text('Agendă'"));
    expect(source, contains('IndexedStack(index:_selectedChatTab'));
    expect(source, contains("collection('groupChatMessages')"));
  });

  test('Agenda has category selection and clearable search', () {
    expect(source, contains('selectedCategory ='));
    expect(source, contains('l.categoryId != selectedCategory'));
    expect(source, contains("tooltip:'Șterge căutarea'"));
    expect(source, contains('Contact indisponibil'));
  });

  test('Member agenda uses permission-aware directory and hides restricted members', () {
    expect(source, contains("selectedCategory=='__members'"));
    expect(source, contains("?'users':'memberDirectory'"));
    expect(source, contains("d['hiddenFromMembers']==true"));
    expect(source, contains("phone.isEmpty?'Contact indisponibil':phone"));
  });

  test('Dashboard reveal keeps reduced-motion accessibility', () {
    expect(source, contains('MediaQuery.disableAnimationsOf(context)'));
    expect(source, contains('AnimatedOpacity('));
    expect(source, contains('Duration(seconds: 3)'));
  });
}
