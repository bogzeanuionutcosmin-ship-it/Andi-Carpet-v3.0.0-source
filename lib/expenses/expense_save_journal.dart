import 'dart:convert';

import '../models/app_data_models.dart';
import '../models/app_enums_permissions.dart';

/// Durable, privacy-minimal intent for creating one expense document.
/// Receipt pixels and raw OCR text are deliberately never serialized.
class ExpenseSaveIntent {
  const ExpenseSaveIntent({required this.userId, required this.teamId, required this.expense});

  final String userId;
  final String teamId;
  final Expense expense;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'userId': userId,
    'teamId': teamId,
    'expense': {
      'id': expense.id,
      'teamId': expense.teamId,
      'settlementId': expense.settlementId,
      'category': expense.category,
      'description': expense.description,
      'amount': expense.amount,
      'date': expense.date.toIso8601String(),
      'documentType': expense.documentType.name,
      'documentNumber': expense.documentNumber,
      'supplier': expense.supplier,
      'liters': expense.liters,
      'pricePerLiter': expense.pricePerLiter,
      'imageFingerprint': expense.imageFingerprint,
      'ocrConfidence': expense.ocrConfidence,
      'confirmed': expense.confirmed,
    },
  };

  factory ExpenseSaveIntent.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['userId'] is! String || json['teamId'] is! String || json['expense'] is! Map) {
      throw const FormatException('Invalid expense save intent.');
    }
    final d = Map<String, dynamic>.from(json['expense'] as Map);
    final id = d['id'];
    final expenseTeam = d['teamId'];
    final dateText = d['date'];
    final typeText = d['documentType'];
    if (id is! String || expenseTeam is! String || dateText is! String || typeText is! String ||
        d['amount'] is! num || d['category'] is! String || d['description'] is! String ||
        d['documentNumber'] is! String || d['supplier'] is! String ||
        d['imageFingerprint'] is! String || d['ocrConfidence'] is! num || d['confirmed'] is! bool ||
        (d['settlementId'] != null && d['settlementId'] is! String) ||
        (d['liters'] != null && d['liters'] is! num) ||
        (d['pricePerLiter'] != null && d['pricePerLiter'] is! num)) {
      throw const FormatException('Invalid expense payload.');
    }
    final parsedDate = DateTime.tryParse(dateText);
    ExpenseDocumentType? documentType;
    for (final value in ExpenseDocumentType.values) {
      if (value.name == typeText) {
        documentType = value;
        break;
      }
    }
    if (parsedDate == null || documentType == null) throw const FormatException('Invalid expense date or type.');
    final expense = Expense(
      id: id,
      teamId: expenseTeam,
      settlementId: d['settlementId'] as String?,
      category: d['category'] as String,
      description: d['description'] as String,
      amount: (d['amount'] as num).toDouble(),
      date: parsedDate,
      documentType: documentType,
      documentNumber: d['documentNumber'] as String,
      supplier: d['supplier'] as String,
      liters: (d['liters'] as num?)?.toDouble(),
      pricePerLiter: (d['pricePerLiter'] as num?)?.toDouble(),
      documentImageBase64: '',
      imageFingerprint: d['imageFingerprint'] as String,
      ocrRawText: '',
      ocrConfidence: (d['ocrConfidence'] as num).toDouble(),
      confirmed: d['confirmed'] as bool,
    );
    final intent = ExpenseSaveIntent(userId: json['userId'] as String, teamId: json['teamId'] as String, expense: expense);
    intent.validate();
    return intent;
  }

  void validate() {
    if (userId.trim().isEmpty || teamId.trim().isEmpty || expense.id.trim().isEmpty ||
        expense.teamId != teamId || expense.category.trim().isEmpty || expense.description.trim().isEmpty ||
        !expense.amount.isFinite || expense.amount <= 0 || !expense.ocrConfidence.isFinite ||
        expense.ocrConfidence < 0 || expense.ocrConfidence > 1 ||
        expense.documentImageBase64.isNotEmpty || expense.ocrRawText.isNotEmpty ||
        (expense.liters != null && (!expense.liters!.isFinite || expense.liters! <= 0)) ||
        (expense.pricePerLiter != null && (!expense.pricePerLiter!.isFinite || expense.pricePerLiter! <= 0))) {
      throw const FormatException('Expense intent is outside its valid scope or contains private image/text data.');
    }
  }

  bool sameOperation(ExpenseSaveIntent other) => userId == other.userId && teamId == other.teamId &&
      expense.id == other.expense.id && expense.teamId == other.expense.teamId &&
      expense.settlementId == other.expense.settlementId && expense.category == other.expense.category &&
      expense.description == other.expense.description && expense.amount == other.expense.amount &&
      expense.date.isAtSameMomentAs(other.expense.date) && expense.documentType == other.expense.documentType &&
      expense.documentNumber == other.expense.documentNumber && expense.supplier == other.expense.supplier &&
      expense.liters == other.expense.liters && expense.pricePerLiter == other.expense.pricePerLiter &&
      expense.imageFingerprint == other.expense.imageFingerprint && expense.ocrConfidence == other.expense.ocrConfidence &&
      expense.confirmed == other.expense.confirmed;
}

class ExpenseSaveJournal {
  const ExpenseSaveJournal({required this.read, required this.write, required this.remove});

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) remove;
  static final Set<String> _inFlight = {};

  String _key(String userId, String teamId) =>
      'expense_save_v1_${base64Url.encode(utf8.encode(jsonEncode([userId, teamId])))}';

  Future<ExpenseSaveIntent?> pending({required String userId, required String teamId}) async {
    final raw = await read(_key(userId, teamId));
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map) throw const FormatException('Intent is not an object.');
      final intent = ExpenseSaveIntent.fromJson(Map<String, dynamic>.from(value));
      if (intent.userId != userId || intent.teamId != teamId) throw const FormatException('Scope mismatch.');
      return intent;
    } on FormatException catch (error) {
      throw StateError('Cheltuiala în așteptare nu poate fi citită; datele au fost păstrate: $error');
    }
  }

  Future<void> persist(ExpenseSaveIntent intent) async {
    intent.validate();
    await write(_key(intent.userId, intent.teamId), jsonEncode(intent.toJson()));
  }

  Future<void> clear(ExpenseSaveIntent intent) => remove(_key(intent.userId, intent.teamId));

  Future<void> run({required ExpenseSaveIntent candidate, required Future<void> Function(Expense) send}) async {
    candidate.validate();
    final key = _key(candidate.userId, candidate.teamId);
    if (!_inFlight.add(key)) throw StateError('O salvare de cheltuială este deja în curs pentru această echipă.');
    try {
      final existing = await pending(userId: candidate.userId, teamId: candidate.teamId);
      if (existing != null && !existing.sameOperation(candidate)) {
        throw StateError('Există o cheltuială anterioară fără confirmare; reîncarcă înainte de o altă salvare.');
      }
      final intent = existing ?? candidate;
      if (existing == null) await persist(intent);
      await send(intent.expense);
      await clear(intent);
    } finally {
      _inFlight.remove(key);
    }
  }
}
