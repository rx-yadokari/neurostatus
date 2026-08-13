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
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            mood INTEGER NOT NULL,
            emotions TEXT NOT NULL,
            event TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_entries_date ON entries(date)');
        await _createCrisisTable(db);
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
      },
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

  Future<void> upsertEntry(MoodEntry entry) async {
    final db = await database;
    await db.insert(
      'entries',
      entry.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MoodEntry?> entryForDate(DateTime date) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: 'date = ?',
      whereArgs: [MoodEntry.dateKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MoodEntry.fromMap(rows.first);
  }

  Future<List<MoodEntry>> allEntries({bool descending = true}) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      orderBy: 'date ${descending ? 'DESC' : 'ASC'}',
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
