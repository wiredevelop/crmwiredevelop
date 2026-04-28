plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val cmKeystorePath = System.getenv("CM_KEYSTORE_PATH")
val cmKeystorePassword = System.getenv("CM_KEYSTORE_PASSWORD")
val cmKeyAlias = System.getenv("CM_KEY_ALIAS")
val cmKeyPassword = System.getenv("CM_KEY_PASSWORD")
val hasCodemagicSigning =
    !cmKeystorePath.isNullOrBlank() &&
    !cmKeystorePassword.isNullOrBlank() &&
    !cmKeyAlias.isNullOrBlank() &&
    !cmKeyPassword.isNullOrBlank()

configurations.configureEach {
    exclude(module = "bcprov-jdk15to18")
}

dependencies {
    implementation("org.slf4j:slf4j-nop:1.7.36")
}

android {
    namespace = "app.wiredevelop.pt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.wiredevelop.pt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        resources {
            pickFirsts += setOf(
                "org/bouncycastle/x509/CertPathReviewerMessages.properties",
                "org/bouncycastle/x509/CertPathReviewerMessages_de.properties",
            )
        }
    }

    signingConfigs {
        create("release") {
            if (hasCodemagicSigning) {
                storeFile = file(cmKeystorePath!!)
                storePassword = cmKeystorePassword
                keyAlias = cmKeyAlias
                keyPassword = cmKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasCodemagicSigning) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
            // R8 is currently exhausting heap in CI with the Stripe stack.
            // Keep release builds unminified until the dependency graph is reduced.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
