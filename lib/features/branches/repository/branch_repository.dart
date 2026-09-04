import '../../../core/database/database_helper.dart';
import '../models/branch_model.dart';

/// Repository for Branch Management CRUD operations.
class BranchRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<BranchModel>> getBranches() async {
    final db = await _dbHelper.database;
    final maps = await db.query('branches', orderBy: 'name ASC');
    return maps.map((m) => BranchModel.fromMap(m)).toList();
  }

  Future<List<BranchModel>> getActiveBranches() async {
    final db = await _dbHelper.database;
    final maps = await db.query('branches', where: 'isActive = 1', orderBy: 'name ASC');
    return maps.map((m) => BranchModel.fromMap(m)).toList();
  }

  Future<BranchModel?> getBranchById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query('branches', where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return BranchModel.fromMap(maps.first);
  }

  Future<int> insertBranch(BranchModel branch) async {
    final db = await _dbHelper.database;
    return await db.insert('branches', branch.toMap());
  }

  Future<void> updateBranch(BranchModel branch) async {
    final db = await _dbHelper.database;
    await db.update(
      'branches',
      {...branch.toMap(), 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [branch.id],
    );
  }

  Future<void> deleteBranch(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'branches',
      {'isActive': 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getBranchCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM branches WHERE isActive = 1');
    return (result.first['cnt'] as int?) ?? 0;
  }
}
