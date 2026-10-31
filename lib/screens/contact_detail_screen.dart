import 'package:flutter/material.dart';

import '../data/database.dart';
import '../services/contact_influence_service.dart';

class ContactDetailScreen extends StatefulWidget {
  final String name;

  const ContactDetailScreen({super.key, required this.name});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  final _notesController = TextEditingController();
  ContactInfluence? _influence;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final influences = await ContactInfluenceService().computeAll();
    final notes = await AppDatabase.instance.contactNotes(widget.name);
    setState(() {
      _influence = influences.firstWhere(
        (i) => i.name == widget.name,
        orElse: () => ContactInfluence(
          name: widget.name,
          daysWith: 0,
          avgMoodWith: 0,
          daysWithout: 0,
          avgMoodWithout: 0,
        ),
      );
      _notesController.text = notes ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await AppDatabase.instance.setContactNotes(
      widget.name,
      _notesController.text,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notes enregistrées')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final influence = _influence!;
    final delta = influence.delta;

    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Influence sur l\'humeur',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (influence.hasEnoughData) ...[
                      Text(
                        'Moyenne les jours avec cette personne : '
                        '${influence.avgMoodWith.toStringAsFixed(1)}/5 '
                        '(${influence.daysWith} jour'
                        '${influence.daysWith > 1 ? 's' : ''})',
                      ),
                      Text(
                        'Moyenne les autres jours : '
                        '${influence.avgMoodWithout.toStringAsFixed(1)}/5 '
                        '(${influence.daysWithout} jour'
                        '${influence.daysWithout > 1 ? 's' : ''})',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        delta! > 0
                            ? 'Écart : +${delta.toStringAsFixed(1)}'
                            : 'Écart : ${delta.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ] else
                      Text(
                        'Pas encore assez de données pour comparer '
                        '(${influence.daysWith} jour'
                        '${influence.daysWith > 1 ? 's' : ''} avec cette '
                        'personne). Continue à taguer tes entrées.',
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Simple comparaison de moyennes sur tes entrées, pas '
                      'une preuve de cause à effet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Contexte, historique, ce que tu remarques...',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
