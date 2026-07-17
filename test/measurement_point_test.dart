import 'package:flutter_test/flutter_test.dart';
import 'package:xprinta_survey/models/measurement_point.dart';

void main() {
  group('MeasurementPoint', () {
    test('Se inicializa correctamente y genera un UUID', () {
      final point = MeasurementPoint(
        projectId: 'ficha_123',
        ubicacion: UbicacionType.interior,
      );

      expect(point.id, isNotEmpty);
      expect(point.projectId, 'ficha_123');
      expect(point.ubicacion, UbicacionType.interior);
      expect(point.isSynced, isFalse);
    });

    test('toMap y fromMap serializan y deserializan correctamente (SQFlite ready)', () {
      final point = MeasurementPoint(
        projectId: 'ficha_456',
        ubicacion: UbicacionType.exterior,
        observaciones: 'Falta un tornillo',
        planoX: 100.5,
        planoY: 200.0,
        fotosElemento: ['foto1.jpg', 'foto2.jpg'],
      );

      final map = point.toMap();

      expect(map['project_id'], 'ficha_456');
      expect(map['ubicacion'], 'exterior');
      expect(map['observaciones'], 'Falta un tornillo');
      expect(map['plano_x_coordinate'], 100.5);
      expect(map['is_synced'], 0);
      expect(map['fotos_elemento'], 'foto1.jpg,foto2.jpg'); // CSV storage

      final newPoint = MeasurementPoint.fromMap(map);

      expect(newPoint.id, point.id);
      expect(newPoint.projectId, point.projectId);
      expect(newPoint.ubicacion, UbicacionType.exterior);
      expect(newPoint.fotosElemento.length, 2);
      expect(newPoint.planoX, 100.5);
    });
  });
}
