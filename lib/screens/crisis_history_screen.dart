import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../models/crisis_log.dart';

class CrisisHistoryScreen extends StatefulWidget {
  const CrisisHistoryScreen({super.key});

  @override
  State<CrisisHistoryScreen> createState() => _CrisisHistoryScreenState();
}

class _CrisisHistoryScreenState extends State<CrisisHistoryScreen> {
  List<CrisisLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final logs = await AppDatabase.instance.allCrisisLogs();
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _delete(CrisisLog log) async {
    await AppDatabase.instance.deleteCrisisLog(log.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des crises')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(child: Text('Aucune crise signalée'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _logs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final subtitleParts = <String>[
                    if (log.durationMinutes != null)
                      '${log.durationMinutes} min',
                    if (log.trigger != null && log.trigger!.isNotEmpty)
                      log.trigger!,
                    if (log.emotions.isNotEmpty) log.emotions.join(', '),
                  ];
                  return Dismissible(
                    key: ValueKey(log.id),
                    background: Container(
                      color: Theme.of(context).colorScheme.errorContainer,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _delete(log),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onError,
                        child: Text('${log.intensity}'),
                      ),
                      title: Text(
                        DateFormat(
                          'EEEE d MMMM yyyy · HH:mm',
                          'fr_FR',
                        ).format(log.timestamp),
                      ),
                      subtitle: subtitleParts.isEmpty
                          ? null
                          : Text(subtitleParts.join(' · ')),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
