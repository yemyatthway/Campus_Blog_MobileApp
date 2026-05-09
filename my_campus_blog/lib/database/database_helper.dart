import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/post.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'my_campus_blog.db';
  static const _databaseVersion = 1;
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
    );
    return _database!;
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $postsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        imagePath TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
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

  Future<List<Post>> getPosts({String query = ''}) async {
    final db = await database;
    final trimmedQuery = query.trim();

    final maps = await db.query(
      postsTable,
      where: trimmedQuery.isEmpty ? null : 'title LIKE ? OR content LIKE ?',
      whereArgs: trimmedQuery.isEmpty
          ? null
          : ['%$trimmedQuery%', '%$trimmedQuery%'],
      orderBy: 'updatedAt DESC',
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
