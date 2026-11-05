plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.scoreline.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        // AGP 9 turns generated resource values off by default, and the flavors below
        // declare app_name with resValue. Without this the build fails at configuration
        // time with "contains custom resource values, but the feature is disabled".
        // The alternative — a strings.xml per flavor source set — is three files instead
        // of this line and splits the flavor's identity away from its declaration.
        resValues = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.scoreline.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

    // One dimension: which environment this build points at. `prod` carries no
    // applicationIdSuffix, so the shipping id stays com.scoreline.app and an
    // already-installed build upgrades in place rather than becoming a fourth app.
    // `dev` and `staging` get their own ids so all three sit side by side on one
    // device.
    //
    // `namespace` above is deliberately left alone: it is the Kotlin/R package, not
    // the install id, so MainActivity does not move and no source file changes.
    //
    // The flavors differ in identity only — id, label, icon. Nothing behavioural is
    // switched here, and nothing in lib/ reads the flavor. When one of them does need
    // to point at a different backend, the honest place for it is a --dart-define
    // read at the composition root, not a Gradle field the Dart side cannot see.
    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Scoreline Dev")
        }
        create("staging") {
            dimension = "env"
            applicationIdSuffix = ".stg"
            resValue("string", "app_name", "Scoreline Staging")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "Scoreline")
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
