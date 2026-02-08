import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/rota.dart';

class DatabaseHelper {
  static const _databaseName = 'rota_mercado_livre.db';
  static const _databaseVersion = 1;
  static const table = 'rotas';

  static const columnId = 'id';
  static const columnNomeRota = 'nomeRota';
  static const columnDataRota = 'dataRota';
  static const columnPlacaCarro = 'placaCarro';
  static const columnQuantidadePacotes = 'quantidadePacotes';
  static const columnPacotesVulso = 'pacotesVulso';
  static const columnTipoVeiculo = 'tipoVeiculo';
  static const columnValorCalculado = 'valorCalculado';

  static final DatabaseHelper _instance = DatabaseHelper._privateConstructor();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnNomeRota TEXT NOT NULL,
        $columnDataRota TEXT NOT NULL,
        $columnPlacaCarro TEXT NOT NULL,
        $columnQuantidadePacotes INTEGER NOT NULL,
        $columnPacotesVulso INTEGER,
        $columnTipoVeiculo TEXT NOT NULL,
        $columnValorCalculado REAL NOT NULL
      )
    ''');
  }

  Future _onOpen(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rotas_dataRota ON $table($columnDataRota)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rotas_valor ON $table($columnValorCalculado)');
  }

  // Insert
  Future<int> insertRota(Rota rota) async {
    Database db = await database;
    return await db.insert(
      table,
      rota.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Query all
  Future<List<Rota>> getAllRotas() async {
    Database db = await database;
    List<Map<String, dynamic>> maps =
        await db.query(table, orderBy: '$columnDataRota DESC');
    return List.generate(maps.length, (i) {
      return Rota.fromMap(maps[i]);
    });
  }

  // Query by id
  Future<Rota?> getRota(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Rota.fromMap(maps.first);
    }
    return null;
  }

  // Update
  Future<int> updateRota(Rota rota) async {
    Database db = await database;
    return await db.update(
      table,
      rota.toMap(),
      where: '$columnId = ?',
      whereArgs: [rota.id],
    );
  }

  // Delete
  Future<int> deleteRota(int id) async {
    Database db = await database;
    return await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Delete all
  Future<void> deleteAllRotas() async {
    Database db = await database;
    await db.delete(table);
  }

  // Get sum of values for a month
  Future<double> getSumValorByMonth(int year, int month) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery(
      'SELECT SUM($columnValorCalculado) as total FROM $table '
      'WHERE substr($columnDataRota,1,4) = ? AND substr($columnDataRota,6,2) = ?',
      [yearStr, monthStr],
    );
    final total = result.first['total'];
    if (total == null) return 0.0;
    if (total is int) return total.toDouble();
    if (total is double) return total;
    return double.tryParse(total.toString()) ?? 0.0;
  }

  // Get rotas for a specific month
  Future<List<Rota>> getRotasByMonth(int year, int month) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final maps = await db.query(
      table,
      where:
          'substr($columnDataRota,1,4) = ? AND substr($columnDataRota,6,2) = ?',
      whereArgs: [yearStr, monthStr],
      orderBy: '$columnDataRota DESC',
    );
    return List.generate(maps.length, (i) => Rota.fromMap(maps[i]));
  }

  // Get rotas for a specific date range
  Future<List<Rota>> getRotasByDateRange(DateTime startDate, DateTime endDate) async {
    Database db = await database;
    final startIso = startDate.toIso8601String();
    final endIso = endDate.toIso8601String();
    final maps = await db.query(
      table,
      where: '$columnDataRota BETWEEN ? AND ?',
      whereArgs: [startIso, endIso],
      orderBy: '$columnDataRota DESC',
    );
    return List.generate(maps.length, (i) => Rota.fromMap(maps[i]));
  }
}
