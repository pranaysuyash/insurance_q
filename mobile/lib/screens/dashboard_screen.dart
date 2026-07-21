import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/document_providers.dart';
import '../providers/policy_providers.dart';
import '../providers/health_score_provider.dart';
import '../services/app_state_repository.dart';
import '../widgets/health_score_card.dart';
import '../widgets/shared/coverwise_components.dart';
import '../widgets/shared/error_widget.dart';
import '../screens/documents_screen.dart';

import '../widgets/dashboard/first_upload_cta.dart';
import '../widgets/dashboard/welcome_card.dart';
import '../widgets/dashboard/policy_summary_cards.dart';
import '../widgets/dashboard/quick_actions.dart';
import '../widgets/dashboard/family_section.dart';
import '../widgets/dashboard/recent_activities.dart';
import '../widgets/dashboard/preventive_tips.dart';
import '../widgets/dashboard/terminology_section.dart';
import '../widgets/dashboard/coverage_type_explorer.dart';

final recentQuestionsProvider = Provider<List<String>>((ref) {
  return AppStateRepository.getRecentQuestions();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);
    final recentQuestions = ref.watch(recentQuestionsProvider);
    final policySummaries = ref.watch(policySummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh policy overview',
            onPressed: () {
              ref.invalidate(documentsProvider);
              ref.invalidate(policySummariesProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(documentsProvider);
          ref.invalidate(policySummariesProvider);
        },
        child: documentsAsync.when(
          loading: () => Center(
            child: Semantics(
              label: 'Loading policy overview',
              child: const CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => AppErrorView(
            message: 'We could not load your policy overview.',
            onRetry: () {
              ref.invalidate(documentsProvider);
              ref.invalidate(policySummariesProvider);
            },
          ),
          data: (documents) {
            if (documents.isEmpty) {
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: FirstUploadCta(
                        onUpload: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DocumentsScreen(
                              startWithFilePicker: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const CoverWisePageHeader(
                          title: 'Your cover, at a glance',
                          subtitle:
                              'See what is protected, what needs attention, and what to do next.',
                        ),
                        const SizedBox(height: 16),
                        QuickActions(documents: documents),
                        const SizedBox(height: 20),
                        SearchShortcutButton(
                          onTap: () => Navigator.pushNamed(context, '/search'),
                        ),
                        const SizedBox(height: 20),
                        HealthScoreCard(
                          healthScore: ref.watch(healthScoreProvider),
                        ),
                        const SizedBox(height: 20),
                        if (policySummaries.isNotEmpty) ...[
                          PolicySummaryCards(summaries: policySummaries),
                          const SizedBox(height: 20),
                        ],
                        WelcomeCard(
                          docCount: documents.length,
                          activePolicies:
                              policySummaries.where((s) => s.isActive).length,
                          expiringCount: policySummaries
                              .where((s) => s.isExpiringSoon)
                              .length,
                          onTap: () =>
                              Navigator.pushNamed(context, '/documents'),
                        ),
                        const SizedBox(height: 20),
                        RecentActivities(
                          documents: documents,
                          recentQuestions: recentQuestions,
                        ),
                        const SizedBox(height: 20),
                        FamilySection(documents: documents),
                        const SizedBox(height: 20),
                        DocumentSummary(documents: documents),
                        const SizedBox(height: 20),
                        if (policySummaries.isNotEmpty) ...[
                          PreventiveTipsSection(summaries: policySummaries),
                          const SizedBox(height: 20),
                        ],
                        const InsuranceTerminologySection(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
