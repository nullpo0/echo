// lib/api_client.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

class ApiClient {
  ApiClient({required String baseUrl, http.Client? client})
      : _client = client ?? http.Client(),
        baseUrl = _normalizeBase(baseUrl);

  final http.Client _client;
  final String baseUrl;

  static String _normalizeBase(String s) {
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s;
  }

  // 필요하면 쿠키/세션/토큰을 위해 헤더를 보관
  Map<String, String> _headers = const {
    'Content-Type': 'application/json',
  };

  Duration timeout = const Duration(seconds: 15);

  void dispose() {
    _client.close();
  }

  /* -------------------------------------------------------
   * 로그인 (옵션)
   * - { "password": "..." } POST /web/login
   * - 토큰(Bearer) 또는 쿠키(Set-Cookie) 모두 대응
   * ----------------------------------------------------- */
  Future<bool> login(String password) async {
    final url = Uri.parse('$baseUrl/web/login');
    final res = await _client
        .post(url, headers: _headers, body: jsonEncode({'password': password}))
        .timeout(timeout);

    if (_isOk(res.statusCode)) {
      // 토큰 파싱 시도
      try {
        final m = jsonDecode(res.body);
        if (m is Map && m['token'] is String) {
          _headers = {
            ..._headers,
            'Authorization': 'Bearer ${m['token']}',
          };
        }
      } catch (_) {
        // 바디가 없거나 JSON이 아닐 수도 있음 -> 무시
      }
      // 쿠키 보관 (http 패키지는 쿠키 저장 안 해줌)
      final setCookie = res.headers['set-cookie'];
      if (setCookie != null && setCookie.isNotEmpty) {
        _headers = {
          ..._headers,
          'Cookie': setCookie,
        };
      }
      return true;
    }
    return false;
  }

  /* -------------------------------------------------------
   * 학생 등록
   * - POST /app/registration  { name }
   * - 응답: { s_id:int } 또는 { id:int } 또는 { data:{ s_id } } etc.
   * - 최후 수단: 목록에서 name 매칭
   * ----------------------------------------------------- */
  Future<int?> register(String name) async {
    final url = Uri.parse('$baseUrl/app/registration');
    final res = await _client
        .post(url, headers: _headers, body: jsonEncode({'name': name}))
        .timeout(timeout);

    if (_isOk(res.statusCode)) {
      // 유연 파싱
      final id = _extractIntId(res.body);
      if (id != null) return id;

      // 최후: 목록에서 매칭
      final who = await getStudents();
      final me = who.firstWhere(
        (e) => e.name == name,
        orElse: () => const _Student(sId: null, name: '', dangerMean: null),
      );
      return me.sId;
    }
    throw Exception('Registration failed (${res.statusCode})');
  }

  /* -------------------------------------------------------
   * 학생 목록
   * - GET /web/get_stds
   * - 응답이 리스트이거나 { data:[...] } 모두 허용
   * 각 항목: { s_id, name, danger_mean }
   * ----------------------------------------------------- */
  Future<List<_Student>> getStudents() async {
    final url = Uri.parse('$baseUrl/web/get_stds');
    final res = await _client.get(url, headers: _headers).timeout(timeout);

    if (_isOk(res.statusCode)) {
      final body = res.body.trim();
      if (body.isEmpty) return const [];

      final decoded = jsonDecode(body);
      final list = (decoded is List)
          ? decoded
          : (decoded is Map && decoded['data'] is List)
              ? decoded['data']
              : const [];

      return list.map<_Student>((e) {
        final m = (e is Map) ? e.cast<String, dynamic>() : <String, dynamic>{};
        return _Student(
          sId: _asInt(m['s_id'] ?? m['id']),
          name: (m['name'] ?? '') as String,
          dangerMean: _asDouble(m['danger_mean']),
        );
      }).toList();
    }
    throw Exception('getStudents failed (${res.statusCode})');
  }

  /* -------------------------------------------------------
   * 일기 목록 (서버 포맷 미정 → 그대로 반환)
   * - GET /web/get_diaries/{sId}
   * - 응답이 {data:...} 여도 그대로 반환
   * ----------------------------------------------------- */
  Future<dynamic> getDiaries(int sId) async {
    final url = Uri.parse('$baseUrl/web/get_diaries/$sId');
    final res = await _client.get(url, headers: _headers).timeout(timeout);
    if (_isOk(res.statusCode)) {
      final body = res.body.trim();
      return body.isEmpty ? null : jsonDecode(body);
    }
    throw Exception('getDiaries failed (${res.statusCode})');
  }

  /* -------------------------------------------------------
   * 일기 업로드
   * - POST /app/upload  (multipart)
   *   fields: s_id, title, text, (img)
   * - 200/201/204 -> true
   * ----------------------------------------------------- */
  Future<bool> uploadDiary({
    required int sId,
    required String title,
    required String text,
    Uint8List? pngBytes,
  }) async {
    final url = Uri.parse('$baseUrl/app/upload');
    final req = http.MultipartRequest('POST', url);

    // 토큰/쿠키 헤더 복사 (Content-Type 제외)
    _headers.forEach((k, v) {
      if (k.toLowerCase() != 'content-type') req.headers[k] = v;
    });

    req.fields['s_id'] = '$sId';
    req.fields['title'] = title;
    req.fields['text'] = text;

    if (pngBytes != null && pngBytes.isNotEmpty) {
      req.files.add(http.MultipartFile.fromBytes(
        'img',
        pngBytes,
        filename: 'drawing.png',
        contentType: MediaType('image', 'png'),
      ));
    }

    final streamed = await req.send().timeout(timeout);
    final res = await http.Response.fromStream(streamed);
    return _isOk(res.statusCode);
  }

  /* ===================== 유틸 ====================== */

  bool _isOk(int code) => code == 200 || code == 201 || code == 204;

  int? _extractIntId(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        // 1차 키
        final direct = _asInt(decoded['s_id'] ?? decoded['id']);
        if (direct != null) return direct;

        // data 내부
        if (decoded['data'] is Map) {
          final m = (decoded['data'] as Map).cast<String, dynamic>();
          return _asInt(m['s_id'] ?? m['id']);
        }
      }
    } catch (_) {}
    return null;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final n = int.tryParse(v);
      if (n != null) return n;
    }
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final n = double.tryParse(v);
      if (n != null) return n;
    }
    return null;
  }
}

/* 내부 사용 모델 */
class _Student {
  const _Student({required this.sId, required this.name, required this.dangerMean});
  final int? sId;
  final String name;
  final double? dangerMean;
}
