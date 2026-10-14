part of '../main.dart';

extension _ExpenseDocumentActions on _ExpensePageState {
  Future<XFile?> _pickDocumentImage({bool allowNoImage = false}) async {
    final source = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Fotografiază acum'), onTap: () => Navigator.pop(c, 'camera')),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Alege din galerie'), onTap: () => Navigator.pop(c, 'gallery')),
      if (allowNoImage) ListTile(leading: const Icon(Icons.edit_note), title: const Text('Fără fotografie'), onTap: () => Navigator.pop(c, 'none')),
    ])));
    if (source == null || source == 'none') return null;
    try {
      return await _imagePicker.pickImage(source: source == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 92, maxWidth: 2400, maxHeight: 2400);
    } catch (e) { if (mounted) showErrorMessage(context, 'Imaginea nu a putut fi deschisă: $e'); return null; }
  }

  Uint8List _compressDocumentImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) { if (bytes.length <= 550000) return bytes; throw const FormatException('Imagine prea mare sau format nesuportat.'); }
    var work = img.bakeOrientation(decoded);
    int longest = work.width > work.height ? work.width : work.height;
    if (longest > 1400) {
      work = work.width >= work.height ? img.copyResize(work, width: 1400) : img.copyResize(work, height: 1400);
    }
    var encoded = Uint8List.fromList(img.encodeJpg(work, quality: 68));
    if (encoded.length > 480000) {
      work = work.width >= work.height ? img.copyResize(work, width: 1050) : img.copyResize(work, height: 1050);
      encoded = Uint8List.fromList(img.encodeJpg(work, quality: 56));
    }
    if (encoded.length > 480000) {
      work = work.width >= work.height ? img.copyResize(work, width: 800) : img.copyResize(work, height: 800);
      encoded = Uint8List.fromList(img.encodeJpg(work, quality: 48));
    }
    return encoded;
  }

  String _fingerprint(Uint8List bytes) {
    var h = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = (BigInt.one << 64) - BigInt.one;
    for (final b in bytes) {
      h ^= BigInt.from(b);
      h = (h * prime) & mask;
    }
    return h.toRadixString(16).padLeft(16, '0');
  }

  String _normalizedDocNo(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Expense? _duplicateOf(Expense candidate) {
    for (final e in widget.expenses) {
      if (e.teamId != candidate.teamId) continue;
      final sameSettlement = (e.settlementId ?? '') == (candidate.settlementId ?? '');
      if (!sameSettlement) continue;
      if (candidate.imageFingerprint.isNotEmpty && e.imageFingerprint == candidate.imageFingerprint) return e;
      final n1 = _normalizedDocNo(candidate.documentNumber), n2 = _normalizedDocNo(e.documentNumber);
      if (n1.isNotEmpty && n1 == n2 && sameDay(candidate.date, e.date) && (candidate.amount - e.amount).abs() < .02) return e;
    }
    return null;
  }

  Future<bool> _duplicateAllowed(Expense candidate) async {
    final learning = widget.settings.learning['conflicts'];
    if (learning?.enabled != true) return true;
    final duplicate = _duplicateOf(candidate);
    if (duplicate == null) return true;
    if (learning!.mode == LearningMode.automatic) {
      if (mounted) showErrorMessage(context, 'Document duplicat blocat automat: ${duplicate.documentNumber.isEmpty ? duplicate.description : duplicate.documentNumber}.');
      widget.log('Duplicat financiar blocat', candidate.documentNumber);
      return false;
    }
    return await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Posibil document duplicat'), content: Text('Există deja un document foarte asemănător: ${duplicate.documentNumber.isEmpty ? 'fără număr' : duplicate.documentNumber}, ${duplicate.amount.toStringAsFixed(2)} lei, ${formatDate(duplicate.date)}.\n\nSalvezi totuși?'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Nu, oprește')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Da, salvează'))])) ?? false;
  }

  Future<void> _manual() async {
    final picked = widget.documentImagePicker == null
        ? await _pickDocumentImage(allowNoImage: true)
        : await widget.documentImagePicker!(true);
    Uint8List? raw;
    FiscalOcrData? parsed;
    if (picked != null) {
      raw = await picked.readAsBytes();
      final ocrSetting = widget.settings.learning['ocr'];
      if (raw.isNotEmpty && ocrSetting?.enabled == true && ocrSetting?.mode == LearningMode.automatic) {
        setState(() => scanning = true);
        try {
          final text = await (widget.documentTextRecognizer ?? recognizeTextFromImage)(raw, path: picked.path);
          parsed = parseFiscalOcr(text);
          widget.log('OCR automat la atașare', '${team.name} · încredere ${(parsed.confidence * 100).round()}%');
        } catch (_) {
          // În modul automat, eșecul OCR nu blochează introducerea manuală.
        } finally {
          if (mounted) setState(() => scanning = false);
        }
      }
    }
    final e = await _expenseDialog(ocr: parsed, imageBytes: raw);
    if (e != null) await _saveNewExpense(e);
  }

  Future<void> _scan() async {
    final ocrSetting = widget.settings.learning['ocr'];
    if (ocrSetting?.enabled != true) { if (mounted) showErrorMessage(context, 'OCR financiar este dezactivat din Learning Center.'); return; }
    final picked = widget.documentImagePicker == null
        ? await _pickDocumentImage()
        : await widget.documentImagePicker!(false);
    if (picked == null) return;
    final raw = await picked.readAsBytes();
    if (raw.isEmpty) return;
    setState(() => scanning = true);
    FiscalOcrData parsed;
    try {
      final text = await (widget.documentTextRecognizer ?? recognizeTextFromImage)(raw, path: picked.path);
      parsed = parseFiscalOcr(text);
      widget.log('OCR document procesat', '${team.name} · încredere ${(parsed.confidence * 100).round()}%');
    } catch (e) {
      parsed = const FiscalOcrData(rawText: '');
      if (mounted) showErrorMessage(context, 'OCR-ul nu a putut citi documentul. Poți completa manual; fotografia nu se salvează în baza de date. Detalii: $e');
    } finally {
      if (mounted) setState(() => scanning = false);
    }
    final expense = await _expenseDialog(ocr: parsed, imageBytes: raw);
    if (expense != null) await _saveNewExpense(expense);
  }

  // Monetary input is validated as decimal text before conversion to double.
  // This prevents NaN, infinity, exponential notation and sub-ban amounts.
  int? _expenseAmountBani(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final lei = int.tryParse(parts.first);
    if (lei == null) return null;
    final bani = parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
    final total = lei * 100 + bani;
    return total > 0 ? total : null;
  }

  Future<Expense?> _expenseDialog({FiscalOcrData? ocr, Uint8List? imageBytes}) async {
    final formKey = GlobalKey<FormState>();
    final number = TextEditingController(text: ocr?.documentNumber ?? '');
    final amount = TextEditingController(text: ocr?.amount == null ? '' : ocr!.amount!.toStringAsFixed(2));
    final supplier = TextEditingController(text: ocr?.supplier ?? '');
    final desc = TextEditingController();
    final litersC = TextEditingController(text: ocr?.liters == null ? '' : ocr!.liters!.toStringAsFixed(2));
    final priceC = TextEditingController(text: ocr?.pricePerLiter == null ? '' : ocr!.pricePerLiter!.toStringAsFixed(2));
    String cat = ocr?.looksLikeFuel == true ? 'Combustibil' : 'Alte cheltuieli';
    ExpenseDocumentType docType = (ocr?.rawText.toUpperCase().contains('FACTUR') ?? false) ? ExpenseDocumentType.invoice : ExpenseDocumentType.fiscalReceipt;
    DateTime docDate = ocr?.date ?? DateTime.now();
    Uint8List? compressed;
    if(imageBytes!=null){
      try{compressed=_compressDocumentImage(imageBytes);}catch(e){if(mounted)showErrorMessage(context,'Fotografia nu a putut fi comprimată și nu va fi atașată: $e');}
    }
    // Fotografia este utilizată numai în memorie pentru OCR/previzualizare.
    // În Firestore salvăm doar un fingerprint mic pentru deduplicare.
    const photoBase64 = '';
    final fingerprint = imageBytes == null ? '' : _fingerprint(imageBytes);

    final result = await showDialog<Expense>(context: context, builder: (d) => StatefulBuilder(builder: (d, setD) => AlertDialog(
      title: Text(ocr == null ? 'Introducere document' : 'Verifică datele citite prin OCR'),
      content: SizedBox(width: 620, child: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (compressed != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(compressed, height: 180, fit: BoxFit.contain)),
          const SizedBox(height: 8),
        ],
        if (ocr != null) ...[
          _InfoCard(icon: Icons.document_scanner, title: 'OCR ${(ocr.confidence * 100).round()}%', text: ocr.rawText.isEmpty ? 'Textul nu a putut fi extras. Completează manual.' : 'Datele au fost completate automat. Verifică-le înainte de salvare. Fotografia este temporară și nu va fi salvată.'),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<ExpenseDocumentType>(initialValue: docType, decoration: const InputDecoration(labelText: 'Tip document'), items: const [DropdownMenuItem(value: ExpenseDocumentType.fiscalReceipt, child: Text('Bon Fiscal')), DropdownMenuItem(value: ExpenseDocumentType.invoice, child: Text('Factură'))], onChanged: (v) { if (v != null) setD(() { docType = v; if (v == ExpenseDocumentType.invoice && cat == 'Alte cheltuieli') cat = 'Facturi'; if (v == ExpenseDocumentType.fiscalReceipt && cat == 'Facturi') cat = 'Alte cheltuieli'; }); }),
        const SizedBox(height: 8),
        TextFormField(controller: number, decoration: InputDecoration(labelText: docType == ExpenseDocumentType.fiscalReceipt ? 'Nr. bon' : 'Nr. factură'), validator: (v) => v == null || v.trim().isEmpty ? 'Numărul documentului este obligatoriu.' : null),
        const SizedBox(height: 8),
        TextFormField(controller: supplier, decoration: const InputDecoration(labelText: 'Furnizor / comerciant')),
        const SizedBox(height: 8),
        TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Sumă', suffixText: 'lei'), validator: (v) => _expenseAmountBani(v ?? '') == null ? 'Introdu o sumă pozitivă, cu maximum 2 zecimale.' : null),
        const SizedBox(height: 8),
        ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Data documentului'), subtitle: Text(_shortDate(docDate)), trailing: TextButton(onPressed: () async { final x = await showDatePicker(context: d, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: docDate); if (x != null) setD(() => docDate = x); }, child: const Text('Alege'))),
        DropdownButtonFormField<String>(initialValue: cat, decoration: const InputDecoration(labelText: 'Categorie'), items: const [DropdownMenuItem(value: 'Combustibil', child: Text('Combustibil')), DropdownMenuItem(value: 'Facturi', child: Text('Facturi')), DropdownMenuItem(value: 'Alte cheltuieli', child: Text('Alte cheltuieli'))], onChanged: (v) { if (v != null) setD(() => cat = v); }),
        if (cat == 'Combustibil') ...[
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextFormField(controller: litersC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Litri'))), const SizedBox(width: 8), Expanded(child: TextFormField(controller: priceC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Preț / litru')))]),
        ],
        const SizedBox(height: 8),
        TextField(controller: desc, decoration: const InputDecoration(labelText: 'Specificație / descriere (opțional)')),
        if (ocr != null && ocr.rawText.isNotEmpty) ExpansionTile(title: const Text('Text OCR brut'), children: [Padding(padding: const EdgeInsets.all(8), child: SelectableText(ocr.rawText, style: const TextStyle(fontSize: 11)))]),
      ])))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
        FilledButton(onPressed: () {
          if (!(formKey.currentState?.validate() ?? false)) return;
          if (docDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
            ScaffoldMessenger.of(d).showSnackBar(const SnackBar(content: Text('Data documentului nu poate fi în viitor.')));
            return;
          }
          final bani = _expenseAmountBani(amount.text);
          if (bani == null) return;
          final value = bani / 100.0;
          Navigator.pop(d, Expense(
            id: idNow(), teamId: team.id, settlementId: settlement?.id, category: cat,
            description: desc.text.trim().isEmpty ? cat : desc.text.trim(), amount: value, date: docDate,
            documentType: docType, documentNumber: number.text.trim(), supplier: supplier.text.trim(),
            liters: double.tryParse(litersC.text.replaceAll(',', '.')), pricePerLiter: double.tryParse(priceC.text.replaceAll(',', '.')),
            documentImageBase64: photoBase64, imageFingerprint: fingerprint, ocrRawText: '', ocrConfidence: ocr?.confidence ?? 0,
            confirmed: isManager,
          ));
        }, child: Text(isManager ? 'Confirmă' : 'Trimite spre confirmare')),
      ],
    )));
    // Keep controllers alive through the closing dialog animation.
    return result;
  }

  Future<void> _saveNewExpense(Expense e) async {
    if (!await _duplicateAllowed(e)) return;
    try {
      await widget.saveExpense(e);
      widget.log('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} introdus', '${e.category} · ${settlement?.name ?? 'istoric anterior'}');
      if (mounted) showSuccessMessage(context, e.confirmed ? 'Documentul a fost salvat.' : 'Documentul a fost trimis gestionarului pentru confirmare.');
    } catch (err) { if (mounted) showErrorMessage(context, 'Nu s-a putut salva documentul: $err'); }
  }

  List<Widget> _groupedExpenses() {
    const groups = ['Combustibil', 'Facturi', 'Alte cheltuieli'];
    final out = <Widget>[];
    for (final g in groups) {
      final items = allEx.where((e) => e.category == g).toList();
      if (items.isEmpty) continue;
      out.add(Padding(padding: const EdgeInsets.only(top: 10, bottom: 6), child: Text(g, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))));
      out.addAll(items.map((e) => Card(child: ListTile(
        leading: e.hasImage ? InkWell(onTap: () => _showExpenseImage(e), child: ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.memory(base64Decode(e.documentImageBase64), width: 48, height: 48, fit: BoxFit.cover))) : const CircleAvatar(child: Icon(Icons.receipt_long)),
        title: Text('${e.documentType == ExpenseDocumentType.fiscalReceipt ? 'Bon Fiscal' : 'Factură'} nr ${e.documentNumber.isEmpty ? '—' : e.documentNumber}'),
        subtitle: Text('${formatDate(e.date)} · ${e.amount.toStringAsFixed(2)} lei${e.supplier.isEmpty ? '' : ' · ${e.supplier}'}${e.description == g ? '' : '\n${e.description}'}${e.ocrRawText.isEmpty ? '' : ' · OCR ${(e.ocrConfidence * 100).round()}%'}'),
        isThreeLine: e.description != g,
        trailing: e.confirmed ? const Chip(label: Text('Confirmat')) : isManager ? FilledButton(onPressed: () => _confirmExpense(e), child: const Text('Confirmă')) : const Chip(label: Text('În așteptare')),
      ))));
    }
    return out;
  }

  Future<void> _showExpenseImage(Expense e) async {
    if (!e.hasImage) return;
    Uint8List? bytes;
    try { bytes = base64Decode(e.documentImageBase64); } catch (_) {}
    if (bytes == null) return;
    await showDialog<void>(context: context, builder: (d) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900, maxHeight: 800), child: Column(mainAxisSize: MainAxisSize.min, children: [AppBar(title: Text(e.documentNumber.isEmpty ? 'Document' : e.documentNumber), automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => Navigator.pop(d), icon: const Icon(Icons.close))]), Flexible(child: InteractiveViewer(minScale: .5, maxScale: 5, child: Image.memory(bytes!, fit: BoxFit.contain)))]))));
  }

  Future<void> _confirmExpense(Expense e) async {
    e.confirmed = true;
    try { await widget.saveExpense(e); widget.log('Cheltuială confirmată', e.documentNumber); }
    catch (err) { e.confirmed = false; if (mounted) showErrorMessage(context, 'Confirmarea a eșuat: $err'); }
  }

  Future<void> _pdf() async {
    setState(() => exporting = true);
    try {
      await downloadDecontPdf(team: team, users: widget.users, expenses: widget.expenses, perDiems: widget.perDiems, finance: finance, settlement: settlement, legacyOnly: isLegacy);
      if (mounted) showSuccessMessage(context, 'PDF generat. Descărcarea a fost pornită.');
    } catch (e) { if (mounted) showErrorMessage(context, 'Eroare PDF: $e'); }
    finally { if (mounted) setState(() => exporting = false); }
  }
}
