package com.coverwise.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log

/**
 * Receives the Play Store INSTALL_REFERRER broadcast and persists the parsed
 * attribution data into SharedPreferences for the Flutter app to read on next
 * launch via `coverwise/install_referrer` MethodChannel (or directly via
 * shared_preferences, which is what we use here).
 *
 * How the broadcast reaches us:
 *   1. User clicks an ad/Play Store link with a referrer query parameter:
 *      https://play.google.com/store/apps/details?id=com.coverwise.app&referrer=utm_source%3Dgoogle%26utm_campaign%3Dwinter2026
 *   2. Play Store downloads + installs the app.
 *   3. Play Store fires the INSTALL_REFERRER intent at our receiver, with
 *      the referrer string in the `referrer` extra.
 *   4. We parse it (utm_source, utm_medium, utm_campaign) and write to
 *      SharedPreferences under the "flutter" name (which is what the
 *      `shared_preferences` Flutter package reads by default).
 *
 * Notes:
 *   - This receiver does NOT require any user permission; the OS delivers
 *     the broadcast automatically on first install.
 *   - On iOS there is no equivalent; Apple provides ATT instead. iOS-side
 *     install attribution is intentionally out of scope for this rev 1.
 *   - The receiver fires once per fresh install. Re-installs fire again.
 *     The Flutter app treats each fire as a fresh attribution signal
 *     (storing install_id is a separate concern in InstallService).
 *
 * Per motto v3 §0.6: this is a customer-facing path. We never log the
 * raw referrer to logcat (it can contain PII like email). We log only
 * "referrer received" + the parsed key count.
 */
class InstallReferrerReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "InstallReferrerRx"
        // shared_preferences package reads from the "flutter" SharedPreferences
        // name by default on Android. The keys below match the keys used by
        // mobile/lib/services/install_service.dart.
        private const val PREFS_NAME = "flutter"
        private const val KEY_SOURCE = "install_referrer_source"
        private const val KEY_MEDIUM = "install_referrer_medium"
        private const val KEY_CAMPAIGN = "install_referrer_campaign"
        private const val KEY_CAPTURED_AT_MS = "install_referrer_captured_at_ms"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.android.vending.INSTALL_REFERRER") {
            Log.w(TAG, "Ignoring non-install-referrer intent: ${intent.action}")
            return
        }

        val rawReferrer: String? = intent.getStringExtra("referrer")
        if (rawReferrer.isNullOrBlank()) {
            // Organic install or untracked download. No attribution; nothing to do.
            Log.d(TAG, "Install referrer broadcast had no referrer extra (organic install)")
            return
        }

        // Parse utm_* params from the referrer. The referrer is URL-encoded
        // and contains params like:
        //   utm_source=google&utm_medium=cpc&utm_campaign=winter2026
        // Use Uri.decode + Uri.parse to handle the encoding.
        val decoded = Uri.decode(rawReferrer)
        val parsed = parseUtmParams(decoded)

        if (parsed.isEmpty()) {
            // No utm_* params in the referrer. Store as 'unknown' source so the
            // Flutter app still knows the install came from a tracked link
            // (the referrer extra was non-empty).
            Log.d(TAG, "Referrer present but no utm_* params found")
        }

        val prefs: SharedPreferences = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        prefs.edit().apply {
            // Only write keys that are present, so the Flutter side can
            // distinguish "no value" from "empty value". The Flutter
            // InstallService treats null as "no referrer" and stops emitting
            // the corresponding property.
            parsed["utm_source"]?.let { putString(KEY_SOURCE, it) }
            parsed["utm_medium"]?.let { putString(KEY_MEDIUM, it) }
            parsed["utm_campaign"]?.let { putString(KEY_CAMPAIGN, it) }
            putLong(KEY_CAPTURED_AT_MS, System.currentTimeMillis())
        }.apply()

        // Do NOT log the raw referrer (may contain PII). Log only the parse
        // result count to confirm we received and processed the broadcast.
        Log.d(TAG, "Install referrer processed (${parsed.size} utm params)")
    }

    /**
     * Parse a decoded referrer string like
     *   "utm_source=google&utm_medium=cpc&utm_campaign=winter2026"
     * into a map. Returns an empty map if the string is malformed.
     *
     * The referrer is a flat key=value&key=value string, not a real URL.
     * We do not use Uri.parse here because the referrer is not a full URL
     * and Uri.parse may reject it.
     */
    private fun parseUtmParams(referrer: String): Map<String, String> {
        val out = mutableMapOf<String, String>()
        try {
            referrer.split("&").forEach { pair ->
                if (pair.isBlank()) return@forEach
                val eq = pair.indexOf('=')
                if (eq <= 0) return@forEach
                val k = pair.substring(0, eq).trim()
                val v = pair.substring(eq + 1).trim()
                if (k.startsWith("utm_") && v.isNotEmpty()) {
                    out[k] = v
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse referrer: ${e.message}")
        }
        return out
    }
}
