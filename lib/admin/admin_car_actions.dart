part of '../main.dart';

// Vehicle editing, deactivation and team assignment cleanup.
mixin _AdminCarActions on State<AdminPanelPage> {
  List<Car> get cars;
  List<Team> get teams;

Future<void> _editCar([Car? existing]) async {
   final plate = TextEditingController(text: existing?.plate ?? '');
   final model = TextEditingController(text: existing?.makeModel ?? '');
   final rca = TextEditingController(text: existing?.rcaUntil == null ? '' : formatDate(existing!.rcaUntil!));
   final itp = TextEditingController(text: existing?.itpUntil == null ? '' : formatDate(existing!.itpUntil!));
   final rov = TextEditingController(text: existing?.rovinietaUntil == null ? '' : formatDate(existing!.rovinietaUntil!));
   final consumption = TextEditingController(text: existing == null || existing.averageConsumption <= 0 ? '' : existing.averageConsumption.toStringAsFixed(1));
   final fuelPrice = TextEditingController(text: existing == null || existing.fuelPricePerLiter <= 0 ? '' : existing.fuelPricePerLiter.toStringAsFixed(2));
   String fuelType = existing?.fuelType ?? 'Motorină';
   DateTime? parseDateInput(String v) {
     final p = v.trim().split('-');
     if (p.length != 4) return null;
     final day = int.tryParse(p[1]);
     final year = int.tryParse(p[3]);
     const months = ['ianuarie','februarie','martie','aprilie','mai','iunie','iulie','august','septembrie','octombrie','noiembrie','decembrie'];
     final month = months.indexOf(p[2]);
     if (day == null || year == null || month < 0) return null;
     return DateTime(year, month + 1, day);
   }
   final result = await showDialog<bool>(
     context: context,
     builder: (d) => AlertDialog(
       title: Text(existing == null ? 'Adaugă mașină' : 'Editează mașină'),
       content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
         TextField(controller: plate, decoration: const InputDecoration(labelText: 'Număr de înmatriculare')),
         TextField(controller: model, decoration: const InputDecoration(labelText: 'Marcă / model')),
         TextField(controller: rca, decoration: const InputDecoration(labelText: 'RCA · ex. luni-30-septembrie-2026')),
         TextField(controller: itp, decoration: const InputDecoration(labelText: 'ITP · ex. luni-30-septembrie-2026')),
         TextField(controller: rov, decoration: const InputDecoration(labelText: 'Rovinietă · ex. luni-30-septembrie-2026')),
         const SizedBox(height: 8),
         DropdownButtonFormField<String>(value:fuelType,decoration:const InputDecoration(labelText:'Carburant'),items:const ['Motorină','Benzină','GPL','Electric'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)fuelType=v;}),
         const SizedBox(height: 8),
         TextField(controller:consumption,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Consum mediu (l/100 km)',helperText:'Folosit pentru sumarul Graficului de lucru')),
         const SizedBox(height: 8),
         TextField(controller:fuelPrice,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Preț carburant (lei/l)',helperText:'Poate fi actualizat manual după prețul OMV')),
         Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()async{await launchUrl(Uri.parse('https://www.omv.ro/ro/mobilitate/carburanti/localizare-statii-omv'),mode:LaunchMode.externalApplication);},icon:appAssetIcon('assets/ui/fuel.png',size:20,accent:Colors.red),label:const Text('Deschide prețurile OMV'))),
       ])),
       actions: [
         TextButton(onPressed: () => Navigator.pop(d), child: const Text('Anulează')),
         FilledButton(onPressed: () {
           if (plate.text.trim().isEmpty) return;
           final c = existing ?? Car(id: idNow(), plate: plate.text.trim());
           c.plate = plate.text.trim();
           c.makeModel = model.text.trim();
           c.rcaUntil = parseDateInput(rca.text);
           c.itpUntil = parseDateInput(itp.text);
           c.rovinietaUntil = parseDateInput(rov.text);
           c.fuelType = fuelType;
           c.averageConsumption = double.tryParse(consumption.text.replaceAll(',', '.')) ?? 0;
           c.fuelPricePerLiter = double.tryParse(fuelPrice.text.replaceAll(',', '.')) ?? 0;
           if (existing == null) cars.add(c);
           widget.log(existing == null ? 'Mașină adăugată' : 'Mașină modificată', c.plate);
           widget.onChanged();
           Navigator.pop(d, true);
         }, child: const Text('Salvează')),
       ],
     ),
   );
   if (result == true) {
     widget.onChanged();
     setState(() {});
     if (mounted) showSuccessMessage(context, existing == null ? 'Mașina a fost adăugată.' : 'Datele mașinii au fost salvate.');
   }
 }
 Future<void> _removeCar(Car c) async {
   final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('Elimină mașina?'), content: Text('${c.plate} va fi scoasă din lista de mașini.'), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Anulează')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Elimină'))]));
   if (ok == true) {
     for (final t in teams) {
       if (t.carId == c.id) t.carId = null;
     }
     cars.remove(c);
     await FirebaseFirestore.instance.collection('cars').doc(c.id).delete();
     widget.onChanged();
     setState(() {});
     if (mounted) showSuccessMessage(context, '${c.plate} a fost eliminată.');
   }
 }
 Widget _cars() => Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
     Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 10, children: [
       const Text('Mașini', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
       Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(c)=>const AlertDialog(title:Text('Setări Mașini'),content:Text('Consum mediu și preț carburant se setează direct pe fiecare mașină și intră automat în sumarul Graficului de lucru. Prețul OMV se verifică din butonul din editarea mașinii.'))),icon:appAssetIcon('assets/ui/settings.png',size:20,accent:Theme.of(context).colorScheme.primary),label:const Text('Setări')),FilledButton.icon(onPressed: () => _editCar(), icon: const Icon(Icons.add), label: const Text('Adaugă mașină'))]),
     ]),
     const SizedBox(height: 12),
     ...cars.map((c) => Card(child: ListTile(
       leading: const Icon(Icons.directions_car),
       title: Text(c.plate),
       subtitle: Text('${c.makeModel} · ${c.fuelType} · ${c.averageConsumption > 0 ? '${c.averageConsumption.toStringAsFixed(1)} l/100 km' : 'consum nesetat'} · ${c.fuelPricePerLiter > 0 ? '${c.fuelPricePerLiter.toStringAsFixed(2)} lei/l' : 'preț nesetat'}\nRCA ${c.rcaUntil == null ? 'nesetat' : formatDate(c.rcaUntil!)} · ITP ${c.itpUntil == null ? 'nesetat' : formatDate(c.itpUntil!)} · Rovinietă ${c.rovinietaUntil == null ? 'nesetată' : formatDate(c.rovinietaUntil!)}'),
       isThreeLine: true,
       trailing: MediaQuery.sizeOf(context).width < 700
           ? PopupMenuButton<String>(
               tooltip: 'Acțiuni mașină',
               onSelected: (value) {
                 if (value == 'edit') _editCar(c);
                 if (value == 'delete') _removeCar(c);
                 if (value == 'toggle') { setState(() => c.active = !c.active); widget.onChanged(); showSuccessMessage(context, c.active ? '${c.plate} a fost activată.' : '${c.plate} a fost dezactivată.'); }
               },
               itemBuilder: (ctx) => [
                 const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editează'))),
                 PopupMenuItem(value: 'toggle', child: ListTile(leading: Icon(c.active ? Icons.pause_circle_outline : Icons.play_circle_outline), title: Text(c.active ? 'Dezactivează' : 'Activează'))),
                 PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_forever, color: Theme.of(ctx).colorScheme.error), title: const Text('Elimină'))),
               ],
             )
           : Wrap(children: [
               IconButton(tooltip: 'Editează datele mașinii', onPressed: () => _editCar(c), icon: const Icon(Icons.edit)),
               IconButton(tooltip: 'Elimină mașina', onPressed: () => _removeCar(c), icon: const Icon(Icons.delete_forever)),
               Switch(value: c.active, onChanged: (v) { setState(() => c.active = v); widget.onChanged(); showSuccessMessage(context, v ? '${c.plate} a fost activată.' : '${c.plate} a fost dezactivată.'); }),
             ]),
     ))),
   ],
 );
 }
