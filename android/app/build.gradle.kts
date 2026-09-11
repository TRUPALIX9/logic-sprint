import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter passes --dart-define / --dart-define-from-file values as base64 entries,
// so the AdMob App ID can live in config/admob.json next to the ad unit IDs.
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.map { String(Base64.getDecoder().decode(it)).split("=", limit = 2) }
    ?.associate { it[0] to it.getOrElse(1) { "" } }
    ?: emptyMap()
val admobAppId = dartDefines["ADMOB_APP_ID"].orEmpty()
val requestedTasks = gradle.startParameter.taskNames
val keystorePropertiesFile = rootProject.file("key.properties")

if (requestedTasks.any { it.contains("Release", ignoreCase = true) } && admobAppId.isEmpty()) {
    throw GradleException(
        "Release builds need ADMOB_APP_ID. Build with --dart-define-from-file=config/admob.json " +
            "(see config/admob.example.json), or use `make build-aab`.",
    )
}
if (requestedTasks.any { it.contains("bundleRelease", ignoreCase = true) } && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Play Store bundles must be release-signed: create android/key.properties " +
            "(see docs/android_release_signing.md).",
    )
}

android {
    namespace = "com.trupal.logicsprint"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.trupal.logicsprint"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Falls back to Google's test App ID for debug builds.
        manifestPlaceholders["admobAppId"] = admobAppId.ifEmpty { "ca-app-pub-3940256099942544~3347511713" }
    }

    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Local-only fallback. Play Store requires android/key.properties — see docs/android_release_signing.md
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
