import 'package:flutter/material.dart';
import '../widgets/modern_card.dart';

class MeasurementHistoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> measurementData;

  const MeasurementHistoryDetailScreen({super.key, required this.measurementData});

  String _formatKey(String key) {
    final clean = key.replaceAll('_', ' ').toLowerCase();
    return clean.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'Ninguno';
    
    if (value is List) {
      if (value.isEmpty) return 'Ninguno';
      if (value.first.toString().startsWith('http')) {
        return '${value.length} archivo(s) (ver en galería)';
      }
      return value.join(', ');
    }
    
    if (value is Map) {
      if (value.containsKey('blueprint_url') || value.containsKey('bluprint_url') || (value.containsKey('x') && value.containsKey('y'))) {
        final x = value['x']?.toString() ?? '0';
        final y = value['y']?.toString() ?? '0';
        final xFormatted = x.length > 4 ? x.substring(0, 4) : x;
        final yFormatted = y.length > 4 ? y.substring(0, 4) : y;
        return 'Marcador en plano (X: $xFormatted, Y: $yFormatted)';
      }
      return value.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    }
    
    if (value.toString().startsWith('http')) {
      return 'Enlace / Archivo (ver en galería)';
    }
    return value.toString();
  }

  Widget _buildValueWidget(dynamic value) {
    if (value is Map && (value.containsKey('blueprint_url') || value.containsKey('bluprint_url') || (value.containsKey('x') && value.containsKey('y')))) {
      final url = value['blueprint_url']?.toString() ?? value['bluprint_url']?.toString() ?? '';
      if (url.isNotEmpty && url.startsWith('http')) {
        final x = double.tryParse(value['x']?.toString() ?? '0') ?? 0.0;
        final y = double.tryParse(value['y']?.toString() ?? '0') ?? 0.0;
        return Container(
          margin: const EdgeInsets.only(top: 8),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Stack(
            children: [
              Image.network(url, width: double.infinity, fit: BoxFit.contain),
              Positioned.fill(
                child: Align(
                  alignment: Alignment(x * 2 - 1, y * 2 - 1),
                  // Centramos un poco el icono usando FractionalTranslation porque el "point" de un pin es su base inferior central
                  child: FractionalTranslation(
                    translation: const Offset(0.0, -0.5),
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    return Text(_formatValue(value), style: const TextStyle(fontSize: 16));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final projectName = measurementData['projects']?['nombre'] ?? 'Proyecto';
    final elementName = measurementData['nombre'] ?? 'Elemento medido';
    final formData = measurementData['measurement_data'] as Map<String, dynamic>? ?? {};
    final attachedFiles = measurementData['attached_files'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Medición'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ModernCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(elementName, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 18, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(projectName, style: textTheme.bodyLarge)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Datos Recopilados', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ModernCard(
            child: formData.isEmpty
                ? const Text('No hay datos adicionales')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: formData.entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatKey(e.key), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            _buildValueWidget(e.value),
                            const Divider(height: 16),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          Text('Fotografías y Adjuntos (${attachedFiles.length})', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (attachedFiles.isEmpty)
            const ModernCard(child: Text('No se adjuntaron fotos'))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: attachedFiles.length,
              itemBuilder: (context, index) {
                final url = attachedFiles[index].toString();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (ctx, err, stack) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
