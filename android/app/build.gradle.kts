plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android 
{
    namespace = "com.example.egypttest"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString() // Explicitly set to 11
    }

    defaultConfig {
        applicationId = "com.example.egypttest"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = "12345678" 
            keyAlias = "key"
            keyPassword = "12345678" 
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release") // Use the release signing config
            // ... other release configurations ...
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.0.0")) //Update to the latest Firebase BOM version
    implementation("com.google.firebase:firebase-analytics")
}