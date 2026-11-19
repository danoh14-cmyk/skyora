import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'region.dart';
import 'kma_service.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const SkyoraApp()); }

const _navy = Color(0xFF081329);
const _purple = Color(0xFF9B80F5);

class SkyoraApp extends StatefulWidget {
  const SkyoraApp({super.key});
  @override State<SkyoraApp> createState() => _SkyoraAppState();
}
class _SkyoraAppState extends State<SkyoraApp> {
  bool dark = true;
  @override void initState() { super.initState(); _loadTheme(); }
  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => dark = p.getBool('dark_mode') ?? true);
  }
  Future<void> _toggleTheme() async {
    setState(() => dark = !dark);
    (await SharedPreferences.getInstance()).setBool('dark_mode', dark);
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'SKYORA', debugShowCheckedModeBanner: false,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF7255C9),
      scaffoldBackgroundColor: const Color(0xFFF2F4FA)),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      colorSchemeSeed: _purple, scaffoldBackgroundColor: _navy,
      cardColor: const Color(0xFF18243B)),
    home: WeatherPage(dark: dark, onTheme: _toggleTheme),
  );
}

class WeatherPage extends StatefulWidget {
  final bool dark;
  final VoidCallback onTheme;
  const WeatherPage({super.key, required this.dark, required this.onTheme});
  @override State<WeatherPage> createState() => _WeatherPageState();
}
class _WeatherPageState extends State<WeatherPage> {
  List<Region> regions = [];
  Region? selected;
  List<Forecast> forecasts = [];
  Set<String> favorites = {};
  DateTime? lastUpdated;
  String? error;
  bool loading = false;
  int tab = 0;
  String metric = '기온';

