import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/share/share_links.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

/// Privacidade da patota: quem encontra, o que cada um vê e o perfil público.
///
/// Fica recolhido por padrão (a tela de configurações já é apertada) e mostra
/// um resumo do que está ligado. O interruptor do link compartilhado pertence
/// às configurações gerais; por isso chega por [publicPageEnabled] e é salvo
/// por [onSaveSettings] junto com o resto do perfil.
class GroupDiscoverySettingsCard extends ConsumerStatefulWidget {
  const GroupDiscoverySettingsCard({
    super.key,
    required this.groupId,
    this.publicPageEnabled = true,
    this.onPublicPageChanged,
    this.onSaveSettings,
  });
  final String groupId;
  final bool publicPageEnabled;
  final ValueChanged<bool>? onPublicPageChanged;
  final Future<void> Function()? onSaveSettings;
  @override
  ConsumerState<GroupDiscoverySettingsCard> createState() => _State();
}

class _State extends ConsumerState<GroupDiscoverySettingsCard> {
  DiscoveryGroupProfile? p;
  late final description = TextEditingController(),
      city = TextEditingController();
  bool saving = false, isPublic = true, accepting = false, showMembers = false;
  bool showGoalsToGuests = false;
  bool open = false;
  DiscoveryDataSource get api => DiscoveryDataSource(ref.read(dioProvider));
  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  @override
  void dispose() {
    description.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final value = await api.group(widget.groupId);
    if (mounted) {
      setState(() {
        p = value;
        isPublic = value.isPublic;
        accepting = value.accepting;
        showMembers = value.showMembers;
        showGoalsToGuests = value.showGoalsToGuests;
        description.text = value.description ?? '';
        city.text = value.city ?? '';
      });
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await api.updateProfile(
        widget.groupId,
        isPublic: isPublic,
        accepting: accepting,
        showMembers: showMembers,
        showGoalsToGuests: showGoalsToGuests,
        description:
            description.text.trim().isEmpty ? null : description.text.trim(),
        city: city.text.trim().isEmpty ? null : city.text.trim(),
      );
      await widget.onSaveSettings?.call();
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacidade e perfil atualizados.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String get _summary {
    final parts = <String>[
      isPublic ? 'Na busca' : 'Fora da busca',
      widget.publicPageEnabled ? 'Link ativo' : 'Link desligado',
      if (accepting) 'Aceitando jogadores',
    ];
    return parts.join(' · ');
  }

  Widget _group(String label, ColorScheme c) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: c.onSurfaceVariant,
          ),
        ),
      );

  Widget _switch(String title, String subtitle, bool value,
          ValueChanged<bool>? onChanged) =>
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    final value = p;
    if (value == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final c = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => open = !open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.lock_outline_rounded,
                        size: 20, color: c.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Privacidade',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          _summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(open
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _group('QUEM ENCONTRA A PATOTA', c),
                  _switch(
                    'Aparecer na busca',
                    isPublic
                        ? 'Qualquer jogador acha a patota na busca'
                        : 'Só entra quem tem o link ou o código',
                    isPublic,
                    (v) => setState(() => isPublic = v),
                  ),
                  _switch(
                    'Aceitando jogadores',
                    'Permite publicar vagas nas partidas',
                    accepting,
                    (v) => setState(() => accepting = v),
                  ),
                  _switch(
                    'Link de compartilhamento',
                    'Abre a página pública da patota',
                    widget.publicPageEnabled,
                    widget.onPublicPageChanged,
                  ),
                  if (widget.publicPageEnabled)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => shareLink(
                          context,
                          ShareLinks.group(widget.groupId),
                          text: 'Conheça nossa patota no PatotasApp',
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Compartilhar patota'),
                      ),
                    ),
                  _group('O QUE QUEM ABRE O PERFIL VÊ', c),
                  _switch(
                    'Exibir integrantes',
                    'Mostra a lista de jogadores',
                    showMembers,
                    (v) => setState(() => showMembers = v),
                  ),
                  _switch(
                    'Mostrar gols a convidados',
                    'Quem jogou como convidado vê quem fez os gols',
                    showGoalsToGuests,
                    (v) => setState(() => showGoalsToGuests = v),
                  ),
                  Text(
                    'Partidas, enquetes, financeiro e presenças nunca '
                    'aparecem para quem está de fora.',
                    style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
                  ),
                  _group('PERFIL DA PATOTA', c),
                  const SizedBox(height: 8),
                  TextField(
                    controller: description,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrição da patota',
                      hintText: 'Conte como são os jogos e o clima da patota.',
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: city,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Cidade ou região',
                      hintText: 'Ex.: Recife · Zona Sul',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.fromLTRB(13, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CÓDIGO DA PATOTA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                value.code,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: value.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Código copiado.')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          tooltip: 'Copiar',
                        ),
                        IconButton(
                          onPressed: () async {
                            final code =
                                await api.regenerateCode(widget.groupId);
                            if (mounted) {
                              setState(() => p = value.copyWithCode(code));
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Gerar outro',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Salvar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on DiscoveryGroupProfile {
  DiscoveryGroupProfile copyWithCode(String value) => DiscoveryGroupProfile(
        id: id,
        name: name,
        code: value,
        logoUrl: logoUrl,
        description: description,
        city: city,
        defaultDayOfWeek: defaultDayOfWeek,
        defaultKickoffTime: defaultKickoffTime,
        members: members,
        isPublic: isPublic,
        accepting: accepting,
        showMembers: showMembers,
        showGoalsToGuests: showGoalsToGuests,
        matches: matches,
        people: people,
      );
}
