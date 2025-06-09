buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.0") // Ensure this matches your Gradle version.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.10") // Directly define Kotlin version
        classpath("com.google.gms:google-services:4.4.2") // Update to the latest google-services plugin version
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}