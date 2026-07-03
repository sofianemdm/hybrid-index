plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Active la config Firebase (google-services.json) pour cette app Android.
    id("com.google.gms.google-services")
    // Crash reporting (Crashlytics) : build ID + upload des symboles au build release.
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "app.hybridindex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.hybridindex"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Clé de signature STABLE pour le release (requise pour Google Sign-In : le SHA-1 doit être
    // enregistré dans Firebase). Fournie via variables d'env (secret GitHub décodé dans le workflow).
    // Si absente (build local sans secret), on retombe sur la clé debug pour ne rien casser.
    val releaseKeystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")
    val hasReleaseKeystore = releaseKeystorePath != null && file(releaseKeystorePath).exists()
    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                storeFile = file(releaseKeystorePath!!)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // R8 : code Java/Kotlin minifié + ressources Android inutilisées retirées.
            // (Le code Dart est déjà tree-shaké par Flutter ; ceci couvre la couche native.)
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
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
