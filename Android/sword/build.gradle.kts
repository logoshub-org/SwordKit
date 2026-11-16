plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("maven-publish")
}

// The native library is built by Tools/build_sword_android.sh (SWORD, CLucene and the JNI in one .so per ABI); Gradle packages what it
// leaves in build/android/<abi>/, or in the folder -PswordJniLibs names (Tools/package_android_aar.sh passes the stripped copies).
val jniLibs = (findProperty("swordJniLibs") as String?)?.let { file(it) } ?: file("../../build/android")
val swordKitVersion = (findProperty("swordKitVersion") as String?) ?: "0.0.0-local"

android {
    namespace = "org.logoshub.sword"
    compileSdk = 36
    defaultConfig {
        minSdk = 23
        ndk { abiFilters += listOf("arm64-v8a", "x86_64") }
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        // the JNI looks classes, methods and fields up by name: a minifying app must not rename them
        consumerProguardFiles("consumer-rules.pro")
    }
    testOptions { targetSdk = 36 }
    sourceSets["main"].jniLibs.srcDir(jniLibs)
    // the GPL text and the notices travel inside the library
    sourceSets["main"].resources.srcDir(layout.buildDirectory.dir("generated/licences"))
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    publishing { singleVariant("release") { withSourcesJar() } }
}

val copyLicences by tasks.registering(Copy::class) {
    from("../../LICENSE", "../../NOTICE")
    into(layout.buildDirectory.dir("generated/licences/META-INF/org.logoshub.sword"))
}
tasks.matching { it.name.startsWith("process") && it.name.endsWith("JavaRes") }.configureEach { dependsOn(copyLicences) }
tasks.matching { it.name.endsWith("SourcesJar") || it.name.startsWith("extract") }.configureEach { mustRunAfter(copyLicences) }

dependencies {
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
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
                artifactId = "sword"
                version = swordKitVersion
                pom {
                    name.set("SwordKit for Android")
                    description.set("The SWORD engine (with CLucene) behind a Kotlin API, for Android: arm64-v8a and x86_64.")
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