  @override void initState() { super.initState(); _initialize(); }
  Future<void> _initialize() async {
    try {
      final loaded = await loadRegions();
      if (loaded.isEmpty) throw StateError('지역 목록이 비어 있어.');
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        regions = loaded;
        selected = loaded.firstWhere((r) => r.code == prefs.getString('region'), orElse: () => loaded.first);
        favorites = prefs.getStringList('favorites')?.toSet() ?? {};
      });
      await _refresh();
    } catch (e) { if (mounted) setState(() => error = '지역 DB 로드 실패: $e'); }
  }
  Future<void> _refresh() async {
    final r = selected;
    if (r == null) return;
    setState(() { loading = true; error = null; });
    try {
      final fetched = await KmaService().fetchForecast(r);
      if (!mounted || selected?.code != r.code) return;
      final now = DateTime.now();
      setState(() {
        forecasts = fetched.where((f) => !f.time.isBefore(now.subtract(const Duration(minutes: 30)))).toList();
        lastUpdated = now;
        loading = false;
        if (forecasts.isEmpty) error = '현재 시각 이후 예보가 없어. 잠시 후 다시 시도해 줘.';
      });
    } catch (e) {
      if (!mounted || selected?.code != r.code) return;
      setState(() { loading = false; error = e.toString(); forecasts = []; });
    }
  }
  Future<void> _selectRegion(Region r) async {
    setState(() { selected = r; forecasts = []; tab = 0; });
    (await SharedPreferences.getInstance()).setString('region', r.code);
    await _refresh();
  }
  Future<void> _pickRegion() async {
    if (regions.isEmpty) return;
    final chosen = await showSearch<Region?>(context: context, delegate: RegionSearch(regions, favorites));
    if (chosen != null && mounted) await _selectRegion(chosen);
  }
  Future<void> _toggleFavorite() async {
    final r = selected; if (r == null) return;
    setState(() { if (!favorites.add(r.code)) favorites.remove(r.code); });
    (await SharedPreferences.getInstance()).setStringList('favorites', favorites.toList());
  }
  String _num(double? n, [String unit = '']) => n == null ? '—' : '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}$unit';
  String _hour(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:00';
  bool _night(DateTime t) => t.hour < 6 || t.hour >= 19;
  IconData _weatherIcon(Forecast? f) {
    if (f == null) return Icons.cloud_outlined;
    if (f.isSnow) return Icons.ac_unit_rounded;
    if (f.isRain) return Icons.water_drop_rounded;
    if (f.sky == 1) return _night(f.time) ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded;
    if (f.sky == 3) return Icons.cloud_queue_rounded;
    return Icons.cloud_rounded;
  }
  Color get _card => widget.dark ? const Color(0xFF17243B) : Colors.white;
  Widget _panel(String title, Widget child, {Widget? trailing}) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22),
      border: Border.all(color: widget.dark ? Colors.white.withValues(alpha: .05) : const Color(0xFFE7E9F2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), if (trailing != null) trailing]),
      const SizedBox(height: 16), child,
    ]),
  );
  Widget _stat(IconData icon, String label, String value) => Row(children: [
    Icon(icon, size: 22, color: _purple), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
    ])),
  ]);
  Widget _hero() {
    final first = forecasts.isEmpty ? null : forecasts.first;
    return Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF152C5A), Color(0xFF413A86), Color(0xFF7C4DAD)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(onTap: _pickRegion, child: Row(children: [const Icon(Icons.location_on_outlined, color: Colors.white70, size: 20),
          const SizedBox(width: 6), Expanded(child: Text(selected?.label ?? '지역 선택', maxLines: 2,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white)])),
        const SizedBox(height: 22),
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_num(first?.temp, '°'), style: const TextStyle(fontSize: 66, fontWeight: FontWeight.w300, color: Colors.white, height: 1)),
          const SizedBox(height: 7), Text(first?.condition ?? '예보 불러오는 중', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        ])), Icon(_weatherIcon(first), size: 78, color: Colors.white)]),
        const SizedBox(height: 20),
        Row(children: [Expanded(child: Text(first == null ? '기상청 단기예보' : '${first.time.month}/${first.time.day} ${_hour(first.time)} 예보',
          style: const TextStyle(color: Colors.white70, fontSize: 12))),
          IconButton(onPressed: _toggleFavorite, tooltip: '즐겨찾기', icon: Icon(
            selected != null && favorites.contains(selected!.code) ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFFFD56B)))])
      ]),
    );
  }
  Widget _hourly() => _panel('시간별 예보', forecasts.isEmpty
    ? const Text('예보 데이터가 아직 없어.')
    : SizedBox(height: 164, child: ListView.separated(scrollDirection: Axis.horizontal,
      itemCount: math.min(forecasts.length, 24), separatorBuilder: (_, __) => const SizedBox(width: 9),
      itemBuilder: (context, i) {
        final f = forecasts[i];
        return Container(width: 88, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          decoration: BoxDecoration(color: _purple.withValues(alpha: .12), borderRadius: BorderRadius.circular(17)),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_hour(f.time), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            Icon(_weatherIcon(f), color: _purple, size: 30),
            Text(_num(f.temp, '°'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('비 ${_num(f.rainProbability, '%')}', style: const TextStyle(fontSize: 11)),
          ]));
      })), trailing: const Icon(Icons.swipe, size: 17));
  Widget _daily() {
    final days = <DateTime, List<Forecast>>{};
    for (final f in forecasts) {
      final key = DateTime(f.time.year, f.time.month, f.time.day);
      days.putIfAbsent(key, () => []).add(f);
    }
    if (days.isEmpty) return _panel('날짜별 예보', const Text('예보가 아직 없어.'));
    return _panel('날짜별 예보', Column(children: days.entries.take(4).map((e) {
      final temps = e.value.map((f) => f.temp).whereType<double>().toList();
      final pops = e.value.map((f) => f.rainProbability).whereType<double>().toList();
      final representative = e.value.firstWhere((f) => f.isRain || f.isSnow, orElse: () => e.value.first);
      final day = e.key;
      return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [
        SizedBox(width: 58, child: Text('${day.month}/${day.day}', style: const TextStyle(fontWeight: FontWeight.w700))),
        Icon(_weatherIcon(representative), color: _purple, size: 25), const SizedBox(width: 10),
        Expanded(child: Text(representative.condition, style: const TextStyle(fontSize: 12))),
        Text('비 ${pops.isEmpty ? '—' : '${pops.reduce(math.max).round()}%'}', style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 10),
        Text(temps.isEmpty ? '—' : '${temps.reduce(math.min).round()}° / ${temps.reduce(math.max).round()}°',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ]));
    }).toList()), trailing: const Text('예보 구간 기준', style: TextStyle(fontSize: 10)));
  }
  Widget _home() {
    final first = forecasts.isEmpty ? null : forecasts.first;
    return Column(children: [
      _hourly(), _daily(),
      _panel('상세 날씨 정보', GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2, mainAxisSpacing: 18, childAspectRatio: 2.5,
        children: [
          _stat(Icons.thermostat_outlined, '예보 기온', _num(first?.temp, '°C')),
          _stat(Icons.water_drop_outlined, '습도', _num(first?.humidity, '%')),
          _stat(Icons.air_rounded, '풍속', _num(first?.wind, ' m/s')),
          _stat(Icons.umbrella_outlined, '강수확률', _num(first?.rainProbability, '%')),
        ])),
      Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('기상청 단기예보 기준 · 실황 관측값 및 일 최저·최고 공식 예보와 다를 수 있어',
        textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)),
    ]);
  }
  double? _metricValue(Forecast f) => switch (metric) {
    '습도' => f.humidity, '강수확률' => f.rainProbability, '풍속' => f.wind, _ => f.temp,
  };
  Widget _forecast() {
    final slice = forecasts.take(24).toList();
    return Column(children: [
      _panel('정밀 예보 그래프', Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final name in ['기온', '강수확률', '습도', '풍속'])
            Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
              label: Text(name), selected: metric == name, onSelected: (_) => setState(() => metric = name))),
        ])),
        const SizedBox(height: 20),
        SizedBox(height: 205, width: double.infinity,
          child: CustomPaint(painter: ForecastPainter(slice.map(_metricValue).toList(), _purple))),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(slice.isEmpty ? '—' : '${slice.first.time.month}/${slice.first.time.day} ${_hour(slice.first.time)}', style: const TextStyle(fontSize: 11)),
          Text(slice.isEmpty ? '—' : '${slice.last.time.month}/${slice.last.time.day} ${_hour(slice.last.time)}', style: const TextStyle(fontSize: 11)),
        ]),
      ])),
      _panel('시간별 상세 예보', Column(children: slice.map((f) => Column(children: [
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(_weatherIcon(f), color: _purple),
          title: Text('${f.time.month}/${f.time.day} ${_hour(f.time)}'),
          subtitle: Text('${f.condition} · 습도 ${_num(f.humidity, '%')} · 비 ${_num(f.rainProbability, '%')}'),
          trailing: Text(_num(f.temp, '°'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        const Divider(height: 1),
      ])).toList())),
    ]);
  }
  Widget _map() {
    final r = selected;
    if (r == null) return _panel('지역 지도', const Text('지역을 먼저 선택해 줘.'));
    return _panel('선택 지역 지도', Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 340,
        child: FlutterMap(key: ValueKey(r.code), options: MapOptions(initialCenter: LatLng(r.lat, r.lon), initialZoom: 10), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.skyora.weather'),
          MarkerLayer(markers: [Marker(point: LatLng(r.lat, r.lon), width: 48, height: 48,
            child: const Icon(Icons.location_pin, size: 43, color: _purple))]),
        ]))),
      const SizedBox(height: 12),
      Text('지도: OpenStreetMap · 기상 레이더/바람장 오버레이는 아직 제공하지 않아.',
        style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
  Widget _settings() {
    final r = selected;
    final grid = r == null ? null : toKmaGrid(r.lat, r.lon);
    final saved = regions.where((item) => favorites.contains(item.code)).toList();
    return Column(children: [
      _panel('앱 설정', SwitchListTile(contentPadding: EdgeInsets.zero,
        title: const Text('다크 모드'), subtitle: const Text('테마 설정 저장'),
        value: widget.dark, onChanged: (_) => widget.onTheme())),
      _panel('즐겨찾는 지역', saved.isEmpty ? const Text('홈 화면의 별을 눌러 지역을 추가해 줘.') :
        Column(children: saved.map((item) => ListTile(contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.star, color: Color(0xFFFFC857)), title: Text(item.label),
          onTap: () => _selectRegion(item))).toList())),
      _panel('데이터 및 연결', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('지역 DB: ${regions.length}개 (제공된 샘플 DB 기준)'),
        Text('선택 지역: ${r?.label ?? '없음'}'),
        Text('기상청 격자: ${grid == null ? '—' : '${grid.nx}, ${grid.ny}'}'),
        Text('예보 상태: ${forecasts.isNotEmpty ? '수신 성공' : '미수신'}'),
        Text('마지막 갱신: ${lastUpdated == null ? '—' : '${lastUpdated!.month}/${lastUpdated!.day} ${_hour(lastUpdated!)}'}'),
        const SizedBox(height: 10),
        const Text('기상청 인증키는 Cloudflare Worker Secret에만 저장해. 앱에는 프록시 주소만 포함돼.',
          style: TextStyle(fontSize: 12)),
      ])),
    ]);
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('✦ SKYORA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .4)),
      actions: [IconButton(tooltip: '지역 검색', onPressed: _pickRegion, icon: const Icon(Icons.search_rounded)),
        IconButton(tooltip: '테마 전환', onPressed: widget.onTheme,
          icon: Icon(widget.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined))]),
    body: RefreshIndicator(onRefresh: _refresh, child: ListView(
      physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
        _hero(),
        if (loading) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
        if (error != null) _panel('데이터 연결 안내', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(error!, style: const TextStyle(fontSize: 12)),
          TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('다시 시도')),
        ])),
        switch (tab) { 0 => _home(), 1 => _forecast(), 2 => _map(), _ => _settings() },
      ])),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
        NavigationDestination(icon: Icon(Icons.show_chart_rounded), label: '정밀예보'),
        NavigationDestination(icon: Icon(Icons.map_outlined), label: '지도'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
      ]),
  );
}

