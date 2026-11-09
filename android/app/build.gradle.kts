import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.holyquran"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.holyquran"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// A release build never carries the unapproved test copy's defines (D-163).
// The Flutter tool passes -Pdart-defines as comma-separated base64 of each
// KEY=VALUE (checked in flutter_tools' encodeDartDefines, Flutter 3.47.9).
val carriesTestCopy = (project.findProperty("dart-defines")?.toString() ?: "")
    .split(',')
    .filter { it.isNotEmpty() }
    .any {
        runCatching { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
            .getOrDefault("")
            .startsWith("HOLYQURAN_TEST_PACK")
    }

gradle.taskGraph.whenReady {
    val release = allTasks.firstOrNull {
        it.project == project && it.name.matches(Regex("(assemble|bundle|package)\\w*Release"))
    }
    if (carriesTestCopy && release != null) {
        throw GradleException(
            "${release.path}: HOLYQURAN_TEST_PACK is set. The unapproved test copy is never built for release (D-163)."
        )
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
