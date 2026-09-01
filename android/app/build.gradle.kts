import java.io.FileInputStream
import java.util.Properties

// Release signing credentials live in android/key.properties, which is
// kept out of version control.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.megz.coloro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 10+ requires core library desugaring,
        // even when scheduled notifications are not used.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.megz.coloro"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Desugaring pulls in enough extra methods to risk the 64k dex limit.
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real upload key — never ship a debug-signed bundle.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Appended to the rules the Flutter plugin already contributes.
            proguardFile("proguard-rules.pro")
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
    // Backports the java.time APIs flutter_local_notifications schedules with
    // to older Android versions. Version pinned by the plugin's README.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // AdMob mediation adapters, Android only — deliberately plain Gradle
    // dependencies rather than the gma_mediation_* Flutter packages, so the
    // iOS build (SPM-only, no Podfile, and a prior tracking-signal rejection
    // on record) is never touched. The GMA SDK discovers adapters natively;
    // no Dart-side code is needed.
    //   Unity Ads — bidding, mapped in the three Coloro-*-Android mediation
    //   groups (Game ID 6183792). The adapter does NOT pull the Unity SDK in
    //   transitively (R8 fails on missing com.unity3d.* without it).
    implementation("com.unity3d.ads:unity-ads:4.20.0")
    implementation("com.google.ads.mediation:unity:4.20.0.1")
    //   AppLovin — waterfall only (AppLovin does not bid on AdMob). Needs
    //   applovin.sdk.key in AndroidManifest.xml to serve.
    implementation("com.google.ads.mediation:applovin:13.6.4.0")
}
