import 'package:flutter/material.dart';

class MoneyCard extends StatelessWidget { final String title; final double value; final VoidCallback? onTap; const MoneyCard({required this.title,required this.value,this.onTap}); @override Widget build(BuildContext context)=>SizedBox(width:210,child:Card(child:InkWell(onTap:onTap,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title),const SizedBox(height:8),Text('${value.toStringAsFixed(2)} lei',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))]))))); }
