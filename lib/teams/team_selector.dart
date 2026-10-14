import 'package:flutter/material.dart';

import '../models/app_data_models.dart';

class TeamSelector extends StatelessWidget {
  final List<Team> teams; final int selected; final ValueChanged<int> onChanged;
  final Color accent;
  const TeamSelector({required this.teams,required this.selected,required this.onChanged,required this.accent});
  @override Widget build(BuildContext context){
    return ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:360),
      child:DropdownButtonFormField<int>(
        value:selected.clamp(0,teams.length-1),
        decoration:InputDecoration(labelText:'Echipă',prefixIcon:Icon(Icons.groups,color:accent)),
        items:[for(int i=0;i<teams.length;i++)DropdownMenuItem(value:i,child:Text(teams[i].name,style:const TextStyle(fontWeight:FontWeight.w700)))],
        onChanged:(v){if(v!=null)onChanged(v);},
      ),
    );
  }
}
