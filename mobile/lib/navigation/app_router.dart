import 'package:flutter/material.dart';

import '../widgets/shared/missing_args_screen.dart';
import '../widgets/shared/screen_error_boundary.dart';

// Screens
import '../screens/qa_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/family_screen.dart';
import '../screens/family_visualization_screen.dart';
import '../screens/emergency_screen.dart';
import '../screens/claims_assistant_screen.dart';
import '../screens/renewal_calendar_screen.dart';
import '../screens/coverage_gap_screen.dart';
import '../screens/policy_comparison_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/help_support_screen.dart';
import '../screens/privacy_security_screen.dart';
import '../screens/about_screen.dart';
import '../screens/policy_detail_screen.dart';
import '../screens/claim_tracking_screen.dart';
import '../screens/search_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/insurance_card_screen.dart';
import '../screens/insurance_literacy_screen.dart';
import '../screens/account_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/notification_preferences_screen.dart';
import '../screens/what_if_calculator_screen.dart';

/// The named-route table for [MaterialApp].
///
/// Extracted from app.dart to isolate screen imports and route-building
/// logic from the app shell. Each entry wraps its screen in a
/// [ScreenErrorBoundary] so uncaught widget errors render a recovery UI
/// instead of a white screen.
Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/qa': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final documentId = switch (args) {
        final String id => id,
        _ => null,
      };
      return ScreenErrorBoundary(
        screenName: 'qa',
        child: QaScreen(initialDocumentId: documentId),
      );
    },
    '/emergency': (context) => const ScreenErrorBoundary(
          screenName: 'emergency',
          child: EmergencyScreen(),
        ),
    '/claims': (context) => const ScreenErrorBoundary(
          screenName: 'claims',
          child: ClaimsAssistantScreen(),
        ),
    '/renewals': (context) => const ScreenErrorBoundary(
          screenName: 'renewals',
          child: RenewalCalendarScreen(),
        ),
    '/coverage-gaps': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final documentId = switch (args) {
        {'documentId': final String id} when id.isNotEmpty => id,
        {'documentId': _} => null,
        _ => null,
      };
      if (documentId == null) {
        return const ScreenErrorBoundary(
          screenName: 'coverage-gaps',
          child: MissingArgsScreen(
            title: 'Coverage overview',
            message: 'No document was specified. '
                'Choose a policy in Documents, then open its coverage details.',
            recoveryRoute: '/documents',
            recoveryLabel: 'Choose a policy',
          ),
        );
      }
      return ScreenErrorBoundary(
        screenName: 'coverage-gaps',
        child: CoverageGapScreen(documentId: documentId),
      );
    },
    '/compare': (context) => const ScreenErrorBoundary(
          screenName: 'compare',
          child: PolicyComparisonScreen(),
        ),
    '/what-if': (context) => const ScreenErrorBoundary(
          screenName: 'what-if',
          child: WhatIfCalculatorScreen(),
        ),
    '/settings': (context) => const ScreenErrorBoundary(
          screenName: 'settings',
          child: SettingsScreen(),
        ),
    '/help': (context) => const ScreenErrorBoundary(
          screenName: 'help',
          child: HelpSupportScreen(),
        ),
    '/privacy': (context) => const ScreenErrorBoundary(
          screenName: 'privacy',
          child: PrivacySecurityScreen(),
        ),
    '/about': (context) => const ScreenErrorBoundary(
          screenName: 'about',
          child: AboutScreen(),
        ),
    '/policy-detail': (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final documentId = switch (args) {
        final String id when id.isNotEmpty => id,
        _ => null,
      };
      if (documentId == null) {
        return const ScreenErrorBoundary(
          screenName: 'policy-detail',
          child: MissingArgsScreen(
            title: 'Policy details',
            message: 'No policy was specified. Open a policy from Documents.',
            recoveryRoute: '/documents',
            recoveryLabel: 'Open documents',
          ),
        );
      }
      return ScreenErrorBoundary(
        screenName: 'policy-detail',
        child: PolicyDetailScreen(documentId: documentId),
      );
    },
    '/claim-tracker': (context) => const ScreenErrorBoundary(
          screenName: 'claim-tracker',
          child: ClaimTrackingScreen(),
        ),
    '/search': (context) => const ScreenErrorBoundary(
          screenName: 'search',
          child: SearchScreen(),
        ),
    '/profile': (context) => const ScreenErrorBoundary(
          screenName: 'profile',
          child: ProfileScreen(),
        ),
    '/insurance-cards': (context) => const ScreenErrorBoundary(
          screenName: 'insurance-cards',
          child: InsuranceCardScreen(),
        ),
    '/literacy': (context) => const ScreenErrorBoundary(
          screenName: 'literacy',
          child: InsuranceLiteracyScreen(),
        ),
    '/account': (context) => const ScreenErrorBoundary(
          screenName: 'account',
          child: AccountScreen(),
        ),
    '/reset-password': (context) => const ScreenErrorBoundary(
          screenName: 'reset-password',
          child: ResetPasswordScreen(),
        ),
    '/family': (context) => const ScreenErrorBoundary(
          screenName: 'family',
          child: FamilyScreen(),
        ),
    '/family/visualization': (context) => const ScreenErrorBoundary(
          screenName: 'family-visualization',
          child: FamilyVisualizationScreen(),
        ),
    '/notifications': (context) => const ScreenErrorBoundary(
          screenName: 'notifications',
          child: NotificationPreferencesScreen(),
        ),
    '/documents': (context) => const ScreenErrorBoundary(
          screenName: 'documents',
          child: DocumentsScreen(),
        ),
  };
}

/// Fallback handler for routes not in [buildAppRoutes].
Route<dynamic> appOnUnknownRoute(RouteSettings settings) {
  debugPrint('Unknown route: ${settings.name}');
  return MaterialPageRoute(
    builder: (_) => const MissingArgsScreen(
      title: 'Page not found',
      message: 'The page you\'re looking for does not exist. '
          'Navigate from the home screen.',
      recoveryRoute: '/',
      recoveryLabel: 'Go home',
    ),
    settings: settings,
  );
}
