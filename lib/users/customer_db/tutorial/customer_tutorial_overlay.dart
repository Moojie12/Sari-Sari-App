import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/customer_db/tutorial/customer_tutorial_service.dart';
import 'package:sari_sari/users/customer_db/tutorial/customer_tutorial_step.dart';

/// Fullscreen overlay that highlights customer app features with a modern
/// spotlight/highlight cutout and an interactive guidance card with Next,
/// Back, Skip, and Finish buttons.
class CustomerTutorialOverlay extends StatefulWidget {
  const CustomerTutorialOverlay({
    super.key,
    required this.onDismiss,
    this.steps,
    this.initialStep = 0,
    this.onStepChanged,
    this.enablePulse = true,
  });

  final VoidCallback onDismiss;
  final List<CustomerTutorialStep>? steps;
  final int initialStep;
  final ValueChanged<int>? onStepChanged;
  final bool enablePulse;

  @override
  State<CustomerTutorialOverlay> createState() => CustomerTutorialOverlayState();
}

class CustomerTutorialOverlayState extends State<CustomerTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late List<CustomerTutorialStep> _steps;
  late int _currentStepIndex;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _steps = widget.steps ?? CustomerTutorialStep.defaultSteps;
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

    _onStepTransition();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToCurrentStepTarget() {
    final step = _steps[_currentStepIndex];
    final key = step.targetKey;
    if (key != null && key.currentContext != null) {
      try {
        final scrollable = Scrollable.maybeOf(key.currentContext!);
        if (scrollable != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: step.id == 'search' ? 0.25 : 0.40,
          ).then((_) {
            if (mounted) setState(() {});
          });
        }
      } catch (_) {}
    }
  }

  void _onStepTransition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToCurrentStepTarget();
    });
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      widget.onStepChanged?.call(_currentStepIndex);
      _onStepTransition();
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      widget.onStepChanged?.call(_currentStepIndex);
      _onStepTransition();
    }
  }

  Future<void> _skipTutorial() async {
    await CustomerTutorialService.markTutorialCompleted();
    widget.onDismiss();
  }

  Future<void> _finishTutorial() async {
    await CustomerTutorialService.markTutorialCompleted();
    widget.onDismiss();
  }

  @visibleForTesting
  Rect calculateTargetRectForTest(BuildContext context, CustomerTutorialStep step) =>
      _calculateTargetRect(context, step);

  Rect _calculateTargetRect(BuildContext context, CustomerTutorialStep step) {
    // 1. Try finding by GlobalKey if mounted and valid
    if (step.targetKey != null && step.targetKey!.currentContext != null) {
      try {
        final renderBox =
            step.targetKey!.currentContext!.findRenderObject() as RenderBox?;
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

    // 2. Fallbacks based on step id and screen dimensions
    final media = MediaQuery.of(context);
    final size = media.size;
    final paddingTop = media.padding.top;

    // Detect if "My Order" banner is currently visible on the customer homepage
    final hasActiveOrder = CustomerOrderController().orders.any((o) =>
        o.status != OrderStatus.completed &&
        o.status != OrderStatus.cancelled &&
        o.status != OrderStatus.delivered);

    switch (step.id) {
      case 'home':
        final bottomBarY = size.height - 32 - 54;
        final navWidth = size.width - 120;
        final itemWidth = navWidth / 4;
        return Rect.fromCenter(
          center: Offset(60 + itemWidth * 0.5, bottomBarY + 27),
          width: 52,
          height: 52,
        );
      case 'search':
        final searchY = paddingTop + (hasActiveOrder ? 259 : 114);
        return Rect.fromLTWH(24, searchY, size.width - 48, 48);
      case 'add_to_cart':
        final dealY = paddingTop + (hasActiveOrder ? 611 : 466);
        return Rect.fromLTWH(size.width - 24 - 34, dealY, 44, 44);
      case 'cart':
      case 'checkout':
        return Rect.fromLTWH(size.width - 66, paddingTop + 22, 48, 48);
      case 'orders':
        final bottomBarY = size.height - 32 - 54;
        final navWidth = size.width - 120;
        final itemWidth = navWidth / 4;
        return Rect.fromCenter(
          center: Offset(60 + itemWidth * 2.5, bottomBarY + 27),
          width: 52,
          height: 52,
        );
      case 'notifications':
        final bottomBarY = size.height - 32 - 54;
        final navWidth = size.width - 120;
        final itemWidth = navWidth / 4;
        return Rect.fromCenter(
          center: Offset(60 + itemWidth * 1.5, bottomBarY + 27),
          width: 52,
          height: 52,
        );
      case 'profile':
        final bottomBarY = size.height - 32 - 54;
        final navWidth = size.width - 120;
        final itemWidth = navWidth / 4;
        return Rect.fromCenter(
          center: Offset(60 + itemWidth * 3.5, bottomBarY + 27),
          width: 52,
          height: 52,
        );
      default:
        return Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 100,
          height: 100,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) return const SizedBox.shrink();

    final step = _steps[_currentStepIndex];
    final media = MediaQuery.of(context);
    final size = media.size;
    final targetRect = _calculateTargetRect(context, step);

    final isTargetInLowerHalf = targetRect.center.dy > (size.height * 0.52);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Spotlight Canvas with Cutout & Glowing Pulse (evaluates targetRect live for smooth tracking)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, _) {
                final liveRect = _calculateTargetRect(context, step);
                return CustomPaint(
                  painter: _SpotlightPainter(
                    targetRect: liveRect,
                    isCircle: step.isCircle,
                    borderRadius: step.borderRadius,
                    pulseValue: _pulseAnimation.value,
                    overlayColor: Colors.black.withValues(alpha: 0.75),
                  ),
                );
              },
            ),
          ),

          // Interactivity blocker around target, but allow touching card
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Prevent accidental taps from dismissing; keep user focused on buttons
              },
            ),
          ),

          // Instruction / Feature Tooltip Card
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 20,
            right: 20,
            top: isTargetInLowerHalf
                ? null
                : (targetRect.bottom + 16).clamp(
                    media.padding.top + 16.0,
                    max(media.padding.top + 16.0, size.height - 300.0),
                  ),
            bottom: isTargetInLowerHalf
                ? ((size.height - targetRect.top) + 16).clamp(
                    16.0,
                    max(16.0, size.height - 300.0),
                  )
                : null,
            child: _TutorialCard(
              stepIndex: _currentStepIndex,
              totalSteps: _steps.length,
              step: step,
              onNext: _nextStep,
              onBack: _previousStep,
              onSkip: _skipTutorial,
              onFinish: _finishTutorial,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates the dark spotlight cutout with a pulsing highlight ring.
class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final bool isCircle;
  final double borderRadius;
  final double pulseValue;
  final Color overlayColor;

  _SpotlightPainter({
    required this.targetRect,
    required this.isCircle,
    required this.borderRadius,
    required this.pulseValue,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    // Use saveLayer to cleanly punch a transparent cutout through the overlay
    canvas.saveLayer(fullRect, Paint());

    // 1. Fill screen with semi-transparent overlay
    canvas.drawRect(fullRect, Paint()..color = overlayColor);

    // 2. Punch cutout hole
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    if (isCircle) {
      canvas.drawOval(targetRect, clearPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(targetRect, Radius.circular(borderRadius)),
        clearPaint,
      );
    }

    canvas.restore();

    // 3. Draw active highlight border
    final borderPaint = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (isCircle) {
      canvas.drawOval(targetRect, borderPaint);

      // Expanding pulse ring
      final pulseRadiusX = (targetRect.width / 2) + (pulseValue * 8);
      final pulseRadiusY = (targetRect.height / 2) + (pulseValue * 8);
      final pulsePaint = Paint()
        ..color = AppColors.primaryOrange.withValues(alpha: (1.0 - pulseValue) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawOval(
        Rect.fromCenter(
          center: targetRect.center,
          width: pulseRadiusX * 2,
          height: pulseRadiusY * 2,
        ),
        pulsePaint,
      );
    } else {
      final rrect =
          RRect.fromRectAndRadius(targetRect, Radius.circular(borderRadius));
      canvas.drawRRect(rrect, borderPaint);

      // Expanding pulse ring
      final pulseRect = targetRect.inflate(pulseValue * 7);
      final pulsePaint = Paint()
        ..color = AppColors.primaryOrange.withValues(alpha: (1.0 - pulseValue) * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          pulseRect,
          Radius.circular(borderRadius + 4),
        ),
        pulsePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isCircle != isCircle ||
        oldDelegate.borderRadius != borderRadius;
  }
}

/// The modern onboarding card containing step badge, feature title,
/// description, dot indicators, and Next, Back, Skip, Finish buttons.
class _TutorialCard extends StatelessWidget {
  const _TutorialCard({
    required this.stepIndex,
    required this.totalSteps,
    required this.step,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.onFinish,
  });

  final int stepIndex;
  final int totalSteps;
  final CustomerTutorialStep step;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  bool get isFirst => stepIndex == 0;
  bool get isLast => stepIndex == totalSteps - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Step pill badge + Skip button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step ${stepIndex + 1} of $totalSteps',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                key: const Key('tutorial_skip_button'),
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Feature Icon & Title
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.icon,
                  color: AppColors.primaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Description text
          Text(
            step.description,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Progress Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalSteps, (index) {
              final isActive = index == stepIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: isActive ? 22 : 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryOrange
                      : AppColors.borderColor.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // Action Buttons: Back, Next, Finish
          Row(
            children: [
              if (!isFirst)
                OutlinedButton.icon(
                  key: const Key('tutorial_back_button'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkText,
                    side: const BorderSide(color: AppColors.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              const Spacer(),
              if (!isLast)
                ElevatedButton.icon(
                  key: const Key('tutorial_next_button'),
                  onPressed: onNext,
                  icon: const Text('Next'),
                  label: const Icon(Icons.arrow_forward, size: 16),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                )
              else
                ElevatedButton.icon(
                  key: const Key('tutorial_finish_button'),
                  onPressed: onFinish,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Finish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
