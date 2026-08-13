import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../models/entry.dart';
import '../services/export_service.dart';
import 'entry_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MoodEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await AppDatabase.instance.allEntries();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exporter',
            onPressed: _entries.isEmpty
                ? null
                : () => ExportService.exportAndShare(_entries),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('Aucune entrée pour le moment'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return ListTile(
                        leading: CircleAvatar(child: Text(entry.mood.toString())),
                        title: Text(
                          DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(entry.date),
                        ),
                        subtitle: Text(
                          entry.emotions.isEmpty
                              ? (entry.event ?? '')
                              : entry.emotions.join(', '),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EntryScreen(date: entry.date),
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
