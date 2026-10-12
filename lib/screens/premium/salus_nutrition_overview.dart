// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_meal_planner_service.dart';
import '../../state/diet_log_state.dart';
import '../../state/today_plan_state.dart';
import '../../widgets/salus_premium_ui.dart';
import '../../widgets/salus_premium_visuals.dart';
import '../../widgets/module_menu_button.dart';
import '../diet/food_visual_overview.dart';

/// All nutrition figures are actual food log values. Planned meals are never
/// counted as eaten. AI-estimated recipe nutrients are shown as estimates.
class SalusNutritionOverview extends ConsumerStatefulWidget {
  SalusNutritionOverview({super.key,required this.onDiscover,required this.onCalendar,required this.onMeals,required this.onJournal});
  final VoidCallback onDiscover,onCalendar,onMeals,onJournal;
  @override ConsumerState<SalusNutritionOverview> createState()=>_SalusNutritionOverviewState();
}
class _SalusNutritionOverviewState extends ConsumerState<SalusNutritionOverview> {
  final _service=SalusMealPlannerService();
  Map<String,SalusMealIdea> _recipes={};
  Map<String,double> _goals={};
  String _objective='Balanced';
  int _offset=0;
  @override void initState(){super.initState();SalusAppearance.load();_load();}
  Future<void> _load() async {
    try{
      final recipes=await _service.loadRecipeAssignments();
      final prefs=await SharedPreferences.getInstance();
      final goals=<String,double>{};
      for(final key in ['Calories','Protein','Carbs','Fat','Fiber']){
        final value=prefs.getDouble('salus_nutrition_target_$key');
        if(value!=null&&value>0)goals[key]=value;
      }
      final saved=prefs.getString('salus_nutrition_objective_v1')??'Balanced';
      if(mounted)setState((){_recipes=recipes;_goals=goals;_objective=saved;});
    }catch(_){/* Keep the journal usable if optional settings fail. */}
  }
  Future<void> _editGoals() async {
    final controllers={for(final key in ['Calories','Protein','Carbs','Fat','Fiber'])key:TextEditingController(text:_goals[key]?.toStringAsFixed(0)??'')};
    var goal=_objective;
    final changed=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:Text('Nutrition goals'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButtonFormField<String>(initialValue:goal,items:[for(final o in ['Balanced','Fat loss','Muscle gain','Maintenance'])DropdownMenuItem(value:o,child:Text(o))],
          onChanged:(v){if(v!=null)setDialog(()=>goal=v);},decoration:InputDecoration(labelText:'Primary goal')),
        SizedBox(height:8),for(final entry in controllers.entries)Padding(padding:const EdgeInsets.symmetric(vertical:4),child:TextField(controller:entry.value,keyboardType:const TextInputType.numberWithOptions(decimal:true),
          decoration:InputDecoration(labelText:'${entry.key} target (${entry.key=='Calories'?'kcal':'g'})',hintText:'Leave blank if unset'))),
        Text('Targets are user-controlled. Missing targets will not be invented.',style:TextStyle(fontSize:11)),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Save'))])));
    if(changed==true){
      final next=<String,double>{};
      for(final item in controllers.entries){final v=double.tryParse(item.value.text.trim());if(v!=null&&v>0&&v<10000)next[item.key]=v;}
      final prefs=await SharedPreferences.getInstance();
      for(final key in controllers.keys){if(next.containsKey(key)){await prefs.setDouble('salus_nutrition_target_$key',next[key]!);}else{await prefs.remove('salus_nutrition_target_$key');}}
      await prefs.setString('salus_nutrition_objective_v1',goal);
      if(mounted)setState((){_goals=next;_objective=goal;});
    }
    for(final c in controllers.values){c.dispose();}
  }
  DateTime get _date=>DateTime.now().add(Duration(days:_offset));
  double? _total(DietLogState log,DateTime day,String key)=>switch(key){
    'Calories'=>log.knownTotal(day,(e)=>e.calories),
    'Protein'=>log.knownTotal(day,(e)=>e.protein),
    'Carbs'=>log.knownTotal(day,(e)=>e.carbs),
    'Fat'=>log.knownTotal(day,(e)=>e.fat),
    'Fiber'=>log.knownTotal(day,(e)=>e.fiber),
    _=>null,
  };
  /// Partial plans are not presented as whole-day calorie totals.
  double? _plannedKcal(DateTime day,Map<String,String> planned){
    if(planned.isEmpty)return null;
    var sum=0.0;
    for(final entry in planned.entries){
      final recipe=_recipes['${salusDayKey(day)}|${entry.key}'];
      if(recipe==null||recipe.name!=entry.value||recipe.calories==null)return null;
      sum+=recipe.calories!;
    }
    return sum;
  }
  double? _plannedMacro(DateTime day,Map<String,String> planned,String metric){
    if(planned.isEmpty)return null;
    var result=0.0;
    for(final entry in planned.entries){
      final meal=_recipes['${salusDayKey(day)}|${entry.key}'];
      if(meal==null||meal.name!=entry.value)return null;
      final value=switch(metric){
        'Calories'=>meal.calories,'Protein'=>meal.protein,
        'Carbs'=>meal.carbs,'Fat'=>meal.fat,'Fiber'=>meal.fiber,_=>null,
      };
      if(value==null)return null;
      result+=value;
    }
    return result;
  }
  @override Widget build(BuildContext context)=>ValueListenableBuilder<bool>(valueListenable:SalusAppearance.light,
    builder:(context,light,_){final p=SalusSkin(light),log=ref.watch(dietLogStateProvider),plans=ref.watch(todayPlanStateProvider);
      final date=_date,foods=log.forDay(date),planned=plans.mealsFor(date);
      final kcal=_total(log,date,'Calories'),protein=_total(log,date,'Protein'),carbs=_total(log,date,'Carbs'),fat=_total(log,date,'Fat'),fiber=_total(log,date,'Fiber');
      final macroKnown=protein!=null&&carbs!=null&&fat!=null;
      final macros=macroKnown?[protein*4,carbs*4,fat*9]:<double>[];
      final past=[for(var i=6;i>=0;i--)DateTime.now().subtract(Duration(days:i))];
      return ColoredBox(color:p.canvas,child:ListView(padding:const EdgeInsets.fromLTRB(16,17,16,35),children:[
        Row(children:[Expanded(child:SalusHeading('Nutrition',caption:'YOUR FOOD & YOUR GOALS')),
          HealthyMeModuleMenuButton(current:HealthyMeModule.diet,onSelected:(m){switch(m){
            case HealthyMeModule.fitness:Navigator.of(context).popUntil((r)=>r.isFirst);break;
            case HealthyMeModule.workout:Navigator.of(context).pushReplacementNamed('/workout');break;
            case HealthyMeModule.diet:break;
            case HealthyMeModule.health:Navigator.of(context).pushReplacementNamed('/health');break;
          }}),PremiumThemeButton()]),
        SizedBox(height:12),Row(children:[IconButton(onPressed:()=>setState(()=>_offset--),icon:Icon(Icons.chevron_left,color:p.accent)),
          Expanded(child:Center(child:Text(_offset==0?'Today · ${date.month}/${date.day}/${date.year}':'${date.month}/${date.day}/${date.year}',style:TextStyle(color:p.ink,fontWeight:FontWeight.w700)))),
          IconButton(onPressed:_offset>=0?null:()=>setState(()=>_offset++),icon:Icon(Icons.chevron_right,color:p.accent))]),
        SizedBox(height:10),PremiumCard(child:Column(children:[
          Row(children:[
            SalusMacroRing(protein:protein,carbs:carbs,fat:fat,kcal:kcal,target:_goals['Calories'],size:143),
            SizedBox(width:20),Expanded(child:Column(children:[
              _inlineMacro(p,'Protein',protein,SalusSkin.green),SizedBox(height:9),
              _inlineMacro(p,'Carbs',carbs,SalusSkin.aqua),SizedBox(height:9),
              _inlineMacro(p,'Fat',fat,SalusSkin.orange),
            ])),
          ]),SizedBox(height:13),
          if(macroKnown&&macros.reduce((a,b)=>a+b)>0)ClipRRect(borderRadius:BorderRadius.circular(8),child:Row(children:[
            for(var i=0;i<3;i++)Expanded(flex:math.max(1,macros[i].round()),child:Container(height:9,color:[SalusSkin.green,SalusSkin.aqua,SalusSkin.orange][i])),
          ]))else Text('Macro distribution needs protein, carbs and fat entries.',style:TextStyle(color:p.muted,fontSize:11)),
          if(foods.isNotEmpty&&log.incomplete(date,(f)=>f.calories))Padding(padding:const EdgeInsets.only(top:8),child:Text('Some foods have unknown calories; total is incomplete.',style:TextStyle(color:p.secondary,fontSize:11))),
        ])),
        SizedBox(height:12),Row(children:[
          Expanded(child:_quickKpi('Calories',kcal,'kcal',SalusV.orange,Icons.local_fire_department)),SizedBox(width:8),
          Expanded(child:_quickKpi('Protein',protein,'g',SalusV.green,Icons.fitness_center)),SizedBox(width:8),
          Expanded(child:_quickKpi('Carbs',carbs,'g',SalusV.blue,Icons.grain)),
        ]),SizedBox(height:10),Row(children:[
          Expanded(child:_quickKpi('Fat',fat,'g',SalusV.red,Icons.water_drop)),SizedBox(width:8),
          Expanded(child:_quickKpi('Fiber',fiber,'g',SalusV.purple,Icons.eco)),
        ]),
        SizedBox(height:12),PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Icon(Icons.eco_outlined,color:SalusSkin.green),SizedBox(width:8),Text('Fiber',style:TextStyle(color:p.ink,fontSize:16,fontWeight:FontWeight.w700))]),
          PremiumProgress(label:'Logged fiber',value:fiber,target:_goals['Fiber'],color:SalusSkin.green),
          if(log.incomplete(date,(e)=>e.fiber))Text('Some logged foods have no fiber information.',style:TextStyle(color:p.secondary,fontSize:11)),
        ])),
        SizedBox(height:13),PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('$_objective · Goal alignment',style:TextStyle(color:p.ink,fontWeight:FontWeight.w800,fontSize:16))),
            TextButton(onPressed:_editGoals,child:Text('Set targets'))]),
          Text(_insight(log,date),style:TextStyle(color:p.secondary,fontSize:13,height:1.45)),
          if(_goals.isNotEmpty) ...[
            SizedBox(height:8),PremiumProgress(label:'Protein',value:protein,target:_goals['Protein'],color:SalusSkin.green),
            PremiumProgress(label:'Carbohydrates',value:carbs,target:_goals['Carbs'],color:SalusSkin.aqua),
            PremiumProgress(label:'Fat',value:fat,target:_goals['Fat'],color:SalusSkin.orange),
          ],
        ])),
        SizedBox(height:13),PremiumCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:Text('Your planned meals',style:TextStyle(color:p.ink,fontSize:16,fontWeight:FontWeight.w800))),
            TextButton(onPressed:widget.onCalendar,child:Text('Edit plan'))]),
          Text(planned.isEmpty?'No meals planned for this date.':'${planned.length} of 4 meal slots planned',style:TextStyle(color:p.secondary,fontSize:12)),
          SizedBox(height:9),Row(children:[
            Expanded(child:_planValue(p,'Energy',_plannedMacro(date,planned,'Calories'),'kcal')),
            Expanded(child:_planValue(p,'Protein',_plannedMacro(date,planned,'Protein'),'g')),
            Expanded(child:_planValue(p,'Carbs',_plannedMacro(date,planned,'Carbs'),'g')),
          ]),SizedBox(height:7),Text(planned.isEmpty?'Use the calendar or Find Meals to start a plan.':
            'AI recipe estimates only. A dash means an assigned recipe lacks complete information. Your actual intake is recorded separately.',
            style:TextStyle(color:p.muted,fontSize:11)),
          if(_goals['Protein']!=null&&_plannedMacro(date,planned,'Protein')!=null)
            Padding(padding:const EdgeInsets.only(top:6),child:Text(
              _plannedMacro(date,planned,'Protein')!<_goals['Protein']! ?
              'Planned protein is ${(_goals['Protein']!-_plannedMacro(date,planned,'Protein')!).round()} g short of your chosen target across the assigned recipes.':
              'The currently planned recipes reach your chosen protein target on estimated values.',
              style:TextStyle(color:p.accent,fontSize:12,fontWeight:FontWeight.w600))),
        ])),
        SizedBox(height:20),PremiumSection(title:'Planned vs eaten · 7 days'),SizedBox(height:8),
        PremiumCard(child:Column(children:[SizedBox(height:130,child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
          for(final d in past)Expanded(child:_dayBar(p,d,_plannedKcal(d,plans.mealsFor(d)),_total(log,d,'Calories'),_goals['Calories'])),
        ])),SizedBox(height:7),Row(mainAxisAlignment:MainAxisAlignment.center,children:[_legend(p,SalusSkin.blue,'Planned, if complete'),SizedBox(width:16),_legend(p,SalusSkin.green,'Logged')]),
        SizedBox(height:7),Text('Planned recipe figures are AI estimates; missing nutrition is never filled in.',textAlign:TextAlign.center,style:TextStyle(color:p.muted,fontSize:10)),
        ])),
        SizedBox(height:14),SalusGlass(glow:SalusV.green,onTap:widget.onDiscover,child:Row(children:[
 ClipRRect(borderRadius:BorderRadius.circular(11),child:Image.asset('assets/premium/meal_illustration.jpg',width:64,height:64,fit:BoxFit.cover)),
 SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('Find meals that fit your goals',style:TextStyle(color:SalusV.ink,fontWeight:FontWeight.w800,fontSize:13)),
 SizedBox(height:5),Text('Illustration · browse recipe ideas, not your food log',style:TextStyle(color:SalusV.secondary,fontSize:10))])),
 Icon(Icons.chevron_right,color:SalusV.cyan)])),
