import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';

class _ExistingFile {
  final String sha;
  final DateTime? createdAt;

  _ExistingFile({required this.sha, this.createdAt});
}

/// Pushes a compact markdown summary (recent history + monthly averages) of
/// the local Neurostatus data to a file in a private GitHub repo (the COG
/// second-brain vault), via GitHub's Contents API — no git client needed on
/// the device. Best-effort: never throws out of [syncIfEnabled].
class CogSyncService {
  CogSyncService._();
  static final CogSyncService instance = CogSyncService._();

  static const _owner = 'rx-yadokari';
  static const _repo = 'second-brain';
  static const _path = '02-personal/neurostatus-suivi.md';
  static const _branch = 'main';

  static const _tokenKey = 'cog_github_token';
  static const _enabledKey = 'cog_sync_enabled';
  static const _lastSyncKey = 'cog_last_sync';
  static const _lastErrorKey = 'cog_last_error';

  final _secureStorage = const FlutterSecureStorage();

  Future<String?> getToken() => _secureStorage.read(key: _tokenKey);

  Future<void> setToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      await _secureStorage.delete(key: _tokenKey);
    } else {
      await _secureStorage.write(key: _tokenKey, value: token.trim());
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<DateTime?> lastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSyncKey);
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<String?> lastError() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastErrorKey);
  }

  Future<void> _recordResult({String? error}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    if (error == null) {
      await prefs.remove(_lastErrorKey);
    } else {
      await prefs.setString(_lastErrorKey, error);
    }
  }

  /// Called after saving an entry or crisis log. Silently does nothing if
  /// sync isn't enabled/configured, and never throws — a failed background
  /// sync must not interrupt the save flow. Check [lastError] to surface
  /// failures in Settings instead.
  Future<void> syncIfEnabled() async {
    try {
      if (!await isEnabled()) return;
      final token = await getToken();
      if (token == null || token.isEmpty) return;
      await syncNow(token: token);
    } catch (_) {
      // Recorded via _recordResult inside syncNow; swallow here so the
      // caller (a save action) never sees a sync failure.
    }
  }

  /// Explicit sync, e.g. from a "Sync now" button. Throws on failure so the
  /// caller can show the error.
  Future<void> syncNow({String? token}) async {
    final effectiveToken = token ?? await getToken();
    if (effectiveToken == null || effectiveToken.isEmpty) {
      throw StateError('Aucun token GitHub configuré.');
    }
    try {
      final existing = await _fetchExisting(effectiveToken);
      final content = await _buildMarkdown(
        createdAt: existing?.createdAt ?? DateTime.now(),
      );
      await _putFile(
        token: effectiveToken,
        content: content,
        sha: existing?.sha,
      );
      await _recordResult();
    } catch (e) {
      await _recordResult(error: e.toString());
      rethrow;
    }
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'Content-Type': 'application/json',
  };

  Future<_ExistingFile?> _fetchExisting(String token) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_owner/$_repo/contents/$_path?ref=$_branch',
    );
    final response = await http.get(uri, headers: _headers(token));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception(
        'Lecture GitHub échouée (${response.statusCode}): ${response.body}',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final sha = json['sha'] as String;
    final contentB64 = (json['content'] as String).replaceAll('\n', '');
    final content = utf8.decode(base64.decode(contentB64));
    final match = RegExp(r'created:\s*"([^"]+)"').firstMatch(content);
    final createdAt = match != null ? DateTime.tryParse(match.group(1)!) : null;
    return _ExistingFile(sha: sha, createdAt: createdAt);
  }

  Future<void> _putFile({
    required String token,
    required String content,
    String? sha,
  }) async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_owner/$_repo/contents/$_path',
    );
    final body = {
      'message':
          'Neurostatus sync — ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      'content': base64.encode(utf8.encode(content)),
      'branch': _branch,
      // ignore: use_null_aware_elements
      if (sha != null) 'sha': sha,
    };
    final response = await http.put(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Écriture GitHub échouée (${response.statusCode}): ${response.body}',
      );
    }
  }

  String _cell(String? s) {
    final v = (s ?? '').replaceAll('|', r'\|').replaceAll('\n', ' ').trim();
    return v.isEmpty ? '—' : v;
  }

  Future<String> _buildMarkdown({required DateTime createdAt}) async {
    final entries = await AppDatabase.instance.allEntries(descending: false);
    final crises = await AppDatabase.instance.allCrisisLogs(descending: false);
    final now = DateTime.now();

    final recentSince = now.subtract(const Duration(days: 30));
    final crisisSince = now.subtract(const Duration(days: 90));

    final recentEntries = entries
        .where((e) => !e.date.isBefore(recentSince))
        .toList();
    final recentCrises = crises
        .where((c) => !c.timestamp.isBefore(crisisSince))
        .toList();

    final monthly = <String, List<int>>{};
    for (final e in entries) {
      final key = DateFormat('yyyy-MM').format(e.date);
      monthly.putIfAbsent(key, () => []).add(e.mood);
    }
    final monthKeys = monthly.keys.toList()..sort();

    final avg30 = recentEntries.isEmpty
        ? null
        : recentEntries.map((e) => e.mood).reduce((a, b) => a + b) /
              recentEntries.length;
    final fatigueEntries = recentEntries
        .where((e) => e.fatigue != null)
        .toList();
    final avgFatigue30 = fatigueEntries.isEmpty
        ? null
        : fatigueEntries.map((e) => e.fatigue!).reduce((a, b) => a + b) /
              fatigueEntries.length;

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('type: "tracked-data"');
    buffer.writeln('thread: "neurostatus"');
    buffer.writeln('status: "ongoing"');
    buffer.writeln(
      'created: "${DateFormat('yyyy-MM-dd HH:mm').format(createdAt)}"',
    );
    buffer.writeln('updated: "${DateFormat('yyyy-MM-dd HH:mm').format(now)}"');
    buffer.writeln('tags: ["#personal", "#sante", "#neurostatus", "#auto-sync"]');
    buffer.writeln('---');
    buffer.writeln();
    buffer.writeln('# Neurostatus — suivi humeur (auto-sync)');
    buffer.writeln();
    buffer.writeln(
      '> Généré automatiquement par l\'app Neurostatus à chaque sauvegarde. '
      'Ne pas éditer à la main (écrasé au prochain sync). '
      'Voir [[sante-burnout]] pour le récit des épisodes.',
    );
    buffer.writeln();
    buffer.writeln('## Résumé');
    buffer.writeln();
    if (entries.isEmpty) {
      buffer.writeln('- Aucune entrée enregistrée pour le moment.');
    } else {
      buffer.writeln(
        '- Période suivie : ${entries.first.dateStr} → '
        '${entries.last.dateStr} (${entries.length} saisie(s) au total)',
      );
    }
    if (avg30 != null) {
      buffer.writeln(
        '- Humeur moyenne (30 derniers jours) : '
        '${avg30.toStringAsFixed(1)}/5 sur ${recentEntries.length} saisie(s)',
      );
    }
    if (avgFatigue30 != null) {
      buffer.writeln(
        '- Fatigue moyenne (30 derniers jours) : '
        '${avgFatigue30.toStringAsFixed(1)}/5 sur ${fatigueEntries.length} '
        'saisie(s)',
      );
    }
    buffer.writeln(
      '- Crises signalées (90 derniers jours) : ${recentCrises.length}',
    );
    buffer.writeln();
    buffer.writeln('## Historique récent (30 derniers jours)');
    buffer.writeln();
    if (recentEntries.isEmpty) {
      buffer.writeln('_Aucune entrée sur cette période._');
    } else {
      buffer.writeln(
        '| Date et heure | Humeur | Fatigue | Émotions | Contacts | '
        'Évènement |',
      );
      buffer.writeln('|---|---|---|---|---|---|');
      for (final e in recentEntries.reversed) {
        final fatigue = e.fatigue == null ? '—' : '${e.fatigue}/5';
        buffer.writeln(
          '| ${DateFormat('yyyy-MM-dd HH:mm').format(e.timestamp)} | '
          '${e.mood}/5 | $fatigue | ${_cell(e.emotions.join(', '))} | '
          '${_cell(e.contacts.join(', '))} | ${_cell(e.event)} |',
        );
      }
    }
    buffer.writeln();
    buffer.writeln('## Crises récentes (90 derniers jours)');
    buffer.writeln();
    if (recentCrises.isEmpty) {
      buffer.writeln('_Aucune crise signalée sur cette période._');
    } else {
      buffer.writeln('| Date | Intensité | Durée | Déclencheur | Émotions |');
      buffer.writeln('|---|---|---|---|---|');
      for (final c in recentCrises.reversed) {
        final duration = c.durationMinutes != null
            ? '${c.durationMinutes} min'
            : '—';
        buffer.writeln(
          '| ${DateFormat('yyyy-MM-dd HH:mm').format(c.timestamp)} | '
          '${c.intensity}/5 | $duration | ${_cell(c.trigger)} | '
          '${_cell(c.emotions.join(', '))} |',
        );
      }
    }
    buffer.writeln();
    buffer.writeln('## Moyennes mensuelles');
    buffer.writeln();
    if (monthKeys.isEmpty) {
      buffer.writeln('_Pas encore de données._');
    } else {
      buffer.writeln('| Mois | Humeur moyenne | Jours suivis |');
      buffer.writeln('|---|---|---|');
      for (final key in monthKeys.reversed) {
        final moods = monthly[key]!;
        final avg = moods.reduce((a, b) => a + b) / moods.length;
        buffer.writeln('| $key | ${avg.toStringAsFixed(1)}/5 | ${moods.length} |');
      }
    }
    return buffer.toString();
  }
}
