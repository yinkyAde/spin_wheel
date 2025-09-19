import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() => runApp(const SimpleWheelApp());

class SimpleWheelApp extends StatelessWidget {
  const SimpleWheelApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Spin Wheel',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    home: const SimpleWheelScreen(),
  );
}

class SimpleWheelScreen extends StatefulWidget {
  const SimpleWheelScreen({super.key});
  @override
  State<SimpleWheelScreen> createState() => _SimpleWheelScreenState();
}

class _SimpleWheelScreenState extends State<SimpleWheelScreen> with TickerProviderStateMixin {
  int deathCount = 1; // 0..(_basePrizes.length-1)

  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _angle = 0; // absolute rotation (radians)
  bool _spinning = false;
  final _rng = Random();

  // Per‑spin snapshot & selection
  List<_Slice>? _spinSlices;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
    _anim = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic))
      ..addListener(() => setState(() {}))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _spinning = false;
          _onStop();
        }
      });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // Base prize tiers from smallest -> largest (so we can replace from the front)
  List<_Slice> get _basePrizes => [
    _Slice('€500k', Colors.orange.shade200, 10),
    _Slice('€1 Mio', Colors.orange.shade400, 9),
    _Slice('€10 Mio', Colors.amber.shade600, 6),
    _Slice('€100 Mio', Colors.amber.shade800, 3.5),
    _Slice('€1 Bil', Colors.deepOrange.shade400, 1.8),
    _Slice('€10 Bil', Colors.deepOrange.shade700, 0.9),
  ];

  int get _maxDeath => _basePrizes.length - 1; // leave at least one prize

  List<_Slice> get _slices {
    final int n = deathCount.clamp(1, _maxDeath).toInt();
    final wheel = List<_Slice>.from(_basePrizes);
    for (int i = 0; i < n; i++) {
      final removed = wheel[i];
      wheel[i] = _Slice('Death', Colors.black87, removed.weight, isDeath: true);
    }
    return wheel;
  }

  double _totalOf(List<_Slice> list) => list.fold(0.0, (s, e) => s + e.weight);

  void _spin() {
    if (_spinning) return;
    _spinning = true;
    HapticFeedback.mediumImpact();

    // Snapshot wheel for this spin
    _spinSlices = List<_Slice>.from(_slices);
    final list = _spinSlices!;
    final total = _totalOf(list);

    // Weighted pick
    final pick = _rng.nextDouble() * total;
    double acc = 0;
    int idx = 0;
    for (var i = 0; i < list.length; i++) {
      acc += list[i].weight;
      if (pick <= acc) { idx = i; break; }
    }
    _selectedIndex = idx; // lock selection

    // --- Center-locked target angle ---
    // Drawing uses start = -pi/2 - aSlice/2 (so wedge 0 center is at pointer when rotation==0).
    // To bring wedge `idx` center to the pointer, we need rotation R such that
    //   (rotation + (-pi/2 + idx*aSlice)) == -pi/2  (mod 2π)  => rotation == -idx*aSlice.
    final aSlice = (2 * pi) / list.length;
    final double currentNorm = _angle % (2 * pi);
    final double desiredNorm = (-idx * aSlice) % (2 * pi);
    final double spins = (6 + _rng.nextInt(3)) * 2 * pi; // full positive spins
    final double deltaNorm = (desiredNorm - currentNorm) % (2 * pi);
    final double target = _angle + spins + deltaNorm; // exact center alignment

    _anim = Tween<double>(begin: _angle, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    )..addListener(() => setState(() {}));

    _ctrl..reset()..forward();
    _angle = target; // keep model angle in sync
  }

  void _onStop() {
    final list = _spinSlices ?? _slices;
    final idx = _selectedIndex ?? 0;
    final s = list[idx];

    if (s.isDeath) {
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(s.isDeath ? FontAwesomeIcons.skull : Icons.celebration,
              size: 42, color: s.isDeath ? Colors.black : Colors.teal),
          const SizedBox(height: 10),
          Text(
            s.isDeath ? 'Uh‑oh! You hit Death.' : 'You won ${s.label}!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            s.isDeath
                ? 'Each Death wedge replaces a smaller prize for bigger stakes.'
                : 'Nice! Spin again or add a Death wedge to raise the stakes.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ]),
      ),
    );

    // clear per‑spin state
    _spinSlices = null;
    _selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Spin Wheel')),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final double shortest = min(constraints.maxWidth, constraints.maxHeight).toDouble();
            final double wheelSize = (shortest.clamp(240.0, 560.0) as double) * 0.8;
            final double pointerSize = max(40.0, wheelSize * 0.14).toDouble();

            return Column(children: [
              ListTile(
                title: const Text('Death wedges'),
                subtitle: const Text('Each one replaces the smallest prize (min 1 Death)'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _spinning || deathCount <= 1 ? null : () => setState(() => deathCount--),
                  ),
                  Text('$deathCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _spinning || deathCount >= _maxDeath ? null : () => setState(() => deathCount++),
                  ),
                ]),
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: wheelSize,
                    height: wheelSize,
                    child: Stack(alignment: Alignment.center, children: [
                      _Wheel(slices: _spinSlices ?? _slices, rotation: _anim.value),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(
                            Icons.arrow_drop_down,
                            size: pointerSize,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _spinning ? null : _spin,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                    child: Text(_spinning ? 'Spinning…' : 'SPIN'),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

// --- Drawing ---
class _Wheel extends StatelessWidget {
  final List<_Slice> slices;
  final double rotation;
  const _Wheel({required this.slices, required this.rotation});
  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: CustomPaint(painter: _WheelPainter(slices, rotation)),
  );
}

class _WheelPainter extends CustomPainter {
  final List<_Slice> slices;
  final double rot;
  _WheelPainter(this.slices, this.rot);

  @override
  void paint(Canvas canvas, Size size) {
    final double r = min(size.width, size.height) / 2;
    final Offset c = Offset(size.width / 2, size.height / 2);
    final Rect rect = Rect.fromCircle(center: c, radius: r);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.translate(-c.dx, -c.dy);

    final int count = max(1, slices.length);
    final double aSlice = (2 * pi) / count;
    // KEY: start so that wedge 0 center is at pointer when rotation==0
    double start = -pi / 2 - aSlice / 2;
    final Paint sector = Paint()..style = PaintingStyle.fill;
    final TextPainter tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int i = 0; i < count; i++) {
      final s = slices[i];
      sector.color = s.color;
      canvas.drawArc(rect, start, aSlice, true, sector);

      // label (responsive)
      final double mid = start + aSlice / 2;
      final Offset off = Offset(c.dx + (r * 0.62) * cos(mid), c.dy + (r * 0.62) * sin(mid));
      final double fs = (s.isDeath ? max(14.0, r * 0.095) : max(12.0, r * 0.075)).toDouble();
      tp.text = TextSpan(
        text: s.label,
        style: TextStyle(
          color: s.isDeath ? Colors.white : Colors.black87,
          fontSize: fs,
          fontWeight: s.isDeath ? FontWeight.w700 : FontWeight.w500,
        ),
      );
      tp.layout(maxWidth: r * 0.9);
      tp.paint(canvas, off - Offset(tp.width / 2, tp.height / 2));

      start += aSlice;
    }

    final Paint hub = Paint()..color = Colors.white;
    final double hubR = max(20.0, r * 0.08).toDouble();
    canvas.drawCircle(c, hubR, hub);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.slices != slices || old.rot != rot;
}

// --- Model ---
class _Slice {
  final String label;
  final Color color;
  final double weight;
  final bool isDeath;
  _Slice(this.label, this.color, this.weight, {this.isDeath = false});
  _Slice copyWith({double? weight}) => _Slice(label, color, weight ?? this.weight, isDeath: isDeath);
}