SizedBox(height:20),PremiumSection(title:"Today's meals",trailing:'Calendar',onTap:widget.onCalendar),
        SizedBox(height:8),for(final slot in salusMealSlots)...[
          PremiumCard(onTap:widget.onJournal,child:Row(children:[
            if(foods.where((f)=>f.slot==slot&&f.imageUrl.trim().isNotEmpty).isNotEmpty)
              FoodPicture(imageUrl:foods.firstWhere((f)=>f.slot==slot&&f.imageUrl.trim().isNotEmpty).imageUrl,size:46)
            else Icon(_slotIcon(slot),color:p.accent,size:27),
            SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(slot,style:TextStyle(color:p.ink,fontWeight:FontWeight.w800)),
              SizedBox(height:4),Text(foods.where((f)=>f.slot==slot).isEmpty?'Nothing logged':foods.where((f)=>f.slot==slot).map((f)=>f.name).join(' · '),maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:p.secondary,fontSize:12)),
              if((planned[slot]??'').isNotEmpty)Text('Planned: ${planned[slot]}',maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:p.muted,fontSize:11)),
            ])),SizedBox(width:6),Icon(Icons.chevron_right,color:p.muted),
          ])),SizedBox(height:8),
        ],
        SizedBox(height:12),Row(children:[Expanded(child:OutlinedButton.icon(onPressed:widget.onJournal,icon:Icon(Icons.add),label:Text('Log food'))),SizedBox(width:8),Expanded(child:FilledButton.icon(onPressed:widget.onDiscover,icon:Icon(Icons.auto_awesome),label:Text('Find meals')))]),
      ]));
    });
  String _insight(DietLogState log,DateTime date){
    final protein=_total(log,date,'Protein'),target=_goals['Protein'];
    if(log.forDay(date).isEmpty)return 'No food logged for this date. Add meals to see whether your intake supports your goal.';
    if(target==null)return 'Set a personal protein and calorie target to compare recorded intake with your $_objective goal. Planned food is not counted as eaten.';
    if(protein==null)return 'Protein data is missing. Check portions and nutrient details before drawing conclusions about your $_objective plan.';
    if(protein<target)return 'Logged protein is ${(target-protein).round()} g below your selected target so far. Review later meals for a protein-rich option; this is not a full-day prediction.';
    return 'Your logged protein has reached your selected target. Review total calories, fiber, and training alongside this result.';
  }
  Widget _quickKpi(String name,double? value,String unit,Color color,IconData icon)=>
    SalusGlass(glow:color,padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:color,size:19),SizedBox(height:7),
      Text(name,style:TextStyle(color:SalusV.secondary,fontSize:11)),
      Text(value==null?'—':'${value.round()} $unit',style:TextStyle(color:SalusV.ink,fontSize:15,fontWeight:FontWeight.w900))]));
  Widget _planValue(SalusSkin p,String label,double? value,String unit)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(label,style:TextStyle(color:p.secondary,fontSize:11)),SizedBox(height:4),
    Text(value==null?'—':'${value.round()} $unit',style:TextStyle(color:p.ink,fontSize:16,fontWeight:FontWeight.w800)),
  ]);
  Widget _inlineMacro(SalusSkin p,String label,double? amount,Color c)=>Row(children:[Container(width:9,height:9,decoration:BoxDecoration(shape:BoxShape.circle,color:c)),SizedBox(width:9),Expanded(child:Text(label,style:TextStyle(color:p.secondary,fontSize:13))),Text(amount==null?'—':'${amount.round()} g',style:TextStyle(color:p.ink,fontSize:14,fontWeight:FontWeight.w800))]);
  Widget _legend(SalusSkin p,Color color,String caption)=>Row(children:[Container(width:8,height:8,color:color),SizedBox(width:5),Text(caption,style:TextStyle(color:p.secondary,fontSize:10))]);
  Widget _dayBar(SalusSkin p,DateTime d,double? planned,double? logged,double? goal){
    final scale=math.max(1,math.max(goal??0,math.max(planned??0,logged??0)));const maxHeight=95.0;
    Widget bar(double? v,Color color)=>Expanded(child:Align(alignment:Alignment.bottomCenter,child:Container(height:v==null?2:(v/scale*maxHeight).clamp(2,maxHeight),decoration:BoxDecoration(color:v==null?p.track:color,borderRadius:const BorderRadius.vertical(top:Radius.circular(4))))));
    const days=['M','T','W','T','F','S','S'];
    return Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:Column(children:[Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.end,children:[bar(planned,SalusSkin.blue),SizedBox(width:2),bar(logged,SalusSkin.green)])),
      SizedBox(height:6),Text(days[d.weekday-1],style:TextStyle(color:p.secondary,fontSize:10))]));
  }
  IconData _slotIcon(String slot)=>switch(slot){'Breakfast'=>Icons.breakfast_dining,'Lunch'=>Icons.lunch_dining,'Dinner'=>Icons.dinner_dining,_=>Icons.cookie_outlined};
}
