import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget { final IconData icon; final String text; const EmptyState({required this.icon,required this.text}); @override Widget build(BuildContext context)=>Card(child:Padding(padding:const EdgeInsets.all(28),child:Row(children:[Icon(icon,size:30),const SizedBox(width:14),Expanded(child:Text(text))]))); }
