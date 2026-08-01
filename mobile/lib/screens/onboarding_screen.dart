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
  bool _acceptedPrivacy = false; // Must be true to proceed from last page.
  bool _acceptedTerms = false; // Must be true to proceed from last page.
  bool _isCompleting = false;


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
    // CW-P0-010: Both Privacy Policy AND Terms of Service must be accepted.
    if (!_acceptedPrivacy || !_acceptedTerms || _isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      // Audit 6 P0.21: If required consent writes fail, onboarding does
      // not complete. The user must see an error and retry. The method
      // propagates the exception from _recordConsentState().
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
    } catch (e) {
      debugPrint('onboarding consent write failed: ${e.runtimeType}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save your consent preferences. Please try again.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompleting = false);
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

  /// Record all onboarding consent decisions.
  ///
  /// Audit 6 P0.21: Required consent writes (privacy policy, terms of service)
  /// must succeed before onboarding completes. If they fail, the method throws
  /// so that onboarding does not proceed without durable evidence of agreement.
  ///
  /// Audit 6 P0.22: Terms of Service acceptance is recorded separately from
  /// privacy policy acceptance — the onboarding checkbox covers both, but the
  /// ledger tracks them as distinct records with their own lifecycles.
  Future<void> _recordConsentState() async {
    final ledger = ConsentLedger();

    // ── Required consent writes (fail-closed) ──────────────────────────
    // These MUST succeed. If they throw, onboarding blocks and the user
    // sees a retry. We do not silently proceed without durable evidence.
    await ledger.recordConsent(
      purpose: ConsentPurpose.privacyPolicy,
      version: AppConfig.privacyPolicyVersion,
      granted: true,
    );
    await ledger.recordConsent(
      purpose: ConsentPurpose.termsOfService,
      version: AppConfig.privacyPolicyVersion,
      granted: true,
    );

    // ── Optional consent write (best-effort) ───────────────────────────
    // Analytics opt-in/out is important but not blocking — if the write
    // fails, the app defaults to no analytics (fail-closed by design).
    try {
      await ledger.recordConsent(
        purpose: ConsentPurpose.analytics,
        version: 'analytics-v1',
        granted: _analyticsConsent,
      );
    } catch (e) {
      debugPrint('onboarding analytics consent write deferred: ${e.runtimeType}');
    }

    // CW-P0-010: Server sync is best-effort — offline onboarding must
    // not be blocked. But we track the pending state so the UI can
    // surface that consent is locally recorded but not yet verified
    // by the server.
    try {
      await ConsentSyncService().syncAll();
    } catch (e) {
      debugPrint('onboarding server consent sync deferred: ${e.runtimeType}');
      // CW-P0-010: Surface the sync-pending state so the user knows
      // consent is recorded locally but not yet verified by the server.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Consent recorded. Will sync when online.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
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
                    // CW-P0-010: Two separate checkboxes for distinct legal
                    // agreements. Previously a single checkbox covered both
                    // Privacy Policy and Terms of Service, conflating two
                    // independent legal records into one user action.
                    //
                    // Privacy Policy acceptance and Terms of Service acceptance
                    // are recorded as separate ledger entries with independent
                    // lifecycles (each can be revoked independently).
                    _LegalCheckbox(
                      value: _acceptedPrivacy,
                      onChanged: (value) {
                        setState(() => _acceptedPrivacy = value ?? false);
                      },
                      label: 'I have read and accept the Privacy Policy',
                      onReview: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _LegalCheckbox(
                      value: _acceptedTerms,
                      onChanged: (value) {
                        setState(() => _acceptedTerms = value ?? false);
                      },
                      label: 'I have read and agree to the Terms of Service',
                      onReview: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermsOfServiceScreen(),
                        ),
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
                          ? (_acceptedPrivacy && _acceptedTerms
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

/// CW-P0-010: A single legal agreement checkbox with a "Review" link.
/// Replaces the old single checkbox that conflated Privacy Policy and
/// Terms of Service into one user action.
class _LegalCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final VoidCallback onReview;

  const _LegalCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text.rich(
              TextSpan(
                text: '$label ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
                children: [
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onReview,
                      child: Text(
                        'Review',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
