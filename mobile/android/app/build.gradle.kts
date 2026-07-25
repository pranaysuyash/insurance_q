plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val productionReleaseBuild = System.getenv("COVERWISE_RELEASE_BUILD") == "true"
val requiredSigningProperties = listOf("storePassword", "keyPassword", "keyAlias", "storeFile")
val missingSigningProperties = requiredSigningProperties.filterNot(keystoreProperties::containsKey)
val configuredStoreFile = keystoreProperties.getProperty("storeFile")
val releaseStoreFile = configuredStoreFile?.let {
    val configured = File(it)
    if (configured.isAbsolute) configured else rootProject.file(it)
}
if (productionReleaseBuild) {
    if (missingSigningProperties.isNotEmpty() || releaseStoreFile == null || !releaseStoreFile.isFile) {
        throw GradleException(
            "Production release requires mobile/android/key.properties with " +
                "storePassword, keyPassword, keyAlias, and an existing storeFile; " +
                "refusing to fall back to the debug keystore."
        )
    }
}

android {
    namespace = "com.coverwise.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = releaseStoreFile
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.coverwise.app"
        minSdk = flutter.minSdkVersion
        // Keep the Play submission target aligned with the current Android
        // platform baseline. This is intentionally separate from minSdk: the
        // app continues to support Android 6+ while opting into Android 16
        // runtime behavior and its privacy/security guarantees.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // When a release keystore is configured (android/key.properties),
            // sign with it for Play Store / production distribution. Otherwise
            // fall back to the debug keystore so local release builds still work.
            // See docs/technical/deployment/release_signing.md to create the keystore.
            signingConfig = if (keystoreProperties.containsKey("keyAlias")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    // Add desugaring dependency with updated version
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}
