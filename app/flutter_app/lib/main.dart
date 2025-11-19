// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'drawing_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaeAriApp());
}

/* ===========================================================
 * =========================================================== */

class MaeAriApp extends StatelessWidget {
  const MaeAriApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '매아리 그림일기',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFE08C)),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const _Bootstrap(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap({super.key});
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final sId = prefs.getInt('s_id');
    final name = prefs.getString('name');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    if (sId == null || name == null || name.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegisterPage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/* ===========================================================
 * 등록 페이지
 * =========================================================== */

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl = TextEditingController();
  final api = ApiServiceDio();
  bool _loading = false;

  Future<void> _submit() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이름을 입력해주세요.')));
      return;
    }

    setState(() => _loading = true);
    try {
      final sId = await api.register(name);
      if (sId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('등록 실패: 서버 응답 오류')));
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('s_id', sId);
      await prefs.setString('name', name);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootScaffold()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('등록 중 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('학생 등록')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('처음 오셨네요! 이름을 등록해주세요 😊'),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('등록하기'),
                    onPressed: _loading ? null : _submit,
                    style:
                        FilledButton.styleFrom(backgroundColor: cs.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===========================================================
 * 모델
 * =========================================================== */

class DiaryEntry {
  DiaryEntry({
    required this.studentName,
    required this.date, // yyyy-MM-dd
    required this.title,
    required this.weather, // ☀️ / ☁️ / ❄️ / 🌧️
    required this.text,
    this.imageBytes,
    this.imageUrl,
    this.stamp = false,
    this.teacherComment = '',
    this.strokesJson,
  });

  final String studentName;
  final String date;
  final String title;
  final String weather;
  final String text;
  final Uint8List? imageBytes; // 로컬/메모리 이미지
  final String? imageUrl;      // 서버에 저장된 이미지 URL
  final bool stamp;
  final String teacherComment;
  final String? strokesJson;

  Map<String, dynamic> toJson() => {
        'studentName': studentName,
        'date': date,
        'title': title,
        'weather': weather,
        'text': text,
        'imageBase64': imageBytes != null ? base64Encode(imageBytes!) : null,
        'imageUrl': imageUrl,
        'stamp': stamp,
        'teacherComment': teacherComment,
        'strokes': strokesJson,
      };

  static DiaryEntry fromJson(Map<String, dynamic> json) => DiaryEntry(
        studentName: json['studentName'] ?? '',
        date: json['date'] ?? '',
        title: json['title'] ?? '',
        weather: json['weather'] ?? '',
        text: json['text'] ?? '',
        imageBytes: (json['imageBase64'] == null ||
                (json['imageBase64'] as String).isEmpty)
            ? null
            : base64Decode(json['imageBase64']),
        imageUrl: json['imageUrl'] as String?,
        stamp: json['stamp'] == true,
        teacherComment: json['teacherComment'] ?? '',
        strokesJson: json['strokes'] as String?,
      );

  /// 서버에서 내려온 JSON 한 건을 앱 내부 모델로 변환
  factory DiaryEntry.fromServerJson(
    Map<String, dynamic> json, {
    required String studentName,
  }) {
    // 날짜
    String rawDate = '';
    if (json['date'] is String) {
      rawDate = json['date'] as String;
    } else if (json['created_at'] is String) {
      rawDate = json['created_at'] as String;
    }
    if (rawDate.length >= 10) {
      rawDate = rawDate.substring(0, 10); // yyyy-MM-dd
    }

    // 이미지: base64 또는 경로(/img/..) 모두 지원
    Uint8List? imgBytes;
    String? imageUrl;

    final dynamic imgRaw =
        json['img_b64'] ?? json['img_base64'] ?? json['imageBase64'] ?? json['img'];

    if (imgRaw is String && imgRaw.isNotEmpty) {
      if (imgRaw.startsWith('data:')) {
        // data URL이면 base64 디코딩
        final pure = imgRaw.split(',').last;
        try {
          imgBytes = base64Decode(pure);
        } catch (_) {
          imgBytes = null;
        }
      } else if (imgRaw.startsWith('http')) {
        imageUrl = imgRaw;
      } else if (imgRaw.startsWith('/')) {
        // 서버에서 "/img/53_20251119.jpg" 형태로 올 때
        imageUrl = '${ApiServiceDio.baseUrl}$imgRaw';
      }
    }

    return DiaryEntry(
      studentName: studentName,
      date: rawDate,
      title: json['title'] as String? ?? '',
      weather: json['weather'] as String? ?? '',
      text: json['text'] as String? ?? '',
      imageBytes: imgBytes,
      imageUrl: imageUrl,
      stamp: json['stamp'] == true,
      // 서버 키: comment 또는 teacherComment 둘 다 지원
      teacherComment:
          (json['comment'] as String?) ??
          (json['teacherComment'] as String?) ??
          '',
      strokesJson: null, // 서버에는 없다고 가정
    );
  }
}

class Profile {
  Profile(
      {this.name = '',
      this.school = '',
      this.grade = '',
      this.classNum = '',
      this.intro = ''});
  String name;
  String school;
  String grade;
  String classNum;
  String intro;

  Map<String, dynamic> toJson() =>
      {'name': name, 'school': school, 'grade': grade, 'classNum': classNum, 'intro': intro};

  static Profile fromJson(Map<String, dynamic> json) => Profile(
        name: json['name'] ?? '',
        school: json['school'] ?? '',
        grade: json['grade'] ?? '',
        classNum: json['classNum'] ?? '',
        intro: json['intro'] ?? '',
      );
}

/* ===========================================================
 * 저장소
 * =========================================================== */

class Store {
  static const _kDiaries = 'maeariDiaries';
  static const _kProfile = 'maeariProfile';
  static String draftKey(String studentName, String date) =>
      'maeariDraft:$studentName:$date';

  static Future<List<DiaryEntry>> loadAllDiaries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kDiaries) ?? <String>[];
    return raw
        .map((e) => DiaryEntry.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList(growable: true);
  }

  static Future<void> saveAllDiaries(List<DiaryEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = items.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_kDiaries, raw);
  }

  static Future<Profile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kProfile);
    if (s == null) return null;
    return Profile.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  static Future<void> saveProfile(Profile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, jsonEncode(p.toJson()));
  }

  static Future<Map<String, dynamic>?> loadDraft(
      String studentName, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(draftKey(studentName, date));
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> saveDraft(
      String studentName, String date, Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(draftKey(studentName, date), jsonEncode(draft));
  }

  static Future<void> clearDraft(String studentName, String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey(studentName, date));
  }
}

