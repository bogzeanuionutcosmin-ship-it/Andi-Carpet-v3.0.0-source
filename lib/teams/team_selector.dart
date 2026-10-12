part of '../main.dart';

class _TeamSelector extends StatelessWidget {
  final List<Team> teams; final int selected; final ValueChanged<int> onChanged;
  const _TeamSelector({required this.teams,required this.selected,required this.onChanged});
  @override Widget build(BuildContext context){
    final accent=sectionAccent('Echipe');
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
