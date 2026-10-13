part of '../main.dart';

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData? icon;
  final String? asset;
  const _StatCard({required this.title, required this.value, this.icon, this.asset}) : assert(icon != null || asset != null);
  @override Widget build(BuildContext context){
    final accent=sectionAccent(title);
    final leading = asset != null
        ? appAssetIcon(asset!, size: 24, accent: accent, selected: true)
        : CircleAvatar(backgroundColor:accent.withValues(alpha:.16),child:Icon(icon,color:accent));
    return SizedBox(width:230,child:Card(child:Container(
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:LinearGradient(colors:[accent.withValues(alpha:.16),Theme.of(context).colorScheme.surface.withValues(alpha:.96)])),
      padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        leading,const SizedBox(height:10),
        Text(title,style:TextStyle(color:accent,fontWeight:FontWeight.w800)),const SizedBox(height:4),
        Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))
      ]),
    )));
  }
}
class _InfoCard extends StatelessWidget {
  final IconData icon; final String title,text;
  const _InfoCard({required this.icon,required this.title,required this.text});
  @override Widget build(BuildContext context){
    final accent=sectionAccent(title);
    return Card(child:ListTile(
      leading:CircleAvatar(backgroundColor:accent.withValues(alpha:.14),child:Icon(icon,color:accent)),
      title:Text(title,style:TextStyle(fontWeight:FontWeight.w800,color:accent)),subtitle:Text(text),
    ));
  }
}
