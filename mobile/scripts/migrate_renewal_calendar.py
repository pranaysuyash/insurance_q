#!/usr/bin/env python3
"""Migrate renewal_calendar_screen.dart from S.xxx to l10n.xxx."""

import re

FILE = "lib/screens/renewal_calendar_screen.dart"

with open(FILE) as f:
    content = f.read()

# 1. Change import
content = content.replace(
    "import '../localization/app_localizations.dart';",
    "import '../l10n/app_localizations_gen.dart';",
)

# 2. Replace all S.xxx → l10n.xxx
replacements = {
    # Simple strings (no parameters)
    "S.renewalTitle": "l10n.renewalTitle",
    "S.renewalEmptyTitle": "l10n.renewalEmptyTitle",
    "S.renewalEmptySubtitle": "l10n.renewalEmptySubtitle",
    "S.insuranceCardsChooseFile": "l10n.insuranceCardsChooseFile",
    "S.renewalHeaderTitle": "l10n.renewalHeaderTitle",
    "S.renewalHeaderSubtitle": "l10n.renewalHeaderSubtitle",
    "S.renewalSectionExpired": "l10n.renewalSectionExpired",
    "S.renewalSectionExpiringSoon": "l10n.renewalSectionExpiringSoon",
    "S.renewalSectionActive": "l10n.renewalSectionActive",
    "S.renewalSectionNoDate": "l10n.renewalSectionNoDate",
    "S.renewalNoDateInfo": "l10n.renewalNoDateInfo",
    "S.renewalReminderText": "l10n.renewalReminderText",
    "S.renewalRemindersOn": "l10n.renewalRemindersOn",
    "S.renewalNotificationsOff": "l10n.renewalNotificationsOff",
    "S.enable": "l10n.enable",
    "S.renewalInsurerNotFound": "l10n.renewalInsurerNotFound",
    "S.renewalContactToRenew": "l10n.renewalContactToRenew",
    "S.renewalStartRenewal": "l10n.renewalStartRenewal",
    "S.renewalCallHelpline": "l10n.renewalCallHelpline",
    "S.renewalSendEmail": "l10n.renewalSendEmail",
    "S.renewalPhoneDialerError": "l10n.renewalPhoneDialerError",
    "S.renewalEmailClientError": "l10n.renewalEmailClientError",
    "S.viewPolicy": "l10n.viewPolicy",
    # Parameterized strings — careful: S.foo(x) → l10n.foo(x)
    "S.renewalExpiringPolicies(": "l10n.renewalExpiringPolicies(",
    "S.renewalExpiringCount(": "l10n.renewalExpiringCount(",
    "S.renewalExpires(": "l10n.renewalExpires(",
    "S.renewalRenewTitle(": "l10n.renewalRenewTitle(",
    "S.renewalContactInsurer(": "l10n.renewalContactInsurer(",
    "S.renewalContactInfoNotFound(": "l10n.renewalContactInfoNotFound(",
}

for old, new in replacements.items():
    content = content.replace(old, new)

with open(FILE, "w") as f:
    f.write(content)

print("Done. All S.xxx → l10n.xxx replacements complete.")
print("")
print("Next: Add l10n declarations to these methods:")
print("  - _RenewalCalendarScreenState.build()")
print("  - _ListViewContent.build()")
print("  - _CalendarViewContent.build()")
print("  - _CalendarViewContent._showDayPolicies()")
print("  - _DayPolicyTile.build()")
print("  - _NoEndDateNote.build()")
print("  - _ReminderCard.build()")
print("  - _RenewalCard.build()")
print("  - _RenewNowButton.build()")
print("  - _RenewNowButton._showRenewalContactSheet()")
print("  - _RenewNowButton._callHelpline()")
print("  - _RenewNowButton._sendEmail()")
print("  - _RenewNowButton._showNoContactInfo()")
