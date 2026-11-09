// Signature tactile de la charte (acceptation OU signature, cf. spec).
import 'package:flutter/material.dart';
import 'theme.dart';

class SignaturePad extends StatefulWidget {
  final ValueChanged<bool> onChanged;
  const SignaturePad({super.key, required this.onChanged});
  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];
  void _clear() {
    setState(() => _points.clear());
    widget.onChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xFFFBFAF6),
            border: Border.all(color: AppColors.gold, width: 1.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() => _points.add(d.localPosition));
                widget.onChanged(true);
              },
              onPanEnd: (_) => setState(() => _points.add(null)),
              child: CustomPaint(
                painter: _SignaturePainter(_points),
                child: _points.isEmpty
                    ? const Center(
                        child: Text('Signez ici avec le doigt (optionnel)',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontStyle: FontStyle.italic)),
                      )
                    : null,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Effacer'),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  _SignaturePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.navyOld
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
