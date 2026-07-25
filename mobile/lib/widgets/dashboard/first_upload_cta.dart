import 'package:flutter/material.dart';
import '../shared/coverwise_components.dart';
import '../shared/coverwise_scene.dart';
import '../../services/analytics_service.dart';

/// Prominent, visual CTA shown when the user has no documents.
/// This IS the onboarding continuation — the first thing a new user sees
/// after the carousel.
class FirstUploadCta extends StatelessWidget {
  final VoidCallback onUpload;

  const FirstUploadCta({super.key, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CoverWiseSurface(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          children: [
            const CoverWiseScene(
              scene: CoverWiseSceneKind.firstPolicy,
              maxHeight: 170,
            ),
            const SizedBox(height: 16),
            Text(
              'Turn your first policy into clear answers',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a PDF or policy image. CoverWise organizes the file and '
              'shows the cover, exclusions and dates for you to review.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              label:
                  'Your original policy remains available in your workspace for review. We process it on our servers to generate summaries.',
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 18),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Your original policy remains available in your workspace for review. We process it to generate summaries.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'CoverWise is a policy information assistant, not an insurer, agent, or broker. '
                          'All policy data is for reference only.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Choose policy file'),
                onPressed: () {
                  AnalyticsService.track('dashboard_first_upload_cta_tapped');
                  onUpload();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