class RegionSearch extends SearchDelegate<Region?> {
  final List<Region> regions;
  final Set<String> favorites;
  RegionSearch(this.regions, this.favorites);
  @override String get searchFieldLabel => '시·군·구·읍·면·동 검색';
  @override List<Widget> buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context) => _results();
  @override Widget buildSuggestions(BuildContext context) => _results();
  Widget _results() {
    final q = query.replaceAll(' ', '').toLowerCase();
    final matching = regions.where((r) => r.label.replaceAll(' ', '').toLowerCase().contains(q)).toList();
    matching.sort((a, b) {
      final af = favorites.contains(a.code) ? 0 : 1;
      final bf = favorites.contains(b.code) ? 0 : 1;
      return af != bf ? af.compareTo(bf) : a.label.compareTo(b.label);
    });
    final hits = matching.take(100).toList();
    return ListView.builder(itemCount: hits.length, itemBuilder: (context, i) {
      final r = hits[i]; final grid = toKmaGrid(r.lat, r.lon);
      return ListTile(leading: Icon(favorites.contains(r.code) ? Icons.star : Icons.place_outlined),
        title: Text(r.label), subtitle: Text('기상청 격자 ${grid.nx}, ${grid.ny}'),
        onTap: () => close(context, r));
    });
  }
}

