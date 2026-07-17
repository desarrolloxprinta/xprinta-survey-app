import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import '../models/measurement_point.dart';
import '../services/offline_db_service.dart';
import 'dart:math';

class InteractiveMapScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const InteractiveMapScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen> {
  final List<MeasurementPoint> _points = [];
  final PhotoViewController _photoViewController = PhotoViewController();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalPoints();
  }

  Future<void> _loadLocalPoints() async {
    final localPoints = await OfflineDbService.instance.getMeasurementPointsByProject(widget.projectId);
    setState(() {
      _points.addAll(localPoints);
      _isLoading = false;
    });
  }

  void _onTapMap(TapUpDetails details, PhotoViewControllerValue controllerValue) {
    // Calculamos las coordenadas relativas al plano
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(details.globalPosition);

    // Mapeo simple de coordenadas (Ajustar según escala del photo_view)
    final x = localPosition.dx;
    final y = localPosition.dy;

    _showMeasurementForm(x, y);
  }

  Future<void> _showMeasurementForm(double x, double y) async {
    final ubicacionController = ValueNotifier<UbicacionType>(UbicacionType.interior);
    final obsController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nuevo Punto de Medición', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ValueListenableBuilder<UbicacionType>(
                valueListenable: ubicacionController,
                builder: (context, value, child) {
                  return Row(
                    children: [
                      Expanded(
                        child: RadioListTile<UbicacionType>(
                          title: const Text('Interior'),
                          value: UbicacionType.interior,
                          groupValue: value,
                          onChanged: (v) => ubicacionController.value = v!,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<UbicacionType>(
                          title: const Text('Exterior'),
                          value: UbicacionType.exterior,
                          groupValue: value,
                          onChanged: (v) => ubicacionController.value = v!,
                        ),
                      ),
                    ],
                  );
                },
              ),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(labelText: 'Observaciones', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Aquí irían los botones para tomar fotos
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Añadir Fotos (Placeholder)'),
                onPressed: () {
                  // Implementar ImagePicker
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funcionalidad de cámara pendiente')));
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  onPressed: () async {
                    final newPoint = MeasurementPoint(
                      projectId: widget.projectId,
                      ubicacion: ubicacionController.value,
                      observaciones: obsController.text,
                      planoX: x,
                      planoY: y,
                    );
                    
                    // Guardar en SQLite local
                    await OfflineDbService.instance.createMeasurementPoint(newPoint);
                    
                    setState(() {
                      _points.add(newPoint);
                    });
                    
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Guardar Punto'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Plano: ${widget.projectName}'),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GestureDetector(
                  onTapUp: (details) => _onTapMap(details, _photoViewController.value),
                  child: PhotoView(
                    controller: _photoViewController,
                    // Placeholder del plano. Luego se conectará a Supabase Storage.
                    imageProvider: const NetworkImage('https://via.placeholder.com/800x600.png?text=Plano+de+la+Ficha'),
                    backgroundDecoration: const BoxDecoration(color: Colors.white),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  ),
                ),
                // Dibujar pines
                ..._points.map((p) {
                  // Transformación simple del pin (esto requerirá ajustes matemáticos precisos con PhotoView scale)
                  return Positioned(
                    left: p.planoX != null ? p.planoX! - 15 : 0,
                    top: p.planoY != null ? p.planoY! - 30 : 0,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                  );
                }),
              ],
            ),
    );
  }
}
