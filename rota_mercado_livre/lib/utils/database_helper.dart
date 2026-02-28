import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/rota.dart';
import '../models/despesa.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'api_service.dart';

class DatabaseHelper {
  static const _databaseName = 'rota_mercado_livre.db';
  static const _databaseVersion = 1;
  static const table = 'rotas';
  static const despesasTable = 'despesas';
  static const settingsTable = 'settings';
  static const columnSettingKey = 'key';
  static const columnSettingValue = 'value';

  static const columnId = 'id';
  static const columnNomeRota = 'nomeRota';
  static const columnDataRota = 'dataRota';
  static const columnPlacaCarro = 'placaCarro';
  static const columnQuantidadePacotes = 'quantidadePacotes';
  static const columnPacotesVulso = 'pacotesVulso';
  static const columnTipoVeiculo = 'tipoVeiculo';
  static const columnValorCalculado = 'valorCalculado';
  static const columnDespesaId = 'id';
  static const columnDespesaDescricao = 'descricao';
  static const columnDespesaData = 'dataDespesa';
  static const columnDespesaValor = 'valor';
  static const columnDespesaCategoria = 'categoria';
  // Romaneio
  static const romaneioTable = 'romaneio_itens';

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
    await db.execute('''
      CREATE TABLE $despesasTable (
        $columnDespesaId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnDespesaDescricao TEXT NOT NULL,
        $columnDespesaData TEXT NOT NULL,
        $columnDespesaValor REAL NOT NULL,
        $columnDespesaCategoria TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $settingsTable (
        $columnSettingKey TEXT PRIMARY KEY,
        $columnSettingValue TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $romaneioTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT,
        idPacote TEXT,
        cliente TEXT,
        endereco TEXT,
        numeroEndereco TEXT,
        complemento TEXT,
        bairro TEXT,
        cidade TEXT,
        cep TEXT,
        tipoEndereco TEXT,
        assinatura TEXT,
        status TEXT DEFAULT 'pendente',
        createdAt TEXT
      )
    ''');
  }

  Future _onOpen(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rotas_dataRota ON $table($columnDataRota)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_rotas_valor ON $table($columnValorCalculado)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS $despesasTable ($columnDespesaId INTEGER PRIMARY KEY AUTOINCREMENT, $columnDespesaDescricao TEXT NOT NULL, $columnDespesaData TEXT NOT NULL, $columnDespesaValor REAL NOT NULL, $columnDespesaCategoria TEXT)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_despesas_data ON $despesasTable($columnDespesaData)');
    await db.execute(
        'CREATE TABLE IF NOT EXISTS $settingsTable ($columnSettingKey TEXT PRIMARY KEY, $columnSettingValue TEXT)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $romaneioTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT,
        idPacote TEXT,
        cliente TEXT,
        endereco TEXT,
        numeroEndereco TEXT,
        complemento TEXT,
        bairro TEXT,
        cidade TEXT,
        cep TEXT,
        tipoEndereco TEXT,
        assinatura TEXT,
        status TEXT DEFAULT 'pendente',
        createdAt TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_romaneio_status ON $romaneioTable(status)');
  }

  // Insert
  Future<int> insertRota(Rota rota) async {
    Database db = await database;
    final id = await db.insert(
      table,
      rota.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    try {
      final base = await getSetting('api_base_url');
      if (base != null && base.isNotEmpty) {
        await ApiService(base).postRota(rota);
      }
    } catch (_) {}
    return id;
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

  Future<List<Despesa>> getAllDespesas() async {
    final db = await database;
    final maps = await db.query(despesasTable, orderBy: '$columnDespesaData DESC');
    return List.generate(maps.length, (i) => Despesa.fromMap(maps[i]));
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
    final count = await db.update(
      table,
      rota.toMap(),
      where: '$columnId = ?',
      whereArgs: [rota.id],
    );
    try {
      final base = await getSetting('api_base_url');
      if (base != null && base.isNotEmpty) {
        await ApiService(base).putRota(rota);
      }
    } catch (_) {}
    return count;
  }

  // Delete
  Future<int> deleteRota(int id) async {
    Database db = await database;
    final count = await db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    try {
      final base = await getSetting('api_base_url');
      if (base != null && base.isNotEmpty) {
        await ApiService(base).deleteRota(id);
      }
    } catch (_) {}
    return count;
  }

  // Delete all
  Future<void> deleteAllRotas() async {
    Database db = await database;
    await db.delete(table);
  }

  Future<void> exportAllToMongo({required String connectionString, required String databaseName}) async {
    final rotas = await getAllRotas();
    final despesas = await getAllDespesas();
    final db = await mongo.Db.create('$connectionString/$databaseName');
    await db.open();
    final rotasColl = db.collection('rotas');
    final despesasColl = db.collection('despesas');
    if (rotas.isNotEmpty) {
      await rotasColl.insertAll(rotas.map((r) {
        final m = r.toMap();
        m['dataRotaDate'] = r.dataRota;
        return m;
      }).toList());
    }
    if (despesas.isNotEmpty) {
      await despesasColl.insertAll(despesas.map((d) {
        final m = d.toMap();
        m['dataDespesaDate'] = d.dataDespesa;
        return m;
      }).toList());
    }
    await db.close();
  }

  Future<Map<String, dynamic>> exportAllToCloudflare({required String baseUrl, void Function(double, String)? onProgress}) async {
    final rotas = await getAllRotas();
    final despesas = await getAllDespesas();
    final api = ApiService(baseUrl);
    int importedRotas = 0;
    int importedDespesas = 0;
    List<List<T>> _chunks<T>(List<T> list, int size) {
      final out = <List<T>>[];
      for (var i = 0; i < list.length; i += size) {
        out.add(list.sublist(i, i + size > list.length ? list.length : i + size));
      }
      return out;
    }
    int _asInt(dynamic v, int fallback) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }
    final rotasChunks = _chunks(rotas, 200);
    final despesasChunks = _chunks(despesas, 200);
    final totalChunks = rotasChunks.length + despesasChunks.length;
    var done = 0;
    onProgress?.call(0.0, 'Iniciando');
    for (var i = 0; i < rotasChunks.length; i++) {
      final ch = rotasChunks[i];
      final res = await api.importAll(rotas: ch, despesas: const []);
      importedRotas += _asInt(res['imported']?['rotas'], ch.length);
      done++;
      onProgress?.call(done / totalChunks, 'Rotas lote ${i + 1}/${rotasChunks.length}');
    }
    for (var j = 0; j < despesasChunks.length; j++) {
      final ch = despesasChunks[j];
      final res = await api.importAll(rotas: const [], despesas: ch);
      importedDespesas += _asInt(res['imported']?['despesas'], ch.length);
      done++;
      onProgress?.call(done / totalChunks, 'Despesas lote ${j + 1}/${despesasChunks.length}');
    }
    return {
      'ok': true,
      'imported': {'rotas': importedRotas, 'despesas': importedDespesas}
    };
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

  Future<int> getCountByMonth(int year, int month) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table '
      'WHERE substr($columnDataRota,1,4) = ? AND substr($columnDataRota,6,2) = ?',
      [yearStr, monthStr],
    );
    final value = result.first['count'];
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<List<Rota>> getRecentRotasByMonth(int year, int month, {int limit = 5}) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final maps = await db.query(
      table,
      where:
          'substr($columnDataRota,1,4) = ? AND substr($columnDataRota,6,2) = ?',
      whereArgs: [yearStr, monthStr],
      orderBy: '$columnDataRota DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Rota.fromMap(maps[i]));
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
    final startIso = _formatDate(startDate);
    final endIso = _formatDate(endDate);
    final maps = await db.query(
      table,
      where: '$columnDataRota BETWEEN ? AND ?',
      whereArgs: [startIso, endIso],
      orderBy: '$columnDataRota DESC',
    );
    return List.generate(maps.length, (i) => Rota.fromMap(maps[i]));
  }

  Future<double> getSumRotasByDateRange(DateTime startDate, DateTime endDate) async {
    Database db = await database;
    final startIso = _formatDate(startDate);
    final endIso = _formatDate(endDate);
    final result = await db.rawQuery(
      'SELECT SUM($columnValorCalculado) as total FROM $table WHERE $columnDataRota BETWEEN ? AND ?',
      [startIso, endIso],
    );
    final total = result.first['total'];
    if (total == null) return 0.0;
    if (total is int) return total.toDouble();
    if (total is double) return total;
    return double.tryParse(total.toString()) ?? 0.0;
  }

  Future<int> getSumQuantidadePacotesByDateRange(DateTime startDate, DateTime endDate) async {
    Database db = await database;
    final startIso = _formatDate(startDate);
    final endIso = _formatDate(endDate);
    final result = await db.rawQuery(
      'SELECT SUM($columnQuantidadePacotes) as total FROM $table WHERE $columnDataRota BETWEEN ? AND ?',
      [startIso, endIso],
    );
    final total = result.first['total'];
    if (total == null) return 0;
    if (total is int) return total;
    return int.tryParse(total.toString()) ?? 0;
  }

  Future<int> getSumPacotesVulsoByDateRange(DateTime startDate, DateTime endDate) async {
    Database db = await database;
    final startIso = _formatDate(startDate);
    final endIso = _formatDate(endDate);
    final result = await db.rawQuery(
      'SELECT SUM($columnPacotesVulso) as total FROM $table WHERE $columnDataRota BETWEEN ? AND ?',
      [startIso, endIso],
    );
    final total = result.first['total'];
    if (total == null) return 0;
    if (total is int) return total;
    return int.tryParse(total.toString()) ?? 0;
  }

  Future<int> getSumPacotesVulsoByMonth(int year, int month) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery(
      'SELECT SUM($columnPacotesVulso) as total FROM $table '
      'WHERE substr($columnDataRota,1,4) = ? AND substr($columnDataRota,6,2) = ?',
      [yearStr, monthStr],
    );
    final total = result.first['total'];
    if (total == null) return 0;
    if (total is int) return total;
    return int.tryParse(total.toString()) ?? 0;
  }

  Future<int> insertDespesa(Despesa despesa) async {
    Database db = await database;
    final id = await db.insert(
      despesasTable,
      despesa.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    try {
      final base = await getSetting('api_base_url');
      if (base != null && base.isNotEmpty) {
        await ApiService(base).postDespesa(despesa);
      }
    } catch (_) {}
    return id;
  }

  Future<List<Despesa>> getDespesasByMonth(int year, int month) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final maps = await db.query(
      despesasTable,
      where:
          'substr($columnDespesaData,1,4) = ? AND substr($columnDespesaData,6,2) = ?',
      whereArgs: [yearStr, monthStr],
      orderBy: '$columnDespesaData DESC',
    );
    return List.generate(maps.length, (i) => Despesa.fromMap(maps[i]));
  }

  Future<double> getSumDespesasByMonth(int year, int month) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery(
      'SELECT SUM($columnDespesaValor) as total FROM $despesasTable '
      'WHERE substr($columnDespesaData,1,4) = ? AND substr($columnDespesaData,6,2) = ?',
      [yearStr, monthStr],
    );
    final total = result.first['total'];
    if (total == null) return 0.0;
    if (total is int) return total.toDouble();
    if (total is double) return total;
    return double.tryParse(total.toString()) ?? 0.0;
  }

  Future<int> getCountDespesasByMonth(int year, int month) async {
    Database db = await database;
    final yearStr = year.toString();
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $despesasTable '
      'WHERE substr($columnDespesaData,1,4) = ? AND substr($columnDespesaData,6,2) = ?',
      [yearStr, monthStr],
    );
    final value = result.first['count'];
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<double> getSumDespesasByDateRange(DateTime startDate, DateTime endDate) async {
    Database db = await database;
    final startIso = _formatDate(startDate);
    final endIso = _formatDate(endDate);
    final result = await db.rawQuery(
      'SELECT SUM($columnDespesaValor) as total FROM $despesasTable WHERE $columnDespesaData BETWEEN ? AND ?',
      [startIso, endIso],
    );
    final total = result.first['total'];
    if (total == null) return 0.0;
    if (total is int) return total.toDouble();
    if (total is double) return total;
    return double.tryParse(total.toString()) ?? 0.0;
  }

  Future<List<Despesa>> getDespesasByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startIso = _formatDate(startDate);
    final endIso = _formatDate(endDate);
    final maps = await db.query(
      despesasTable,
      where: '$columnDespesaData BETWEEN ? AND ?',
      whereArgs: [startIso, endIso],
      orderBy: '$columnDespesaData DESC',
    );
    return List.generate(maps.length, (i) => Despesa.fromMap(maps[i]));
  }

  Future<Despesa?> getDespesa(int id) async {
    final db = await database;
    final maps = await db.query(
      despesasTable,
      where: '$columnDespesaId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Despesa.fromMap(maps.first);
  }

  Future<int> updateDespesa(Despesa despesa) async {
    final db = await database;
    final count = await db.update(
      despesasTable,
      despesa.toMap(),
      where: '$columnDespesaId = ?',
      whereArgs: [despesa.id],
    );
    try {
      final base = await getSetting('api_base_url');
      if (base != null && base.isNotEmpty) {
        await ApiService(base).putDespesa(despesa);
      }
    } catch (_) {}
    return count;
  }

  Future<int> deleteDespesa(int id) async {
    final db = await database;
    final count = await db.delete(
      despesasTable,
      where: '$columnDespesaId = ?',
      whereArgs: [id],
    );
    try {
      final base = await getSetting('api_base_url');
      if (base != null && base.isNotEmpty) {
        await ApiService(base).deleteDespesa(id);
      }
    } catch (_) {}
    return count;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      settingsTable,
      {columnSettingKey: key, columnSettingValue: value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      settingsTable,
      where: '$columnSettingKey = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first[columnSettingValue] as String?;
  }
  // Romaneio helpers
  Future<void> clearRomaneio() async {
    final db = await database;
    await db.delete(romaneioTable);
  }
  Future<int> insertRomaneioItem(Map<String, dynamic> item) async {
    final db = await database;
    return db.insert(romaneioTable, item, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> insertRomaneioItemsBulk(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (final it in items) {
      batch.insert(romaneioTable, it, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
  Future<List<Map<String, dynamic>>> getRomaneio({String? status}) async {
    final db = await database;
    return db.query(
      romaneioTable,
      where: status != null ? 'status = ?' : null,
      whereArgs: status != null ? [status] : null,
      orderBy: 'id ASC',
    );
  }
  Future<int> marcarConferido(int id, {bool conferido = true}) async {
    final db = await database;
    return db.update(romaneioTable, {'status': conferido ? 'conferido' : 'pendente'}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> marcarFaltante(int id, {bool faltante = true}) async {
    final db = await database;
    return db.update(romaneioTable, {'status': faltante ? 'faltante' : 'pendente'}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> deleteConferidos() async {
    final db = await database;
    return db.delete(romaneioTable, where: 'status = ?', whereArgs: ['conferido']);
  }
  Future<int> atualizarRomaneio(int id, Map<String, dynamic> fields) async {
    final db = await database;
    return db.update(romaneioTable, fields, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> atualizarRomaneioPorIdPacote(String idPacote, Map<String, dynamic> fields) async {
    final db = await database;
    return db.update(romaneioTable, fields, where: 'idPacote = ?', whereArgs: [idPacote]);
  }
  Future<int> conferirSeNaoConferidoPorIdPacote(String idPacote) async {
    final db = await database;
    return db.update(
      romaneioTable,
      {'status': 'conferido'},
      where: 'idPacote = ? AND status != ?',
      whereArgs: [idPacote, 'conferido'],
    );
  }
  Future<Map<String, dynamic>?> getRomaneioByIdPacote(String idPacote) async {
    final db = await database;
    final maps = await db.query(romaneioTable, where: 'idPacote = ?', whereArgs: [idPacote], limit: 1);
    if (maps.isEmpty) return null;
    return maps.first;
  }
  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
