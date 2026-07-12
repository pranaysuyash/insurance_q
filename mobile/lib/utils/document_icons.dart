// Re-export from policy_type.dart for backward compatibility.
// All type classification logic now lives in policy_type.dart as the single
// source of truth (motto §7: one canonical path, not parallel implementations).
export 'policy_type.dart' show
    iconForDocumentType,
    colorForDocumentType,
    iconForPolicyType,
    colorForPolicyType,
    classifyPolicyType,
    canonicalTypeName,
    PolicyType;
