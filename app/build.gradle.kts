plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// Version is bumped on every release. Keep PROJECT_INFO.txt in sync.
val appVersionName = "0.1.1"
val appVersionCode = 2

android {
    // TODO: confirm the final applicationId before the first Play Store upload.
    namespace = "com.pdfai.app"
    compileSdk = 37 // Compose 1.12 requires compileSdk 37.

    defaultConfig {
        applicationId = "com.pdfai.app"
        minSdk = 26
        // TODO: verify Google Play's current target API requirement before publishing.
        targetSdk = 36
        versionCode = appVersionCode
        versionName = appVersionName
    }

    buildTypes {
        release {
            // TODO: enable minification once real features exist and keep rules are verified.
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
