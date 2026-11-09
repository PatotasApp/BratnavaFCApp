import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/discovery_datasource.dart';
import '../../domain/discovery_models.dart';

class GroupDiscoverySettingsCard extends ConsumerStatefulWidget {
  const GroupDiscoverySettingsCard({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupDiscoverySettingsCard> createState() => _State();
}

class _State extends ConsumerState<GroupDiscoverySettingsCard> {
  DiscoveryGroupProfile? p;
  late final description = TextEditingController(),
      city = TextEditingController();
  bool saving = false, isPublic = true, accepting = false, showMembers = false;
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
    if (mounted)
      setState(() {
        p = value;
        isPublic = value.isPublic;
        accepting = value.accepting;
        showMembers = value.showMembers;
        description.text = value.description ?? '';
        city.text = value.city ?? '';
      });
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await api.updateProfile(
        widget.groupId,
        isPublic: isPublic,
        accepting: accepting,
        showMembers: showMembers,
        description:
            description.text.trim().isEmpty ? null : description.text.trim(),
        city: city.text.trim().isEmpty ? null : city.text.trim(),
      );
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil da patota atualizado.')),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = p;
    if (value == null)
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    final c = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    color: c.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perfil e descoberta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Busca, vagas e visibilidade',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: description,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrição da patota',
                hintText: 'Conte como são os jogos e o clima da patota.',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: city,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Cidade ou região',
                hintText: 'Ex.: Recife · Zona Sul',
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
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
                  ),
                  IconButton(
                    onPressed: () async {
                      final code = await api.regenerateCode(widget.groupId);
                      if (mounted) setState(() => p = value.copyWithCode(code));
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Gerar outro',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isPublic,
              onChanged: (v) => setState(() => isPublic = v),
              title: const Text(
                'Patota pública',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Aparece nas buscas'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: accepting,
              onChanged: (v) => setState(() => accepting = v),
              title: const Text(
                'Aceitando jogadores',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Permite publicar vagas nas partidas'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: showMembers,
              onChanged: (v) => setState(() => showMembers = v),
              title: const Text(
                'Exibir integrantes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Mostra a lista no perfil público'),
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
              label: const Text('Salvar perfil'),
            ),
          ],
        ),
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
        members: members,
        isPublic: isPublic,
        accepting: accepting,
        showMembers: showMembers,
        matches: matches,
        people: people,
      );
}
