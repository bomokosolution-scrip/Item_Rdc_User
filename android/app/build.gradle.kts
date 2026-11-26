plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // Le plugin Gradle de Flutter doit être appliqué après ceux d'Android et de Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vault.itemrdc"
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.vault.itemrdc"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO : remplacer par votre clé de signature avant publication sur le Play Store.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
