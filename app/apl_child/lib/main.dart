// lib/main.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drawing_page.dart'; // 같은 lib 폴더

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaeAriApp());
}

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
      home: const RootScaffold(),
      debugShowCheckedModeBanner: false,
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
    required this.imageBytes,
    this.stamp = false,
    this.teacherComment = '',
    this.strokesJson,
  });

  final String studentName;
  final String date;
  final String title;
  final String weather;
  final String text;
  final Uint8List? imageBytes;
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
        imageBytes: (json['imageBase64'] == null || (json['imageBase64'] as String).isEmpty)
            ? null
            : base64Decode(json['imageBase64']),
        stamp: json['stamp'] == true,
        teacherComment: json['teacherComment'] ?? '',
        strokesJson: json['strokes'] as String?,
      );
}

class Profile {
  Profile({this.name = '', this.school = '', this.grade = '', this.classNum = '', this.intro = ''});
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
  static String draftKey(String studentName, String date) => 'maeariDraft:$studentName:$date';

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

  static Future<Map<String, dynamic>?> loadDraft(String studentName, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(draftKey(studentName, date));
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> saveDraft(String studentName, String date, Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(draftKey(studentName, date), jsonEncode(draft));
  }

  static Future<void> clearDraft(String studentName, String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey(studentName, date));
  }
}

/* ===========================================================
 * 루트
 * =========================================================== */

enum RootTab { home, journal, profile }

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
    final p = await Store.loadProfile();
    final all = await Store.loadAllDiaries();
    setState(() {
      _profile = p;
      _all = all;
    });
  }

  void _onSavedDiary(DiaryEntry entry) async {
    final idx = _all.indexWhere((d) => d.studentName == entry.studentName && d.date == entry.date);
    if (idx >= 0) {
      _all[idx] = entry;
    } else {
      _all.add(entry);
    }
    await Store.saveAllDiaries(_all);
    setState(() {});
  }

  void _onDeletedDiary(DiaryEntry entry) async {
    _all.removeWhere((d) => d.studentName == entry.studentName && d.date == entry.date);
    await Store.saveAllDiaries(_all);
    setState(() {});
  }

  void _onSavedProfile(Profile p) async {
    await Store.saveProfile(p);
    setState(() => _profile = p);
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
            border: Border(bottom: BorderSide(color: Color(0xFFFFE08C), width: 2)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/images/logo.png', height: 36, errorBuilder: (_, __, ___) {
                    return const Icon(Icons.image, size: 28);
                  }),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('매아리', style: TextStyle(color: Color(0xFF6BB7FF), fontWeight: FontWeight.w700)),
                    Text('매일 아이 이해하기', style: TextStyle(color: Color(0xFF7DCFB6), fontSize: 12)),
                  ],
                ),
                const Spacer(),
                const Text('🌤️', style: TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: IndexedStack(
              index: _tab.index,
              children: [
                HomeTab(
                  profile: _profile,
                  all: _all,
                  selectedDate: _selectedDate,
                  onChangeDate: (d) => setState(() => _selectedDate = d),
                  onSaved: _onSavedDiary,
                ),
                JournalTab(
                  profile: _profile,
                  all: _all,
                  onOpen: (e) async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewDiaryPage(entry: e, onDelete: _onDeletedDiary),
                      ),
                    );
                    setState(() {});
                  },
                  onGoHome: () => setState(() => _tab = RootTab.home),
                ),
                ProfileTab(profile: _profile, onSaved: _onSavedProfile),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 56,
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => setState(() => _tab = RootTab.values[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.photo_album_outlined), selectedIcon: Icon(Icons.photo_album), label: '내 일기장'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '내 프로필'),
        ],
      ),
    );
  }
}

/* ===========================================================
 * 공통 스케치북(시안 매칭)
 * =========================================================== */

