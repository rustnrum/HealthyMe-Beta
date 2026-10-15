// Build 87 Nutrition Overview: approved dark premium layout, actual food records.
// No fabricated servings, energy totals or target achievement.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_meal_planner_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus77_design.dart';
import '../diet/food_visual_overview.dart';
import 'salus87_ui.dart';

class SalusNutrition87 extends ConsumerStatefulWidget {
  const SalusNutrition87({super.key,required this.onDiscover,
    required this.onCalendar,required this.onMeals,required this.onJournal});
  final VoidCallback onDiscover,onCalendar,onMeals,onJournal;
  @override ConsumerState<SalusNutrition87> createState()=>_SalusNutrition87State();
}
class _SalusNutrition87State extends ConsumerState<SalusNutrition87>{
  int _scope=0,_offset=0;
  Map<String,double> _goals={};
  Map<String,SalusMealIdea> _recipes={};
  String _objective='Balanced';
  DateTime get _date=>DateTime.now().add(Duration(days:_offset));
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final prefs=await SharedPreferences.getInstance();
      final recipes=await const SalusMealPlannerService().loadRecipeAssignments();
      final goals=<String,double>{};
      for(final name in ['Calories','Protein','Carbs','Fat','Fiber']){
        final value=prefs.getDouble('salus_nutrition_target_$name');
        if(value!=null&&value>0)goals[name]=value;
      }
      if(mounted)setState((){
        _goals=goals;_recipes=recipes;
        _objective=prefs.getString('salus_nutrition_objective_v1')??'Balanced';
      });
    }catch(_){/* Optional goals must not hide food history. */}
  }
  Future<void> _editGoals()async{
    final fields={for(final name in ['Calories','Protein','Carbs','Fat','Fiber'])
      name:TextEditingController(text:_goals[name]?.round().toString()??'')};
    var objective=_objective;
    final save=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,update)=>AlertDialog(title:const Text('Personal nutrition targets'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:objective,
          decoration:const InputDecoration(labelText:'Primary goal'),
          items:[for(final x in ['Balanced','Fat loss','Muscle gain','Maintenance'])
            DropdownMenuItem(value:x,child:Text(x))],
          onChanged:(x){if(x!=null)update(()=>objective=x);}),
        for(final entry in fields.entries)TextField(controller:entry.value,
          keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:'${entry.key} (${entry.key=='Calories'?'kcal':'g'})',
            hintText:'No target set')),
        const SizedBox(height:8),
        const Text('Only values you set are used. Missing values remain unknown.',
          style:TextStyle(fontSize:11)),
      ])),actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Save')),
      ])));
    if(save==true){
      final prefs=await SharedPreferences.getInstance();
      final goals=<String,double>{};
      for(final item in fields.entries){
        final number=double.tryParse(item.value.text.trim());
        if(number!=null&&number>0&&number<10000){
          goals[item.key]=number;await prefs.setDouble('salus_nutrition_target_${item.key}',number);
        }else{await prefs.remove('salus_nutrition_target_${item.key}');}
      }
      await prefs.setString('salus_nutrition_objective_v1',objective);
      if(mounted)setState((){_goals=goals;_objective=objective;});
    }
    for(final field in fields.values){field.dispose();}
  }
  double? _one(DietLogState log,DateTime date,String key)=>switch(key){
    'Calories'=>log.knownTotal(date,(e)=>e.calories),
    'Protein'=>log.knownTotal(date,(e)=>e.protein),
    'Carbs'=>log.knownTotal(date,(e)=>e.carbs),
    'Fat'=>log.knownTotal(date,(e)=>e.fat),
    'Fiber'=>log.knownTotal(date,(e)=>e.fiber),_=>null,
  };
  double? _total(DietLogState log,String key,DateTime last,int count){
    double? sum;
    for(var i=0;i<count;i++){
      final n=_one(log,last.subtract(Duration(days:i)),key);
      if(n!=null)sum=(sum??0.0)+n;
    }
    return sum;
  }
  double? _planned(TodayPlanState plan,DateTime date){
    final names=plan.mealsFor(date);if(names.isEmpty)return null;
    var sum=0.0;
    for(final slot in names.keys){
      final idea=_recipes['${salusDayKey(date)}|$slot'];
      if(idea==null||idea.name!=names[slot]||idea.calories==null)return null;
      sum+=idea.calories!;
    }
    return sum;
  }
  double? _plannedRange(TodayPlanState plan,DateTime end,int days){
    double? sum;
    for(var i=0;i<days;i++){
      final day=end.subtract(Duration(days:i));
      if(plan.mealsFor(day).isEmpty)continue;
      final amount=_planned(plan,day);
      if(amount==null)return null;
      sum=(sum??0.0)+amount;
    }
    return sum;
  }
  String _dateLabel(DateTime d)=>'${d.month}/${d.day}/${d.year}';
  Widget _small(String name,double? current,String unit,Color color,
      IconData icon,double? target)=>S87Stat(icon:icon,title:name,
        value:current==null?'—':'${current.round()}$unit',
        detail:current==null?'not logged':target==null?'recorded':'goal ${target.round()}$unit',
        color:color);
  Widget _meal(DietLogState log,TodayPlanState plan,DateTime day,
      String slot,Color color,IconData icon){
    final foods=log.forDay(day).where((e)=>e.slot==slot).toList();
    final planned=plan.mealsFor(day)[slot];
    final recorded=foods.where((e)=>e.calories!=null).fold<double>(0,(a,b)=>a+b.calories!);
    final hasEnergy=foods.any((e)=>e.calories!=null);
    final photo=foods.where((e)=>e.imageUrl.trim().isNotEmpty).toList();
    return Padding(padding:const EdgeInsets.only(bottom:9),child:S87Panel(
      padding:const EdgeInsets.all(10),onTap:widget.onJournal,
      child:Row(children:[
        ClipRRect(borderRadius:BorderRadius.circular(11),child:photo.isNotEmpty?
          FoodPicture(imageUrl:photo.first.imageUrl,size:63):
          Container(width:63,height:63,color:color.withValues(alpha:.15),
            child:Icon(icon,color:color,size:25))),
        const SizedBox(width:11),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(slot,style:const TextStyle(color:S87.ink,fontWeight:FontWeight.w700,fontSize:13)),
          const SizedBox(height:4),
          Text(foods.isNotEmpty?foods.map((e)=>e.name).join(' · '):planned??'Not planned or logged',
            maxLines:2,overflow:TextOverflow.ellipsis,
            style:const TextStyle(color:S87.muted,fontSize:11)),
          if(planned!=null&&foods.isNotEmpty)Text('Planned: $planned',
            maxLines:1,overflow:TextOverflow.ellipsis,
            style:const TextStyle(color:S87.muted,fontSize:10)),
        ])),
        const SizedBox(width:5),
        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text(hasEnergy?'${recorded.round()} kcal':'—',
            style:const TextStyle(color:S87.ink,fontWeight:FontWeight.w700,fontSize:11)),
          const SizedBox(height:8),Icon(foods.isNotEmpty?Icons.check_circle:Icons.circle_outlined,
            color:foods.isNotEmpty?S87.green:S87.muted,size:18),
        ]),
      ])));
  }
  Widget _goalRow(String label,double? value,double? target,Color color){
    final valid=target!=null&&target>0;
    return Padding(padding:const EdgeInsets.symmetric(vertical:8),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(label,style:const TextStyle(color:S87.ink,fontSize:12))),
        Text(value==null?'—': '${value.round()} / ${valid?target.round():'—'}',
          style:const TextStyle(color:S87.muted,fontSize:11))]),
      const SizedBox(height:6),
      ClipRRect(borderRadius:BorderRadius.circular(8),child:LinearProgressIndicator(
        minHeight:8,value:!valid||value==null?0.0:(value/target).clamp(0.0,1.0).toDouble(),
        color:color,backgroundColor:S87.border)),
    ]));
  }
  @override Widget build(BuildContext context){
    final log=ref.watch(dietLogStateProvider),plan=ref.watch(todayPlanStateProvider);
    final date=_date,days=_scope==0?1:_scope==1?7:30;
    final calories=_total(log,'Calories',date,days);
    final protein=_total(log,'Protein',date,days);
    final carbs=_total(log,'Carbs',date,days);
    final fat=_total(log,'Fat',date,days);
    final fiber=_total(log,'Fiber',date,days);
    final targets={for(final p in _goals.entries)p.key:p.value*days};
    final knownTargets=['Calories','Protein','Carbs','Fat','Fiber'].where((key)=>
      targets.containsKey(key)&&_total(log,key,date,days)!=null).toList();
    final aligned=knownTargets.where((key){
      final value=_total(log,key,date,days)!;
      final goal=targets[key]!;
      return value>=goal*.8&&value<=goal*1.2;
    }).length;
    final macrosKnown=protein!=null&&carbs!=null&&fat!=null;
    final labels=<String>[],planned=<double?>[],eaten=<double?>[];
    for(var i=6;i>=0;i--){
      final datePoint=date.subtract(Duration(days:_scope==2?i*5:i));
      final span=_scope==2?5:1;
      labels.add(_scope==2?'${datePoint.month}/${datePoint.day}':
        ['M','T','W','T','F','S','S'][datePoint.weekday-1]);
      planned.add(_plannedRange(plan,datePoint,span));
      eaten.add(_total(log,'Calories',datePoint,span));
    }
    return ColoredBox(color:S87.bg,child:ListView(
      padding:const EdgeInsets.fromLTRB(16,18,16,40),children:[
      S87Brand(subtitle:'NUTRITION FOR A STRONGER YOU',
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[
          IconButton(tooltip:'Home',onPressed:()=>Navigator.of(context).popUntil((r)=>r.isFirst),
            icon:const Icon(Icons.home_outlined,color:S87.ink)),
          IconButton(tooltip:'Voice assistant',
            onPressed:()=>Navigator.of(context).pushNamed('/voice'),
            icon:const Icon(Icons.mic_none_rounded,color:S87.ink)),
        ])),
      const SizedBox(height:25),
      const Text('Nutrition Overview',style:TextStyle(color:S87.ink,
        fontSize:24,fontWeight:FontWeight.w700)),
      const SizedBox(height:6),
      Text(_scope==0?'Today, ${_dateLabel(date)}':'${_scope==1?'Week':'Month'} ending ${_dateLabel(date)}',
        style:const TextStyle(color:S87.muted,fontSize:12)),
      const SizedBox(height:18),
      Row(children:[for(var i=0;i<3;i++)Expanded(child:Padding(
        padding:const EdgeInsets.symmetric(horizontal:3),child:S87Chip(
          ['Day','Week','Month'][i],selected:i==_scope,onTap:()=>setState(()=>_scope=i))))]),
      const SizedBox(height:9),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(icon:const Icon(Icons.chevron_left_rounded,color:S87.teal),
          onPressed:()=>setState(()=>_offset-=(_scope==2?30:_scope==1?7:1))),
        Text(_dateLabel(date),style:const TextStyle(color:S87.ink,fontWeight:FontWeight.w600)),
        IconButton(icon:const Icon(Icons.chevron_right_rounded,color:S87.teal),
          onPressed:_offset>=0?null:()=>setState(()=>_offset=
            (_offset+(_scope==2?30:_scope==1?7:1)).clamp(-10000,0).toInt())),
      ]),
      const SizedBox(height:7),
      S87Panel(accent:S87.teal,child:LayoutBuilder(builder:(context,c){
        final ringSize=(c.maxWidth-145).clamp(105.0,166.0).toDouble();
        return Column(children:[
          Row(children:[
            S87ArtworkRing(asset:'assets/preview84/img/ring_calories.png',
              size:ringSize,value:calories?.round().toString()??'—',
              caption:calories==null?'No log':targets['Calories']==null?'kcal eaten':
                'of ${targets['Calories']!.round()} kcal',measured:macrosKnown),
            const SizedBox(width:11),
            Expanded(child:Column(children:[
              S87MetricLine(label:'Protein',value:protein==null?'—':'${protein.round()} g',
                icon:Icons.sports_gymnastics,color:S87.green),
              S87MetricLine(label:'Carbs',value:carbs==null?'—':'${carbs.round()} g',
                icon:Icons.grain_rounded,color:S87.blue),
              S87MetricLine(label:'Fat',value:fat==null?'—':'${fat.round()} g',
                icon:Icons.water_drop_rounded,color:S87.orange),
              S87MetricLine(label:'Fiber',value:fiber==null?'—':'${fiber.round()} g',
                icon:Icons.eco_outlined,color:S87.purple),
            ])),
          ]),
          const SizedBox(height:9),
          Text(macrosKnown?'Recorded macro totals':'Missing nutrition stays unknown; log food to fill this view.',
            style:const TextStyle(color:S87.muted,fontSize:10)),
        ]);
      })),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:_small('Calories',calories,'',S87.red,Icons.local_fire_department,
          targets['Calories'])),const SizedBox(width:8),
        Expanded(child:_small('Protein',protein,' g',S87.green,Icons.fitness_center,
          targets['Protein'])),const SizedBox(width:8),
        Expanded(child:_small('Carbs',carbs,' g',S87.blue,Icons.grain,
          targets['Carbs'])),
      ]),
      const SizedBox(height:9),
      Row(children:[
        Expanded(child:_small('Fat',fat,' g',S87.orange,Icons.water_drop,
          targets['Fat'])),const SizedBox(width:8),
        Expanded(child:_small('Fiber',fiber,' g',S87.purple,Icons.eco,
          targets['Fiber'])),
      ]),
      const SizedBox(height:24),
      S87Heading('Planned vs Eaten',action:'Meal planner',onTap:widget.onCalendar),
      const SizedBox(height:7),
      S87Panel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        S77PairedChart(left:planned,right:eaten,labels:labels,
          firstColor:S87.blue,secondColor:S87.green),
        const SizedBox(height:11),
        const Row(children:[Icon(Icons.circle,color:S87.blue,size:9),SizedBox(width:5),
          Text('Planned',style:TextStyle(color:S87.muted,fontSize:11)),
          SizedBox(width:13),Icon(Icons.circle,color:S87.green,size:9),SizedBox(width:5),
          Text('Logged',style:TextStyle(color:S87.muted,fontSize:11))]),
        const SizedBox(height:9),
        const Text('Planned recipe calories are estimates. Unlogged meals are not zero.',
          style:TextStyle(color:S87.muted,fontSize:10)),
      ])),
      const SizedBox(height:22),
      S87Heading("Today's Meals",action:'Calendar',onTap:widget.onCalendar),
      const SizedBox(height:6),
      for(final slot in salusMealSlots)_meal(log,plan,date,slot,
        slot=='Breakfast'?S87.orange:slot=='Lunch'?S87.green:
        slot=='Dinner'?S87.blue:S87.purple,
        slot=='Breakfast'?Icons.free_breakfast:slot=='Lunch'?Icons.lunch_dining:
        slot=='Dinner'?Icons.dinner_dining:Icons.cookie_outlined),
      const SizedBox(height:7),
      Row(children:[Expanded(child:OutlinedButton.icon(onPressed:widget.onJournal,
        icon:const Icon(Icons.add),label:const Text('Log food'))),
        const SizedBox(width:9),Expanded(child:FilledButton.icon(
          onPressed:widget.onDiscover,icon:const Icon(Icons.auto_awesome),
          label:const Text('Find meals')))]),
      const SizedBox(height:23),
      S87Heading('Goal Alignment',action:'Edit targets',onTap:_editGoals),
      const SizedBox(height:6),
      S87Panel(accent:S87.green,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Icon(Icons.track_changes,color:S87.green,size:28),
          const SizedBox(width:10),Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(_objective,style:const TextStyle(color:S87.ink,
                fontWeight:FontWeight.w700,fontSize:16)),
              const Text('Your nutrition goal',style:TextStyle(color:S87.muted,fontSize:11)),
            ])),
          Text(knownTargets.isEmpty?'—':'$aligned/${knownTargets.length}',
            style:const TextStyle(color:S87.green,fontSize:20,fontWeight:FontWeight.w700)),
        ]),
        if(_goals.isEmpty)const Padding(padding:EdgeInsets.only(top:13),
          child:Text('Set your calorie and macro targets to see comparisons.',
            style:TextStyle(color:S87.muted,fontSize:12))),
        const SizedBox(height:9),
        _goalRow('Calories',calories,targets['Calories'],S87.green),
        _goalRow('Protein',protein,targets['Protein'],S87.blue),
        _goalRow('Carbs',carbs,targets['Carbs'],S87.teal),
        _goalRow('Fat',fat,targets['Fat'],S87.orange),
        _goalRow('Fiber',fiber,targets['Fiber'],S87.purple),
      ])),
      const SizedBox(height:20),
      const S87PhotoBanner(asset:'assets/premium/nutrition_photo77.jpg',
        title:'Real food.\nReal progress.',
        caption:'Save meals and plan what comes next.',height:140),
      const SizedBox(height:12),
      SizedBox(width:double.infinity,child:FilledButton(onPressed:widget.onMeals,
        child:const Text('My saved meals'))),
    ]));
  }
}
