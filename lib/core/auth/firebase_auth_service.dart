import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Ponto único de contato com o Firebase Auth.
///
/// Depois da migração a API não participa de identidade: não há endpoint de
/// login, cadastro, refresh, logout nem troca de senha. Tudo aqui é SDK, e o
/// backend só valida o ID token e resolve a identidade interna.
///
/// O ID token dura ~1h e o SDK renova sozinho a partir de um refresh token
/// persistido no aparelho. Por isso não existe — e não deve voltar a existir —
/// nenhuma máquina de refresh nossa.
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? google})
      : _auth = auth ?? FirebaseAuth.instance,
        _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// `initialize()` do google_sign_in precisa rodar uma vez antes de qualquer
  /// `authenticate()`. Guardar o Future serializa chamadas concorrentes.
  Future<void>? _googleInit;

  User? get currentUser => _auth.currentUser;

  /// Emite ao entrar, ao sair e quando o SDK termina de ler a sessão do disco.
  ///
  /// O primeiro evento é o que resolve o `initializing` da UI: até ele chegar,
  /// "sem usuário" não significa deslogado — significa que ainda não sabemos.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Reflete trocas de e-mail e de verificação, que `authStateChanges` ignora.
  Stream<User?> userChanges() => _auth.userChanges();

  // ── Entrada ────────────────────────────────────────────────────────────────

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  Future<UserCredential> signInWithGoogle() async {
    _googleInit ??= _google.initialize();
    await _googleInit;

    // Falso apenas na web, que não é alvo deste app. Checar evita um erro
    // obscuro de plataforma caso alguém rode o app fora do mobile.
    if (!_google.supportsAuthenticate()) {
      throw UnsupportedError(
        'Login com Google não suportado nesta plataforma.',
      );
    }

    // Diferente da API 6.x, `authenticate` LANÇA quando o usuário cancela em
    // vez de devolver null — ver isUserCancelled em auth_errors.dart.
    final account = await _google.authenticate();

    final idToken = account.authentication.idToken;

    if (idToken == null) {
      // Acontece quando o projeto não tem OAuth client web (client_type 3) no
      // google-services.json, ou quando o SHA do build não está registrado.
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'O Google não devolveu um ID token. Verifique se o SHA deste '
            'build está registrado no projeto Firebase.',
      );
    }

    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) =>
      _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  // ── Saída ──────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    // A sessão do Google é separada da do Firebase. Sem encerrá-la, o próximo
    // login pularia a escolha de conta e entraria de novo na mesma.
    try {
      _googleInit ??= _google.initialize();
      await _googleInit;
      await _google.signOut();
    } catch (error) {
      debugPrint('[Auth] Falha ao encerrar a sessão do Google: $error');
    }

    await _auth.signOut();
  }

  // ── Senha, e-mail e verificação ────────────────────────────────────────────

  /// Único caminho de troca de senha que existe — inclusive para quem está
  /// logado. Redefinir por e-mail também marca o endereço como verificado, o
  /// que é o que destrava o vínculo com a linha existente no provisionamento.
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Troca de e-mail no padrão verify-before-update: o link vai para o endereço
  /// NOVO e a troca só vale depois que a pessoa clica. A API não participa — o
  /// `SyncEmailAsync` atualiza a coluna sozinho no acesso seguinte.
  Future<void> changeEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Sessão expirada. Entre novamente.',
      );
    }
    await user.verifyBeforeUpdateEmail(newEmail.trim());
  }

  /// Relê o registro no servidor. O Firebase não avisa o app quando o e-mail é
  /// verificado — o link costuma ser aberto em outro aparelho, então nada
  /// dispara localmente e a checagem precisa ser sob demanda.
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    await user.reload();

    final refreshed = _auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return false;

    // `reload()` atualiza o objeto local, mas o ID token em mãos segue dizendo
    // email_verified: false até ser reemitido. Forçar aqui evita que o backend
    // veja o estado antigo por até uma hora.
    await refreshed.getIdToken(true);

    return true;
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  /// ID token atual, renovado pelo SDK quando necessário.
  ///
  /// Devolve null sem sessão, e também quando a renovação falha sem rede — aí a
  /// request sai sem header e o 401 concentra o tratamento num lugar só.
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } catch (error) {
      debugPrint('[Auth] Falha ao obter o ID token: $error');
      return null;
    }
  }

  /// Renova o token quando ele ainda não carrega as custom claims do backend.
  ///
  /// O `GET /me` provisiona o usuário e, com ele, grava `internal_id` e `role`
  /// como custom claims. Só que o token em mãos foi emitido ANTES dessa escrita,
  /// e o Firebase não empurra mudança de claim para o cliente — quem puxa somos
  /// nós.
  ///
  /// Sem isto o middleware do backend cai no caminho lento (SELECT + regravação
  /// das claims) em TODA request, não só na primeira, até o token expirar quase
  /// uma hora depois.
  ///
  /// `getIdTokenResult()` sem forçar lê o token já em cache, sem rede: em
  /// sessão que já tem as claims isto não custa nada. Falha é ignorada de
  /// propósito — é otimização, e o backend nunca depende dela.
  Future<void> refreshClaimsIfMissing() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final result = await user.getIdTokenResult();
      final claims = result.claims ?? const {};

      if (claims['internal_id'] != null && claims['role'] != null) return;

      await user.getIdToken(true);
    } catch (_) {
      // Segue com o token atual.
    }
  }
}
