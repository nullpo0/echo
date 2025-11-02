// lib/drawing_page.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:saver_gallery/saver_gallery.dart'; // 갤러리 저장

class DrawingPage extends StatefulWidget {
  const DrawingPage({
    super.key,
    this.onDone,                // PNG 콜백(선택)
    this.initialStrokesJson,    // 이어그리기 복원(선택)
  });

  final ValueChanged<Uint8List>? onDone;
  final String? initialStrokesJson;

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  // 렌더
  final _repaintKey = GlobalKey();

  // 데이터
  final _strokes = <Stroke>[];

  // 편집 히스토리(되돌리기/다시하기)
  final List<_EditAction> _undoStack = [];
  final List<_EditAction> _redoStack = [];

  // 도구 상태
  Color _color = Colors.black;
  bool _eraserMode = false; // ★ 획 지우개 모드

  // 두께 슬라이더
  double _thickness = 12.0; // 2~40 권장
  double _minWidth = 3.0;
  double _maxWidth = 12.0;

  // 속도 보정(필압 미지원 기기)
  static const double _speedThinStart = 100.0;
  static const double _speedThinEnd = 1800.0;

  // 진행 중 스트로크
  Stroke? _current;
  DateTime? _lastTime;
  Offset? _lastViewportPos;

  // 리렌더 트리거
  int _rev = 0;
  void _mark() => setState(() => _rev++);

  @override
  void initState() {
    super.initState();
    // ★ 저장된 strokes JSON 복원
    if (widget.initialStrokesJson != null && widget.initialStrokesJson!.isNotEmpty) {
      final restored = _decodeStrokesJson(widget.initialStrokesJson!);
      _strokes
        ..clear()
        ..addAll(restored);
    }
  }

  // ===== 입력 처리 =====
  void _startStroke(PointerDownEvent e) {
    final isStylus =
        e.kind == ui.PointerDeviceKind.stylus || e.kind == ui.PointerDeviceKind.invertedStylus;

    // ✏️ 그리기 모드: 스타일러스만 허용 / 🩹 지우개: 전부 허용
    if (!_eraserMode && !isStylus) return;

    _redoStack.clear();

    _lastTime = DateTime.now();
    _lastViewportPos = e.localPosition;

    // 지우개: 근처 '한 획' 삭제
    if (_eraserMode) {
      final idx = _hitStrokeIndex(e.localPosition);
      if (idx != null) {
        final removed = _strokes.removeAt(idx);
        _pushAction(_EditAction.remove(removed, idx));
        _mark();
      }
      return;
    }

    // 그리기
    final press = _normalizePressure(e);
    final width = _pressureToWidth(press);

    _current = Stroke(
      color: _color,
      points: [
        StrokePoint(
          e.localPosition,
          pressure: press,
          width: width,
          time: _lastTime!,
        ),
      ],
    );
    _mark();
  }

  void _extendStroke(PointerMoveEvent e) {
    final isStylus =
        e.kind == ui.PointerDeviceKind.stylus || e.kind == ui.PointerDeviceKind.invertedStylus;
    if (!_eraserMode && !isStylus) return;

    if (_eraserMode) {
      final idx = _hitStrokeIndex(e.localPosition);
      if (idx != null) {
        final removed = _strokes.removeAt(idx);
        _pushAction(_EditAction.remove(removed, idx));
        _mark();
      }
      return;
    }

    if (_current == null) return;

    final now = DateTime.now();
    var press = _normalizePressure(e);

    if (_looksUnsupportedPressure(e)) {
      final dt = now.difference(_lastTime!).inMilliseconds.clamp(1, 1000) / 1000.0;
      final dx = (e.localPosition.dx - _lastViewportPos!.dx);
      final dy = (e.localPosition.dy - _lastViewportPos!.dy);
      final speed = (math.sqrt(dx * dx + dy * dy)) / dt;
      final t = ((speed - _speedThinStart) / (_speedThinEnd - _speedThinStart)).clamp(0.0, 1.0);
      press = 1.0 - t * 0.9;
    }

    final width = _pressureToWidth(press);

    // 위치 스무딩(EMA)
    const double alpha = 0.6;
    final rawPos = e.localPosition;
    Offset scenePos = rawPos;
    if (_current!.points.isNotEmpty) {
      final last = _current!.points.last.position;
      scenePos = Offset(
        ui.lerpDouble(last.dx, rawPos.dx, alpha)!,
        ui.lerpDouble(last.dy, rawPos.dy, alpha)!,
      );
      if ((last - scenePos).distance < 0.15) {
        _lastTime = now;
        _lastViewportPos = e.localPosition;
        return;
      }
    }

    _current!.points.add(
      StrokePoint(scenePos, pressure: press, width: width, time: now),
    );

    _lastTime = now;
    _lastViewportPos = e.localPosition;
    _mark();
  }