/* ===========================================================
 * 루트(큰 UI)
 * =========================================================== */

enum RootTab { home, journal }

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});
  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  RootTab _tab = RootTab.home;
  Profile? _profile;
  List<DiaryEntry> _all = [];
  String _selectedDate = _today();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final sId = prefs.getInt('s_id');
    final regName = prefs.getString('name') ?? '';

    final p = await Store.loadProfile();
    final localAll = await Store.loadAllDiaries();

    // 내 이름 결정 (프로필 > 등록 이름 > 기본값)
    final String myName = (p?.name ?? '').isNotEmpty
        ? p!.name
        : (regName.isNotEmpty ? regName : '이름미정');

    // 우선 로컬 일기들
    final List<DiaryEntry> merged = List.of(localAll);

    // 서버에서 일기 목록 가져와서 합치기
    if (sId != null) {
      try {
        final api = ApiServiceDio();
        final serverList = await api.loadDiaries(sId);

        if (serverList != null) {
          final serverEntries = serverList
              .map((m) =>
                  DiaryEntry.fromServerJson(m, studentName: myName))
              .toList();

          for (final e in serverEntries) {
            final idx = merged.indexWhere(
              (d) => d.studentName == e.studentName && d.date == e.date,
            );
            if (idx >= 0) {
              merged[idx] = e;
            } else {
              merged.add(e);
            }
          }
        }
      } catch (e) {
        print('서버에서 일기 가져오기 실패: $e');
      }
    }

    // 날짜순 정렬 후 로컬에도 저장
    merged.sort((a, b) => a.date.compareTo(b.date));
    await Store.saveAllDiaries(merged);

    if (!mounted) return;
    setState(() {
      _profile = p ?? Profile(name: myName);
      _all = merged;
    });
  }

  void _onSavedDiary(DiaryEntry entry) async {
    final idx = _all.indexWhere(
        (d) => d.studentName == entry.studentName && d.date == entry.date);
    if (idx >= 0) {
      _all[idx] = entry;
    } else {
      _all.add(entry);
    }
    await Store.saveAllDiaries(_all);
    setState(() {});
  }

  void _onDeletedDiary(DiaryEntry entry) async {
    _all.removeWhere(
        (d) => d.studentName == entry.studentName && d.date == entry.date);
    await Store.saveAllDiaries(_all);
    setState(() {});
  }

  Future<void> _logoutAndReRegister() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('s_id');
    await prefs.remove('name');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white70,
            border:
                Border(bottom: BorderSide(color: Color(0xFFFFE08C), width: 2)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _tab = RootTab.home),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/images/logo.png',
                        height: 36, errorBuilder: (_, __, ___) {
                      return const Icon(Icons.image, size: 28);
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('매아리',
                        style: TextStyle(
                            color: Color(0xFF6BB7FF),
                            fontWeight: FontWeight.w700)),
                    Text('매일 아이 이해하기',
                        style: TextStyle(
                            color: Color(0xFF7DCFB6), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: '내 일기장',
                  icon: Icon(Icons.photo_album_outlined,
                      color: _tab == RootTab.journal
                          ? const Color(0xFF6BB7FF)
                          : Colors.black87),
                  onPressed: () => setState(() => _tab = RootTab.journal),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '다시 등록하기',
                  onPressed: _logoutAndReRegister,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: IndexedStack(
              index: _tab.index,
              children: [
                HomeTab(
                  profile: _profile,
                  all: _all,
                  selectedDate: _selectedDate,
                  onChangeDate: (d) {
                    setState(() {
                      _selectedDate = d;
                    });
                    _loadAll(); // 날짜 바뀔 때도 최신 데이터
                  },
                  onSaved: _onSavedDiary,
                ),
                JournalTab(
                  profile: _profile,
                  all: _all,
                  onGoHome: () => setState(() => _tab = RootTab.home),
                  onChangeDate: (date) {
                    setState(() {
                      _selectedDate = date;
                      _tab = RootTab.home;
                    });
                    _loadAll(); // 달력 클릭 시 서버에서 최신 일기 다시 가져오기
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ===========================================================
 * 공통 스케치북(시안 매칭)
 * =========================================================== */

class SketchbookShell extends StatelessWidget {
  const SketchbookShell(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(14, 28, 14, 16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFFFFDF8);
    return Container(
      decoration: BoxDecoration(
        color: paper,
        border: Border.all(color: const Color(0xFF222222), width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Colors.black12)
        ],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFEFD), Color(0xFFFFFDF8)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
              child: _LinedPaperOverlay(
                  spacing: 29, offsetTop: 18, opacity: .035)),
          const _RingStrip(),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _RingStrip extends StatelessWidget {
  const _RingStrip();
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          border: const Border(
              bottom: BorderSide(color: Color(0xFF222222), width: 2)),
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          gradient: const LinearGradient(
              colors: [Color(0xFFECE8DF), Color(0xFFF7F3EA)]),
        ),
        child: CustomPaint(painter: _RingHolesPainter()),
      ),
    );
  }
}

class _RingHolesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(.2);
    const step = 52.0;
    const r = 6.0;
    final cy = size.height / 2;
    for (double x = 13; x < size.width; x += step) {
      canvas.drawCircle(Offset(x, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinedPaperOverlay extends StatelessWidget {
  const _LinedPaperOverlay(
      {required this.spacing, required this.offsetTop, required this.opacity});
  final double spacing;
  final double offsetTop;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinesPainter(
          spacing: spacing, offsetTop: offsetTop, opacity: opacity),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter(
      {required this.spacing, required this.offsetTop, required this.opacity});
  final double spacing;
  final double offsetTop;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withOpacity(opacity)
      ..strokeWidth = 1;
    double y = offsetTop;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      y += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* 점선 Divider */
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 6),
      painter: _DashPainter(),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withOpacity(.6)
      ..strokeWidth = 4;
    const dash = 10.0;
    double x = 0;
    final y = size.height / 2;
    bool on = true;
    while (x < size.width) {
      final nx = x + dash;
      if (on) canvas.drawLine(Offset(x, y), Offset(nx, y), p);
      on = !on;
      x = nx;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* 스케치 액자 프레임 */
class SketchArtFrame extends StatelessWidget {
  const SketchArtFrame({
    super.key,
    this.imageBytes,
    this.imageUrl,
    this.aspectW = 4,
    this.aspectH = 3,
    this.showStamp = false,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final double aspectW;
  final double aspectH;
  final bool showStamp;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (imageBytes != null) {
      child = Image.memory(imageBytes!, fit: BoxFit.contain);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.network(imageUrl!, fit: BoxFit.contain);
    } else {
      child = const Center(
        child: Text('(그림 없음)', style: TextStyle(color: Colors.grey)),
      );
    }

    // 액자 + 그림
    final framed = Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF9),
        border: Border.all(color: const Color(0xFF222222), width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, spreadRadius: 0),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFAAAAAA), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );

    // ✅ 여기서 도장을 그림 위, 왼쪽 위에 올려줌
    return AspectRatio(
      aspectRatio: aspectW / aspectH,
      child: Stack(
        children: [
          Positioned.fill(child: framed),
          if (showStamp)
            Positioned(
              top: 6,
              left: 6,
              child: Image.asset(
                'assets/images/stamp.png',
                height: 150,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}


/* 점선 박스(썸네일 placeholder) */
class DottedThumbBox extends StatelessWidget {
  const DottedThumbBox({super.key, required this.onTap, this.child});
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEF9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFAAAAAA),
                width: 2,
                style: BorderStyle.solid),
          ),
          child: child ??
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🖍️ 여기를 눌러 그림 그리기',
                        style:
                            TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 6),
                    Text('그림 전용 화면으로 이동해요',
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}

/* 날씨 버튼 */
class WeatherButton extends StatelessWidget {
  const WeatherButton(
      {super.key,
      required this.emoji,
      required this.active,
      required this.onTap});
  final String emoji;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border =
        active ? const Color(0xFFFFB800) : const Color(0xFFB6B6B6);
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: border, width: 2, style: BorderStyle.solid),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: const Color(0xFFFFE08C).withOpacity(.8),
                      blurRadius: 0,
                      spreadRadius: 3)
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/* ===========================================================
 * 홈 (여기서 서버 업로드까지)
 * =========================================================== */

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.profile,
    required this.all,
    required this.selectedDate,
    required this.onChangeDate,
    required this.onSaved,
  });

  final Profile? profile;
  final List<DiaryEntry> all;
  final String selectedDate;
  final ValueChanged<String> onChangeDate;
  final ValueChanged<DiaryEntry> onSaved;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final titleCtrl = TextEditingController();
  final textCtrl = TextEditingController();
  Uint8List? _tempImg;
  String? _imageUrl;
  String _weather = '';
  bool _readOnly = false;
  String? _strokesJson;
  bool _uploading = false;
  bool _stamp = false;
  String _teacherComment = ''; // 선생님 코멘트

  @override
  void initState() {
    super.initState();
    _applyDate(widget.selectedDate, first: true);
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.all != widget.all) {
      _applyDate(widget.selectedDate);
    }
  }

  String get _studentName =>
      widget.profile?.name.isNotEmpty == true
          ? widget.profile!.name
          : '이름미정';

  Future<void> _applyDate(String date, {bool first = false}) async {
    final finalOne = widget.all
        .where((e) => e.studentName == _studentName && e.date == date)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (finalOne.isNotEmpty) {
      final e = finalOne.last;
      setState(() {
        _readOnly = true;
        titleCtrl.text = e.title;
        textCtrl.text = e.text;
        _weather = e.weather;
        _tempImg = e.imageBytes;
        _imageUrl = e.imageUrl;
        _strokesJson = e.strokesJson;
        _stamp = e.stamp;
        _teacherComment = e.teacherComment; // ✅ 서버 코멘트 반영
      });
      return;
    }

    final d = await Store.loadDraft(_studentName, date);
    setState(() {
      _readOnly = false;
      titleCtrl.text = d?['title'] ?? '';
      textCtrl.text = d?['text'] ?? '';
      _weather = d?['weather'] ?? '';
      final img64 = d?['imageBase64'];
      _tempImg = (img64 is String && img64.isNotEmpty)
          ? base64Decode(img64)
          : null;
      _imageUrl = d?['imageUrl'] as String?;
      _strokesJson = d?['strokes'] as String?;
      _stamp = d?['stamp'] == true;
      _teacherComment = d?['teacherComment'] ?? '';
    });

    if (!first) FocusScope.of(context).unfocus();
  }

  Future<void> _saveDraft() async {
    final date = widget.selectedDate;
    final m = {
      'studentName': _studentName,
      'date': date,
      'title': titleCtrl.text,
      'weather': _weather,
      'text': textCtrl.text,
      'imageBase64': _tempImg != null ? base64Encode(_tempImg!) : null,
      'imageUrl': _imageUrl,
      'strokes': _strokesJson,
      'stamp': _stamp,
      'teacherComment': _teacherComment,
    };
    await Store.saveDraft(_studentName, date, m);
  }

  void _setWeather(String w) {
    setState(() => _weather = w);
    _saveDraft();
  }

  Future<void> _openCanvas() async {
    if (_readOnly) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingPage(initialStrokesJson: _strokesJson),
      ),
    );
    if (result != null) {
      setState(() {
        _tempImg = result['png'] as Uint8List?;
        _strokesJson = result['strokes'] as String?;
        _imageUrl = null; // 로컬 그림으로 대체
      });
      _saveDraft();
    }
  }

  // 서버 업로드 + 로컬 저장
  Future<void> _submit() async {
    if (_tempImg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('먼저 그림을 그려주세요.')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final sId = prefs.getInt('s_id');
    final name = prefs.getString('name') ?? '';
    if (sId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('등록 정보가 없습니다. 다시 등록해주세요.')));
      return;
    }

    final entry = DiaryEntry(
      studentName: name.isEmpty ? _studentName : name,
      date: widget.selectedDate,
      title: titleCtrl.text.trim().isEmpty
          ? '제목 없음'
          : titleCtrl.text.trim(),
      weather: _weather,
      text: textCtrl.text.trim().isEmpty
          ? '내용 없음'
          : textCtrl.text.trim(),
      imageBytes: _tempImg,
      imageUrl: null, // 업로드 직후는 로컬 이미지만
      strokesJson: _strokesJson,
      stamp: _stamp,
      teacherComment: _teacherComment,
    );

    setState(() => _uploading = true);
    final tmpDir = Directory.systemTemp;
    final file =
        File('${tmpDir.path}/diary_${DateTime.now().millisecondsSinceEpoch}.png');
    try {
      await file.writeAsBytes(_tempImg!);
      final api = ApiServiceDio();
      final ok = await api.upload(sId, entry.title, entry.text, file);

      if (!mounted) return;

      if (ok) {
        widget.onSaved(entry);
        await Store.clearDraft(_studentName, widget.selectedDate);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '업로드 완료! 🎉 ($name / ${_krDate(widget.selectedDate)})')),
        );
        setState(() => _readOnly = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('업로드 실패: 서버 응답 오류')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('업로드 중 오류: $e')));
      }
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      bool isWide =
          constraints.maxWidth > constraints.maxHeight &&
              constraints.maxWidth > 600;

      return SketchbookShell(
        padding: isWide
            ? const EdgeInsets.fromLTRB(24, 24, 24, 24)
            : const EdgeInsets.fromLTRB(14, 28, 14, 16),
        child: isWide ? _buildLandscapeLayout() : _buildPortraitLayout(),
      );
    });
  }

  Widget _buildPortraitLayout() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 6),
          const DashedDivider(),
          const SizedBox(height: 8),
          if (_readOnly)
            ..._buildReadOnlyContent(isWide: false)
          else
            ..._buildFormContent(isWide: false),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    final showStamp = _readOnly && (_stamp || _teacherComment.isNotEmpty);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _readOnly
                    // ✨ 읽기 전용일 때는 도장을 그림 위에
                    ? SketchArtFrame(
                        imageBytes: _tempImg,
                        imageUrl: _imageUrl,
                        showStamp: showStamp,
                      )
                    : (_tempImg == null
                        ? DottedThumbBox(onTap: _openCanvas)
                        : GestureDetector(
                            onTap: _openCanvas,
                            child: SketchArtFrame(
                              imageBytes: _tempImg,
                              imageUrl: _imageUrl,
                            ),
                          )),
              ),
            ],
          ),
        ),

        const SizedBox(width: 24),
        Container(width: 2, color: Colors.black12),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(),
              const SizedBox(height: 12),
              const DashedDivider(),
              const SizedBox(height: 16),
              Expanded(
                child:
                    _readOnly ? _buildReadOnlyRightSide() : _buildFormRightSide(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: _DateField(
              value: widget.selectedDate,
              onChanged: widget.onChangeDate,
            ),
          ),
          const SizedBox(width: 8),
          const Text('날씨 :', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          WeatherButton(
              emoji: '☀️',
              active: _weather == '☀️',
              onTap: () => _setWeather('☀️')),
          const SizedBox(width: 8),
          WeatherButton(
              emoji: '☁️',
              active: _weather == '☁️',
              onTap: () => _setWeather('☁️')),
          const SizedBox(width: 8),
          WeatherButton(
              emoji: '❄️',
              active: _weather == '❄️',
              onTap: () => _setWeather('❄️')),
          const SizedBox(width: 8),
          WeatherButton(
              emoji: '🌧️',
              active: _weather == '🌧️',
              onTap: () => _setWeather('🌧️')),
        ],
      ),
    );
  }

  List<Widget> _buildFormContent({required bool isWide}) {
    return [
      _buildTitleInput(),
      const SizedBox(height: 10),
      AspectRatio(
        aspectRatio: 4 / 3,
        child: _tempImg == null
            ? DottedThumbBox(onTap: _openCanvas)
            : GestureDetector(
                onTap: _openCanvas,
                child: SketchArtFrame(imageBytes: _tempImg, imageUrl: _imageUrl)),
      ),
      const SizedBox(height: 12),
      _buildTextArea(isWide: false),
      const SizedBox(height: 12),
      _buildSubmitButton(),
    ];
  }

  Widget _buildFormRightSide() {
    return Column(
      children: [
        _buildTitleInput(),
        const SizedBox(height: 16),
        Expanded(child: _buildTextArea(isWide: true)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: _uploading ? null : _submit,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: const Text('완성!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitleInput() {
    return Row(
      children: [
        const SizedBox(
            width: 40,
            child:
                Text('제목', style: TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: titleCtrl,
            onChanged: (_) => _saveDraft(),
            decoration: _inputDeco('오늘 그림일기의 제목'),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea({required bool isWide}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEF9),
        border: Border.all(color: const Color(0xFF222222), width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(10),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned.fill(
              child: _LinedPaperOverlay(
                  spacing: 32, offsetTop: 26, opacity: .23)),
          TextField(
            controller: textCtrl,
            onChanged: (_) => _saveDraft(),
            expands: isWide,
            maxLines: isWide ? null : 8,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText: '오늘의 이야기를 써 보세요.',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton.icon(
          onPressed: _uploading ? null : _submit,
          icon: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload),
          label: const Text('완성!'),
        ),
      ],
    );
  }

  List<Widget> _buildReadOnlyContent({required bool isWide}) {
    final showStamp = _stamp || _teacherComment.isNotEmpty;

    return [
      Text(
        titleCtrl.text.isEmpty ? '제목 없음' : titleCtrl.text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      const SizedBox(height: 4),
      Text(
        '${_krDate(widget.selectedDate)} / ${_weather.isNotEmpty ? _weather : ''}',
        style: const TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 10),
      SketchArtFrame(
        imageBytes: _tempImg,
        imageUrl: _imageUrl,
        showStamp: showStamp,
      ),

      const SizedBox(height: 16),
      Text(
        textCtrl.text,
        style: const TextStyle(fontSize: 16, height: 1.5),
      ),
      if (_teacherComment.isNotEmpty) ...[
        const SizedBox(height: 16),
        _TeacherCommentBox(comment: _teacherComment),
      ],
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PillButton(
            label: '✏️ 수정하기',
            color: const Color(0xFFFFE08C),
            borderColor: const Color(0xFFD3A700),
            onTap: () => setState(() => _readOnly = false),
          ),
        ],
      ),
    ];
  }

  Widget _buildReadOnlyRightSide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleCtrl.text.isEmpty ? '제목 없음' : titleCtrl.text,
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textCtrl.text,
                  style: const TextStyle(fontSize: 17, height: 1.6),
                ),
                if (_teacherComment.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _TeacherCommentBox(comment: _teacherComment),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _PillButton(
              label: '✏️ 수정하기',
              color: const Color(0xFFFFE08C),
              borderColor: const Color(0xFFD3A700),
              onTap: () => setState(() => _readOnly = false),
            ),
          ],
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(width: 2, color: Color(0xFF222222)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(width: 2, color: Color(0xFF222222)),
        ),
        fillColor: const Color(0xFFFFFEF9),
        filled: true,
      );
}

/* ===========================================================
 * 일기장(폴라로이드), 상세, 프로필
 * =========================================================== */

class JournalTab extends StatefulWidget {
  const JournalTab({
    super.key,
    required this.profile,
    required this.all,
    required this.onGoHome,
    required this.onChangeDate,
  });

  final Profile? profile;
  final List<DiaryEntry> all;
  final VoidCallback onGoHome;
  final ValueChanged<String> onChangeDate;

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.entry,
    required this.onTap,
    required this.isToday,
  });

  final int day;
  final DiaryEntry? entry;
  final VoidCallback onTap;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _DottedCirclePainter(
                hasEntry: entry != null, isToday: isToday),
          ),
          if (entry != null) ...[
            ClipOval(
              child: entry!.imageBytes != null
                  ? Image.memory(entry!.imageBytes!,
                      fit: BoxFit.cover, width: 44, height: 44)
                  : (entry!.imageUrl != null && entry!.imageUrl!.isNotEmpty
                      ? Image.network(entry!.imageUrl!,
                          fit: BoxFit.cover, width: 44, height: 44)
                      : Text(entry!.weather,
                          style: const TextStyle(fontSize: 28))),
            ),
          ] else ...[
            Text(
              '$day',
              style: TextStyle(
                color:
                    isToday ? const Color(0xFF6BB7FF) : Colors.black54,
                fontWeight:
                    isToday ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ],
          if (entry != null)
            Positioned(
              bottom: 2,
              child: Text(
                '$day',
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          if (isToday)
            Positioned(
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6BB7FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '오늘',
                  style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  _DottedCirclePainter({required this.hasEntry, required this.isToday});
  final bool hasEntry;
  final bool isToday;

  @override
  void paint(Canvas canvas, Size size) {
    final color = isToday
        ? const Color(0xFF6BB7FF)
        : (hasEntry
            ? const Color(0xFFFFE08C)
            : Colors.grey.shade300);

    final paint = Paint()
      ..color = color
      ..strokeWidth = isToday ? 2.5 : 2
      ..style = hasEntry ? PaintingStyle.fill : PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);

    final minDimension = math.min(size.width, size.height);
    final radius = (minDimension / 2) * 0.8;

    if (hasEntry) {
      canvas.drawCircle(center, radius, paint);
      if (isToday) {
        final borderPaint = Paint()
          ..color = const Color(0xFF6BB7FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(center, radius, borderPaint);
      }
    } else {
      _drawDashedCircle(canvas, center, radius, paint);
    }
  }

  void _drawDashedCircle(
      Canvas canvas, Offset center, double radius, Paint paint) {
    const double dashWidth = 4;
    const double dashSpace = 4;
    double startAngle = 0;
    final circumference = 2 * math.pi * radius;
    final dashCount =
        (circumference / (dashWidth + dashSpace)).floor();
    final angleStep = (2 * math.pi) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        angleStep * (dashWidth / (dashWidth + dashSpace)),
        false,
        paint,
      );
      startAngle += angleStep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _JournalTabState extends State<JournalTab> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SketchbookShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  '${_focusedDay.year}년 ${_focusedDay.month}월',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _focusedDay =
                        DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _focusedDay =
                        DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                  }),
                ),
              ],
            ),
          ),
          const DashedDivider(),
          const SizedBox(height: 20),
          Expanded(
            child: _buildCalendarGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth =
        DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth =
        DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    int firstWeekday = firstDayOfMonth.weekday % 7;
    int daysInMonth = lastDayOfMonth.day;
    int totalCells = firstWeekday + daysInMonth;

    int totalRows = (totalCells / 7).ceil();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['일', '월', '화', '수', '목', '금', '토']
              .map((e) => Expanded(
                    child: Center(
                      child: Text(e,
                          style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              const double spacing = 18;

              final cellWidth = (width - (spacing * 6)) / 7;
              final cellHeight =
                  (height - (spacing * (totalRows - 1))) / totalRows;
              final ratio = cellWidth / cellHeight;

              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: ratio,
                ),
                itemCount: totalCells,
                itemBuilder: (context, index) {
                  if (index < firstWeekday) return const SizedBox();

                  final day = index - firstWeekday + 1;

                  final currentDayDate =
                      DateTime(_focusedDay.year, _focusedDay.month, day);
                  final dateStr =
                      DateFormat('yyyy-MM-dd').format(currentDayDate);
                  final entry = _findEntry(dateStr);

                  final now = DateTime.now();
                  final isToday = now.year == currentDayDate.year &&
                      now.month == currentDayDate.month &&
                      now.day == currentDayDate.day;

                  return _CalendarDayCell(
                    day: day,
                    entry: entry,
                    isToday: isToday,
                    // ✅ 일기 유무와 상관없이 항상 쓰기/수정 화면(HomeTab)으로 이동
                    onTap: () {
                      widget.onChangeDate(dateStr);
                      widget.onGoHome();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  DiaryEntry? _findEntry(String dateStr) {
    final name = (widget.profile?.name ?? '').isEmpty
        ? '이름미정'
        : widget.profile!.name;
    try {
      return widget.all.firstWhere(
          (e) => e.studentName == name && e.date == dateStr);
    } catch (_) {
      return null;
    }
  }

  // 지금은 쓰지 않지만, 나중에 다시 "읽기 전용 북뷰"를 쓰고 싶으면 onTap 에서 이 함수 호출
  void _openBookView(DiaryEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BookPageView(
          initialEntry: entry,
          allEntries: widget.all,
          profile: widget.profile,
        ),
      ),
    );
  }
}

class _BookPageView extends StatefulWidget {
  const _BookPageView(
      {required this.initialEntry,
      required this.allEntries,
      required this.profile});
  final DiaryEntry initialEntry;
  final List<DiaryEntry> allEntries;
  final Profile? profile;

  @override
  State<_BookPageView> createState() => _BookPageViewState();
}

class _BookPageViewState extends State<_BookPageView> {
  late PageController _controller;
  List<DiaryEntry> _myDiaries = [];

  @override
  void initState() {
    super.initState();
    final name = (widget.profile?.name ?? '').isEmpty
        ? '이름미정'
        : widget.profile!.name;
    _myDiaries =
        widget.allEntries.where((d) => d.studentName == name).toList();
    _myDiaries.sort((a, b) => a.date.compareTo(b.date));

    int initialIndex =
        _myDiaries.indexWhere((e) => e.date == widget.initialEntry.date);
    if (initialIndex < 0) initialIndex = 0;

    _controller = PageController(initialPage: initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일기장 읽기'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SketchbookShell(
              padding: EdgeInsets.zero,
              child: PageView.builder(
                controller: _controller,
                itemCount: _myDiaries.length,
                itemBuilder: (context, index) {
                  return _buildBookSpread(_myDiaries[index]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookSpread(DiaryEntry entry) {
    final showStamp = entry.stamp || entry.teacherComment.isNotEmpty;

    Widget imageWidget;
    if (entry.imageBytes != null) {
      imageWidget = Image.memory(entry.imageBytes!, fit: BoxFit.contain);
    } else if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty) {
      imageWidget = Image.network(entry.imageUrl!, fit: BoxFit.contain);
    } else {
      imageWidget = const Center(child: Text('그림 없음'));
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: Colors.grey.shade400)),
                        padding: const EdgeInsets.all(8),
                        child: imageWidget,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(entry.date,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                if (showStamp)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Image.asset('assets/images/stamp.png',
                        width: 80),
                  ),
              ],
            ),
          ),
          SizedBox(
              width: 40,
              child: CustomPaint(painter: _RingBinderPainter())),
          Expanded(
            flex: 1,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.text,
                              style: const TextStyle(
                                  fontSize: 16, height: 1.6)),
                          if (entry.teacherComment.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _TeacherCommentBox(
                              comment: entry.teacherComment,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingBinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const springRadius = 7.0;
    const springSpacing = 28.0;
    const verticalOffset = 25.0;

    final centerX = size.width / 2;

    final ringColor = Colors.grey.shade700;
    final highlightColor =
        Colors.grey.shade200.withOpacity(0.8);
    final shadowColor = Colors.black.withOpacity(0.4);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.fill;

    final holePaint = Paint()
      ..color = const Color(0xFFFFFDF8)
      ..style = PaintingStyle.fill;

    Paint gradientRingPaint(Rect rect) {
      return Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlightColor, ringColor, Colors.grey.shade900],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
    }

    for (double y = verticalOffset;
        y < size.height - verticalOffset - springRadius;
        y += springSpacing) {
      canvas.drawOval(
        Rect.fromCircle(
            center: Offset(centerX + 2.0, y + 2.0),
            radius: springRadius + 1),
        Paint()..color = shadowColor,
      );

      final ringRect =
          Rect.fromCircle(center: Offset(centerX, y), radius: springRadius);
      canvas.drawOval(ringRect, gradientRingPaint(ringRect));

      canvas.drawOval(
        Rect.fromCircle(
            center: Offset(centerX, y),
            radius: springRadius * 0.5),
        holePaint,
      );

      canvas.drawRect(
          Rect.fromLTWH(centerX - springRadius, y - springRadius,
              springRadius, springRadius * 2),
          holePaint);
      canvas.drawRect(
          Rect.fromLTWH(centerX, y - springRadius, springRadius,
              springRadius * 2),
          holePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      false;
}

class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({required this.entry});
  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final showStamp = entry.stamp || entry.teacherComment.isNotEmpty;

    Widget thumb;
    if (entry.imageBytes != null) {
      thumb = Image.memory(entry.imageBytes!, fit: BoxFit.contain);
    } else if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty) {
      thumb = Image.network(entry.imageUrl!, fit: BoxFit.contain);
    } else {
      thumb = const Center(
        child: Text('(그림 없음)',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }

    return Transform.rotate(
      angle: -0.0035,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEF9),
              border:
                  Border.all(color: const Color(0xFF222222), width: 2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(blurRadius: 10, color: Colors.black12)
              ],
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFD8D2C7)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: thumb,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.title.isEmpty ? '제목 없음' : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_krDate(entry.date)} / ${entry.weather}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Positioned(
            top: -8,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF3E1A1), Color(0xFFF5E7B8)],
                      stops: [0.0, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(
                        color: Colors.black12, width: 1),
                    boxShadow: const [
                      BoxShadow(blurRadius: 3, color: Colors.black26)
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showStamp)
            Positioned(
              top: 6,
              right: 6,
              child: Image.asset('assets/images/stamp.png',
                  width: 56, height: 56, errorBuilder: (_, __, ___) {
                return const SizedBox.shrink();
              }),
            ),
        ],
      ),
    );
  }
}

/* 상세 페이지 */

class ViewDiaryPage extends StatelessWidget {
  const ViewDiaryPage(
      {super.key, required this.entry, required this.onDelete});
  final DiaryEntry entry;
  final ValueChanged<DiaryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final showStamp = entry.stamp || entry.teacherComment.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
          title:
              Text(entry.title.isEmpty ? '제목 없음' : entry.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SketchbookShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    entry.title.isEmpty ? '제목 없음' : entry.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_krDate(entry.date)} / ${entry.weather}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                                    const SizedBox(height: 6),
                  SketchArtFrame(
                    imageBytes: entry.imageBytes,
                    imageUrl: entry.imageUrl,
                    showStamp: showStamp,
                  ),

                  const SizedBox(height: 8),
                  Text(entry.text,
                      style: const TextStyle(fontSize: 15)),
                  if (entry.teacherComment.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _TeacherCommentBox(comment: entry.teacherComment),
                  ],
                  const SizedBox(height: 12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _PillButton(
                          label: '🗑️ 삭제',
                          color: const Color(0xFFF28482),
                          borderColor: const Color(0xFFC96C6A),
                          textColor: Colors.white,
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('삭제할까요?'),
                                content: const Text(
                                    '정말 이 그림일기를 삭제하시겠어요?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('취소')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('삭제')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              onDelete(entry);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                        ),
                      ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* 프로필 탭 */

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.profile, required this.onSaved});
  final Profile? profile;
  final ValueChanged<Profile> onSaved;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _edit = false;
  late final TextEditingController nameCtrl;
  late final TextEditingController schoolCtrl;
  String grade = '';
  String classNum = '';
  late final TextEditingController introCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.profile ?? Profile();
    nameCtrl = TextEditingController(text: p.name);
    schoolCtrl = TextEditingController(text: p.school);
    grade = p.grade;
    classNum = p.classNum;
    introCtrl = TextEditingController(text: p.intro);
    _edit = widget.profile == null;

    _prefillNameFromRegistration();
  }

  // 등록한 이름 프로필에도 적용
  Future<void> _prefillNameFromRegistration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final regName = prefs.getString('name') ?? '';
      if (!mounted) return;
      if ((nameCtrl.text.trim().isEmpty) && regName.isNotEmpty) {
        setState(() {
          nameCtrl.text = regName;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile && !_edit) {
      final p =
          widget.profile ?? Profile();
      nameCtrl.text = p.name;
      schoolCtrl.text = p.school;
      grade = p.grade;
      classNum = p.classNum;
      introCtrl.text = p.intro;
      setState(() {});
    }
  }

  void _save() {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이름을 입력해주세요.')));
      return;
    }
    widget.onSaved(Profile(
      name: nameCtrl.text.trim(),
      school: schoolCtrl.text.trim(),
      grade: grade,
      classNum: classNum,
      intro: introCtrl.text.trim(),
    ));
    setState(() => _edit = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile ??
        Profile(
            name: nameCtrl.text,
            school: schoolCtrl.text,
            grade: grade,
            classNum: classNum,
            intro: introCtrl.text);

    return SingleChildScrollView(
      child: SketchbookShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내 프로필',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (!_edit) ...[
              _RowText('이름', p.name),
              _RowText('학교', p.school),
              _RowText('학년', p.grade),
              _RowText('반', p.classNum),
              _RowText('소개', p.intro),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _PillButton(
                    label: '✏️ 수정하기',
                    color: const Color(0xFFFFE08C),
                    borderColor: const Color(0xFFD3A700),
                    onTap: () {
                      setState(() => _edit = true);
                    }),
              ]),
            ] else ...[
              _LabeledText('이름', nameCtrl, hint: '이름 입력'),
              const SizedBox(height: 10),
              _LabeledText('학교', schoolCtrl, hint: '예: 매아리초등학교'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _LabeledDropdown(
                    label: '학년',
                    value: grade.isEmpty ? null : grade,
                    items: const [
                      '1학년',
                      '2학년',
                      '3학년',
                      '4학년',
                      '5학년',
                      '6학년'
                    ],
                    onChanged: (v) => setState(() => grade = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LabeledDropdown(
                    label: '반',
                    value: classNum.isEmpty ? null : classNum,
                    items: const ['1반', '2반', '3반', '4반', '5반'],
                    onChanged: (v) => setState(() => classNum = v ?? ''),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _LabeledText('자기소개', introCtrl,
                  hint: '나를 소개해요!', maxLines: 4),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _PillButton(
                    label: '취소',
                    color: Colors.white,
                    borderColor: const Color(0xFF222222),
                    onTap: () {
                      setState(() => _edit = false);
                    }),
                const SizedBox(width: 8),
                _PillButton(
                    label: '💾 저장하기',
                    color: const Color(0xFF6BB7FF),
                    borderColor: const Color(0xFF4F9FE9),
                    textColor: Colors.white,
                    onTap: _save),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

/* 폼 요소 공통 */

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final date = _parseYmd(value);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2023, 1, 1),
          lastDate: DateTime(2100, 12, 31),
          initialDate: date,
        );
        if (picked != null) {
          onChanged(DateFormat('yyyy-MM-dd').format(picked));
        }
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF9),
          border:
              Border.all(color: const Color(0xFFB6B6B6), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const SizedBox(
                width: 52,
                child: Text('날짜 :',
                    style:
                        TextStyle(fontWeight: FontWeight.w700))),
            Text(_krDate(value),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText(this.label, this.controller,
      {this.hint, this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              fillColor: const Color(0xFFFFFEF9),
              filled: true,
            ),
          )
        ]);
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown(
      {required this.label,
      required this.value,
      required this.items,
      required this.onChanged});
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            items: items
                .map(
                    (e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              fillColor: const Color(0xFFFFFEF9),
              filled: true,
            ),
          )
        ]);
  }
}

class _RowText extends StatelessWidget {
  const _RowText(this.label, this.value, {super.key});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 64,
              child: Text(label,
                  style: th.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  (value ?? '').isEmpty ? '—' : value!,
                  style: th.bodyMedium)),
        ],
      ),
    );
  }
}

