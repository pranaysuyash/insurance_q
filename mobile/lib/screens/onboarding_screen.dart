import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/consent_ledger.dart';
import '../services/analytics_service.dart';
import '../services/consent_sync_service.dart';
import '../theme/coverwise_theme.dart';
import '../theme/coverwise_motion.dart';
import '../widgets/shared/coverwise_mark.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final void Function({bool openFilePicker}) onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _analyticsConsent = false; // Optional analytics is explicit opt-in.
  bool _acceptedTerms = false; // Must be true to proceed from last page.

  static const _pages = [
    _OnboardingData(
      eyebrow: 'UNDERSTAND',
      assetPath: 'assets/onboarding/understand-policy.png',
      title: 'Turn policy pages into plain answers.',
      description:
          'Add a policy once. We process it securely on our servers to surface the cover, exclusions and benefits that matter.',
      accent: CoverWiseColors.blue,
    ),
    _OnboardingData(
      eyebrow: 'ASK',
      assetPath: 'assets/onboarding/ask-policy.png',
      title: 'Ask your policy, not the internet.',
      description:
          'Get clear answers based on your actual policy — not generic advice from the internet.',
      accent: Color(0xFF7C5CE7),
    ),
    _OnboardingData(
      eyebrow: 'STAY INFORMED',
      assetPath: 'assets/onboarding/stay-ready.png',
      title: 'Know what needs attention next.',
      description:
          'See policy dates, document-based questions, and preparation notes in one place. CoverWise helps organize policy information; it is not an insurer, broker, or adviser.',
      accent: Color(0xFF079A86),
    ),
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.track('onboarding_started');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete({bool openFilePicker = false}) async {
    if (!_acceptedTerms) return;
    // Record both analytics consent and terms acceptance.
    // Analytics: only if user explicitly toggled the switch.
    // Terms: always record — the user must check the box to proceed.
    await _recordConsentState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    AnalyticsService.track(
      'onboarding_completed',
      {
        'analytics_consent': _analyticsConsent,
        'total_steps': _pages.length,
      },
    );
    if (mounted) {
      widget.onComplete(openFilePicker: openFilePicker);
    }
  }

  void _skipIntro() {
    final lastPage = _pages.length - 1;
    if (CoverWiseMotion.isReduced(context)) {
      _controller.jumpToPage(lastPage);
    } else {
      _controller.animateToPage(
        lastPage,
        duration: CoverWiseMotion.emphasized,
        curve: CoverWiseMotion.enterCurve,
      );
    }
  }

  Future<void> _recordConsentState() async {
    final ledger = ConsentLedger();
    try {
      // Record an explicit analytics decision, including an opt-out. This
      // keeps the UI choice and the fail-closed analytics gate aligned.
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: _analyticsConsent,
      );
      // Audit 5 P1.3: Manual refreshConsentCache() removed —
      // AnalyticsNotifier now subscribes to ConsentLedger.consentChanges
      // and picks up this change automatically.

      // The local ledger is the immediate offline cache. The server append
      // below is attempted separately so an unavailable backend does not
      // strand first-run onboarding.
      await ledger.recordConsent(
        purpose: ConsentPurpose.privacyPolicy,
        version: AppConfig.privacyPolicyVersion,
        granted: _acceptedTerms,
      );
    } catch (e) {
      debugPrint('onboarding local consent write deferred: ${e.runtimeType}');
    }

    try {
      await ConsentSyncService().syncAll();
    } catch (e) {
      // Cache-first onboarding remains usable offline. Upload and later
      // account/session sync paths retry the consent bridge where applicable.
      debugPrint('onboarding server consent sync deferred: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  CoverWiseMark(
                    size: 30,
                    onDark: theme.brightness == Brightness.dark,
                    decorative: true,
                  ),
                  if (MediaQuery.textScalerOf(context).scale(1) <= 1.5) ...[
                    const SizedBox(width: 10),
                    Text(
                      'CoverWise',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!isLast)
                    MediaQuery.textScalerOf(context).scale(1) > 1.5
                        ? IconButton(
                            onPressed: _skipIntro,
                            tooltip: 'Skip intro',
                            icon: const Icon(Icons.last_page_rounded),
                          )
                        : TextButton(
                            onPressed: _skipIntro,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(92, 48),
                            ),
                            child: const Text('Skip intro'),
                          ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  AnalyticsService.track(
                    'onboarding_step_viewed',
                    {
                      'step': index + 1,
                      'total_steps': _pages.length,
                    },
                  );
                },
                itemBuilder: (_, index) => _OnboardingPage(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Expanded(
                        child: AnimatedContainer(
                          duration: CoverWiseMotion.duration(
                            context,
                            CoverWiseMotion.standard,
                          ),
                          height: 4,
                          margin: EdgeInsets.only(
                            right: index == _pages.length - 1 ? 0 : 8,
                          ),
                          decoration: BoxDecoration(
                            color: index <= _currentPage
                                ? _pages[_currentPage].accent
                                : CoverWiseColors.line,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Interactive analytics consent toggle on the last page.
                  if (isLast) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Anonymous usage stats (optional)',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Only anonymous usage events are sent; policy '
                                  'content is not included.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _analyticsConsent,
                            onChanged: (value) {
                              setState(() {
                                _analyticsConsent = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Privacy Policy and Terms of Service links
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            ),
                            child: const Text('Privacy Policy'),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TermsOfServiceScreen(),
                              ),
                            ),
                            child: const Text('Terms of Service'),
                          ),
                        ],
                      ),
                    ),
                    // Explicit consent checkbox — required before proceeding
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: (value) {
                              setState(() {
                                _acceptedTerms = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'I have read and agree to the Privacy Policy '
                                'and Terms of Service',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scope disclaimer — CoverWise is an information assistant.
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 10),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'CoverWise is a policy information assistant, not an insurer, '
                              'agent, or broker. All policy information shown is for '
                              'reference only and does not constitute professional advice.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLast
                          ? (_acceptedTerms
                              ? () => _complete(openFilePicker: true)
                              : null)
                          : () {
                              if (CoverWiseMotion.isReduced(context)) {
                                _controller.jumpToPage(_currentPage + 1);
                              } else {
                                _controller.nextPage(
                                  duration: CoverWiseMotion.emphasized,
                                  curve: CoverWiseMotion.enterCurve,
                                );
                              }
                            },
                      icon: Icon(isLast
                          ? Icons.arrow_forward_rounded
                          : Icons.chevron_right_rounded),
                      label: Text(isLast ? 'Add my first policy' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;

    Widget artwork() => DecoratedBox(
          decoration: BoxDecoration(
            color: data.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -36,
                top: -28,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.94, end: 1),
                  duration: CoverWiseMotion.duration(
                    context,
                    CoverWiseMotion.onboarding,
                  ),
                  curve: CoverWiseMotion.enterCurve,
                  builder: (_, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      data.assetPath,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: data.accent.withValues(alpha: 0.08),
                        child: Center(
                          child: CoverWiseMark(
                            size: 92,
                            onDark: theme.brightness == Brightness.dark,
                            decorative: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    Widget details() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.eyebrow,
              style: theme.textTheme.labelMedium?.copyWith(
                color: data.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              data.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.08,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              data.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (largeText) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: (constraints.maxHeight * .38).clamp(180.0, 260.0),
                  width: double.infinity,
                  child: artwork(),
                ),
                const SizedBox(height: 24),
                details(),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: artwork()),
              const SizedBox(height: 30),
              details(),
            ],
          ),
        );
      },
    );
  }
}

class _OnboardingData {
  final String eyebrow;
  final String assetPath;
  final String title;
  final String description;
  final Color accent;

  const _OnboardingData({
    required this.eyebrow,
    required this.assetPath,
    required this.title,
    required this.description,
    required this.accent,
  });
}
