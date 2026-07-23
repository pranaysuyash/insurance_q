import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/backend_health_provider.dart';
import '../providers/connectivity_provider.dart';
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
///
/// P0-02: On first frame, probes [GET /health] with a 5-second timeout.
/// If the backend is unreachable a "Service unavailable" banner appears.
/// A 30-second periodic timer invalidates the probe so the banner
/// auto-dismisses when the backend recovers.
class SplashScreen extends ConsumerStatefulWidget {
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
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  Timer? _completionTimer;
  Timer? _healthPoller;
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

    // P0-02: Re-probe backend health every 30 seconds so the "Service
    // unavailable" banner auto-dismisses when the backend recovers.
    _healthPoller = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(backendHealthProvider);
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
    _healthPoller?.cancel();
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
        child: Column(
          children: [
            // P0-02: backend health banner — shown on top when the service is
            // unreachable. Auto-dismisses on next poll when health recovers.
            _HealthBanner(),

            // ── Centered splash content ──
            Expanded(
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
                            colors: [
                              CoverWiseColors.blue,
                              CoverWiseColors.mint,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin amber banner that appears when the backend health check fails and
/// the device is online (to avoid false "Service unavailable" messages when
/// the user is simply offline — the OfflineBanner handles that case).
///
/// Watches [backendHealthProvider] and [isOnlineProvider]. Shows nothing
/// while loading, when healthy, or when the device is offline.
class _HealthBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(backendHealthProvider);
    final isOnline = ref.watch(isOnlineProvider);

    // Show nothing while loading, when healthy, or when the device is
    // offline (the OfflineBanner in main screens handles offline state).
    final isHealthy = healthAsync.asData?.value ?? true;
    if (isHealthy || !isOnline) return const SizedBox.shrink();

    final theme = Theme.of(context);
    const warning = Color(0xFFD97706);
    final textColor = theme.brightness == Brightness.dark
        ? const Color(0xFFF5A623)
        : const Color(0xFF5C3E00);

    return Material(
      color: theme.brightness == Brightness.dark
          ? warning.withValues(alpha: 0.16)
          : const Color(0xFFFFF4DD),
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CoverWiseColors.line, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_off_outlined,
                    size: 18, color: warning),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Service unavailable. Some features may be limited. '
                      'Reconnecting…',
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: textColor,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