  void _endStroke(PointerEvent e) {
    final isStylus =
        e.kind == ui.PointerDeviceKind.stylus || e.kind == ui.PointerDeviceKind.invertedStylus;
    if (!_eraserMode && !isStylus) return;

    if (_eraserMode) return; // 지우개는 move에서 처리함
    if (_current == null) return;

    if (_current!.points.isNotEmpty) {
      final index = _strokes.length;
      _strokes.add(_current!);
      _pushAction(_EditAction.add(_current!, index));
    }
    _current = null;
    _mark();
  }

  void _cancelStroke() {
    _current = null;
    _mark();
  }

  // ===== 공통 유틸 =====
  double _normalizePressure(PointerEvent e) {
    final min = e.pressureMin;
    final max = e.pressureMax;
    var p = e.pressure;
    if (max > min) p = ((p - min) / (max - min)).clamp(0.0, 1.5);
    return p.clamp(0.0, 1.0);
  }

  bool _looksUnsupportedPressure(PointerEvent e) {
    final unsupported = (e.pressureMax - e.pressureMin).abs() < 1e-6;
    final fixedOne = (e.pressure - 1.0).abs() < 1e-6;
    return unsupported || fixedOne;
  }

  double _pressureToWidth(double press) {
    _maxWidth = _thickness.clamp(2.0, 40.0);
    _minWidth = math.max(0.5, _maxWidth * 0.25);
    final curved = math.pow(press, 0.7).toDouble();
    return ui.lerpDouble(_minWidth, _maxWidth, curved)!.clamp(_minWidth, _maxWidth);
  }

  // ===== 편의 기능 =====
  void _undo() {
    if (_undoStack.isEmpty) return;
    final act = _undoStack.removeLast();

    switch (act.type) {
      case _ActionType.add:
        final idx = _indexOfStrokeIdentity(_strokes, act.stroke!);
        if (idx != -1) _strokes.removeAt(idx);
        _redoStack.add(act);
        break;

      case _ActionType.remove:
        final insertAt = act.index!.clamp(0, _strokes.length);
        _strokes.insert(insertAt, act.stroke!);
        _redoStack.add(act);
        break;

      case _ActionType.clear:
        _strokes
          ..clear()
          ..addAll(act.before!);
        _redoStack.add(act);
        break;
    }
    _mark();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final act = _redoStack.removeLast();

    switch (act.type) {
      case _ActionType.add:
        final insertAt = act.index!.clamp(0, _strokes.length);
        _strokes.insert(insertAt, act.stroke!);
        _undoStack.add(act);
        break;

      case _ActionType.remove:
        final idx = _indexOfStrokeIdentity(_strokes, act.stroke!);
        final removeAt = idx != -1 ? idx : act.index!.clamp(0, _strokes.length - 1);
        if (_strokes.isNotEmpty && removeAt >= 0 && removeAt < _strokes.length) {
          _strokes.removeAt(removeAt);
        }
        _undoStack.add(act);
        break;

      case _ActionType.clear:
        _strokes.clear();
        _undoStack.add(act);
        break;
    }
    _mark();
  }

