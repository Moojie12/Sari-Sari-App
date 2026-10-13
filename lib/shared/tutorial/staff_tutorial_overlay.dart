import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'staff_tutorial_service.dart';
import 'staff_tutorial_step.dart';

/// Fullscreen overlay that highlights Owner and Employee features with
/// a spotlight cutout and interactive step walkthrough cards.
class StaffTutorialOverlay extends StatefulWidget {
  const StaffTutorialOverlay({
    super.key,
    required this.onDismiss,
    required this.isOwner,
    this.steps,
    this.initialStep = 0,
    this.enablePulse = true,
  });

  final VoidCallback onDismiss;
  final bool isOwner;
  final List<StaffTutorialStep>? steps;
  final int initialStep;
  final bool enablePulse;

  @override
  State<StaffTutorialOverlay> createState() => _StaffTutorialOverlayState();
}

class _StaffTutorialOverlayState extends State<StaffTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late List<StaffTutorialStep> _steps;
  late int _currentStepIndex;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _steps = widget.steps ?? (widget.isOwner ? StaffTutorialStep.ownerSteps : StaffTutorialStep.employeeSteps);
    _currentStepIndex = widget.initialStep.clamp(0, max(0, _steps.length - 1));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.enablePulse) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 0.5;
    }

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() => _currentStepIndex++);
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() => _currentStepIndex--);
    }
  }

  Future<void> _skipTutorial() async {
    await StaffTutorialService.markTutorialCompleted(isOwner: widget.isOwner);
    widget.onDismiss();
  }

  Future<void> _finishTutorial() async {
    await StaffTutorialService.markTutorialCompleted(isOwner: widget.isOwner);
    widget.onDismiss();
  }

  Rect _calculateTargetRect(BuildContext context, StaffTutorialStep step) {
    if (step.targetKey != null && step.targetKey!.currentContext != null) {
      try {
        final renderBox = step.targetKey!.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null &&
            renderBox.attached &&
            renderBox.hasSize &&
            renderBox.size.width > 0 &&
            renderBox.size.height > 0) {
          final overlayRenderBox = context.findRenderObject() as RenderBox?;
          final position = overlayRenderBox != null && overlayRenderBox.attached
              ? renderBox.localToGlobal(Offset.zero, ancestor: overlayRenderBox)
              : renderBox.localToGlobal(Offset.zero);
          final rawRect = position & renderBox.size;
          return Rect.fromLTRB(
            rawRect.left - step.padding.left,
            rawRect.top - step.padding.top,
            rawRect.right + step.padding.right,
            rawRect.bottom + step.padding.bottom,
          );
        }
      } catch (_) {}
    }

    // Fallback: estimate floating bottom navigation bar positions
    final media = MediaQuery.of(context);
    final size = media.size;
    final bottomBarY = size.height - 32 - 60;
    final navWidth = size.width - 48;
    final itemWidth = navWidth / 5;

    int navIndex = 0;
    if (step.id.contains('home')) {
      navIndex = 0;
    } else if (step.id.contains('pos')) {
      navIndex = 1;
    } else if (step.id.contains('inventory')) {
      navIndex = 2;
    } else if (step.id.contains('orders')) {
      navIndex = 3;
    } else if (step.id.contains('profile')) {
      navIndex = 4;
    }

    return Rect.fromCenter(
      center: Offset(24 + itemWidth * (navIndex + 0.5), bottomBarY + 30),
      width: 54,
      height: 54,
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStepIndex];
    final targetRect = _calculateTargetRect(context, step);
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Spotlight cutout mask
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _StaffSpotlightPainter(
                  targetRect: targetRect,
                  isCircle: step.isCircle,
                  borderRadius: step.borderRadius,
                  pulseScale: widget.enablePulse ? (1.0 + _pulseAnimation.value * 0.08) : 1.0,
                ),
              );
            },
          ),

          // Interactivity blocker that permits taps on the card
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: const SizedBox.expand(),
            ),
          ),

          // Guidance Card
          _buildGuidanceCard(context, step, targetRect, size),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard(
    BuildContext context,
    StaffTutorialStep step,
    Rect targetRect,
    Size screenSize,
  ) {
    // Determine card positioning: place card in top half if target is near bottom bar
    final isTargetInBottomHalf = targetRect.center.dy > screenSize.height * 0.5;
    final cardTop = isTargetInBottomHalf
        ? (screenSize.height * 0.18)
        : (targetRect.bottom + 20);

    return Positioned(
      left: 20,
      right: 20,
      top: cardTop,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(step.id),
        duration: const Duration(milliseconds: 300),
        tween: Tween<double>(begin: 0.92, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon, Role Badge, Skip button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(step.icon, color: AppColors.primaryOrange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.isOwner ? 'Owner Tutorial' : 'Employee Tutorial'} • Step ${_currentStepIndex + 1} of ${_steps.length}',
                          style: TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('staff_tut_skip_button'),
                    onPressed: _skipTutorial,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                step.description,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Step indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (idx) {
                  final isCurrent = idx == _currentStepIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 5,
                    width: isCurrent ? 20 : 5,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primaryOrange
                          : AppColors.borderColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),

              // Footer Actions
              Row(
                children: [
                  if (_currentStepIndex > 0)
                    OutlinedButton.icon(
                      key: const Key('staff_tut_back_button'),
                      onPressed: _previousStep,
                      icon: const Icon(Icons.arrow_back, size: 15),
                      label: const Text('Back', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.darkText,
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  const Spacer(),
                  if (_currentStepIndex < _steps.length - 1)
                    ElevatedButton.icon(
                      key: const Key('staff_tut_next_button'),
                      onPressed: _nextStep,
                      icon: const Text('Next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      label: const Icon(Icons.arrow_forward, size: 15),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      key: const Key('staff_tut_finish_button'),
                      onPressed: _finishTutorial,
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Finish', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffSpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final bool isCircle;
  final double borderRadius;
  final double pulseScale;

  _StaffSpotlightPainter({
    required this.targetRect,
    required this.isCircle,
    required this.borderRadius,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withValues(alpha: 0.75);

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final spotlightCenter = targetRect.center;
    final scaledWidth = targetRect.width * pulseScale;
    final scaledHeight = targetRect.height * pulseScale;
    final scaledRect = Rect.fromCenter(
      center: spotlightCenter,
      width: scaledWidth,
      height: scaledHeight,
    );

    final spotlightPath = Path();
    if (isCircle) {
      spotlightPath.addOval(scaledRect);
    } else {
      spotlightPath.addRRect(
        RRect.fromRectAndRadius(scaledRect, Radius.circular(borderRadius)),
      );
    }

    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      spotlightPath,
    );

    canvas.drawPath(combinedPath, backgroundPaint);

    // Glowing border ring
    final borderPaint = Paint()
      ..color = AppColors.primaryOrange.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    if (isCircle) {
      canvas.drawOval(scaledRect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, Radius.circular(borderRadius)),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaffSpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseScale != pulseScale ||
        oldDelegate.isCircle != isCircle;
  }
}
