part of '../main.dart';

class FeedbackPage extends StatefulWidget {
  final AppUser currentUser; final int initialTab;
  const FeedbackPage({super.key,required this.currentUser,this.initialTab=0});
  @override State<FeedbackPage> createState()=>_FeedbackPageState();
}
class _FeedbackPageState extends State<FeedbackPage> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final details=TextEditingController(); final expected=TextEditingController(); final suggestion=TextEditingController();
  String area='Dashboard'; String severity='Mă încurcă, dar pot continua'; bool sending=false;
  @override void initState(){super.initState();tabs=TabController(length:2,vsync:this,initialIndex:widget.initialTab.clamp(0,1));}
  @override void dispose(){tabs.dispose();details.dispose();expected.dispose();suggestion.dispose();super.dispose();}
  Future<void> _sendError() async {
    if(details.text.trim().length<8){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Scrie pe scurt ce s-a întâmplat, măcar 8 caractere.')));return;}
    setState(()=>sending=true);
    try{await FirebaseFirestore.instance.collection('errorReports').add({'userId':widget.currentUser.id,'userName':widget.currentUser.name,'area':area,'severity':severity,'details':details.text.trim(),'expected':expected.text.trim(),'status':'nou','createdAt':FieldValue.serverTimestamp()});details.clear();expected.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Eroarea a fost trimisă. Mersi, detectivule.'),backgroundColor:Colors.green));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nu s-a putut trimite: $e')));}finally{if(mounted)setState(()=>sending=false);}
  }
  Future<void> _sendSuggestion() async {
    if(suggestion.text.trim().length<5)return;
    setState(()=>sending=true);
    try{await FirebaseFirestore.instance.collection('suggestions').add({'userId':widget.currentUser.id,'userName':widget.currentUser.name,'message':suggestion.text.trim(),'upVotes':<String>[],'downVotes':<String>[],'createdAt':FieldValue.serverTimestamp()});suggestion.clear();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Sugestia a intrat la vot. Să înceapă democrația.'),backgroundColor:Colors.green));}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Nu s-a putut trimite: $e')));}finally{if(mounted)setState(()=>sending=false);}
  }
  Future<void> _vote(DocumentSnapshot<Map<String,dynamic>> doc,bool up) async {
    final uid=widget.currentUser.id; final d=doc.data()??{}; final ups=List<String>.from((d['upVotes'] as List?)??const[]); final downs=List<String>.from((d['downVotes'] as List?)??const[]);
    if(up){downs.remove(uid);ups.contains(uid)?ups.remove(uid):ups.add(uid);}else{ups.remove(uid);downs.contains(uid)?downs.remove(uid):downs.add(uid);}
    await doc.reference.update({'upVotes':ups,'downVotes':downs});
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eroare sau idee? Dă-i aici.'),
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(icon: Icon(Icons.bug_report), text: 'Raportează eroare'),
            Tab(icon: Icon(Icons.lightbulb), text: 'Sugestii'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _InfoCard(
                icon: Icons.support_agent,
                title: 'Spune-ne unde doare',
                text: 'Alege zona, gravitatea și descrie simplu ce ai făcut și ce s-a întâmplat. Cu cât e mai clar, cu atât reparăm mai repede.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: area,
                decoration: const InputDecoration(labelText: 'Unde a apărut?'),
                items: const ['Dashboard','Grafic de lucru','Hartă','Centralizator','Decont','Documente','Profil','Admin Panel','Altundeva']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setState(() => area = v ?? area),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(labelText: 'Cât de grav e?'),
                items: const ['Doar arată ciudat','Mă încurcă, dar pot continua','Nu mai pot continua','Date greșite / risc de pierdere date']
                    .map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
                onChanged: (v) => setState(() => severity = v ?? severity),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: details,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Ce s-a întâmplat?',
                  hintText: 'Ex.: Am apăsat INTRĂ la Million X și butonul a rămas blocat…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expected,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ce te așteptai să se întâmple?',
                  hintText: 'Ex.: Să apară imediat sala în Dashboard și ora în Centralizator.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: sending ? null : _sendError,
                icon: const Icon(Icons.send),
                label: const Text('Trimite eroarea'),
              ),
            ],
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: suggestion,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Sugestia ta',
                        hintText: 'Ex.: Ar fi util să…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: sending ? null : _sendSuggestion,
                        icon: const Icon(Icons.add_comment),
                        label: const Text('Publică sugestia'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('suggestions').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Nu pot încărca sugestiile: ${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('Nicio sugestie încă. Fii primul care complică aplicația.'));
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      itemBuilder: (c, i) {
                        final doc = docs[i];
                        final d = doc.data();
                        final ups = List<String>.from((d['upVotes'] as List?) ?? const []);
                        final downs = List<String>.from((d['downVotes'] as List?) ?? const []);
                        final uid = widget.currentUser.id;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((d['message'] ?? '').toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('de ${(d['userName'] ?? 'Utilizator').toString()}', style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    FilledButton.tonalIcon(
                                      onPressed: () => _vote(doc, true),
                                      icon: Icon(Icons.check_circle, color: ups.contains(uid) ? Colors.green : null),
                                      label: Text('${ups.length} Da'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _vote(doc, false),
                                      icon: Icon(Icons.cancel, color: downs.contains(uid) ? Colors.red : null),
                                      label: Text('${downs.length} Nu'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

