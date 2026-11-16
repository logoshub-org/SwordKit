plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

val swordKitVersion = (findProperty("swordKitVersion") as String?) ?: "0.0.0-local"

// The HTTP client SWORD's install manager uses on Android: OkHttp behind SwordNative.HttpFetcher. A module of its own so that the
// core library has no HTTP dependency (a host may bring its own fetcher).
android {
    namespace = "org.logoshub.sword.okhttp"
    compileSdk = 36
    defaultConfig {
        minSdk = 23
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    testOptions { targetSdk = 36 }
    publishing { singleVariant("release") { withSourcesJar() } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":sword"))
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
    androidTestImplementation("com.squareup.okhttp3:okhttp-tls:4.12.0")
}

kotlin {
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

afterEvaluate {
    publishing {
        publications {
            register<MavenPublication>("release") {
                from(components["release"])
                groupId = "org.logoshub"
                artifactId = "sword-okhttp"
                version = swordKitVersion
                pom {
                    name.set("SwordKit for Android: OkHttp fetcher")
                    description.set("The OkHttp client for SwordKit's install manager.")
                    url.set("https://github.com/logoshub-org/SwordKit")
                    licenses {
                        license { name.set("GPL-2.0-only"); url.set("https://www.gnu.org/licenses/old-licenses/gpl-2.0.html") }
                    }
                }
            }
        }
        repositories { maven { name = "release"; url = uri(rootProject.layout.buildDirectory.dir("maven")) } }
    }
}
