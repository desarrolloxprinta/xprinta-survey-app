import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/measurement_point.dart';

class OfflineDbService {
  static final OfflineDbService instance = OfflineDbService._init();
  static Database? _database;

  OfflineDbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('measurements.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT';
    const floatType = 'REAL';
    const integerType = 'INTEGER';

    await db.execute('''
CREATE TABLE measurement_points (
  id $idType,
  project_id $textType,
  ubicacion $textType,
  observaciones $textType,
  plano_x_coordinate $floatType,
  plano_y_coordinate $floatType,
  fotos_elemento $textType,
  fotos_medidas $textType,
  is_synced $integerType,
  created_at $textType
  )
''');
  }

  Future<void> createMeasurementPoint(MeasurementPoint point) async {
    final db = await instance.database;
    await db.insert('measurement_points', point.toMap());
  }

  Future<List<MeasurementPoint>> getMeasurementPointsByProject(String projectId) async {
    final db = await instance.database;
    final result = await db.query(
      'measurement_points',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );

    return result.map((json) => MeasurementPoint.fromMap(json)).toList();
  }

  Future<List<MeasurementPoint>> getUnsyncedPoints() async {
    final db = await instance.database;
    final result = await db.query(
      'measurement_points',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    return result.map((json) => MeasurementPoint.fromMap(json)).toList();
  }

  Future<int> markAsSynced(String id) async {
    final db = await instance.database;
    return db.update(
      'measurement_points',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
