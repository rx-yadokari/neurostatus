import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/contacts_repository.dart';
import '../data/database.dart';
import '../data/emotion_icons.dart';
import '../data/emotions_repository.dart';
import '../data/mood_colors.dart';
import '../models/entry.dart';
import '../services/cog_sync_service.dart';
import '../services/pattern_alert_service.dart';
import 'crisis_log_sheet.dart';
import 'entry_calendar_picker_screen.dart';

class EntryScreen extends StatefulWidget {
  /// Edit an existing entry (opened from History). When null, a brand new
  /// entry is created on save instead.
  final MoodEntry? existingEntry;

  /// Starting instant for a new entry. Ignored when [existingEntry] is set.
  /// Defaults to now.
  final DateTime? initialTimestamp;

  final VoidCallback? onSaved;

  const EntryScreen({
    super.key,
    this.existingEntry,
    this.initialTimestamp,
    this.onSaved,
  });

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  int? _entryId;
  late DateTime _timestamp;
  double _mood = 3;
  double _fatigue = 3;
  final Set<String> _selectedEmotions = {};
  final Set<String> _selectedContacts = {};
  final _eventController = TextEditingController();
  List<String> _availableEmotions = [];
  List<String> _availableContacts = [];
  List<MoodEntry> _otherEntriesSameDay = [];
  bool _loading = true;
  bool _saving = false;
  String? _patternAlert;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEntry;
    _entryId = existing?.id;
    _timestamp =
        existing?.timestamp ?? widget.initialTimestamp ?? DateTime.now();
    if (existing != null) {
      _mood = existing.mood.toDouble();
      _fatigue = (existing.fatigue ?? 3).toDouble();
      _selectedEmotions.addAll(existing.emotions);
      _selectedContacts.addAll(existing.contacts);
      _eventController.text = existing.event ?? '';
    }
    _load();
  }

  Future<void> _load() async {
    final emotions = await EmotionsRepository.instance.allEmotions();
    final contacts = await ContactsRepository.instance.allContacts();
    final alert = await PatternAlertService().checkForConcerningPattern();
    setState(() {
      _availableEmotions = emotions;
      _availableContacts = contacts;
      _patternAlert = alert;
      _loading = false;
    });
    await _refreshOtherEntries();
  }

  Future<void> _refreshOtherEntries() async {
    final dayEntries = await AppDatabase.instance.entriesForDate(_timestamp);
    if (!mounted) return;
    setState(() {
      _otherEntriesSameDay = dayEntries
          .where((e) => e.id != _entryId)
          .toList();
    });
  }

  Future<void> _pickTimestamp() async {
    final pickedDate = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryCalendarPickerScreen(initialDate: _timestamp),
      ),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_timestamp),
    );
    if (pickedTime == null) return;
    setState(() {
      _timestamp = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
    await _refreshOtherEntries();
  }

  Future<void> _openOtherEntry(MoodEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EntryScreen(existingEntry: entry)),
    );
    await _refreshOtherEntries();
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

  Future<void> _addCustomContact() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau contact'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex : Alice, Famille'),
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
      await ContactsRepository.instance.addContact(result);
      final contacts = await ContactsRepository.instance.allContacts();
      setState(() {
        _availableContacts = contacts;
        _selectedContacts.add(result.trim());
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final entry = MoodEntry(
      id: _entryId,
      timestamp: _timestamp,
      mood: _mood.round(),
      fatigue: _fatigue.round(),
      emotions: _selectedEmotions.toList(),
      contacts: _selectedContacts.toList(),
      event: _eventController.text.trim().isEmpty
          ? null
          : _eventController.text.trim(),
      createdAt: widget.existingEntry?.createdAt ?? DateTime.now(),
    );
    final savedId = await AppDatabase.instance.saveEntry(entry);
    _entryId = savedId;
    unawaited(CogSyncService.instance.syncIfEnabled());
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
    final dateLabel = DateFormat(
      'EEEE d MMMM yyyy · HH:mm',
      'fr_FR',
    ).format(_timestamp);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dateLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_outlined),
            tooltip: 'Choisir une autre date/heure',
            onPressed: _pickTimestamp,
          ),
          IconButton(
            icon: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: 'Signaler une crise',
            onPressed: () async {
              final saved = await showCrisisLogSheet(
                context,
                initialDate: _timestamp,
              );
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
            if (_otherEntriesSameDay.isNotEmpty) ...[
              Text(
                'Autres saisies ce jour-là',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in _otherEntriesSameDay)
                    ActionChip(
                      avatar: CircleAvatar(
                        backgroundColor: MoodColors.colorFor(e.mood),
                        child: Text(
                          '${e.mood}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      label: Text(DateFormat('HH:mm').format(e.timestamp)),
                      onPressed: () => _openOtherEntry(e),
                    ),
                ],
              ),
              const SizedBox(height: 24),
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
              'Fatigue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _fatigue,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _fatigue.round().toString(),
                    onChanged: (v) => setState(() => _fatigue = v),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    _fatigue.round().toString(),
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
                    avatar: Text(EmotionIcons.iconFor(emotion)),
                    showCheckmark: false,
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
              'Contacts sociaux (optionnel)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final contact in _availableContacts)
                  FilterChip(
                    label: Text(contact),
                    selected: _selectedContacts.contains(contact),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedContacts.add(contact);
                        } else {
                          _selectedContacts.remove(contact);
                        }
                      });
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  onPressed: _addCustomContact,
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
