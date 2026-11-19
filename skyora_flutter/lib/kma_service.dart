import 'dart:convert';
import 'package:http/http.dart' as http;
import 'region.dart';

class Forecast {
  final DateTime time;
  final double? temp, rainProbability, humidity, wind, precipitation;
  const Forecast(this.time, {this.temp, this.rainProbability, this.humidity, this.wind, this.precipitation});
}

class KmaService {
  // Production: provide a server-side proxy via --dart-define=SKYORA_PROXY_URL=...
  // Never ship an unrestricted KMA service key in a client binary.
  static const proxyUrl = String.fromEnvironment('SKYORA_PROXY_URL');
  static const directKey = String.fromEnvironment('KMA_SERVICE_KEY'); // development only

  Future<List<Forecast>> fetchForecast(Region region) async {
    final grid = toKmaGrid(region.lat, region.lon);
    final now = DateTime.now();
    // Latest published base for short-term forecast. Publication may be delayed;
    // fallback to earlier bases if API returns no items.
    const bases = [2,5,8,11,14,17,20,23];
    final eligible = bases.where((h) => h < now.hour || (h == now.hour && now.minute >= 15)).toList();
    final baseHour = eligible.isNotEmpty ? eligible.last : 23;
    final date = eligible.isNotEmpty ? now : now.subtract(const Duration(days:1));
    String two(int n) => n.toString().padLeft(2,'0');
    final dateText = '${date.year}${two(date.month)}${two(date.day)}';
    final baseTime = '${two(baseHour)}00';
    final query = {'pageNo':'1','numOfRows':'1000','dataType':'JSON',
      'base_date':dateText,'base_time':baseTime,'nx':'${grid.nx}','ny':'${grid.ny}'};
    final Uri uri;
    if (proxyUrl.isNotEmpty) {
      uri = Uri.parse(proxyUrl).replace(queryParameters:query);
    } else if (directKey.isNotEmpty) {
      uri = Uri.https('apis.data.go.kr','/1360000/VilageFcstInfoService_2.0/getVilageFcst',
          {...query,'serviceKey':directKey});
    } else {
      throw StateError('기상청 API 연결 정보가 없어. SKYORA_PROXY_URL을 설정해 줘.');
    }
    final response = await http.get(uri).timeout(const Duration(seconds:12));
    if (response.statusCode != 200) throw Exception('기상청 HTTP ${response.statusCode}');
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String,dynamic>;
    final result = body['response']?['header']?['resultCode']?.toString();
    if (result != '00') throw Exception('기상청 응답 오류: ${body['response']?['header']?['resultMsg']}');
    final raw = body['response']?['body']?['items']?['item'];
    if (raw is! List || raw.isEmpty) throw StateError('예보 항목이 없어. 발표 시각 또는 API 상태를 확인해 줘.');
    final grouped = <String,Map<String,String>>{};
    for (final value in raw) {
      if (value is! Map) continue;
      final item = Map<String,dynamic>.from(value);
      final key = '${item['fcstDate']}${item['fcstTime']}';
      grouped.putIfAbsent(key,()=>{})['${item['category']}']='${item['fcstValue']}';
    }
    double? parse(String? v) => double.tryParse(v ?? '');
    final output = <Forecast>[];
    for (final entry in grouped.entries) {
      final t = DateTime.tryParse('${entry.key.substring(0,4)}-${entry.key.substring(4,6)}-${entry.key.substring(6,8)}T${entry.key.substring(8,10)}:${entry.key.substring(10,12)}');
      if (t == null) continue;
      final v=entry.value;
      output.add(Forecast(t,temp:parse(v['TMP']),rainProbability:parse(v['POP']),
        humidity:parse(v['REH']),wind:parse(v['WSD']),precipitation:parse(v['PCP'])));
    }
    output.sort((a,b)=>a.time.compareTo(b.time));
    return output.where((f)=>f.time.isAfter(now.subtract(const Duration(hours:1)))).toList();
  }
}
