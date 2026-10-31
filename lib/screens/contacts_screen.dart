import 'package:flutter/material.dart';

import '../data/mood_colors.dart';
import '../services/contact_influence_service.dart';
import 'contact_detail_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactInfluence> _influences = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final influences = await ContactInfluenceService().computeAll();
    influences.sort((a, b) {
      final da = a.delta;
      final db = b.delta;
      if (da == null && db == null) return a.name.compareTo(b.name);
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    setState(() {
      _influences = influences;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personnes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _influences.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun contact pour le moment. Ajoutes-en un depuis '
                  'une entrée du jour pour commencer à voir son influence.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _influences.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final influence = _influences[index];
                  return _ContactTile(
                    influence: influence,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ContactDetailScreen(name: influence.name),
                        ),
                      );
                      _load();
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactInfluence influence;
  final VoidCallback onTap;

  const _ContactTile({required this.influence, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final delta = influence.delta;
    final Color badgeColor;
    final String badgeText;
    if (delta == null) {
      badgeColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      badgeText = '?';
    } else if (delta > 0.05) {
      badgeColor = MoodColors.colorFor(5);
      badgeText = '+${delta.toStringAsFixed(1)}';
    } else if (delta < -0.05) {
      badgeColor = MoodColors.colorFor(1);
      badgeText = delta.toStringAsFixed(1);
    } else {
      badgeColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      badgeText = '=';
    }

    final subtitle = influence.hasEnoughData
        ? 'Avec : ${influence.avgMoodWith.toStringAsFixed(1)}/5 '
              '(${influence.daysWith} j) · Sans : '
              '${influence.avgMoodWithout.toStringAsFixed(1)}/5 '
              '(${influence.daysWithout} j)'
        : 'Pas assez de données (${influence.daysWith} jour'
              '${influence.daysWith > 1 ? 's' : ''} avec cette personne)';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: badgeColor,
        foregroundColor: Colors.white,
        child: Text(badgeText, style: const TextStyle(fontSize: 12)),
      ),
      title: Text(influence.name),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