class SketchbookShell extends StatelessWidget {
  const SketchbookShell({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(14, 28, 14, 16)});
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
        boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Colors.black12)],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFEFD), Color(0xFFFFFDF8)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _LinedPaperOverlay(spacing: 29, offsetTop: 18, opacity: .035)),
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
      left: 0, right: 0, top: 0,
      height: 22,
      child: Container(
        decoration: BoxDecoration(
          border: const Border(bottom: BorderSide(color: Color(0xFF222222), width: 2)),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          gradient: const LinearGradient(colors: [Color(0xFFECE8DF), Color(0xFFF7F3EA)]),
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
  const _LinedPaperOverlay({required this.spacing, required this.offsetTop, required this.opacity});
  final double spacing;
  final double offsetTop;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinesPainter(spacing: spacing, offsetTop: offsetTop, opacity: opacity),
    );
  }
}

class _LinesPainter extends CustomPainter {
  _LinesPainter({required this.spacing, required this.offsetTop, required this.opacity});
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
  const SketchArtFrame({super.key, this.imageBytes, this.aspectW = 4, this.aspectH = 3});
  final Uint8List? imageBytes;
  final double aspectW;
  final double aspectH;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectW / aspectH,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF9),
          border: Border.all(color: const Color(0xFF222222), width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1, spreadRadius: 0)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFAAAAAA), width: 2, style: BorderStyle.solid),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageBytes != null
                ? Image.memory(imageBytes!, fit: BoxFit.contain)
                : const Center(child: Text('(그림 없음)', style: TextStyle(color: Colors.grey))),
          ),
        ),
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
            border: Border.all(color: const Color(0xFFAAAAAA), width: 2, style: BorderStyle.solid),
          ),
          child: child ??
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🖍️ 여기를 눌러 그림 그리기', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 6),
                    Text('그림 전용 화면으로 이동해요', style: TextStyle(fontSize: 13, color: Colors.grey)),
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
  const WeatherButton({super.key, required this.emoji, required this.active, required this.onTap});
  final String emoji;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = active ? const Color(0xFFFFB800) : const Color(0xFFB6B6B6);
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 2, style: BorderStyle.solid),
          boxShadow: active ? [BoxShadow(color: const Color(0xFFFFE08C).withOpacity(.8), blurRadius: 0, spreadRadius: 3)] : null,
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/* ===========================================================
 * 홈 
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
  String _weather = '';
  bool _readOnly = false;
  String? _strokesJson;

  // 👇 도장 상태 추가
  bool _stamp = false;

  @override
  void initState() {
    super.initState();
    _applyDate(widget.selectedDate, first: true);
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate || oldWidget.all != widget.all) {
      _applyDate(widget.selectedDate);
    }
  }

  String get _studentName => widget.profile?.name.isNotEmpty == true ? widget.profile!.name : '이름미정';

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
        _strokesJson = e.strokesJson;
        _stamp = e.stamp; // ✅ 저장된 값에 따라 도장 표시
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
      _tempImg = (img64 is String && img64.isNotEmpty) ? base64Decode(img64) : null;
      _strokesJson = d?['strokes'] as String?;
      _stamp = d?['stamp'] == true; // 드래프트에 있으면 반영
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
      'strokes': _strokesJson,
      'stamp': _stamp,
    };
    await Store.saveDraft(_studentName, date, m);
  }

  void _setWeather(String w) {
    setState(() => _weather = w);
    _saveDraft();
  }

  Future<void> _openCanvas() async {
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
      });
      _saveDraft();
    }
  }

  void _submit() async {
    final entry = DiaryEntry(
      studentName: _studentName,
      date: widget.selectedDate,
      title: titleCtrl.text.trim().isEmpty ? '제목 없음' : titleCtrl.text.trim(),
      weather: _weather,
      text: textCtrl.text.trim().isEmpty ? '내용 없음' : textCtrl.text.trim(),
      imageBytes: _tempImg,
      strokesJson: _strokesJson,
      stamp: _stamp, // ✅ 저장 시 도장 상태 유지
    );
    widget.onSaved(entry);
    await Store.clearDraft(_studentName, widget.selectedDate);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오늘의 그림일기가 저장되었습니다.')));
      setState(() => _readOnly = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 스크롤 가능하게 감싸기 (스타일 변경 없음)
    return SingleChildScrollView(
      child: SketchbookShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 날짜 + 날씨
            Padding(
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
                  WeatherButton(emoji: '☀️', active: _weather == '☀️', onTap: () => _setWeather('☀️')),
                  const SizedBox(width: 8),
                  WeatherButton(emoji: '☁️', active: _weather == '☁️', onTap: () => _setWeather('☁️')),
                  const SizedBox(width: 8),
                  WeatherButton(emoji: '❄️', active: _weather == '❄️', onTap: () => _setWeather('❄️')),
                  const SizedBox(width: 8),
                  WeatherButton(emoji: '🌧️', active: _weather == '🌧️', onTap: () => _setWeather('🌧️')),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const DashedDivider(),
            const SizedBox(height: 8),

            if (_readOnly) ..._buildReadOnly() else ..._buildForm(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildForm() {
    return [
      Row(
        children: [
          const SizedBox(width: 52, child: Text('제목', style: TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: titleCtrl,
              onChanged: (_) => _saveDraft(),
              decoration: _inputDeco('오늘 그림일기의 제목'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_tempImg == null)
        DottedThumbBox(onTap: _openCanvas)
      else
        GestureDetector(onTap: _openCanvas, child: SketchArtFrame(imageBytes: _tempImg)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF9),
          border: Border.all(color: const Color(0xFF222222), width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Positioned.fill(child: _LinedPaperOverlay(spacing: 32, offsetTop: 26, opacity: .23)),
            TextField(
              controller: textCtrl,
              onChanged: (_) => _saveDraft(),
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '오늘의 이야기를 써 보세요.',
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PillButton(label: '완성!', color: const Color(0xFFFFE08C), borderColor: const Color(0xFFD3A700), onTap: _submit),
        ],
      ),
    ];
  }

  List<Widget> _buildReadOnly() {
    return [
      const Text('오늘의 일기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 4),
      Text('${_krDate(widget.selectedDate)} / ${_weather.isNotEmpty ? _weather : ''}',
          style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 6),

      // ✅ 도장: stamp=true일 때만 표시
      if (_stamp)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Image.asset('assets/images/stamp.png', height: 120, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),

      SketchArtFrame(imageBytes: _tempImg),
      const SizedBox(height: 8),
      Text(titleCtrl.text.isEmpty ? '제목 없음' : titleCtrl.text, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(textCtrl.text, style: const TextStyle(fontSize: 15)),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PillButton(label: '✏️ 수정하기', color: const Color(0xFFFFE08C), borderColor: const Color(0xFFD3A700), onTap: () {
            setState(() => _readOnly = false);
          }),
        ],
      ),
    ];
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(width: 2, color: Color(0xFF222222)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(width: 2, color: Color(0xFF222222)),
        ),
        fillColor: const Color(0xFFFFFEF9),
        filled: true,
      );
}

/* ===========================================================
 * 일기장(폴라로이드 카드)
 * =========================================================== */

