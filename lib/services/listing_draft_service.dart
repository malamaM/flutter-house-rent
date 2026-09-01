import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class ListingDraftService {
  ListingDraftService._();
  static final instance = ListingDraftService._();
  static const _prefix = 'listing_draft_v1:';

  Future<Map<String, dynamic>?> load(String id) async {
    final raw =
        (await SharedPreferences.getInstance()).getString('$_prefix$id');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String id, Map<String, dynamic> value) async {
    await (await SharedPreferences.getInstance()).setString(
      '$_prefix$id',
      jsonEncode({...value, 'saved_at': DateTime.now().toIso8601String()}),
    );
  }

  Future<File> retainMedia(String id, String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return source;
    final directory = Directory(
        path.join(await getDatabasesPath(), 'listing_drafts', _safe(id)));
    await directory.create(recursive: true);
    final extension = path.extension(sourcePath);
    final target = File(path.join(
        directory.path, '${DateTime.now().microsecondsSinceEpoch}$extension'));
    return source.copy(target.path);
  }

  Future<void> clear(String id) async {
    await (await SharedPreferences.getInstance()).remove('$_prefix$id');
    final directory = Directory(
        path.join(await getDatabasesPath(), 'listing_drafts', _safe(id)));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    final draftKeys = preferences
        .getKeys()
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false);
    await Future.wait(draftKeys.map(preferences.remove));

    final directory =
        Directory(path.join(await getDatabasesPath(), 'listing_drafts'));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  String _safe(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}