/* 선생님 코멘트 박스 */

class _TeacherCommentBox extends StatelessWidget {
  const _TeacherCommentBox({required this.comment, super.key});
  final String comment;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CommentBorderPainter(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF), // 아주 옅은 파란 배경
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 라인
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '📄 ',
                    style: TextStyle(fontSize: 14),
                  ),
                  TextSpan(
                    text: '선생님 코멘트',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: ui.Color.fromARGB(255, 50, 64, 121),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 실제 코멘트
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.color,
    required this.borderColor,
    this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color borderColor;
  final Color? textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: StadiumBorder(
          side: BorderSide(color: borderColor, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          child: Text(label,
              style: TextStyle(
                  color: textColor ?? Colors.black, fontSize: 15)),
        ),
      ),
    );
  }
}

/* ===========================================================
 * 유틸
 * =========================================================== */

String _today() => DateFormat('yyyy-MM-dd').format(DateTime.now());

DateTime _parseYmd(String ymd) {
  try {
    return DateFormat('yyyy-MM-dd').parseStrict(ymd);
  } catch (_) {
    return DateTime.now();
  }
}

String _krDate(String ymd) {
  final d = _parseYmd(ymd);
  return '${d.year}년 ${d.month}월 ${d.day}일';
}

class _CommentBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const radius = 14.0;
    final rrect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height,
      const Radius.circular(radius),
    );

    final paint = Paint()
      ..color = const ui.Color.fromARGB(255, 136, 162, 255) // 점선 색
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4; // 점선 두께

    const dash = 6.0;
    const gap = 4.0;

    final path = Path()..addRRect(rrect); // ← 여기!

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        final extractPath = metric.extractPath(
          distance,
          next.clamp(0.0, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}