import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

/// Service managing SQLite local database for mobile apps (Customer & Employee portals).
/// On Web platforms (Admin Website), it gracefully operates in-memory / dummy mode.
class LocalDatabaseService {
  LocalDatabaseService._internal();
  static final LocalDatabaseService instance = LocalDatabaseService._internal();

  @visibleForTesting
  static String dbName = 'sari_sari_v2.db';

  sqflite.Database? _db;
  bool _isInitializing = false;

  @visibleForTesting
  Future<void> closeForTesting() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  /// Initializes SQLite database and creates the 7 local tables
  Future<sqflite.Database?> get database async {
    if (kIsWeb) return null; // SQLite is not used on Web
    if (_db != null && _db!.isOpen) return _db;
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _db;
    }

    _isInitializing = true;
    try {
      final dbPath = await sqflite.getDatabasesPath();
      final path = p.join(dbPath, dbName);

      _db = await sqflite.openDatabase(
        path,
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Migration v1 -> v2: Add idempotency_key column to sync_queue
            await db.execute('ALTER TABLE sync_queue ADD COLUMN idempotency_key TEXT;');
          }
        },
        onCreate: (db, version) async {
          // 1. Products Table
          await db.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              barcode TEXT,
              description TEXT,
              price REAL,
              cost REAL,
              quantity REAL,
              unit TEXT,
              category_id TEXT,
              image TEXT,
              expiration_date TEXT,
              low_stock_threshold REAL,
              is_active INTEGER DEFAULT 1,
              updated_at TEXT
            )
          ''');

          // 2. Categories Table
          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              icon_name TEXT,
              updated_at TEXT
            )
          ''');

          // 3. Orders Table
          await db.execute('''
            CREATE TABLE orders (
              order_id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              customer_name TEXT,
              order_date TEXT,
              order_type TEXT,
              payment_method TEXT,
              payment_status TEXT,
              subtotal REAL,
              delivery_fee REAL,
              total_amount REAL,
              status TEXT,
              delivery_address TEXT,
              cancellation_reason TEXT,
              updated_at TEXT
            )
          ''');

          // 4. Order Items Table
          await db.execute('''
            CREATE TABLE order_items (
              id TEXT PRIMARY KEY,
              order_id TEXT NOT NULL,
              product_id TEXT,
              product_name TEXT,
              price REAL,
              capital REAL,
              quantity INTEGER,
              subtotal REAL,
              FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE
            )
          ''');

          // 5. User Profile Table
          await db.execute('''
            CREATE TABLE user_profile (
              user_id TEXT PRIMARY KEY,
              first_name TEXT,
              middle_initial TEXT,
              last_name TEXT,
              email TEXT,
              contact_number TEXT,
              photo_path TEXT,
              role TEXT,
              updated_at TEXT
            )
          ''');

          // 6. Cart Items Table
          await db.execute('''
            CREATE TABLE cart_items (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              product_id TEXT,
              product_name TEXT,
              unit_price REAL,
              quantity INTEGER,
              is_deal INTEGER DEFAULT 0,
              deal_title TEXT,
              subtotal REAL
            )
          ''');

          // 7. Sync Queue Table
          await db.execute('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL,
              action TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT DEFAULT 'pending',
              retry_count INTEGER DEFAULT 0,
              created_at TEXT
            )
          ''');
        },
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error opening SQLite database: $e');
    } finally {
      _isInitializing = false;
    }
    return _db;
  }

  // ==================== GENERIC CRUD METHODS ====================

  Future<int> insert(String table, Map<String, dynamic> row) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    return await db.insert(table, row, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table, {String? userId, String? orderBy}) async {
    if (kIsWeb) return [];
    final db = await database;
    if (db == null) return [];
    if (userId != null && userId.isNotEmpty) {
      return await db.query(table, where: 'user_id = ?', whereArgs: [userId], orderBy: orderBy);
    }
    return await db.query(table, orderBy: orderBy);
  }

  Future<int> delete(String table, String whereClause, List<dynamic> whereArgs) async {
    if (kIsWeb) return 0;
    final db = await database;
    if (db == null) return 0;
    return await db.delete(table, where: whereClause, whereArgs: whereArgs);
  }

  Future<int> clearUserTables(String userId) async {
    if (kIsWeb || userId.isEmpty) return 0;
    final db = await database;
    if (db == null) return 0;
    int count = 0;
    count += await db.delete('order_items', where: 'order_id IN (SELECT order_id FROM orders WHERE user_id = ?)', whereArgs: [userId]);
    count += await db.delete('orders', where: 'user_id = ?', whereArgs: [userId]);
    count += await db.delete('user_profile', where: 'user_id = ?', whereArgs: [userId]);
    count += await db.delete('cart_items', where: 'user_id = ?', whereArgs: [userId]);
    count += await db.delete('sync_queue', where: 'user_id = ?', whereArgs: [userId]);
    return count;
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  // ==================== SYNC QUEUE HELPER METHODS ====================

  Future<void> queueOfflineAction({
    required String userId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) return;
    final uuid = _generateUuidV4();
    final row = {
      'id': uuid,
      'user_id': userId,
      'action': action,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    await insert('sync_queue', row);
  }

  Future<List<Map<String, dynamic>>> getPendingSyncActions(String userId) async {
    if (kIsWeb) return [];
    final db = await database;
    if (db == null) return [];
    return await db.query(
      'sync_queue',
      where: 'user_id = ? AND status = ? AND retry_count < 3',
      whereArgs: [userId, 'pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> markSyncActionCompleted(String syncId) async {
    if (kIsWeb) return;
    await delete('sync_queue', 'id = ?', [syncId]);
  }

  Future<void> incrementSyncRetry(String syncId, int currentRetry) async {
    if (kIsWeb) return;
    final db = await database;
    if (db == null) return;
    await db.update(
      'sync_queue',
      {'retry_count': currentRetry + 1, 'status': currentRetry + 1 >= 3 ? 'failed' : 'pending'},
      where: 'id = ?',
      whereArgs: [syncId],
    );
  }
}
