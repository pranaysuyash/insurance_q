import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Hive-backed cache for document thumbnail bytes.
///
/// Thumbnails are stored as base64-encoded byte strings keyed by file path.
/// The cache has a maximum entry count to prevent unbounded storage growth.
class DocumentThumbnailCache {
  static const _maxEntries = 100;
  static const _boxName = 'thumbnail_cache';

  Box? _box;

  Future<Box> _getBox() async {
    _box ??= await Hive.openBox(_boxName);
    return _box!;
  }

  /// Retrieve cached thumbnail bytes for a file path, or null.
  Future<Uint8List?> get(String filePath) async {
    try {
      final box = await _getBox();
      final raw = box.get(_key(filePath)) as String?;
      if (raw == null) return null;
      return base64Decode(raw);
    } catch (e) {
      debugPrint('Thumbnail cache read failed: $e');
      return null;
    }
  }

  /// Store thumbnail bytes for a file path.
  Future<void> set(String filePath, Uint8List bytes) async {
    try {
      final box = await _getBox();
      if (box.length >= _maxEntries) {
        // Evict oldest entry
        final first = box.keys.first;
        await box.delete(first);
      }
      await box.put(_key(filePath), base64Encode(bytes));
    } catch (e) {
      debugPrint('Thumbnail cache write failed: $e');
    }
  }

  /// Remove a cached thumbnail.
  Future<void> remove(String filePath) async {
    try {
      final box = await _getBox();
      await box.delete(_key(filePath));
    } catch (e) {
      debugPrint('Thumbnail cache delete failed: $e');
    }
  }

  String _key(String path) => 'thumb:${path.hashCode}';
}