class JournalTab extends StatelessWidget {
  const JournalTab({super.key, required this.profile, required this.all, required this.onOpen, required this.onGoHome});
  final Profile? profile;
  final List<DiaryEntry> all;
  final ValueChanged<DiaryEntry> onOpen;
  final VoidCallback onGoHome;


  @override
  Widget build(BuildContext context) {
    final name = (profile?.name ?? '').isEmpty ? '이름미정' : profile!.name;
    final mine = all.where((d) => d.studentName == name).toList()..sort((a, b) => b.date.compareTo(a.date));

    return SingleChildScrollView(
      child: SketchbookShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text('내 일기장', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              primary: false,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 4 / 5,
              ),
              itemCount: mine.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => onOpen(mine[i]),
                child: _PolaroidCard(entry: mine[i]),
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _PillButton(
                label: '🖍️ 그림일기 쓰기',
                color: const Color(0xFFFFE08C),
                borderColor: const Color(0xFFD3A700),
                onTap: onGoHome,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({required this.entry});
  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.0035,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFEF9),
              border: Border.all(color: const Color(0xFF222222), width: 2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
            ),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD8D2C7)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: entry.imageBytes != null
                        ? Image.memory(entry.imageBytes!, fit: BoxFit.contain)
                        : const Center(child: Text('(그림 없음)', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  ),
                ),
                const SizedBox(height: 6),
                Text(entry.title.isEmpty ? '제목 없음' : entry.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${_krDate(entry.date)} / ${entry.weather}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          // 테이프
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
                    border: Border.all(color: Colors.black12, width: 1),
                    boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
                  ),
                ),
              ),
            ),
          ),
          if (entry.stamp)
            Positioned(
              top: 6,
              right: 6,
              child: Image.asset('assets/images/stamp.png', width: 56, height: 56, errorBuilder: (_, __, ___) {
                return const SizedBox.shrink();
              }),
            ),
        ],
      ),
    );
  }
}

