class InstallationBlueprint {
  final String id;
  final String reference;
  final String blueprintUrl;
  final String blueprintName;
  final String storagePath;
  final List<InstallationDot> dots;

  InstallationBlueprint({
    required this.id,
    required this.reference,
    required this.blueprintUrl,
    required this.blueprintName,
    required this.storagePath,
    required this.dots,
  });

  factory InstallationBlueprint.fromJson(Map<String, dynamic> json) {
    return InstallationBlueprint(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? 'Plano',
      blueprintUrl: json['blueprint_url'] as String? ?? '',
      blueprintName: json['blueprint_name'] as String? ?? '',
      storagePath: json['storage_path'] as String? ?? '',
      dots: (json['dots'] as List<dynamic>?)
          ?.map((d) => InstallationDot.fromJson(d as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class InstallationDot {
  final String id;
  final double x;
  final double y;
  final String label;
  final String? productId;

  InstallationDot({
    required this.id,
    required this.x,
    required this.y,
    required this.label,
    this.productId,
  });

  factory InstallationDot.fromJson(Map<String, dynamic> json) {
    return InstallationDot(
      id: json['id'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      label: json['label'] as String? ?? '',
      productId: json['product_id'] as String?,
    );
  }
}

class InstallationProduct {
  final String id;
  final String titulo;
  final String descripcion;
  final int cantidad;

  InstallationProduct({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.cantidad,
  });

  factory InstallationProduct.fromJson(Map<String, dynamic> json) {
    return InstallationProduct(
      id: json['id'] as String? ?? '',
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
    );
  }
}
