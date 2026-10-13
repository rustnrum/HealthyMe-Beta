// Build 77: authored Nutrition dashboard matching the approved art direction.
// No sample foods, calories, hydration measurements, or fabricated goal alignment.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_meal_planner_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/module_menu_button.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus77_design.dart';
import '../diet/food_visual_overview.dart';

class SalusNutrition77 extends ConsumerStatefulWidget {
  const SalusNutrition77({super.key,required this.onDiscover,required this.onCalendar,required this.onMeals,required this.onJournal});
  final VoidCallback onDiscover,onCalendar,onMeals,onJournal;
  @override ConsumerState<SalusNutrition77> createState()=>_SalusNutrition77State();
}
class _SalusNutrition77State extends ConsumerState<SalusNutrition77> {
  int _offset=0,_scope=0;
  Map<String,double> _goals={};
  Map<String,SalusMealIdea> _recipes={};
  String _objective='Balanced';
  DateTime get _date=>DateTime.now().add(Duration(days:_offset));
  @override void initState(){super.initState();SalusAppearance.load();_load();}
  Future<void> _load()async{
    try{
      final prefs=await SharedPreferences.getInstance();
      final recipes=await const SalusMealPlannerService().loadRecipeAssignments();
      final goals=<String,double>{};
      for(final name in ['Calories','Protein','Carbs','Fat','Fiber']){
        final x=prefs.getDouble('salus_nutrition_target_$name');if(x!=null&&x>0)goals[name]=x;
      }
      if(mounted)setState((){_goals=goals;_recipes=recipes;_objective=prefs.getString('salus_nutrition_objective_v1')??'Balanced';});
    }catch(_){/* Keep overview available even if optional settings are unreadable. */}
  }
  Future<void> _editGoals()async{
    final fields={for(final name in ['Calories','Protein','Carbs','Fat','Fiber'])name:TextEditingController(text:_goals[name]?.round().toString()??'')};
    var objective=_objective;
    final submit=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:const Text('Personal nutrition targets'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:objective,decoration:const InputDecoration(labelText:'Primary goal'),
          items:[for(final o in ['Balanced','Fat loss','Muscle gain','Maintenance'])DropdownMenuItem(value:o,child:Text(o))],
          onChanged:(v){if(v!=null)setDialog(()=>objective=v);}),
        for(final f in fields.entries)TextField(controller:f.value,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:'${f.key} (${f.key=='Calories'?'kcal':'g'})',hintText:'No target set')),
        const SizedBox(height:8),const Text('Only values you set are compared. Empty goals remain unknown.',style:TextStyle(fontSize:11)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save'))])));
    if(submit==true){
      final prefs=await SharedPreferences.getInstance();final goals=<String,double>{};
      for(final x in fields.entries){final value=double.tryParse(x.value.text.trim());
        if(value!=null&&value>0&&value<10000){goals[x.key]=value;await prefs.setDouble('salus_nutrition_target_${x.key}',value);}
        else await prefs.remove('salus_nutrition_target_${x.key}');}
      await prefs.setString('salus_nutrition_objective_v1',objective);
      if(mounted)setState((){_goals=goals;_objective=objective;});
    }
    for(final field in fields.values){field.dispose();}
  }
  double? _one(DietLogState log,DateTime day,String key)=>switch(key){
    'Calories'=>log.knownTotal(day,(x)=>x.calories),'Protein'=>log.knownTotal(day,(x)=>x.protein),
    'Carbs'=>log.knownTotal(day,(x)=>x.carbs),'Fat'=>log.knownTotal(day,(x)=>x.fat),
    'Fiber'=>log.knownTotal(day,(x)=>x.fiber),_=>null};
  double? _sum(DietLogState log,String key,DateTime last,int count){
    double? total;
    for(var i=0;i<count;i++){
      final current=_one(log,last.subtract(Duration(days:i)),key);
      if(current!=null)total=(total??0.0)+current;
    }
    return total;
  }
  double? _planned(TodayPlanState plan,DateTime date){
    final named=plan.mealsFor(date);if(named.isEmpty)return null;
    var total=0.0;
    for(final slot in named.keys){
      final recipe=_recipes['${salusDayKey(date)}|$slot'];
      if(recipe==null||recipe.name!=named[slot]||recipe.calories==null)return null;
      total+=recipe.calories!;
    }
    return total;
  }
  double? _planSum(TodayPlanState plan,DateTime last,int count){
    double? total;
    for(var i=0;i<count;i++){
      final d=last.subtract(Duration(days:i));
      if(plan.mealsFor(d).isEmpty)continue;
      final value=_planned(plan,d);
      // An incomplete period must not appear as a complete planned total.
      if(value==null)return null;
      total=(total??0.0)+value;
    }
    return total;
  }
  String _pretty(DateTime d)=>'${d.month}/${d.day}/${d.year}';
  String _name(int s)=>['Day','Week','Month'][s];
  Widget _mini(String label,double? value,Color color,IconData icon,{String unit='g',double? goal})=>S77Metric(
    label:label,value:value==null?'—':value.round().toString(),icon:icon,color:color,
    caption:value==null?'Not logged':goal==null?'$unit logged':'of ${goal.round()} $unit',
    height:100,progress:value==null||goal==null?null:value/goal);
  Widget _mealSlot(DietLogState log,TodayPlanState plan,DateTime date,String slot,Color color,IconData icon){
    final foods=log.forDay(date).where((x)=>x.slot==slot).toList();
    final named=plan.mealsFor(date)[slot];
    final cals=foods.where((x)=>x.calories!=null).fold<double>(0,(a,x)=>a+x.calories!);
    final known=foods.any((x)=>x.calories!=null);
    final hasPhoto=foods.any((x)=>x.imageUrl.trim().isNotEmpty);
    return Padding(padding:const EdgeInsets.only(bottom:8),child:S77Surface(onTap:widget.onJournal,padding:const EdgeInsets.all(10),
      child:Row(children:[
        ClipRRect(borderRadius:BorderRadius.circular(12),child:hasPhoto
          ? FoodPicture(imageUrl:foods.firstWhere((x)=>x.imageUrl.trim().isNotEmpty).imageUrl,size:61)
          : Container(width:61,height:61,color:color.withValues(alpha:.15),child:Icon(icon,color:color,size:27))),
        const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(slot,style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:13)),
          const SizedBox(height:3),Text(foods.isNotEmpty?foods.map((x)=>x.name).join(' · '):named??'Not planned or logged',
            maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.sub,fontSize:11)),
          if(named!=null&&foods.isNotEmpty)Text('Planned: $named',maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:S77.dim,fontSize:10)),
        ])),const SizedBox(width:5),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text(known?'${cals.round()} kcal':'—',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:11)),
          const SizedBox(height:9),Icon(foods.isNotEmpty?Icons.check_circle:Icons.circle_outlined,
            size:19,color:foods.isNotEmpty?S77.green:S77.dim),
        ])
      ])));
  }
  @override Widget build(BuildContext context){
    final log=ref.watch(dietLogStateProvider),plan=ref.watch(todayPlanStateProvider);
    return ValueListenableBuilder<bool>(valueListenable:SalusAppearance.light,builder:(context,light,_){
      final date=_date,days=_scope==0?1:_scope==1?7:30;
      final energy=_sum(log,'Calories',date,days),p=_sum(log,'Protein',date,days);
      final carbs=_sum(log,'Carbs',date,days),fat=_sum(log,'Fat',date,days),fiber=_sum(log,'Fiber',date,days);
      final haveMacros=p!=null&&carbs!=null&&fat!=null;
      final completeMacro=haveMacros&&!(log.entries.any((x)=>
        !x.eatenAt.isAfter(DateTime(date.year,date.month,date.day,23,59,59))&&
        !x.eatenAt.isBefore(DateTime(date.year,date.month,date.day).subtract(Duration(days:days-1)))&&
        (x.protein==null||x.carbs==null||x.fat==null)));
      final macroParts=completeMacro?<({double value,Color color})>[
        (value:p*4,color:S77.green),(value:carbs*4,color:S77.blue),(value:fat*9,color:S77.orange)]:<({double value,Color color})>[];
      final chartLabels=<String>[],planned=<double?>[],eaten=<double?>[];
      for(var i=(_scope==2?5:6);i>=0;i--){
        final day=date.subtract(Duration(days:_scope==2?i*5:i));
        final span=_scope==2?5:1;
        chartLabels.add(_scope==2?'${day.month}/${day.day}':['M','T','W','T','F','S','S'][day.weekday-1]);
        planned.add(_planSum(plan,day,span));eaten.add(_sum(log,'Calories',day,span));
      }
      final target=_goals['Calories'];
      final allTargets=['Protein','Carbs','Fat','Fiber'].where((x)=>_goals[x]!=null).toList();
      final knownGoals=allTargets.where((x)=>_sum(log,x,date,days)!=null).toList();
      final aligned=knownGoals.isNotEmpty?knownGoals.where((key){
        final v=_sum(log,key,date,days)!;
        final goal=_goals[key]!*days;return v>=goal*.8&&v<=goal*1.2;
      }).length:null;
      final isPast=_offset<0;
      return ColoredBox(color:S77.bg,child:ListView(padding:const EdgeInsets.fromLTRB(17,16,17,40),children:[
        S77Title('Nutrition',subtitle:'PLAN · TRACK · IMPROVE',trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          HealthyMeModuleMenuButton(iconColor:S77.ink,showLabel:true,lightSurface:light,current:HealthyMeModule.diet,onSelected:(m){switch(m){
            case HealthyMeModule.fitness:Navigator.of(context).popUntil((r)=>r.isFirst);break;
            case HealthyMeModule.workout:Navigator.of(context).pushReplacementNamed('/workout');break;
            case HealthyMeModule.diet:break;
            case HealthyMeModule.health:Navigator.of(context).pushReplacementNamed('/health');break;
          }}),const PremiumThemeButton()])),
        const SizedBox(height:8),Text(_scope==0?_pretty(date):'${_name(_scope)} ending ${_pretty(date)}',style:TextStyle(color:S77.sub,fontSize:12)),
        const SizedBox(height:12),S77Tabs(items:const ['Day','Week','Month'],selected:_scope,onSelected:(i)=>setState(()=>_scope=i)),
        const SizedBox(height:10),Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          IconButton(onPressed:()=>setState(()=>_offset-=(_scope==2?30:_scope==1?7:1)),icon:Icon(Icons.chevron_left,color:S77.cyan)),
          Text(_pretty(date),style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800)),
          IconButton(onPressed:_offset>=0?null:()=>setState(()=>_offset=(_offset+(_scope==2?30:_scope==1?7:1)).clamp(-10000,0).toInt()),icon:Icon(Icons.chevron_right,color:S77.cyan)),
        ]),
        S77Surface(accent:S77.cyan,child:Column(children:[
          Row(children:[S77Arc(size:149,center:energy==null?'—':'${energy.round()}',
            caption:target==null?'kcal logged':'of ${(target*days).round()} kcal',segments:macroParts),
            const SizedBox(width:15),Expanded(child:Column(children:[
              _macroLine('Protein',p,S77.green),_macroLine('Carbs',carbs,S77.blue),_macroLine('Fat',fat,S77.orange),_macroLine('Fiber',fiber,S77.purple),
            ]))]),const SizedBox(height:11),Text(completeMacro?'Ring shows recorded macro energy distribution.':'Log protein, carbs and fat for a complete macro ring.',
            style:TextStyle(color:S77.dim,fontSize:10)),
        ])),
        const SizedBox(height:11),Row(children:[
          Expanded(child:_mini('Calories',energy,S77.orange,Icons.local_fire_department_outlined,unit:'kcal',goal:target==null?null:target*days)),
          const SizedBox(width:8),Expanded(child:_mini('Protein',p,S77.green,Icons.fitness_center,goal:_goals['Protein']==null?null:_goals['Protein']!*days)),
          const SizedBox(width:8),Expanded(child:_mini('Carbs',carbs,S77.blue,Icons.grain,goal:_goals['Carbs']==null?null:_goals['Carbs']!*days)),
        ]),const SizedBox(height:9),Row(children:[
          Expanded(child:_mini('Fat',fat,S77.red,Icons.water_drop_outlined,goal:_goals['Fat']==null?null:_goals['Fat']!*days)),
          const SizedBox(width:9),Expanded(child:_mini('Fiber',fiber,S77.purple,Icons.eco_outlined,goal:_goals['Fiber']==null?null:_goals['Fiber']!*days)),
        ]),
        const SizedBox(height:17),S77Section('Planned vs Eaten',action:'Edit plan',onTap:widget.onCalendar),
        const SizedBox(height:6),S77Surface(child:Column(children:[
          S77PairedChart(left:planned,right:eaten,labels:chartLabels),const SizedBox(height:4),
          S77Legend(items:[(label:'Planned recipe estimates',color:S77.blue),(label:'Recorded intake',color:S77.green)]),
          const SizedBox(height:9),Text('Unknown recipe nutrition and unlogged food stay unknown. Bars are not daily-goal predictions.',
            style:TextStyle(color:S77.dim,fontSize:10)),
        ])),
        const SizedBox(height:18),S77Section('Today\'s Meals',action:'Calendar',onTap:widget.onCalendar),
        const SizedBox(height:5),for(final slot in salusMealSlots)_mealSlot(log,plan,date,slot,
          slot=='Breakfast'?S77.orange:slot=='Lunch'?S77.green:slot=='Dinner'?S77.blue:S77.purple,
          slot=='Breakfast'?Icons.free_breakfast:slot=='Lunch'?Icons.lunch_dining:slot=='Dinner'?Icons.dinner_dining:Icons.cookie_outlined),
        const SizedBox(height:9),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:widget.onJournal,icon:const Icon(Icons.add),label:const Text('Log food'))),
          const SizedBox(width:9),Expanded(child:FilledButton.icon(onPressed:widget.onDiscover,icon:const Icon(Icons.auto_awesome),label:const Text('Find meals')))]),
        const SizedBox(height:17),S77Section('Goal Alignment',action:'Edit',onTap:_editGoals),
        const SizedBox(height:6),S77Surface(accent:S77.green,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Icon(Icons.track_changes,color:S77.green,size:26),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(_objective,style:TextStyle(color:S77.ink,fontWeight:FontWeight.w900,fontSize:16)),
            Text('Your personal nutrition goal',style:TextStyle(color:S77.sub,fontSize:11))])),
            if(aligned!=null)Text('$aligned / ${knownGoals.length}',style:TextStyle(color:S77.green,fontWeight:FontWeight.w900,fontSize:22))]),
          const SizedBox(height:14),if(_goals.isEmpty)Text('Set your targets to enable goal comparisons.',style:TextStyle(color:S77.sub,fontSize:12)),
          if(_goals['Calories']!=null)S77Progress(label:'Calories',value:energy,target:_goals['Calories']!*days,color:S77.orange,unit:'kcal'),
          S77Progress(label:'Protein',value:p,target:_goals['Protein']==null?null:_goals['Protein']!*days,color:S77.green),
          S77Progress(label:'Carbs',value:carbs,target:_goals['Carbs']==null?null:_goals['Carbs']!*days,color:S77.blue),
          S77Progress(label:'Fat',value:fat,target:_goals['Fat']==null?null:_goals['Fat']!*days,color:S77.orange),
          S77Progress(label:'Fiber',value:fiber,target:_goals['Fiber']==null?null:_goals['Fiber']!*days,color:S77.purple),
          const SizedBox(height:5),Text(energy==null?'No calorie entries for this period.':
            _goals['Protein']==null?'Set a protein target to compare actual intake with your goal.':
            p==null?'Protein data missing; check logged serving details.':
            p<_goals['Protein']!*days?'Recorded protein is ${(_goals['Protein']!*days-p).round()} g below your selected target for this period.':
            'Recorded protein meets your selected target for this period.',
            style:TextStyle(color:S77.sub,fontSize:11,height:1.4)),
          if(isPast)Text('Viewing previous period',style:TextStyle(color:S77.dim,fontSize:10)),
        ])),
        const SizedBox(height:19),S77Hero(asset:'assets/premium/nutrition_photo77.jpg',title:'Real food.\nReal progress.',
          caption:'Discover ideas, save favorites and plan meals in your calendar.',onTap:widget.onDiscover,height:150),
      ]));
    });
  }
  Widget _macroLine(String name,double? value,Color color)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[
    Container(width:10,height:10,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:8),
    Expanded(child:Text(name,style:TextStyle(color:S77.sub,fontSize:12))),
    Text(value==null?'—':'${value.round()}g',style:TextStyle(color:S77.ink,fontWeight:FontWeight.w800,fontSize:13)),
  ]));
}
