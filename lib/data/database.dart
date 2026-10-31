import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/crisis_log.dart';
import '../models/entry.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'neurostatus.db');
    return openDatabase(
      path,
      version: 7,
      onCreate: (db, version) async {
        await _createEntriesTable(db);
        await _createCrisisTable(db);
        await _createContactNotesTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Mood scale changed from 0-10 to 1-5; rescale existing entries
          // proportionally instead of losing their history.
          final rows = await db.query('entries', columns: ['id', 'mood']);
          for (final row in rows) {
            final oldMood = row['mood'] as int;
            final newMood = ((oldMood * 0.4).round() + 1).clamp(1, 5);
            await db.update(
              'entries',
              {'mood': newMood},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        if (oldVersion < 3) {
          await _createCrisisTable(db);
        }
        if (oldVersion < 4) {
          // "Stress" merged into "Anxiété" as a single emotion.
          await _renameEmotion(db, 'entries', 'Stress', 'Anxiété');
          await _renameEmotion(db, 'crisis_logs', 'Stress', 'Anxiété');
        }
        if (oldVersion < 5) {
          await db.execute(
            "ALTER TABLE entries ADD COLUMN contacts TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 6) {
          await _createContactNotesTable(db);
        }
        if (oldVersion < 7) {
          // Entries move from "one per day" (UNIQUE date) to "as many as
          // you want per day", now keyed by a full timestamp instead of a
          // bare date. created_at (the real moment it was saved) becomes
          // the migrated timestamp — more honest than a fabricated noon.
          await db.execute('ALTER TABLE entries RENAME TO entries_v6');
          // The old index stays bound to entries_v6 under its original
          // name; drop it so the new entries table can reuse the name.
          await db.execute('DROP INDEX IF EXISTS idx_entries_date');
          await _createEntriesTable(db);
          await db.execute('''
            INSERT INTO entries
              (id, timestamp, date, mood, emotions, contacts, event, created_at)
            SELECT id, created_at, date, mood, emotions, contacts, event, created_at
            FROM entries_v6
          ''');
          await db.execute('DROP TABLE entries_v6');
        }
      },
    );
  }

  Future<void> _createEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        date TEXT NOT NULL,
        mood INTEGER NOT NULL,
        emotions TEXT NOT NULL,
        contacts TEXT NOT NULL DEFAULT '[]',
        event TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_entries_date ON entries(date)');
    await db.execute(
      'CREATE INDEX idx_entries_timestamp ON entries(timestamp)',
    );
  }

  Future<void> _renameEmotion(
    Database db,
    String table,
    String from,
    String to,
  ) async {
    final rows = await db.query(table, columns: ['id', 'emotions']);
    for (final row in rows) {
      final emotions = (jsonDecode(row['emotions'] as String) as List)
          .cast<String>();
      if (!emotions.contains(from)) continue;
      final renamed = <String>[];
      for (final e in emotions) {
        final mapped = e == from ? to : e;
        if (!renamed.contains(mapped)) renamed.add(mapped);
      }
      await db.update(
        table,
        {'emotions': jsonEncode(renamed)},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _createCrisisTable(Database db) async {
    await db.execute('''
      CREATE TABLE crisis_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        intensity INTEGER NOT NULL,
        duration_minutes INTEGER,
        trigger TEXT,
        emotions TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_crisis_logs_timestamp ON crisis_logs(timestamp)',
    );
  }

  Future<void> _createContactNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE contact_notes (
        name TEXT PRIMARY KEY,
        notes TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<String?> contactNotes(String name) async {
    final db = await database;
    final rows = await db.query(
      'contact_notes',
      columns: ['notes'],
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['notes'] as String?;
  }

  Future<void> setContactNotes(String name, String notes) async {
    final db = await database;
    if (notes.trim().isEmpty) {
      await db.delete('contact_notes', where: 'name = ?', whereArgs: [name]);
      return;
    }
    await db.insert('contact_notes', {
      'name': name,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Inserts a new entry, or updates it in place when [entry.id] is set
  /// (editing an existing entry rather than adding another one for the day).
  Future<int> saveEntry(MoodEntry entry) async {
    final db = await database;
    if (entry.id == null) {
      return db.insert('entries', entry.toMap()..remove('id'));
    }
    await db.update(
      'entries',
      entry.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    return entry.id!;
  }

  /// All entries for a given calendar day, oldest first — several may exist
  /// (e.g. a morning and an evening check-in).
  Future<List<MoodEntry>> entriesForDate(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: 'date = ?',
      whereArgs: [MoodEntry.dateKey(date)],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<List<MoodEntry>> allEntries({bool descending = true}) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      orderBy: 'timestamp ${descending ? 'DESC' : 'ASC'}',
    );
    return rows.map(MoodEntry.fromMap).toList();
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertCrisisLog(CrisisLog log) async {
    final db = await database;
    await db.insert('crisis_logs', log.toMap()..remove('id'));
  }

  Future<List<CrisisLog>> allCrisisLogs({bool descending = true}) async {
    final db = await database;
    final rows = await db.query(
      'crisis_logs',
      orderBy: 'timestamp ${descending ? 'DESC' : 'ASC'}',
    );
    return rows.map(CrisisLog.fromMap).toList();
  }

  Future<int> crisisLogCountSince(DateTime since) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM crisis_logs WHERE timestamp >= ?',
      [since.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteCrisisLog(int id) async {
    final db = await database;
    await db.delete('crisis_logs', where: 'id = ?', whereArgs: [id]);
  }
}