  Future<void> _clear() async {
    if (_strokes.isEmpty) return;
    final before = List<Stroke>.from(_strokes);
    _strokes.clear();
    _pushAction(_EditAction.clear(before));
    _current = null;
    _mark();
  }

  Future<Uint8List?> _exportPng({double pixelRatio = 3.0}) async {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToGallery() async {
    final png = await _exportPng();
    if (!mounted) return;
    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 생성 실패')),
      );
      return;
    }

    final name = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      final res = await SaverGallery.saveImage(
        png,
        quality: 100,
        fileName: name,
        androidRelativePath: 'Pictures/DrawingPad',
        skipIfExists: false,
      );
      final ok = res.isSuccess;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '갤러리에 저장됨: $name' : '저장 실패')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const paper = Color(0xFFFFFDF8);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            const Icon(Icons.brush, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                ),
                child: Slider(
                  value: _thickness,
                  min: 2,
                  max: 40,
                  divisions: 38,
                  label: _thickness.round().toString(),
                  onChanged: (v) => setState(() => _thickness = v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 32,
              child: Text(
                _thickness.round().toString(),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: '되돌리기', icon: const Icon(Icons.undo), onPressed: _undo),
          IconButton(tooltip: '다시하기', icon: const Icon(Icons.redo), onPressed: _redo),
          IconButton(tooltip: '전체 지우기', icon: const Icon(Icons.layers_clear), onPressed: _clear),
          IconButton(
            tooltip: '갤러리에 저장',
            icon: const Icon(Icons.save_alt),
            onPressed: _saveToGallery,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: FilledButton(
              onPressed: () async {
                final png = await _exportPng();
                if (png == null) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PNG 생성 실패')),
                  );
                  return;
                }

                final strokesJson = _encodeStrokesJson(_strokes); // ★ JSON 직렬화

                // (선택) 콜백
                widget.onDone?.call(png);

                // pop으로 png + strokes 함께 반환
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop({'png': png, 'strokes': strokesJson});
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PNG가 준비되었습니다')),
                  );
                }
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
              child: const Text('그림 완성!'),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          _VerticalPalette(
            color: _color,
            eraserMode: _eraserMode,
            onPick: (c) => setState(() {
              _eraserMode = false;
              _color = c;
            }),
            onToggleEraser: () => setState(() => _eraserMode = !_eraserMode),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth;
                  final maxH = constraints.maxHeight;
                  const aspect = 4 / 3;

                  double w = maxW;
                  double h = w / aspect;
                  if (h > maxH) {
                    h = maxH;
                    w = h * aspect;
                  }

                  return Center(
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(blurRadius: 10, spreadRadius: -4)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: RepaintBoundary(
                            key: _repaintKey,
                            child: Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: _startStroke,
                              onPointerMove: _extendStroke,
                              onPointerUp: _endStroke,
                              onPointerCancel: (_) => _cancelStroke(),
                              child: CustomPaint(
                                painter: _CanvasPainter(
                                  strokes: _strokes,
                                  current: _current,
                                  background: paper,
                                  revision: _rev,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 히스토리 도우미 =====
  void _pushAction(_EditAction act) {
    _undoStack.add(act);
    _redoStack.clear();
  }

  int _indexOfStrokeIdentity(List<Stroke> list, Stroke target) {
    for (int i = 0; i < list.length; i++) {
      if (identical(list[i], target)) return i;
    }
    return -1;
  }

  // ====== ‘획 단위’ 지우개 히트 테스트 ======
  int? _hitStrokeIndex(Offset p) {
    for (int i = _strokes.length - 1; i >= 0; i--) {
      final s = _strokes[i];
      if (s.points.isEmpty) continue;

      final avgW = s.points.map((e) => e.width).fold<double>(0, (a, b) => a + b) /
          math.max(1, s.points.length);
      final th = math.max(14.0, avgW * 0.9);

      for (int j = 1; j < s.points.length; j++) {
        final a = s.points[j - 1].position;
        final b = s.points[j].position;
        if (_distanceToSegment(p, a, b) <= th) {
          return i;
        }
      }

      if (s.points.length == 1) {
        if ((s.points.first.position - p).distance <= th) {
          return i;
        }
      }
    }
    return null;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 == 0) return (p - a).distance;
    double t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance;
  }

  // ===== JSON 직렬화/복원 =====
  String _encodeStrokesJson(List<Stroke> strokes) {
    final list = strokes
        .map((s) => {
              'color': s.color.value,
              'points': s.points
                  .map((p) => {
                        'x': p.position.dx,
                        'y': p.position.dy,
                        'pressure': p.pressure,
                        'width': p.width,
                        't': p.time.millisecondsSinceEpoch,
                      })
                  .toList(),
            })
        .toList();
    return jsonEncode(list);
  }

  List<Stroke> _decodeStrokesJson(String jsonStr) {
    try {
      final raw = jsonDecode(jsonStr) as List<dynamic>;
      return raw.map<Stroke>((m) {
        final map = m as Map<String, dynamic>;
        final color = Color(map['color'] as int);
        final pts = (map['points'] as List<dynamic>).map<StrokePoint>((pm) {
          final mm = pm as Map<String, dynamic>;
          return StrokePoint(
            Offset((mm['x'] as num).toDouble(), (mm['y'] as num).toDouble()),
            pressure: (mm['pressure'] as num).toDouble(),
            width: (mm['width'] as num).toDouble(),
            time: DateTime.fromMillisecondsSinceEpoch(mm['t'] as int),
          );
        }).toList();
        return Stroke(color: color, points: pts);
      }).toList();
    } catch (_) {
      return <Stroke>[];
    }
  }
}

/// 편집 액션
enum _ActionType { add, remove, clear }

class _EditAction {
  _EditAction.add(Stroke stroke, int index)
      : type = _ActionType.add,
        stroke = stroke,
        index = index,
        before = null;

  _EditAction.remove(Stroke stroke, int index)
      : type = _ActionType.remove,
        stroke = stroke,
        index = index,
        before = null;

  _EditAction.clear(List<Stroke> before)
      : type = _ActionType.clear,
        stroke = null,
        index = null,
        before = before;

  final _ActionType type;
  final Stroke? stroke; // add/remove
  final int? index; // add/remove
  final List<Stroke>? before; // clear
}

/// 왼쪽 세로 팔레트 + 지우개 버튼
/// 왼쪽 세로 팔레트 + 무지개(커스텀 컬러 피커) + 지우개 버튼
class _VerticalPalette extends StatelessWidget {
  const _VerticalPalette({
    required this.color,
    required this.eraserMode,
    required this.onPick,
    required this.onToggleEraser,
  });

  final Color color;
  final bool eraserMode;
  final ValueChanged<Color> onPick;
  final VoidCallback onToggleEraser;

  // 기본 칩들 (보라와 흰색 사이에 커스텀 버튼 삽입)
  static const List<Color> colors = [
    Colors.black,
    Color(0xffb71c1c),
    Color(0xffef6c00),
    Color(0xfffdd835),
    Color(0xff1b5e20),
    Color(0xff76e0d6),
    Color(0xff6fa8ff),
    Color(0xff0d47a1),
    Color(0xff6a1b9a), // 보라
    // [여기에 무지개 버튼 자리]
    Colors.white,
  ];

  static const int _pickerPos = 9; // 0-based: 보라 다음(흰색 바로 앞)

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = colors.length + 1; // 무지개 버튼 포함
    // + 지우개 버튼 1개 더
    final itemCount = total + 1;

    return Container(
      width: 64,
      margin: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(blurRadius: 10, spreadRadius: -6)],
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          // 맨 끝: 지우개 버튼
          if (i == itemCount - 1) {
            return _EraserTile(
              active: eraserMode,
              onTap: onToggleEraser,
            );
          }

          // 무지개 버튼 자리
          if (i == _pickerPos) {
            return _RainbowCircle(
              onTap: () async {
                final picked = await _showCompactColorPickerSheet(context, initial: color);
                if (picked != null) onPick(picked);
              },
            );
          }

          final idx = i > _pickerPos ? i - 1 : i; // 인덱스 보정
          final c = colors[idx];
          final selected = !eraserMode && c.value == color.value;

          return GestureDetector(
            onTap: () => onPick(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.amber : Colors.white,
                  width: selected ? 3 : 2,
                ),
                boxShadow: const [BoxShadow(blurRadius: 6, spreadRadius: -2)],
              ),
              child: selected
                  ? const Center(child: Icon(Icons.check, size: 18, color: Colors.black))
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _EraserTile extends StatelessWidget {
  const _EraserTile({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? cs.primary.withOpacity(0.15) : cs.surface,
          border: Border.all(
            color: active ? cs.primary : Colors.white,
            width: active ? 3 : 2,
          ),
          boxShadow: const [BoxShadow(blurRadius: 6, spreadRadius: -2)],
        ),
        child: Icon(
          Icons.auto_fix_off,
          size: 18,
          color: active ? cs.primary : cs.onSurface,
        ),
      ),
    );
  }
}

/// 무지개 그라디언트 동그라미 (컬러 피커 트리거)
class _RainbowCircle extends StatelessWidget {
  const _RainbowCircle({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(colors: [
            Colors.red, Colors.orange, Colors.yellow, Colors.green,
            Colors.cyan, Colors.blue, Colors.purple, Colors.red,
          ]),
          boxShadow: const [BoxShadow(blurRadius: 6, spreadRadius: -2)],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Center(
          child: Icon(Icons.colorize, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// ======= 콤팩트 컬러 피커(bottom sheet) =======
Future<Color?> _showCompactColorPickerSheet(BuildContext context, {required Color initial}) async {
  Color temp = initial;

  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final sz = MediaQuery.of(ctx).size;
      final double sheetH = math.min(420.0, sz.height * 0.55);

      double hue = HSVColor.fromColor(temp).hue;
      void setHue(double h) {
        final hsv = HSVColor.fromColor(temp);
        temp = HSVColor.fromAHSV(hsv.alpha, h, hsv.saturation, hsv.value).toColor();
      }

      return SafeArea(
        child: SizedBox(
          height: sheetH,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                final hsv = HSVColor.fromColor(temp);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hue 바 + 미리보기
                    SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          _ColorPreviewCircle(color: temp),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 20,
                              child: _HueBar(
                                hue: hue,
                                onChanged: (h) => setLocal(() {
                                  hue = h;
                                  setHue(h);
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // S/V 박스
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1.6,
                          child: _SVBox(
                            hue: hue,
                            saturation: hsv.saturation,
                            value: hsv.value,
                            onChanged: (s, v) {
                              setLocal(() {
                                temp = HSVColor.fromAHSV(1, hue, s, v).toColor();
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    // 버튼
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        0, 8, 0, 12 + MediaQuery.of(ctx).viewPadding.bottom,
                      ),
                      child: Row(
                        children: [
                          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('취소')),
                          const Spacer(),
                          FilledButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('완료')),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

// Hue 슬라이더(0~360)
class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});
  final double hue; // 0..360
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = c.maxWidth;
        final x = (hue / 360.0).clamp(0.0, 1.0) * w;
        double _dxToHue(double dx) => (dx / w).clamp(0.0, 1.0) * 360.0;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => onChanged(_dxToHue(d.localPosition.dx)),
          onPanUpdate: (d) => onChanged(_dxToHue(d.localPosition.dx)),
          child: Stack(
            children: [
              Container(
                height: 16,
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black.withOpacity(0.12)),
                  gradient: const LinearGradient(colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ]),
                ),
              ),
              Positioned(
                left: (x - 10).clamp(0.0, w - 20),
                top: 0, bottom: 0,
                child: Container(
                  width: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    boxShadow: const [BoxShadow(blurRadius: 4, spreadRadius: -1)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Hue 고정, 가로 S(0→1), 세로 V(1→0)
class _SVBox extends StatelessWidget {
  const _SVBox({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  final double hue;          // 0..360
  final double saturation;   // 0..1
  final double value;        // 0..1
  final void Function(double s, double v) onChanged;

  @override
  Widget build(BuildContext context) {
    final base = HSVColor.fromAHSV(1, hue, 1, 1).toColor();

    return LayoutBuilder(
      builder: (ctx, cons) {
        final w = cons.maxWidth;
        final h = cons.maxHeight;

        double clamp01(double x) => x.clamp(0.0, 1.0);

        void handle(Offset p) {
          final s = clamp01(p.dx / w);
          final v = clamp01(1.0 - (p.dy / h)); // 위(1) -> 아래(0)
          onChanged(s, v);
        }

        final knobX = saturation * w;
        final knobY = (1.0 - value) * h;

        return GestureDetector(
          onPanDown: (d) => handle(d.localPosition),
          onPanUpdate: (d) => handle(d.localPosition),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(blurRadius: 6, spreadRadius: -3)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // 가로: white -> base(hue,1,1)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.white, base],
                      ),
                    ),
                  ),
                  // 세로: 위 투명 -> 아래 검정 (Value 감소)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  // 현재 위치 표시
                  Positioned(
                    left: (knobX - 10).clamp(0.0, w - 20),
                    top: (knobY - 10).clamp(0.0, h - 20),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        color: HSVColor.fromAHSV(1, hue, saturation, value).toColor(),
                        boxShadow: const [BoxShadow(blurRadius: 4, spreadRadius: -1)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ColorPreviewCircle extends StatelessWidget {
  const _ColorPreviewCircle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 4, spreadRadius: -1)],
      ),
    );
  }
}

// ===== 데이터 모델 =====
class StrokePoint {
  StrokePoint(this.position, {required this.pressure, required this.width, required this.time});
  final Offset position; // 씬 좌표
  final double pressure;
  final double width;
  final DateTime time;
}

class Stroke {
  Stroke({
    required this.color,
    required this.points,
  });

  final Color color;
  final List<StrokePoint> points;
}

// ===== 페인터 =====
class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.strokes,
    required this.current,
    required this.background,
    required this.revision,
  });

  final List<Stroke> strokes;
  final Stroke? current;
  final Color background;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, bgPaint);

    _paintStrokes(canvas, strokes);
    if (current != null) _paintStrokes(canvas, [current!]);
  }

  // Catmull–Rom 스플라인으로 부드럽게
  void _paintStrokes(Canvas canvas, List<Stroke> list) {
    const double tension = 0.5;

    for (final s in list) {
      final pts = s.points;
      if (pts.isEmpty) continue;

      final paint = Paint()
        ..blendMode = BlendMode.srcOver
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      if (pts.length == 1) {
        final p = pts.first;
        canvas.drawCircle(p.position, p.width / 2, Paint()..color = s.color);
        continue;
      }

      Offset getPos(int i) {
        if (i < 0) return pts.first.position;
        if (i >= pts.length) return pts.last.position;
        return pts[i].position;
      }

      double getWidth(int i) {
        if (i < 0) return pts.first.width;
        if (i >= pts.length) return pts.last.width;
        return pts[i].width;
      }

      for (int i = 0; i < pts.length - 1; i++) {
        final p0 = getPos(i - 1);
        final p1 = getPos(i);
        final p2 = getPos(i + 1);
        final p3 = getPos(i + 2);

        final c1 = Offset(
          p1.dx + (p2.dx - p0.dx) * (tension / 6.0),
          p1.dy + (p2.dy - p0.dy) * (tension / 6.0),
        );
        final c2 = Offset(
          p2.dx - (p3.dx - p1.dx) * (tension / 6.0),
          p2.dy - (p3.dy - p1.dy) * (tension / 6.0),
        );

        final w = ui.lerpDouble(getWidth(i), getWidth(i + 1), 0.5)!.clamp(0.5, 100.0);

        final segPath = Path()..moveTo(p1.dx, p1.dy);
        segPath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);

        paint.strokeWidth = w;
        canvas.drawPath(segPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter old) {
    return old.revision != revision;
  }
}
