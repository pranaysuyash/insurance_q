import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/coverwise_theme.dart';
import '../theme/coverwise_motion.dart';
import '../widgets/shared/coverwise_mark.dart';

/// Branded splash screen shown while the app initializes.
///
/// Displays the CoverWise logo and a subtle loading indicator.
/// Designed to match the app's blue color scheme and provide
/// a polished first-run experience.
///
/// Shows for [minimumDuration] to ensure brand visibility, then calls
/// [onComplete] to transition to the main app.
class SplashScreen extends StatefulWidget {
  /// Callback invoked when the splash is done (after minimum duration).
  final VoidCallback onComplete;

  /// Minimum time to show the splash (ensures brand visibility).
  final Duration minimumDuration;

  const SplashScreen({
    super.key,
    required this.onComplete,
    this.minimumDuration = const Duration(milliseconds: 1100),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  Timer? _completionTimer;
  bool _motionPreferenceApplied = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CoverWiseMotion.emphasized,
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: CoverWiseMotion.enterCurve,
    );
    _scaleUp = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: CoverWiseMotion.enterCurve),
    );

    // Complete after minimum duration to ensure brand visibility.
    // By the time this fires, main() initialization (Hive, auth, analytics)
    // has already completed before runApp() was called.
    _completionTimer = Timer(widget.minimumDuration, () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionPreferenceApplied) return;
    _motionPreferenceApplied = true;
    if (CoverWiseMotion.isReduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: CoverWiseColors.ink,
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scaleUp,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: const CoverWiseMark(
                    size: 76,
                    onDark: true,
                    decorative: true,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'CoverWise',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your cover, made clear.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.68),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 54),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [CoverWiseColors.blue, CoverWiseColors.mint],
                    ),
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
