import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/emotions_repository.dart';
import '../models/crisis_log.dart';
import '../services/cog_sync_service.dart';

const _quickEmotions = ['Peur', 'Anxiété', 'Colère', 'Désespoir'];

Future<bool> showCrisisLogSheet(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CrisisLogSheet(initialDate: initialDate),
  );
  return result ?? false;
}

class _CrisisLogSheet extends StatefulWidget {
  final DateTime? initialDate;

  const _CrisisLogSheet({this.initialDate});

  @override
  State<_CrisisLogSheet> createState() => _CrisisLogSheetState();
}

class _CrisisLogSheetState extends State<_CrisisLogSheet> {
  late DateTime _timestamp;
  double _intensity = 3;
  final _durationController = TextEditingController();
  final _triggerController = TextEditingController();
  final Set<String> _emotions = {};
  List<String> _availableEmotions = _quickEmotions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _timestamp = widget.initialDate ?? DateTime.now();
    EmotionsRepository.instance.allEmotions().then((all) {
      if (!mounted) return;
      setState(() {
        _availableEmotions = [
          for (final e in _quickEmotions) e,
          for (final e in all)
            if (!_quickEmotions.contains(e)) e,
        ];
      });
    });
  }

  Future<void> _pickTimestamp() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _timestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
  }

  @override
  void dispose() {
    _durationController.dispose();
    _triggerController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final duration = int.tryParse(_durationController.text.trim());
    await AppDatabase.instance.insertCrisisLog(
      CrisisLog(
        timestamp: _timestamp,
        intensity: _intensity.round(),
        durationMinutes: duration,
        trigger: _triggerController.text.trim().isEmpty
            ? null
            : _triggerController.text.trim(),
        emotions: _emotions.toList(),
      ),
    );
    unawaited(CogSyncService.instance.syncIfEnabled());
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Signaler une crise',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              InkWell(
                onTap: _pickTimestamp,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat(
                        'EEEE d MMMM yyyy · HH:mm',
                        'fr_FR',
                      ).format(_timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit, size: 14),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Intensité : ${_intensity.round()}/5'),
              Slider(
                value: _intensity,
                min: 1,
                max: 5,
                divisions: 4,
                label: _intensity.round().toString(),
                onChanged: (v) => setState(() => _intensity = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée estimée (minutes, optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _triggerController,
                decoration: const InputDecoration(
                  labelText: 'Déclencheur (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Émotions ressenties (optionnel)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emotion in _availableEmotions)
                    FilterChip(
                      label: Text(emotion),
                      selected: _emotions.contains(emotion),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _emotions.add(emotion);
                          } else {
                            _emotions.remove(emotion);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
