import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Torna uma identidade de jogador navegável quando ela está vinculada a um usuário.
class UserProfileLink extends StatelessWidget {
  final String? userId;
  final Widget child;

  const UserProfileLink({
    super.key,
    required this.userId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final id = userId?.trim();
    if (id == null || id.isEmpty) return child;

    return Semantics(
      button: true,
      label: 'Abrir perfil',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/app/profile/$id'),
        child: child,
      ),
    );
  }
}
