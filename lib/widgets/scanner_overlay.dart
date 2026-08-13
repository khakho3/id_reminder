import 'dart:math' as math;

import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({
    super.key,
    required this.statusMessage,
    this.isReady = false,
    this.isReading = false,
  });

  final String statusMessage;
  final bool isReady;
  final bool isReading;

  @override
  Widget build(BuildContext context) {
    final color = isReady
        ? const Color(0xFF67E8A5)
        : isReading
        ? const Color(0xFF7DD3FC)
        : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final frame = ScannerFrameGeometry.frameFor(size);
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ScannerMaskPainter(frame: frame, borderColor: color),
            ),
            Positioned(
              left: frame.left + 12,
              right: size.width - frame.right + 12,
              top: frame.top,
              height: frame.height,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isReady || isReading ? 0 : 0.78,
                  child: const Text(
                    'PLACE ID HERE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isReading
                        ? SizedBox(
                            key: const ValueKey('progress'),
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: color,
                            ),
                          )
                        : Icon(
                            isReady
                                ? Icons.check_circle_rounded
                                : Icons.badge_outlined,
                            key: ValueKey(isReady),
                            color: color,
                            size: 28,
                          ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      statusMessage,
                      key: ValueKey(statusMessage),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Keep the card flat and avoid glare',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ScannerFrameGeometry {
  static const double cardAspectRatio = 85.60 / 53.98;

  static Rect frameFor(Size size) {
    final horizontalPadding = size.width < 380 ? 24.0 : 32.0;
    final availableWidth = math.max(
      120.0,
      size.width - (horizontalPadding * 2),
    );
    // Keep a dedicated area at the bottom for the live scan guidance. On
    // short and landscape screens this is what prevents the frame and text
    // from being clipped or overlapping each other.
    final statusReserve = size.height < 500 ? 118.0 : 132.0;
    final maxFrameHeight = math.max(90.0, size.height - statusReserve - 64);
    final width = math.min(
      availableWidth,
      math.min(520.0, maxFrameHeight * cardAspectRatio),
    );
    final height = width / cardAspectRatio;
    final maximumTop = math.max(
      16.0,
      size.height - statusReserve - height - 16,
    );
    final top = (size.height * .22).clamp(16.0, maximumTop).toDouble();
    return Rect.fromLTWH((size.width - width) / 2, top, width, height);
  }
}

class _ScannerMaskPainter extends CustomPainter {
  const _ScannerMaskPainter({required this.frame, required this.borderColor});

  final Rect frame;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final frameShape = RRect.fromRectAndRadius(
      frame,
      const Radius.circular(18),
    );
    final outsidePath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(frameShape),
    );

    canvas.drawPath(
      outsidePath,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );
    canvas.drawRRect(
      frameShape,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerMaskPainter oldDelegate) {
    return frame != oldDelegate.frame || borderColor != oldDelegate.borderColor;
  }
}
