part of '../main.dart';

/// O fișă în Firestore este doar METADATE, nu un fișier PDF încărcat.
class ManualAppDocument {
  final String id;
  String title;
  String category;
  DateTime date;
  String notes;
  ManualAppDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    this.notes = '',
  });
}

class DocumentsPage extends StatefulWidget {
  final bool isAdmin;
  const DocumentsPage({super.key, required this.isAdmin});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  // Un document de configurare din colecția existentă, vizibil tuturor
  // membrilor activi, modificabil numai de admin conform firestore.rules.
  static const String _magicVisibilityId = '__pv_magic_visibility__';
  static const List<String> _categories = [
    'Proces verbal',
    'Contract',
    'Anexă',
    'Alte documente',
  ];

  Future<void> _exportPvMagic() async {
    try {
      final data = await rootBundle.load('assets/pv_magic.pdf');
      final saved = await downloadFile(
        data.buffer.asUint8List(),
        'PV_MAGIC.pdf',
        mimeType: 'application/pdf',
      );
      if (!mounted || !saved) return; // Salvarea poate fi anulată.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PV MAGIC: salvarea fișierului a fost solicitată.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut salva PV MAGIC: ' + e.toString())),
      );
    }
  }

  Future<void> _sharePvMagic() async {
    try {
      final data = await rootBundle.load('assets/pv_magic.pdf');
      await Printing.sharePdf(
        bytes: data.buffer.asUint8List(),
        filename: 'PV_MAGIC.pdf',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut partaja PV MAGIC: ' + e.toString())),
      );
    }
  }

  Future<void> _setMagicVisibility(bool visible) async {
    if (!widget.isAdmin) return;
    final action = visible ? 'reafișezi' : 'ascunzi';
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(visible ? 'Reafișează PV MAGIC?' : 'Ascunde PV MAGIC?'),
        content: Text(
          'Confirmi că vrei să ' + action + ' cardul PV MAGIC pentru toți utilizatorii? '
          'Fișierul PDF inclus în aplicație NU va fi șters.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmă'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await FirebaseFirestore.instance.collection('documents')
          .doc(_magicVisibilityId).set({
        'title': 'Configurare vizibilitate PV MAGIC',
        'category': '_system',
        'date': Timestamp.fromDate(DateTime(2000, 1, 1)),
        'visible': visible,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vizibilitatea PV MAGIC nu a putut fi salvată: ' + e.toString())),
      );
    }
  }

  Future<void> _addDocument() async {
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final notes = TextEditingController();
    var category = 'Alte documente';
    var categoryChosen = false;
    var date = DateTime.now();
    final result = await showDialog<ManualAppDocument>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Adaugă fișă document'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width < 700
                  ? MediaQuery.sizeOf(context).width * .82
                  : 520,
              child: SingleChildScrollView(
                child: Column(children: [
                  const Text(
                    'Se salvează doar denumirea, categoria, data și notițele. '
                    'Această funcție NU încarcă un fișier PDF; nu va apărea '
                    'un buton de descărcare pentru această fișă.',
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Denumire document'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Denumirea este obligatorie.'
                        : null,
                    onChanged: (value) {
                      if (!categoryChosen) {
                        setD(() => category = isProtocolDocument(
                          title: value,
                          category: 'Alte documente',
                        ) ? 'Proces verbal' : 'Alte documente');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categorie'),
                    items: _categories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setD(() {
                        categoryChosen = true;
                        category = v;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data documentului'),
                    subtitle: Text(formatDate(date)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        initialDate: date,
                      );
                      if (d != null) setD(() => date = d);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Observații / detalii'),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(ctx, ManualAppDocument(
                  id: idNow(),
                  title: title.text.trim(),
                  category: category,
                  date: date,
                  notes: notes.text.trim(),
                ));
              },
              child: const Text('Adaugă fișă'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    notes.dispose();
    if (result == null) return;
    try {
      await FirebaseFirestore.instance.collection('documents').doc(result.id).set({
        'title': result.title,
        'category': result.category,
        'date': Timestamp.fromDate(result.date),
        'notes': result.notes,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu s-a putut salva fișa: ' + e.toString())),
      );
    }
  }

  Future<void> _editCategory(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (!widget.isAdmin) return;
    final data = document.data();
    var selected = (data['category'] ?? 'Alte documente').toString();
    if (!_categories.contains(selected)) selected = 'Alte documente';
    final newCategory = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Modifică categoria fișei'),
          content: DropdownButtonFormField<String>(
            value: selected,
            decoration: const InputDecoration(labelText: 'Categorie'),
            items: _categories.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c),
            )).toList(),
            onChanged: (v) { if (v != null) setD(() => selected = v); },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
    if (newCategory == null || newCategory == data['category']) return;
    try {
      await document.reference.update({'category': newCategory});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Categoria nu a putut fi modificată: ' + e.toString())),
      );
    }
  }

  Future<void> _deleteDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    if (!widget.isAdmin || document.id == _magicVisibilityId) return;
    final title = (document.data()['title'] ?? 'Document').toString();
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge fișa documentului?'),
        content: Text(
          'Se va șterge doar fișa „' + title +
          '” din colecția documents. Nu există fișier PDF atașat acestei fișe. '
          'Acțiunea nu poate fi anulată automat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge fișa'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await document.reference.delete();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fișa nu a putut fi ștearsă: ' + e.toString())),
      );
    }
  }

  Widget _metadataDocumentCard(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final d = document.data();
    final date = d['date'] is Timestamp
        ? (d['date'] as Timestamp).toDate()
        : DateTime.now();
    final notes = (d['notes'] ?? '').toString();
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
        title: Text((d['title'] ?? 'Document').toString()),
        subtitle: Text(
          (d['category'] ?? 'Document').toString() + ' · ' + formatDate(date) +
          '\nFișă informativă — PDF neatașat' +
          (notes.isEmpty ? '' : '\n' + notes),
        ),
        isThreeLine: true,
        trailing: widget.isAdmin
            ? PopupMenuButton<String>(
                tooltip: 'Opțiuni fișă',
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'category', child: Text('Schimbă categoria')),
                  PopupMenuItem(value: 'delete', child: Text('Șterge fișa')),
                ],
                onSelected: (action) {
                  if (action == 'category') {
                    _editCategory(document);
                  } else if (action == 'delete') {
                    _deleteDocument(document);
                  }
                },
              )
            : null,
      ),
    );
  }

  Widget _magicCard({required bool visible}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(radius: 28, child: Icon(Icons.description_outlined, size: 30)),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proces verbal MAGIC GAMES AB' + (visible ? '' : ' · ascuns'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'PDF fix inclus în aplicație. Descărcarea salvează un fișier '
              'pe dispozitiv; partajarea este o acțiune separată.',
            ),
            const SizedBox(height: 14),
            if (visible) Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _exportPvMagic,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Descarcă PDF'),
                ),
                if (!kIsWeb) OutlinedButton.icon(
                  onPressed: _sharePvMagic,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Partajează PDF'),
                ),
              ],
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _setMagicVisibility(!visible),
                icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                label: Text(visible ? 'Ascunde cardul Magic' : 'Reafișează cardul Magic'),
              ),
            ],
          ],
        )),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Documente',
    subtitle: 'Bibliotecă permanentă de documente',
    actions: [
      if (widget.isAdmin)
        FilledButton.icon(
          onPressed: _addDocument,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Adaugă fișă'),
        ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('documents')
              .orderBy('date', descending: true).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return _InfoCard(
              icon: Icons.error_outline,
              title: 'Documente',
              text: 'Eroare: ' + snap.error.toString(),
            );
            if (!snap.hasData) return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            );
            final all = snap.data!.docs;
            var magicVisible = true;
            for (final d in all) {
              if (d.id == _magicVisibilityId) {
                magicVisible = d.data()['visible'] != false;
                break;
              }
            }
            final userDocuments = all.where((d) =>
                d.id != _magicVisibilityId).toList();
            final pvDocuments = userDocuments.where((d) =>
                isProtocolDocument(
                  title: (d.data()['title'] ?? '').toString(),
                  category: (d.data()['category'] ?? '').toString(),
                )).toList();
            final otherDocuments = userDocuments.where((d) =>
                !isProtocolDocument(
                  title: (d.data()['title'] ?? '').toString(),
                  category: (d.data()['category'] ?? '').toString(),
                )).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (magicVisible || widget.isAdmin)
                  _magicCard(visible: magicVisible),
                if (pvDocuments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Alte procese verbale',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...pvDocuments.map(_metadataDocumentCard),
                ],
                const SizedBox(height: 18),
                Text(
                  'Alte documente permanente',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (otherDocuments.isEmpty)
                  const _Empty(
                    icon: Icons.folder_open,
                    text: 'Nu există alte fișe de documente permanente.',
                  )
                else
                  ...otherDocuments.map(_metadataDocumentCard),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          icon: Icons.info_outline,
          title: 'Regulă documente',
          text: 'PV MAGIC este un PDF fix inclus în aplicație și poate fi '
              'ascuns/reafișat de administrator, nu șters din APK. '
              'Fișele adăugate manual conțin doar metadate, fără PDF. '
              'Fișierele operaționale se generează la cerere și se salvează '
              'prin dialogul de descărcare; nu sunt arhivate în Firebase.',
        ),
      ],
    ),
  );
}
