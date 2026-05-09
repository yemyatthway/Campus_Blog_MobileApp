import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config/post_options.dart';
import '../models/post.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'my_campus_blog.db';
  static const _databaseVersion = 2;
  static const postsTable = 'posts';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, _databaseName);
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
    return _database!;
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $postsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'General',
        imagePath TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE $postsTable ADD COLUMN category TEXT NOT NULL DEFAULT 'General'",
      );
    }
  }

  Future<int> insertPost(Post post) async {
    final db = await database;
    return db.insert(postsTable, post.toMap());
  }

  Future<int> updatePost(Post post) async {
    final db = await database;
    return db.update(
      postsTable,
      post.toMap(),
      where: 'id = ?',
      whereArgs: [post.id],
    );
  }

  Future<List<Post>> getPosts({
    String query = '',
    String? category,
    PostSortOption sortOption = PostSortOption.newest,
  }) async {
    final db = await database;
    final trimmedQuery = query.trim();
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (trimmedQuery.isNotEmpty) {
      whereParts.add('(title LIKE ? OR content LIKE ?)');
      whereArgs.addAll(['%$trimmedQuery%', '%$trimmedQuery%']);
    }

    if (category != null && category.isNotEmpty) {
      whereParts.add('category = ?');
      whereArgs.add(category);
    }

    final maps = await db.query(
      postsTable,
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: sortOption.orderBy,
    );

    return maps.map(Post.fromMap).toList();
  }

  Future<Post?> getPost(int id) async {
    final db = await database;
    final maps = await db.query(
      postsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }
    return Post.fromMap(maps.first);
  }

  Future<int> deletePost(int id) async {
    final db = await database;
    return db.delete(postsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePosts(List<int> ids) async {
    if (ids.isEmpty) {
      return 0;
    }

    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    return db.delete(
      postsTable,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }
}
