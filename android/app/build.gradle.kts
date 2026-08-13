import java.io.FileInputStream
import java.util.Properties

// Chave de assinatura de release. O arquivo fica FORA do repositório (bloqueado
// no .gitignore junto com *.jks e *.p12) porque contém as senhas e um caminho
// local de cada máquina. Distribuição por cofre de senhas, nunca por chat.
//
// Ausente = build de release cai no signing de debug (ver signingConfigs). É
// deliberado: quem não tem a chave continua conseguindo buildar release para
// medir performance e tamanho, só não gera nada publicável.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    // 1. AQUI: O novo namespace do app
    namespace = "br.com.patotasapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        // Keystore de debug versionado, compartilhado por todos os devs e pelo CI.
        //
        // Sem ele, cada máquina gera o próprio ~/.android/debug.keystore e produz um SHA-1
        // diferente — e o login com Google exige que o SHA do APK esteja registrado no app
        // Firebase. Com o arquivo no repo, é um SHA só para o time inteiro.
        //
        // Não é segredo: a senha "android" e o alias "androiddebugkey" são os padrões do
        // Android SDK. O que limita o risco é este SHA estar registrado APENAS no projeto
        // Firebase de desenvolvimento. Nunca registrá-lo em produção, e nunca usar esta
        // chave para assinar release.
        getByName("debug") {
            storeFile = file("../keystores/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        // A upload key: assina o AAB enviado à Play e os APKs de release
        // buildados localmente. A Play remove esta assinatura e re-assina com a
        // app signing key, que é do Google — por isso os DOIS SHAs precisam
        // estar registrados no projeto Firebase de produção.
        //
        // Em keystore PKCS12 existe uma senha só: keyPassword é a mesma que
        // storePassword. O key.properties repete o valor nas duas chaves.
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        // 2. AQUI: O ID base oficial do aplicativo
        applicationId = "br.com.patotasapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev" // ID final: br.com.patotasapp.dev
            resValue("string", "app_name", "PatotasApp Dev") 
        }
        create("prod") {
            dimension = "env"
            // ID final: br.com.patotasapp
            resValue("string", "app_name", "PatotasApp") 
        }
    }

    buildTypes {
        release {
            // Sem key.properties o release sai assinado com a chave de debug.
            // Serve para testar, NUNCA para publicar: a Play recusa APK assinado
            // com chave de debug, e o SHA dessa chave está no repositório.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}