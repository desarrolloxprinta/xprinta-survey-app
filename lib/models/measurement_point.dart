import 'package:uuid/uuid.dart';

enum UbicacionType { exterior, interior }

class MeasurementPoint {
  final String id;
  final String projectId; // Referencia a ficha_id / project_id
  final UbicacionType ubicacion;
  final String observaciones;
  final double? planoX;
  final double? planoY;
  final List<String> fotosElemento;
  final List<String> fotosMedidas;
  final bool isSynced; // Local flag para saber si está sincronizado con Supabase
  final DateTime createdAt;

  MeasurementPoint({
    String? id,
    required this.projectId,
    required this.ubicacion,
    this.observaciones = '',
    this.planoX,
    this.planoY,
    this.fotosElemento = const [],
    this.fotosMedidas = const [],
    this.isSynced = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'ubicacion': ubicacion.name,
      'observaciones': observaciones,
      'plano_x_coordinate': planoX,
      'plano_y_coordinate': planoY,
      'fotos_elemento': fotosElemento.join(','), // Guardado como CSV localmente
      'fotos_medidas': fotosMedidas.join(','),
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MeasurementPoint.fromMap(Map<String, dynamic> map) {
    return MeasurementPoint(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      ubicacion: UbicacionType.values.firstWhere(
        (e) => e.name == map['ubicacion'],
        orElse: () => UbicacionType.interior,
      ),
      observaciones: map['observaciones'] as String? ?? '',
      planoX: map['plano_x_coordinate'] as double?,
      planoY: map['plano_y_coordinate'] as double?,
      fotosElemento: (map['fotos_elemento'] as String?)?.split(',').where((e) => e.isNotEmpty).toList() ?? [],
      fotosMedidas: (map['fotos_medidas'] as String?)?.split(',').where((e) => e.isNotEmpty).toList() ?? [],
      isSynced: (map['is_synced'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
