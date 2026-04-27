import 'package:flutter/material.dart';

/// Renders the blank answer space for one question or part on a paper preview.
/// Used ONLY in read-only paper previews — not in live exam taking.
class AnswerSpaceWidget extends StatelessWidget {
  const AnswerSpaceWidget({
    super.key,
    required this.answerSpaceType,
    this.answerLines = 4,
    this.answerBoxHeightMm = 80,
  });

  /// 'lines' | 'plain_box' | 'diagram_box' | 'construction_box' | 'grid_box'
  final String answerSpaceType;
  final int answerLines;

  /// Height in mm — converted to logical pixels at 3.78 px/mm.
  final int answerBoxHeightMm;

  static const double _mmToPx = 3.78;
  static const double _lineHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: switch (answerSpaceType) {
        'lines' => _buildLines(),
        'plain_box' => _buildBox(context, label: null),
        'diagram_box' => _buildBox(context, label: 'Diagram'),
        'construction_box' => _buildBox(
          context,
          label: 'Use ruler and compasses',
        ),
        'grid_box' => _buildGrid(context),
        _ => _buildLines(),
      },
    );
  }

  Widget _buildLines() {
    return Column(
      children: List.generate(
        answerLines,
        (_) => const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Divider(height: 1, thickness: 0.5, color: Color(0xFFBBBBBB)),
        ),
      ),
    );
  }

  Widget _buildBox(BuildContext context, {required String? label}) {
    final height = answerBoxHeightMm * _mmToPx;
    return Stack(
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (label != null)
          Positioned(
            right: 6,
            bottom: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final height = answerBoxHeightMm * _mmToPx;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _GridPainter(),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double cellSize = 28.0; // ~7mm at 96 dpi
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    for (double x = cellSize; x < size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = cellSize; y < size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
