part of '../main.dart';

class ManualAppDocument {
  final String id;
  String title;
  String category;
  DateTime date;
  String notes;
  ManualAppDocument({required this.id, required this.title, required this.category, required this.date, this.notes = ''});
}

class DocumentsPage extends StatefulWidget {
  final bool isAdmin;
  const DocumentsPage({super.key,required this.isAdmin});
  @override State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  Future<void> _exportPvMagic() async {
    try {
      final data = await rootBundle.load('assets/pv_magic.pdf');
      await downloadFile(data.buffer.asUint8List(), 'PV_MAGIC.pdf', mimeType: 'application/pdf');
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PDF-ul a fost generat pentru descărcare.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nu am putut exporta PV MAGIC: $e')));
    }
  }

  Future<void> _addDocument() async {
    final formKey=GlobalKey<FormState>();
    final title = TextEditingController();
    final notes = TextEditingController();
    String category = 'Alte documente';
    DateTime date = DateTime.now();
    final result = await showDialog<ManualAppDocument>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Adaugă document permanent'),
          content: Form(key:formKey,child:SizedBox(width: MediaQuery.sizeOf(context).width < 700 ? MediaQuery.sizeOf(context).width * .82 : 520, child: SingleChildScrollView(child: Column(children: [
            TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Denumire document'),validator:(v)=>v==null||v.trim().isEmpty?'Denumirea este obligatorie.':null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Categorie'),
              items: const [
                DropdownMenuItem(value: 'Proces verbal', child: Text('Proces verbal')),
                DropdownMenuItem(value: 'Contract', child: Text('Contract')),
                DropdownMenuItem(value: 'Anexă', child: Text('Anexă')),
                DropdownMenuItem(value: 'Alte documente', child: Text('Alte documente')),
              ],
              onChanged: (v) { if (v != null) setD(() => category = v); },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data documentului'),
              subtitle: Text(formatDate(date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(context: c, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: date);
                if (d != null) setD(() => date = d);
              },
            ),
            const SizedBox(height: 10),
            TextField(controller: notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Observații / detalii')),
          ])))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Anulează')),
            FilledButton(
              onPressed: () {
                if(!(formKey.currentState?.validate()??false))return;
                Navigator.pop(c, ManualAppDocument(id: idNow(), title: title.text.trim(), category: category, date: date, notes: notes.text.trim()));
              },
              child: const Text('Adaugă'),
            ),
          ],
        ),
      ),
    );
    title.dispose(); notes.dispose();
    if(result==null)return;
    try {
      await FirebaseFirestore.instance.collection('documents').doc(result.id).set({
        'title':result.title,'category':result.category,'date':Timestamp.fromDate(result.date),'notes':result.notes,'createdAt':FieldValue.serverTimestamp(),
      });
    } catch(e) {
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nu s-a putut salva documentul: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Documente',
    subtitle: 'Bibliotecă permanentă de documente',
    actions: [if(widget.isAdmin)FilledButton.icon(onPressed: _addDocument, icon: const Icon(Icons.note_add_outlined), label: const Text('Adaugă document'))],
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.description_outlined, size: 30)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Proces verbal MAGIC GAMES AB', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Document fix păstrat în aplicație. La apăsare se descarcă PDF-ul; nu se arhivează copii generate în Firebase.'),
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: _exportPvMagic, icon: const Icon(Icons.picture_as_pdf), label: const Text('Exportă PDF')),
            ])),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Text('Alte documente permanente', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream: FirebaseFirestore.instance.collection('documents').orderBy('date',descending:true).snapshots(),
        builder:(context,snap){
          if(snap.hasError)return _InfoCard(icon:Icons.error_outline,title:'Documente',text:'Eroare: ${snap.error}');
          if(!snap.hasData)return const Center(child:Padding(padding:EdgeInsets.all(20),child:CircularProgressIndicator()));
          final docs=snap.data!.docs;
          if(docs.isEmpty)return const _Empty(icon:Icons.folder_open,text:'Nu sunt încă alte documente permanente. Când trimiți al doilea PV și celelalte documente, le adăugăm aici.');
          return Column(children:docs.map((doc){final d=doc.data();final date=d['date'] is Timestamp?(d['date'] as Timestamp).toDate():DateTime.now();return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.insert_drive_file_outlined)),title:Text((d['title']??'Document').toString()),subtitle:Text('${d['category']??'Document'} · ${formatDate(date)}${(d['notes']??'').toString().isEmpty?'':'\n${d['notes']}'}'),isThreeLine:(d['notes']??'').toString().isNotEmpty,trailing:widget.isAdmin?IconButton(tooltip:'Șterge',onPressed:() async {await doc.reference.delete();},icon:const Icon(Icons.delete_outline)):null));}).toList());
        },
      ),
      const SizedBox(height: 12),
      const _InfoCard(icon: Icons.info_outline, title: 'Regulă documente', text: 'PDF-urile operaționale (Centralizator, Decont, rapoarte) se generează la cerere și se descarcă; nu se păstrează în Firebase. În bibliotecă rămân numai documentele fixe.'),
    ]),
  );
}

