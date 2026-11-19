import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'region.dart';
import 'kma_service.dart';
import 'dart:ui' as ui;

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const SkyoraApp()); }
class SkyoraApp extends StatefulWidget { const SkyoraApp({super.key}); @override State<SkyoraApp> createState()=>_SkyoraAppState(); }
class _SkyoraAppState extends State<SkyoraApp> {
  bool dark=true;
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'SKYORA',debugShowCheckedModeBanner:false,
    themeMode:dark?ThemeMode.dark:ThemeMode.light,
    theme:ThemeData(useMaterial3:true,colorSchemeSeed:const Color(0xff7956dc),scaffoldBackgroundColor:const Color(0xffedf3fa)),
    darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:const Color(0xffa58aff),scaffoldBackgroundColor:const Color(0xff09162b),cardColor:const Color(0xff182a49)),
    home:WeatherPage(dark:dark,onTheme:()=>setState(()=>dark=!dark)));
}
class WeatherPage extends StatefulWidget {
  final bool dark;final VoidCallback onTheme;
  const WeatherPage({super.key,required this.dark,required this.onTheme});
  @override State<WeatherPage> createState()=>_WeatherPageState();
}
class _WeatherPageState extends State<WeatherPage> {
  List<Region> regions=[]; Region? selected; List<Forecast> forecasts=[];
  bool loading=false;String? error;int tab=0;String metric='기온';
  Set<String> favorites={};
  @override void initState(){super.initState();_initialize();}
  Future<void> _initialize() async {
    try {final list=await loadRegions();final prefs=await SharedPreferences.getInstance();
      final saved=prefs.getString('region');
      if(!mounted)return;
      setState((){regions=list;selected=list.firstWhere((r)=>r.code==saved,orElse:()=>list.first);favorites=prefs.getStringList('favorites')?.toSet()??{};});
      await _refresh();
    }catch(e){if(mounted)setState(()=>error='지역 DB 로드 실패: $e');}
  }
  Future<void> _refresh() async {
    if(selected==null)return;
    setState((){loading=true;error=null;});
    try{final result=await KmaService().fetchForecast(selected!);
      if(!mounted)return;setState((){forecasts=result;loading=false;if(result.isEmpty)error='현재 이용 가능한 예보가 없어.';});
    }catch(e){if(mounted)setState((){loading=false;forecasts=[];error=e.toString();});}
  }
  Future<void> _pickRegion() async {
    final chosen=await showSearch<Region?>(context:context,delegate:RegionSearch(regions));
    if(chosen==null||!mounted)return;
    final prefs=await SharedPreferences.getInstance();await prefs.setString('region',chosen.code);
    setState(()=>selected=chosen);await _refresh();
  }
  Future<void> _toggleFavorite() async {
    if(selected==null)return;final key=selected!.code;
    setState((){if(!favorites.add(key))favorites.remove(key);});
    final prefs=await SharedPreferences.getInstance();await prefs.setStringList('favorites',favorites.toList());
  }
  String _fmt(double? n,[String suffix=''])=>n==null?'—':'${n.toStringAsFixed(n%1==0?0:1)}$suffix';
  Widget _panel(String title,Widget child)=>Card(margin:const EdgeInsets.only(bottom:12),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:16)),const SizedBox(height:12),child])));
  Widget _home(){final first=forecasts.isNotEmpty?forecasts.first:null;
    return Column(children:[_panel('현재 선택 지역',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(selected?.label??'지역 불러오는 중'),const SizedBox(height:6),Text('기상청 단기예보 · 현재 실황 관측값과 다를 수 있어',style:Theme.of(context).textTheme.bodySmall)])),
      _panel('시간별 예보',forecasts.isEmpty?const Text('예보가 아직 없어. API 연결 상태를 확인해 줘.'):SizedBox(height:155,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:math.min(forecasts.length,16),separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(context,i){final f=forecasts[i];return Container(width:76,padding:const EdgeInsets.all(8),decoration:BoxDecoration(borderRadius:BorderRadius.circular(12),color:Theme.of(context).colorScheme.primary.withValues(alpha:.12)),child:Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[Text('${f.time.hour.toString().padLeft(2,'0')}:00'),const Icon(Icons.wb_cloudy_outlined),Text(_fmt(f.temp,'°'),style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text('비 ${_fmt(f.rainProbability,'%')}',style:const TextStyle(fontSize:11))]));}))),
      _panel('날씨 정보',Wrap(spacing:20,runSpacing:16,children:[_info('기온',_fmt(first?.temp,'°C')), _info('습도',_fmt(first?.humidity,'%')),_info('풍속',_fmt(first?.wind,'m/s')),_info('강수확률',_fmt(first?.rainProbability,'%'))])),]);}
  Widget _info(String title,String value)=>SizedBox(width:130,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:4),Text(value,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))]));
  double? _metric(Forecast f)=>switch(metric){'기온'=>f.temp,'습도'=>f.humidity,'풍속'=>f.wind,'강수확률'=>f.rainProbability,_=>f.temp};
  Widget _forecast(){return Column(children:[_panel('정밀 예보 그래프',Column(children:[SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:['기온','강수확률','습도','풍속'].map((m)=>Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(m),selected:metric==m,onSelected:(_)=>setState(()=>metric=m)))).toList())),const SizedBox(height:18),SizedBox(height:200,width:double.infinity,child:CustomPaint(painter:ForecastPainter(forecasts.take(16).map(_metric).toList(),Theme.of(context).colorScheme.primary))),const SizedBox(height:6),const Text('왼쪽부터 시간 순서 · 최대 16개 시점',style:TextStyle(fontSize:11))])),_panel('시간별 상세 데이터',Column(children:forecasts.take(24).map((f)=>ListTile(dense:true,contentPadding:EdgeInsets.zero,title:Text('${f.time.month}/${f.time.day} ${f.time.hour.toString().padLeft(2,'0')}:00'),subtitle:Text('습도 ${_fmt(f.humidity,'%')} · 강수확률 ${_fmt(f.rainProbability,'%')}'),trailing:Text(_fmt(f.temp,'°'),style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)))).toList()))]);}
  Widget _map(){final r=selected;return r==null?const Center(child:Text('지역 선택 필요')):_panel('지역 지도 · OpenStreetMap',Column(children:[SizedBox(height:330,child:FlutterMap(options:MapOptions(initialCenter:LatLng(r.lat,r.lon),initialZoom:10),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.example.skyora'),MarkerLayer(markers:[Marker(point:LatLng(r.lat,r.lon),width:48,height:48,child:const Icon(Icons.location_pin,color:Colors.purpleAccent,size:42))])])),const SizedBox(height:12),Text('기상 레이더·바람장 타일은 아직 미연결. 지도 배경만 제공해.',style:Theme.of(context).textTheme.bodySmall)]));}
  Widget _settings(){final r=selected;final g=r==null?null:toKmaGrid(r.lat,r.lon);return Column(children:[_panel('연결 정보',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('지역 DB: ${regions.length}개 항목'),Text('선택 좌표: ${r?.lat}, ${r?.lon}'),Text('기상청 격자: nx=${g?.nx??'—'}, ny=${g?.ny??'—'}'),Text('API 연결: ${error==null&&forecasts.isNotEmpty?'응답 수신':'연결 필요 / 오류'}'),const SizedBox(height:8),const Text('공개 API 인증키를 앱에 직접 포함하지 말고 서버 프록시를 사용해.',style:TextStyle(fontSize:12))])),_panel('즐겨찾기',Column(children:regions.where((r)=>favorites.contains(r.code)).map((r)=>ListTile(title:Text(r.label),onTap:()async{setState(()=>selected=r);final prefs=await SharedPreferences.getInstance();await prefs.setString('region',r.code);await _refresh();setState(()=>tab=0);})).toList())),_panel('앱 설정',SwitchListTile(title:const Text('다크 모드'),value:widget.dark,onChanged:(_)=>widget.onTheme()))]);}
  @override Widget build(BuildContext context){final first=forecasts.isNotEmpty?forecasts.first:null;return Scaffold(appBar:AppBar(title:const Text('✦ SKYORA',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(tooltip:'지역 검색',onPressed:_pickRegion,icon:const Icon(Icons.search)),IconButton(tooltip:'테마 전환',onPressed:widget.onTheme,icon:Icon(widget.dark?Icons.light_mode_outlined:Icons.dark_mode_outlined))]),body:RefreshIndicator(onRefresh:_refresh,child:ListView(padding:const EdgeInsets.all(14),children:[Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xff182b60),Color(0xff5c3c91)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[InkWell(onTap:_pickRegion,child:Row(children:[const Icon(Icons.location_on_outlined,color:Colors.white70,size:19),const SizedBox(width:5),Expanded(child:Text(selected?.label??'지역 선택',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600))),const Icon(Icons.expand_more,color:Colors.white)])),const SizedBox(height:15),Row(children:[Expanded(child:Text(_fmt(first?.temp,'°'),style:const TextStyle(color:Colors.white,fontSize:62,fontWeight:FontWeight.w300))),const Icon(Icons.cloud_outlined,size:65,color:Colors.white)]),const Text('기상청 단기예보',style:TextStyle(color:Colors.white70)),const SizedBox(height:8),Row(children:[const Text('SKYORA · ',style:TextStyle(color:Colors.white70,fontSize:12)),Text(first==null?'데이터 미연결':'${first.time.month}/${first.time.day} ${first.time.hour}:00 예보',style:const TextStyle(color:Colors.white70,fontSize:12)),const Spacer(),IconButton(onPressed:_toggleFavorite,icon:Icon(selected!=null&&favorites.contains(selected!.code)?Icons.star:Icons.star_border,color:Colors.amber))])])),if(loading)const LinearProgressIndicator(),if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(error!,style:const TextStyle(fontSize:12)),TextButton(onPressed:_refresh,child:const Text('다시 시도'))])))),const SizedBox(height:14),switch(tab){0=>_home(),1=>_forecast(),2=>_map(),_=>_settings()}])),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.home_outlined),label:'홈'),NavigationDestination(icon:Icon(Icons.show_chart),label:'정밀예보'),NavigationDestination(icon:Icon(Icons.map_outlined),label:'지도'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'설정')]));}
}
class RegionSearch extends SearchDelegate<Region?> {
  final List<Region> regions;RegionSearch(this.regions);
  @override List<Widget> buildActions(BuildContext context)=>[IconButton(onPressed:()=>query='',icon:const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context)=>IconButton(onPressed:()=>close(context,null),icon:const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context)=>_list();
  @override Widget buildSuggestions(BuildContext context)=>_list();
  Widget _list(){final q=query.replaceAll(' ','').toLowerCase();final hits=regions.where((r)=>r.label.replaceAll(' ','').toLowerCase().contains(q)).take(100).toList();return ListView.builder(itemCount:hits.length,itemBuilder:(context,i){final r=hits[i];return ListTile(leading:const Icon(Icons.place_outlined),title:Text(r.label),subtitle:Text('격자 ${toKmaGrid(r.lat,r.lon).nx}, ${toKmaGrid(r.lat,r.lon).ny}'),onTap:()=>close(context,r));});}
}
class ForecastPainter extends CustomPainter {
  final List<double?> values;final Color color;ForecastPainter(this.values,this.color);
  @override void paint(Canvas canvas,Size size){final paint=Paint()..color=color..strokeWidth=3..style=PaintingStyle.stroke..strokeCap=StrokeCap.round;
    final valid=values.whereType<double>().toList();if(valid.length<2)return;
    final lo=valid.reduce(math.min),hi=valid.reduce(math.max);final span=(hi-lo).abs()<.001?1.0:hi-lo;
    final path=ui.Path();bool started=false;
    for(int i=0;i<values.length;i++){final v=values[i];if(v==null){started=false;continue;}final x=12+(size.width-24)*i/(values.length-1);final y=15+(size.height-30)*(1-(v-lo)/span);if(!started){path.moveTo(x,y);started=true;}else{path.lineTo(x,y);}canvas.drawCircle(Offset(x,y),3,Paint()..color=color);}
    canvas.drawPath(path,paint);
  }
  @override bool shouldRepaint(covariant ForecastPainter old)=>old.values!=values||old.color!=color;
}
