import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

class Region {
  final String code, province, district, town;
  final double lat, lon;
  const Region(this.code, this.province, this.district, this.town, this.lat, this.lon);
  String get label => '$province $district $town';
  factory Region.fromJson(Map<String, dynamic> j) => Region(
    '${j['code'] ?? ''}', '${j['province']}', '${j['district']}', '${j['town']}',
    (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
}
Future<List<Region>> loadRegions() async {
  final json = jsonDecode(await rootBundle.loadString('assets/data/regions.json')) as List;
  return json.map((e) => Region.fromJson(e as Map<String,dynamic>)).toList();
}

class GridPoint {
  final int nx, ny;
  const GridPoint(this.nx, this.ny);
}
// KMA DFS Lambert Conformal Conic conversion (5km grid).
GridPoint toKmaGrid(double lat, double lon) {
  const re = 6371.00877 / 5.0, rad = 3.141592653589793 / 180;
  final slat1 = 30 * rad, slat2 = 60 * rad, olon = 126 * rad, olat = 38 * rad;
  final sn = math.log(math.tan(3.141592653589793 / 4 + slat2 / 2) /
      math.tan(3.141592653589793 / 4 + slat1 / 2));
  final n = math.log(math.cos(slat1) / math.cos(slat2)) / sn;
  final sf = math.pow(math.tan(3.141592653589793 / 4 + slat1 / 2), n) * math.cos(slat1) / n;
  final ro = re * sf / math.pow(math.tan(3.141592653589793 / 4 + olat / 2), n);
  final ra = re * sf / math.pow(math.tan(3.141592653589793 / 4 + lat * rad / 2), n);
  var theta = lon * rad - olon;
  if (theta > 3.141592653589793) theta -= 2 * 3.141592653589793;
  if (theta < -3.141592653589793) theta += 2 * 3.141592653589793;
  theta *= n;
  return GridPoint((ra * math.sin(theta) + 43 + .5).floor(),
      (ro - ra * math.cos(theta) + 136 + .5).floor());
}
