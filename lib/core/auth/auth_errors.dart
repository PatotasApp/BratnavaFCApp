import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Traduz os códigos do Firebase Auth para mensagens em português.
///
/// Espelha `src/auth/authErrors.ts` do front web, com uma diferença de formato: o
/// SDK Dart entrega o código SEM o prefixo `auth/` que a versão JS usa.
///
/// A proteção contra enumeração de contas faz o Firebase devolver
/// `invalid-credential` tanto para senha errada quanto para e-mail inexistente —
/// então a mensagem é genérica de propósito. Distinguir os dois vazaria quais
/// e-mails têm conta.
const Map<String, String> _messages = {
  'invalid-credential': 'E-mail ou senha incorretos.',
  'invalid-login-credentials': 'E-mail ou senha incorretos.',
  'wrong-password': 'E-mail ou senha incorretos.',
  'user-not-found': 'E-mail ou senha incorretos.',
  'invalid-email': 'E-mail inválido.',
  'user-disabled': 'Esta conta foi desativada.',
  'email-already-in-use':
      'Já existe uma conta com este e-mail. Tente entrar ou recuperar a senha.',
  'weak-password': 'A senha precisa ter pelo menos 6 caracteres.',
  'missing-password': 'Informe a senha.',
  'too-many-requests':
      'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
  'network-request-failed':
      'Sem conexão com o servidor. Verifique sua internet.',
  'account-exists-with-different-credential':
      'Já existe uma conta com este e-mail usando outro método de login. '
          'Entre por ele e vincule depois.',
  'requires-recent-login':
      'Por segurança, entre novamente antes de fazer esta alteração.',
};

/// Mensagem amigável para [error], ou [fallback] quando o código é desconhecido.
String authErrorMessage(Object error, String fallback) {
  if (error is FirebaseAuthException) {
    return _messages[error.code] ?? fallback;
  }

  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Login cancelado.',
      GoogleSignInExceptionCode.interrupted =>
        'O login foi interrompido. Tente de novo.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Configuração do login com Google inválida neste build.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'O login com Google não está habilitado para este ambiente.',
      _ => fallback,
    };
  }

  return fallback;
}

/// Cancelar o login não é falha: a UI não deve mostrar erro nesses casos.
///
/// No mobile o cancelamento chega como exceção — diferente do `signIn()` da API
/// antiga do google_sign_in, que devolvia `null`.
bool isUserCancelled(Object error) {
  if (error is GoogleSignInException) {
    return error.code == GoogleSignInExceptionCode.canceled;
  }

  return error is FirebaseAuthException && error.code == 'web-context-canceled';
}
