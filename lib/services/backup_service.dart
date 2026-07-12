import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database.dart';

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
}

/// Backup and restore of the whole river as a single SQLite file.
class BackupService {
  Future<String> _dbPath() async => join(await getDatabasesPath(), 'river.db');

  /// Copies the database to a timestamped file and opens the share sheet
  /// so the user can send it anywhere (Drive, mail, another device...).
  Future<void> export() async {
    final source = File(await _dbPath());
    if (!await source.exists()) {
      throw BackupException('Nothing to back up yet.');
    }

    // Close so the copy is one consistent file with no pending journal.
    await RiverDatabase.instance.close();

    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final copy =
        await source.copy(join(dir.path, 'chronoflow_backup_$stamp.db'));

    await SharePlus.instance.share(ShareParams(
      files: [XFile(copy.path, mimeType: 'application/octet-stream')],
      subject: 'ChronoFlow backup $stamp',
    ));
  }

  /// Replaces the current database with a user-picked backup file.
  /// Returns false if the user cancelled the picker.
  Future<bool> restore() async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null) return false;

    final file = File(path);
    final header = await file.openRead(0, 16).first;
    if (!String.fromCharCodes(header).startsWith('SQLite format 3')) {
      throw BackupException("That file isn't a ChronoFlow backup.");
    }

    final dbPath = await _dbPath();
    await RiverDatabase.instance.close();

    // Keep the current river until the new one is safely in place.
    final current = File(dbPath);
    final safety =
        await current.exists() ? await current.copy('$dbPath.pre_restore') : null;

    try {
      await file.copy(dbPath);
      // Stale journals from the old database would corrupt the restored one.
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final leftover = File('$dbPath$suffix');
        if (await leftover.exists()) await leftover.delete();
      }
      await RiverDatabase.instance.database; // reopen + run migrations
      return true;
    } catch (_) {
      if (safety != null) await safety.copy(dbPath);
      await RiverDatabase.instance.database;
      throw BackupException('Restore failed — your river is unchanged.');
    }
  }
}
