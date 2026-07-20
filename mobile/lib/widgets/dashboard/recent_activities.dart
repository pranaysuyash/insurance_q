import 'package:flutter/material.dart';
import '../../models/document_model.dart';
import '../../services/app_state_repository.dart';
import '../../services/analytics_service.dart';
import '../../screens/documents_screen.dart';
import '../shared/coverwise_components.dart';

class RecentActivities extends StatelessWidget {
  final List<InsuranceDocument> documents;
  final List<String> recentQuestions;

  const RecentActivities(
      {super.key, required this.documents, required this.recentQuestions});

  @override
  Widget build(BuildContext context) {
    final recentDocs = [...documents]
      ..sort((a, b) => b.uploadedOn.compareTo(a.uploadedOn));
    final docs = recentDocs.take(3).toList();
    final deletedDocs = AppStateRepository.getRecentlyDeletedDocuments();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoverWiseSectionLabel('Recent Activities'),
        const SizedBox(height: 12),
        if (docs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently uploaded documents',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ),
          ...docs.map((doc) => _ActivityItem(
                icon: Icons.upload_file,
                title: doc.filename,
                subtitle:
                    'Uploaded on ${doc.uploadedOn.day}/${doc.uploadedOn.month}/${doc.uploadedOn.year}',
                color: Theme.of(context).colorScheme.primary,
                onTap: () {
                  AnalyticsService.track('dashboard_activity_item_tapped', {'activity_type': 'document_view'});
                  Navigator.pushNamed(context, '/policy-detail', arguments: doc.id);
                },
              )),
          const SizedBox(height: 8),
        ],
        if (deletedDocs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Recently deleted documents',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ),
          ...deletedDocs.take(2).map((filename) => _ActivityItem(
                icon: Icons.delete_outline,
                title: filename,
                subtitle: 'Deleted recently',
                color: Theme.of(context).colorScheme.error,
                onTap: () {
                  AnalyticsService.track('dashboard_activity_item_tapped', {'activity_type': 'deleted_documents'});
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DocumentsScreen(),
                    ),
                  );
                },
              )),
          const SizedBox(height: 8),
        ],
        if (recentQuestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text('Recent questions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
          ),
          ...recentQuestions.take(3).map((question) => _ActivityItem(
                icon: Icons.chat_bubble_outline_rounded,
                title: question,
                subtitle: 'Asked recently',
                color: Theme.of(context).colorScheme.secondary,
                onTap: () {
                  AnalyticsService.track('dashboard_activity_item_tapped', {'activity_type': 'recent_question'});
                  Navigator.pushNamed(context, '/qa');
                },
              )),
        ],
        if (docs.isEmpty && recentQuestions.isEmpty && deletedDocs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No recent activities')),
            ),
          ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ActivityItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: tile,
            )
          : tile,
    );
  }
}
