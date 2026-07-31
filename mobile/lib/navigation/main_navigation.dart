import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/policy_summary.dart';
import '../providers/entitlement_provider.dart';
import '../providers/policy_providers.dart';
import '../screens/dashboard_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/profile_screen.dart';
import '../services/notification_service.dart';
import '../widgets/shared/auth_expired_banner.dart';
import '../widgets/shared/offline_banner.dart';
import '../widgets/shared/screen_error_boundary.dart';

/// Primary bottom-navigation shell for the authenticated app.
///
/// Extracted from app.dart to isolate tab management, billing init, and
/// renewal-notification scheduling from the app shell.
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0, 1};
  bool _demoNavigationScheduled = false;
  bool _notificationsScheduled = false;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    if (AppConfig.bootstrapPolicyDemo) {
      _selectedIndex = 1;
      _visitedTabs.add(1);
      _scheduleDemoNavigation();
    }
    _initBilling();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(policySummariesProvider, (prev, next) {
      if (next.isNotEmpty) {
        _scheduleRenewalReminders(next);
      }
    });

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          const AuthExpiredBanner(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const ScreenErrorBoundary(
                  screenName: 'dashboard',
                  child: DashboardScreen(),
                ),
                _visitedTabs.contains(1)
                    ? const ScreenErrorBoundary(
                        screenName: 'policies',
                        child: DocumentsScreen(),
                      )
                    : const SizedBox.shrink(),
                _visitedTabs.contains(2)
                    ? const ScreenErrorBoundary(
                        screenName: 'insights',
                        child: InsightsScreen(),
                      )
                    : const SizedBox.shrink(),
                _visitedTabs.contains(3)
                    ? const ScreenErrorBoundary(
                        screenName: 'profile',
                        child: ProfileScreen(),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/qa'),
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Ask'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: 'Policies',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _scheduleDemoNavigation() {
    if (_demoNavigationScheduled) return;
    _demoNavigationScheduled = true;
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _selectedIndex = 1;
        _visitedTabs.add(1);
      });
    });
  }

  void _scheduleRenewalReminders(List<PolicySummary> summaries) {
    if (_notificationsScheduled || summaries.isEmpty) return;
    _notificationsScheduled = true;
    unawaited(NotificationService.scheduleRenewalReminders(summaries));
  }

  void _initBilling() {
    if (!AppConfig.hasRevenueCatConfig) return;
    ref.read(billingInitProvider);
  }
}
