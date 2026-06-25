import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload-keystore credentials, kept out of git in android/key.properties (see
// RELEASE_PLAN.md). Absent on dev machines, so we fall back to debug signing
// below — a Play-store build REQUIRES this file to exist.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.aknsoftware.questionapp"
    // Some plugins (package_info_plus, …) require API 36; raise above the
    // Flutter default if it is lower.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs that require core
        // library desugaring to run on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aknsoftware.questionapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // RevenueCat's paywall UI (purchases_ui_flutter) requires minSdk 24;
        // this also covers google_mobile_ads' minSdk 23. Raise the Flutter
        // default if it is lower.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only wired up when android/key.properties exists. The values come from
        // the upload keystore you generate with keytool (see RELEASE_PLAN.md).
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sign with the real upload keystore when key.properties is present;
            // otherwise fall back to debug keys so `flutter run --release` still
            // works on dev machines. A debug-signed build is REJECTED by Play —
            // create the keystore before submitting (RELEASE_PLAN.md, Krok 1).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Flutter enables R8 shrinking/obfuscation for release; supply our
            // own keep rules (see proguard-rules.pro) so reflectively-loaded
            // classes — Room's generated WorkManager DB impl — survive.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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

dependencies {
    // Required by flutter_local_notifications when core library desugaring is on.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
