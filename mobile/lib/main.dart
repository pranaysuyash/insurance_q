import 'bootstrap/app_bootstrap.dart';

/// CoverWise — Insurance companion app.
///
/// This file is the composition root. All startup logic, widget trees, and
/// navigation have been extracted into dedicated modules:
///
/// - `bootstrap/app_bootstrap.dart` — Configuration validation, Sentry,
///   Hive, Supabase, principal resolution, migration, and `runApp()`.
/// - `app.dart` — InsuranceApp widget, routing, auth listener,
///   workspace transitions, deep links, reconciliation, and MainNavigation.
void main() => runAppBootstrap();
