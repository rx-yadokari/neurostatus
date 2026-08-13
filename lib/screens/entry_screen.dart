import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/emotions_repository.dart';
import '../models/entry.dart';
import '../services/pattern_alert_service.dart';
import 'crisis_log_sheet.dart';

class EntryScreen extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onSaved;

  const EntryScreen({super.key, required this.date, this.onSaved});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  double _mood = 3;
  final Set<String> _selectedEmotions = {};
  final _eventController = TextEditingController();
  List<String> _availableEmotions = [];
  bool _loading = true;
  bool _saving = false;
  String? _patternAlert;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final emotions = await EmotionsRepository.instance.allEmotions();
    final existing = await AppDatabase.instance.entryForDate(widget.date);
    final alert = await PatternAlertService().checkForConcerningPattern();
    setState(() {
      _availableEmotions = emotions;
      if (existing != null) {
        _mood = existing.mood.toDouble();
        _selectedEmotions.addAll(existing.emotions);
        _eventController.text = existing.event ?? '';
      }
      _patternAlert = alert;
      _loading = false;
    });
  }

  Future<void> _dismissPatternAlert() async {
    await PatternAlertService().snoozeForOneWeek();
    setState(() => _patternAlert = null);
  }

  Future<void> _addCustomEmotion() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle émotion'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex : Nostalgie'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await EmotionsRepository.instance.addCustomEmotion(result);
      final emotions = await EmotionsRepository.instance.allEmotions();
      setState(() {
        _availableEmotions = emotions;
        _selectedEmotions.add(result.trim());
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final entry = MoodEntry(
      date: widget.date,
      mood: _mood.round(),
      emotions: _selectedEmotions.toList(),
      event: _eventController.text.trim().isEmpty
          ? null
          : _eventController.text.trim(),
      createdAt: DateTime.now(),
    );
    await AppDatabase.instance.upsertEntry(entry);
    if (mounted) {
      setState(() => _saving = false);
      if (widget.onSaved != null) {
        widget.onSaved!();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrée enregistrée')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(widget.date);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dateLabel),
        actions: [
          IconButton(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Signaler une crise',
            onPressed: () async {
              final saved = await showCrisisLogSheet(context);
              if (saved && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Crise enregistrée')),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_patternAlert != null) ...[
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _patternAlert!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Si tu es en détresse, le 3114 (numéro national de '
                        'prévention du suicide, gratuit, 24/7) peut t\'aider.',
                        style: TextStyle(fontSize: 12),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _dismissPatternAlert,
                          child: const Text('Masquer cette semaine'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'État général',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _mood,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _mood.round().toString(),
                    onChanged: (v) => setState(() => _mood = v),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    _mood.round().toString(),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Émotions principales',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final emotion in _availableEmotions)
                  FilterChip(
                    label: Text(emotion),
                    selected: _selectedEmotions.contains(emotion),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedEmotions.add(emotion);
                        } else {
                          _selectedEmotions.remove(emotion);
                        }
                      });
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  onPressed: _addCustomEmotion,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Évènement majeur (optionnel)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _eventController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ex : entretien, dispute, bonne nouvelle...',
              ),
            ),
            const SizedBox(height: 24),
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
