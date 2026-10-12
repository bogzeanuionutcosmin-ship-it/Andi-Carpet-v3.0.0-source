part of '../main.dart';

class _Empty extends StatelessWidget { final IconData icon; final String text; const _Empty({required this.icon,required this.text}); @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(28),child:Row(children:[Icon(icon,size:30),const SizedBox(width:14),Expanded(child:Text(text))]))); }
