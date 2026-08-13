import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/daylio_import_service.dart';
import '../services/notification_service.dart';
import 'crisis_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TimeOfDay? _time;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.getReminderTime().then((t) {
      setState(() => _time = t);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) {
      await NotificationService.instance.setReminderTime(picked);
      setState(() => _time = picked);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heure du rappel mise à jour')),
        );
      }
    }
  }

  Future<void> _importDaylio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lire le fichier')),
        );
      }
      return;
    }

    if (!mounted) return;
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Daylio'),
        content: const Text(
          'Si une entrée existe déjà pour un jour donné dans Neurostatus, '
          'que faire ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ignorer ce jour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Écraser'),
          ),
        ],
      ),
    );
    if (overwrite == null) return;

    setState(() => _importing = true);
    try {
      final content = utf8.decode(bytes);
      final importResult = await DaylioImportService().importCsv(
        content,
        overwriteExisting: overwrite,
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import terminé'),
            content: Text(
              '${importResult.imported} entrée(s) importée(s)\n'
              '${importResult.skippedExisting} jour(s) déjà existant(s) ignoré(s)\n'
              '${importResult.skippedInvalid} ligne(s) invalide(s) ignorée(s)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur pendant l\'import : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_active),
            title: const Text('Heure du rappel quotidien'),
            subtitle: Text(_time == null ? '...' : _time!.format(context)),
            onTap: _pickTime,
          ),
          const Divider(),
          ListTile(
            leading: _importing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload),
            title: const Text('Importer un export Daylio (CSV)'),
            subtitle: const Text(
              'Humeur convertie sur 1-5, activités importées comme émotions',
            ),
            onTap: _importing ? null : _importDaylio,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning_amber_rounded),
            title: const Text('Historique des crises'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CrisisHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
