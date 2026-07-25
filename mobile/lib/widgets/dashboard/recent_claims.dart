import 'package:flutter/material.dart';
import '../../models/claim_record.dart';
import '../../services/app_state_repository.dart';
import '../../services/analytics_service.dart';
import '../../screens/claim_tracking_screen.dart';
import '../shared/coverwise_components.dart';

/// Shows the 3 most recently filed claims with their current status.
/// Shared: maps a [ClaimStatus] to its display color for the given theme.
Color _claimStatusColor(ClaimStatus status, ColorScheme scheme) {
  switch (status) {
    case ClaimStatus.filed:
      return scheme.primary;
    case ClaimStatus.inReview:
      return scheme.tertiary;
    case ClaimStatus.approved:
      return const Color(0xFF2E7D32);
    case ClaimStatus.rejected:
      return scheme.error;
    case ClaimStatus.paid:
      return const Color(0xFF1565C0);
  }
}

class RecentClaims extends StatelessWidget {
  /// Optional: inject claims directly for testing without Hive.
  final List<ClaimRecord>? claims;

  const RecentClaims({super.key, this.claims});

  @override
  Widget build(BuildContext context) {
    final claims = this.claims ?? AppStateRepository.getClaimRecords();
    final recent = claims.take(3).toList();

    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CoverWiseSectionLabel('Recent Claims'),
        const SizedBox(height: 12),
        ...recent.map((claim) => _ClaimCard(claim: claim)),
        if (claims.length > 3) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () {
              AnalyticsService.track(
                'dashboard_recent_claims_tapped',
                {'action': 'view_all'},
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClaimTrackingScreen(),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(
              'View all ${claims.length} claims',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final ClaimRecord claim;
  const _ClaimCard({required this.claim});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          AnalyticsService.track('dashboard_recent_claim_tapped', {
            'claim_id': claim.id,
            'status': claim.status.name,
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ClaimTrackingScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Incident type icon
              CircleAvatar(
                backgroundColor: _statusColor(claim.status, scheme)
                    .withValues(alpha: 0.12),
                radius: 22,
                child: Icon(
                  _incidentIcon(claim.incidentType),
                  color: _statusColor(claim.status, scheme),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Claim details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.insurer,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${claim.incidentType} — ${claim.filedDate.day}/${claim.filedDate.month}/${claim.filedDate.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status chip
              _ClaimStatusChip(status: claim.status),
            ],
          ),
        ),
      ),
    );
  }

  IconData _incidentIcon(String incidentType) {
    switch (incidentType.toLowerCase()) {
      case 'accident':
        return Icons.car_crash_outlined;
      case 'theft':
        return Icons.lock_outline;
      case 'fire':
        return Icons.local_fire_department_outlined;
      case 'natural disaster':
      case 'natural_disaster':
        return Icons.thunderstorm_outlined;
      case 'health':
      case 'medical':
      case 'hospitalization':
        return Icons.medical_services_outlined;
      case 'travel':
        return Icons.flight_outlined;
      case 'liability':
        return Icons.gavel_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _statusColor(ClaimStatus status, ColorScheme scheme) =>
      _claimStatusColor(status, scheme);
}

class _ClaimStatusChip extends StatelessWidget {
  final ClaimStatus status;
  const _ClaimStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _chipColor(status, scheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _chipColor(ClaimStatus status, ColorScheme scheme) =>
      _claimStatusColor(status, scheme);
}
