import 'package:flutter/material.dart';
import '../finance/per_diem_money.dart';
import '../models/app_data_models.dart';

/// The route owns its controllers until its closing animation disposes it.
class ReceivedMoneyDialog extends StatefulWidget {
  const ReceivedMoneyDialog({super.key,required this.departure,required this.now,required this.newId});
  final bool departure;
  final DateTime now;
  final String Function() newId;
  @override State<ReceivedMoneyDialog> createState()=>_ReceivedMoneyDialogState();
}
class _ReceivedMoneyDialogState extends State<ReceivedMoneyDialog> {
  final amount=TextEditingController(),source=TextEditingController();
  final form=GlobalKey<FormState>();
  String method='Cash';
  @override void dispose(){amount.dispose();source.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(
    scrollable:true,
    title:Text(widget.departure?'Adaugă sumă primită la plecare':'Adaugă sumă primită în timpul deplasării'),
    content:SizedBox(width:480,child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:amount,autofocus:true,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(labelText:'Valoare',suffixText:'lei'),
        validator:(value)=>parsePerDiemBani(value??'',allowZero:false)==null
          ?'Introdu o sumă pozitivă, cu maximum 2 zecimale.':null),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:method,
        decoration:const InputDecoration(labelText:'Metodă'),
        items:const[DropdownMenuItem(value:'Cash',child:Text('Cash')),DropdownMenuItem(value:'Transfer',child:Text('Transfer'))],
        onChanged:(value){if(value!=null)setState(()=>method=value);}),
      const SizedBox(height:10),
      TextFormField(controller:source,textCapitalization:TextCapitalization.words,
        decoration:const InputDecoration(labelText:'De la cine'),
        validator:(value)=>value==null||value.trim().isEmpty?'Completează sursa sumei.':null),
      const SizedBox(height:10),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.event_outlined),title:const Text('Data'),
        subtitle:Text('${widget.now.day.toString().padLeft(2,'0')}.${widget.now.month.toString().padLeft(2,'0')}.${widget.now.year} · completată automat')),
    ]))),
    actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Anulează')),
      FilledButton(onPressed:(){
        if(!(form.currentState?.validate()??false))return;
        final bani=parsePerDiemBani(amount.text,allowZero:false)!;
        Navigator.pop(context,ReceivedMoneyEntry(id:widget.newId(),kind:widget.departure?'departure':'during',
          amount:bani/100,method:method,fromName:source.text.trim(),date:widget.now));
      },child:const Text('Adaugă'))],
  );
}
