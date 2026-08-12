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
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}