class ForecastPainter extends CustomPainter {
  final List<double?> values;
  final Color color;
  ForecastPainter(this.values, this.color);
  @override void paint(Canvas canvas, Size size) {
    final valid = values.whereType<double>().toList();
    if (valid.length < 2 || size.width <= 0 || size.height <= 0) return;
    final low = valid.reduce(math.min), high = valid.reduce(math.max);
    final span = (high - low).abs() < .001 ? 1.0 : high - low;
    final grid = Paint()..color = color.withValues(alpha: .18)..strokeWidth = 1;
    for (var j = 0; j <= 4; j++) {
      final y = 14 + (size.height - 28) * j / 4;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), grid);
    }
    final line = Paint()..color = color..strokeWidth = 3..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = ui.Path();
    var started = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) { started = false; continue; }
      final x = 12 + (size.width - 24) * i / (values.length - 1);
      final y = 14 + (size.height - 28) * (1 - (v - low) / span);
      if (!started) { path.moveTo(x, y); started = true; }
      else { path.lineTo(x, y); }
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
    }
    canvas.drawPath(path, line);
  }
  @override bool shouldRepaint(covariant ForecastPainter old) => old.color != color ||
    old.values.length != values.length ||
    List.generate(values.length, (i) => i).any((i) => values[i] != old.values[i]);
}
