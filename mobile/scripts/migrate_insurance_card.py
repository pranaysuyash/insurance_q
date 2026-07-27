#!/usr/bin/env python3
"""Migrate insurance_card_screen.dart from S.xxx to l10n.xxx."""

FILE = "lib/screens/insurance_card_screen.dart"

with open(FILE) as f:
    content = f.read()

# 1. Change import
content = content.replace(
    "import '../localization/app_localizations.dart';",
    "import '../l10n/app_localizations_gen.dart';",
)

# 2. Replace all S.xxx → l10n.xxx (simple strings, no parameters)
replacements = {
    "S.insuranceCardsTitle": "l10n.insuranceCardsTitle",
    "S.insuranceCardsEmptyTitle": "l10n.insuranceCardsEmptyTitle",
    "S.insuranceCardsEmptySubtitle": "l10n.insuranceCardsEmptySubtitle",
    "S.insuranceCardsChooseFile": "l10n.insuranceCardsChooseFile",
    "S.insuranceCardsHeaderTitle": "l10n.insuranceCardsHeaderTitle",
    "S.insuranceCardsHeaderSubtitle": "l10n.insuranceCardsHeaderSubtitle",
    "S.insuranceCardsPolicyNumber": "l10n.insuranceCardsPolicyNumber",
    "S.insuranceCardsCoverage": "l10n.insuranceCardsCoverage",
    "S.insuranceCardsPremium": "l10n.insuranceCardsPremium",
    "S.insuranceCardsValidFrom": "l10n.insuranceCardsValidFrom",
    "S.insuranceCardsValidUntil": "l10n.insuranceCardsValidUntil",
    "S.insuranceCardsCallInsurer": "l10n.insuranceCardsCallInsurer",
    "S.insuranceCardsShareCard": "l10n.insuranceCardsShareCard",
    "S.insuranceCardsPhoneError": "l10n.insuranceCardsPhoneError",
    "S.insuranceCardsShareTitle": "l10n.insuranceCardsShareTitle",
    "S.insuranceCardsInsurerPrefix": "l10n.insuranceCardsInsurerPrefix",
    "S.insuranceCardsPolicyNumberPrefix": "l10n.insuranceCardsPolicyNumberPrefix",
    "S.insuranceCardsCoveragePrefix": "l10n.insuranceCardsCoveragePrefix",
    "S.insuranceCardsValidUntilPrefix": "l10n.insuranceCardsValidUntilPrefix",
    "S.insuranceCardsHelplinePrefix": "l10n.insuranceCardsHelplinePrefix",
    "S.insuranceCardsShareFooter": "l10n.insuranceCardsShareFooter",
    "S.insuranceCardsShareError": "l10n.insuranceCardsShareError",
}

for old, new in replacements.items():
    content = content.replace(old, new)

with open(FILE, "w") as f:
    f.write(content)

print("Done. All S.xxx → l10n.xxx replacements complete.")
print("")
print("Next: Add l10n declarations to these methods:")
print("  - InsuranceCardScreen.build()")
print("  - _InsuranceCard.build()")
print("  - _InsuranceCard._callInsurer()")
print("  - _InsuranceCard._shareCard()")
print("")
print("Then: Fix const CoverWisePageHeader - remove const")
