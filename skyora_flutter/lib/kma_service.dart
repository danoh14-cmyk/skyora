import 'dart:convert';
import 'package:http/http.dart' as http;
import 'region.dart';

class Forecast {
  final DateTime time;
  final double? temp, rainProbability, humidity, wind, precipitation;
  final int? sky, precipitationType;
  const Forecast(this.time, {this.temp, this.rainProbability, this.humidity,
    this.wind, this.precipitation, this.sky, this.precipitationType});
  bool get isRain => const [1, 2, 4].contains(precipitationType);
  bool get isSnow => const [2, 3].contains(precipitationType);
  String get condition {
    if (precipitationType == 3) return '눈';
    if (precipitationType == 2) return '비/눈';
    if (precipitationType == 4) return '소나기';
    if (precipitationType == 1) return '비';
    if (sky == 1) return '맑음';
    if (sky == 3) return '구름 많음';
    if (sky == 4) return '흐림';
    return '날씨 정보 없음';
  }
}

class KmaService {
  // The secret KMA API key belongs ONLY in Cloudflare Workers.
  static const proxyUrl = String.fromEnvironment('SKYORA_PROXY_URL');
  static const _baseHours = [2, 5, 8, 11, 14, 17, 20, 23];
  final http.Client _client;
  KmaService({http.Client? client}) : _client = client ?? http.Client();

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _date(DateTime d) => '${d.year}${_two(d.month)}${_two(d.day)}';

  // Publication may be delayed. Try the last three released bases, newest first.
  static List<DateTime> candidateBases(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final candidates = <DateTime>[];
    for (var offset = 0; offset <= 1; offset++) {
      final day = today.subtract(Duration(days: offset));
      for (final h in _baseHours.reversed) {
        final base = day.add(Duration(hours: h));
        if (!base.add(const Duration(minutes: 20)).isAfter(now)) {
          candidates.add(base);
        }
      }
    }
    candidates.sort((a, b) => b.compareTo(a));
    return candidates.take(3).toList();
  }

  Future<List<Forecast>> fetchForecast(Region region, {DateTime? clock}) async {
    if (proxyUrl.trim().isEmpty) {
      throw StateError('SKYORA_PROXY_URL이 APK에 설정되지 않았어. GitHub Actions Variables와 새 APK를 확인해 줘.');
    }
    final root = Uri.tryParse(proxyUrl);
    if (root == null || root.scheme != 'https' || root.host.isEmpty) {
      throw StateError('SKYORA_PROXY_URL은 올바른 HTTPS 주소여야 해.');
    }
    final now = clock ?? DateTime.now();
    final grid = toKmaGrid(region.lat, region.lon);
    String? lastError;
    for (final base in candidateBases(now)) {
      final uri = root.replace(queryParameters: {
        ...root.queryParameters,
        'base_date': _date(base),
        'base_time': '${_two(base.hour)}00',
        'nx': '${grid.nx}', 'ny': '${grid.ny}',
      });
      try {
        final response = await _client.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          lastError = '서버 HTTP ${response.statusCode}';
          if (response.statusCode == 401 || response.statusCode == 403) break;
          continue;
        }
        final payload = jsonDecode(utf8.decode(response.bodyBytes));
        if (payload is! Map) { lastError = '응답 형식 오류'; continue; }
        final header = payload['response']?['header'];
        if (header?['resultCode']?.toString() != '00') {
          lastError = '기상청: ${header?['resultMsg'] ?? '알 수 없는 오류'}';
          continue;
        }
        final items = payload['response']?['body']?['items']?['item'];
        if (items is! List || items.isEmpty) { lastError = '발표된 예보 데이터가 없어'; continue; }
        final forecasts = parseForecastItems(items);
        if (forecasts.isNotEmpty) return forecasts;
        lastError = '해석 가능한 예보 항목이 없어';
      } catch (e) {
        lastError = '네트워크 또는 데이터 처리 오류: $e';
      }
    }
    throw StateError(lastError ?? '최근 예보를 불러오지 못했어.');
  }

  static double? _number(Object? value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s == '강수없음' || s == '적설없음') return 0;
    if (s.startsWith('1mm 미만')) return null; // Do not invent a precise amount.
    return double.tryParse(s);
  }

  static List<Forecast> parseForecastItems(List<dynamic> items) {
    final grouped = <String, Map<String, dynamic>>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final date = '${raw['fcstDate'] ?? ''}';
      final time = '${raw['fcstTime'] ?? ''}';
      if (!RegExp(r'^\d{8}$').hasMatch(date) || !RegExp(r'^\d{4}$').hasMatch(time)) continue;
      grouped.putIfAbsent('$date$time', () => {})['${raw['category']}'] = raw['fcstValue'];
    }
    final output = <Forecast>[];
    for (final entry in grouped.entries) {
      final key = entry.key;
      final time = DateTime.tryParse('${key.substring(0, 4)}-${key.substring(4, 6)}-${key.substring(6, 8)}T${key.substring(8, 10)}:${key.substring(10, 12)}');
      if (time == null) continue;
      final v = entry.value;
      output.add(Forecast(time,
        temp: _number(v['TMP']), rainProbability: _number(v['POP']),
        humidity: _number(v['REH']), wind: _number(v['WSD']),
        precipitation: _number(v['PCP']),
        sky: int.tryParse('${v['SKY'] ?? ''}'),
        precipitationType: int.tryParse('${v['PTY'] ?? ''}')));
    }
    output.sort((a, b) => a.time.compareTo(b.time));
    return output;
  }
}
