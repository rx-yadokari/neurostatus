import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/cog_sync_service.dart';

class CogSyncScreen extends StatefulWidget {
  const CogSyncScreen({super.key});

  @override
  State<CogSyncScreen> createState() => _CogSyncScreenState();
}

class _CogSyncScreenState extends State<CogSyncScreen> {
  final _tokenController = TextEditingController();
  bool _loading = true;
  bool _enabled = false;
  bool _hasToken = false;
  bool _syncing = false;
  DateTime? _lastSync;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = CogSyncService.instance;
    final token = await service.getToken();
    final enabled = await service.isEnabled();
    final lastSync = await service.lastSyncAt();
    final lastError = await service.lastError();
    setState(() {
      _hasToken = token != null && token.isNotEmpty;
      _enabled = enabled;
      _lastSync = lastSync;
      _lastError = lastError;
      _loading = false;
    });
  }

  Future<void> _saveToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    await CogSyncService.instance.setToken(token);
    _tokenController.clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Token enregistré')));
    }
    await _load();
  }

  Future<void> _clearToken() async {
    await CogSyncService.instance.setToken(null);
    await CogSyncService.instance.setEnabled(false);
    await _load();
  }

  Future<void> _toggleEnabled(bool value) async {
    await CogSyncService.instance.setEnabled(value);
    setState(() => _enabled = value);
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await CogSyncService.instance.syncNow();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Synchronisation réussie')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec de la synchro : $e')));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synchro COG')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Envoie un résumé de ton historique (humeur, émotions, '
                    'crises) vers ton repo GitHub privé rx-yadokari/second-brain, '
                    'dans 02-personal/neurostatus-suivi.md.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_hasToken)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.key, color: Colors.green),
                      title: const Text('Token configuré'),
                      trailing: TextButton(
                        onPressed: _clearToken,
                        child: const Text('Retirer'),
                      ),
                    )
                  else ...[
                    TextField(
                      controller: _tokenController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Token GitHub (fine-grained)',
                        border: OutlineInputBorder(),
                        hintText: 'github_pat_...',
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _saveToken,
                      child: const Text('Enregistrer le token'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Synchroniser automatiquement'),
                    subtitle: const Text(
                      'À chaque sauvegarde d\'une entrée ou d\'une crise',
                    ),
                    value: _enabled,
                    onChanged: _hasToken ? _toggleEnabled : null,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: (_hasToken && !_syncing) ? _syncNow : null,
                    icon: _syncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      _syncing ? 'Synchronisation...' : 'Synchroniser maintenant',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lastSync == null
                        ? 'Jamais synchronisé'
                        : 'Dernière synchro : '
                              '${DateFormat('d MMM yyyy · HH:mm', 'fr_FR').format(_lastSync!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dernière erreur : $_lastError',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