/* ===========================================================
 * 상세 페이지 
 * =========================================================== */

class ViewDiaryPage extends StatelessWidget {
  const ViewDiaryPage({super.key, required this.entry, required this.onDelete});
  final DiaryEntry entry;
  final ValueChanged<DiaryEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry.title.isEmpty ? '제목 없음' : entry.title)),
      body: SingleChildScrollView( // ✅ 스크롤 가능
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SketchbookShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(entry.title.isEmpty ? '제목 없음' : entry.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${_krDate(entry.date)} / ${entry.weather}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 6),
                  if (entry.stamp)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Image.asset('assets/images/stamp.png', height: 120, errorBuilder: (_, __, ___) {
                        return const SizedBox.shrink();
                      }),
                    ),
                  SketchArtFrame(imageBytes: entry.imageBytes),
                  const SizedBox(height: 8),
                  Text(entry.text, style: const TextStyle(fontSize: 15)),
                  if (entry.teacherComment.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FBFF),
                        border: Border.all(color: const Color(0xFF6BB7FF), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('📝 선생님 코멘트',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1D5AA6))),
                        const SizedBox(height: 6),
                        Text(entry.teacherComment),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
                            content: const Text('정말 이 그림일기를 삭제하시겠어요?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
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
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile && !_edit) {
      final p = widget.profile ?? Profile();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이름을 입력해주세요.')));
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
        Profile(name: nameCtrl.text, school: schoolCtrl.text, grade: grade, classNum: classNum, intro: introCtrl.text);

    return SingleChildScrollView(
      child: SketchbookShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내 프로필', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (!_edit) ...[
              _RowText('이름', p.name),
              _RowText('학교', p.school),
              _RowText('학년', p.grade),
              _RowText('반', p.classNum),
              _RowText('소개', p.intro),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _PillButton(label: '✏️ 수정하기', color: const Color(0xFFFFE08C), borderColor: const Color(0xFFD3A700), onTap: () {
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
                    items: const ['1학년', '2학년', '3학년', '4학년', '5학년', '6학년'],
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
              _LabeledText('자기소개', introCtrl, hint: '나를 소개해요!', maxLines: 4),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _PillButton(label: '취소', color: Colors.white, borderColor: const Color(0xFF222222), onTap: () {
                  setState(() => _edit = false);
                }),
                const SizedBox(width: 8),
                _PillButton(label: '💾 저장하기', color: const Color(0xFF6BB7FF), borderColor: const Color(0xFF4F9FE9), textColor: Colors.white, onTap: _save),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

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
        if (picked != null) onChanged(DateFormat('yyyy-MM-dd').format(picked));
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFEF9),
          border: Border.all(color: const Color(0xFFB6B6B6), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const SizedBox(width: 52, child: Text('날짜 :', style: TextStyle(fontWeight: FontWeight.w700))),
            // Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(_krDate(value), style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText(this.label, this.controller, {this.hint, this.maxLines = 1});
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          fillColor: const Color(0xFFFFFEF9),
          filled: true,
        ),
      )
    ]);
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          SizedBox(width: 64, child: Text(label, style: th.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text((value ?? '').isEmpty ? '—' : value!, style: th.bodyMedium)),
        ],
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
      shape: StadiumBorder(side: BorderSide(color: borderColor, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(label, style: TextStyle(color: textColor ?? Colors.black, fontSize: 15)),
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
