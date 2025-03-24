plugins {
    id("com.android.application") version "8.2.0" // ✅ Add version
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") 
    id("org.jetbrains.kotlin.android") version "1.9.22" // ✅ Ensure Kotlin plugin versio
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")?.toIntOrNull() ?: 1
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

android {
    // Fix for NDK version
    ndkVersion = "27.0.12077973"
    namespace = "com.example.turikumwe"
    compileSdk = libs.versions.compileSdk.get().toInt()

    compileOptions {
        // Enable desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    defaultConfig {
        applicationId = "com.example.turikumwe"
        minSdk = libs.versions.minSdk.get().toInt()
        targetSdk = libs.versions.targetSdk.get().toInt()
        versionCode = flutterVersionCode
        versionName = flutterVersionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = ".."
}

dependencies {
    // Add desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}