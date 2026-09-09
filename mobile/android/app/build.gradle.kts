import java.util.Properties

// ⚠️ LA CLÉ DE SIGNATURE N'EST PAS DANS CE DÉPÔT, et ne doit jamais y entrer.
//
//    `key.properties` et le fichier .jks sont ignorés par git. En local ils
//    sont posés à la main ; sur GitHub Actions, la chaîne les écrit depuis
//    des secrets. Voir .github/workflows/mobile.yml.
val proprietesCle = Properties()
val fichierCle = rootProject.file("key.properties")
if (fichierCle.exists()) {
    fichierCle.inputStream().use { proprietesCle.load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // ⚠️ APRÈS le greffon Flutter, jamais avant : il lit la configuration
    //    Android que celui-ci vient de poser.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.garah.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // ⚠️ CE NOM EST UNE CLÉ, pas une étiquette : Firebase apparie les
        //    messages à l'application par lui. Il doit rester EXACTEMENT égal
        //    au package_name de google-services.json. Une lettre de travers,
        //    et rien n'arrive — sans le moindre message d'erreur.
        applicationId = "com.garah.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ⚠️ CE BLOC REMPLACE LE `TODO` DE FLUTTER, qui signait la RELEASE avec la
    //    clé de DEBUG. Un APK ainsi signé s'installe et fonctionne, ce qui est
    //    précisément le piège : rien n'avertit. Mais la clé de debug est
    //    engendrée par la machine qui compile — elle change d'un poste à
    //    l'autre et d'un coureur GitHub au suivant. Deux APK « release » ne se
    //    mettent alors pas à jour l'un l'autre, et aucun n'est publiable.
    signingConfigs {
        create("release") {
            keyAlias = proprietesCle.getProperty("keyAlias")
            keyPassword = proprietesCle.getProperty("keyPassword")
            storeFile = proprietesCle.getProperty("storeFile")?.let { file(it) }
            storePassword = proprietesCle.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // ⚠️ ON ÉCHOUE PLUTÔT QUE DE RETOMBER SUR LA CLÉ DE DEBUG.
            //
            //    Le repli silencieux est ce qui a laissé passer le problème :
            //    la chaîne rendait un .apk, tout avait l'air de marcher. Sans
            //    clé, la compilation release s'arrête ici et dit pourquoi — un
            //    échec bruyant vaut mieux qu'un artefact qu'on croit bon.
            //
            //    Le debug, lui, continue de se compiler sans rien : c'est ce
            //    qui permet de reprendre le dépôt et de lancer l'application
            //    sans détenir la clé.
            signingConfig = if (fichierCle.exists()) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "Aucune clé de signature : android/key.properties est absent.\n" +
                    "  • En local  : le poser à côté du .jks — voir key.properties.exemple.\n" +
                    "  • Sur la CI : Settings > Secrets and variables > Actions.\n" +
                    "      Secrets   : ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, " +
                    "ANDROID_KEY_PASSWORD\n" +
                    "      Variables : ANDROID_KEY_ALIAS — c'est une VARIABLE et non un " +
                    "secret : les deux onglets sont des espaces de noms distincts."
                )
            }
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
