plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nuvi.nuvi_lifestyle"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.nuvi.lifestyle"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        // Required for the per-flavor app_name resValue below; off by default
        // in this Android Gradle Plugin version.
        resValues = true
    }

    // Distinct application IDs mean dev, staging and production can be
    // installed side by side on one device, and a staging build can never be
    // mistaken for — or upgrade over — production.
    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Nuvi Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Nuvi Staging")
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Nuvi Lifestyle")
        }
    }

    buildTypes {
        release {
            // Phase 0: signed with the debug key so `flutter run --release`
            // works locally. A real upload key and its custody are an
            // Infrastructure task before any store submission.
            signingConfig = signingConfigs.getByName("debug")
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
