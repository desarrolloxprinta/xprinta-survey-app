import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import '../main.dart'; // supabase
import 'signature_screen.dart';

class MeasurementFormScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;

  const MeasurementFormScreen({super.key, required this.projectData});

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  String _ubicacion = 'Interior';
  final TextEditingController _nombreElementoCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _fotosElemento = [];
  List<XFile> _fotosMedidas = [];

  bool _isSaving = false;

  // Planos
  List<Map<String, dynamic>> _availableBlueprints = [];
  String? _blueprintUrl;
  Offset? _pinPosition;
  final GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.projectData['planos_tecnicos'] != null && widget.projectData['planos_tecnicos'] is List) {
      List planos = widget.projectData['planos_tecnicos'];
      for (var plano in planos) {
        if (plano is Map && plano['blueprint_url'] != null && plano['blueprint_url'].toString().trim().isNotEmpty) {
          _availableBlueprints.add(Map<String, dynamic>.from(plano));
        }
      }
      if (_availableBlueprints.isNotEmpty) {
        _blueprintUrl = _availableBlueprints.first['blueprint_url'];
      }
    }
  }

  @override
  void dispose() {
    _nombreElementoCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages(bool isElemento, ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> selectedImages = await _picker.pickMultiImage(imageQuality: 80);
        if (selectedImages.isNotEmpty) {
          setState(() {
            if (isElemento) {
              _fotosElemento.addAll(selectedImages);
              if (_fotosElemento.length > 5) _fotosElemento = _fotosElemento.sublist(0, 5);
            } else {
              _fotosMedidas.addAll(selectedImages);
              if (_fotosMedidas.length > 5) _fotosMedidas = _fotosMedidas.sublist(0, 5);
            }
          });
        }
      } else {
        final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
        if (image != null) {
          setState(() {
            if (isElemento) {
              if (_fotosElemento.length < 5) _fotosElemento.add(image);
            } else {
              if (_fotosMedidas.length < 5) _fotosMedidas.add(image);
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _onBlueprintTap(TapDownDetails details) {
    if (_imageKey.currentContext == null) return;
    RenderBox box = _imageKey.currentContext!.findRenderObject() as RenderBox;
    Offset localPosition = box.globalToLocal(details.globalPosition);
    
    // Calcular posición relativa (0.0 a 1.0) para guardar independiente del tamaño de pantalla
    double xRel = localPosition.dx / box.size.width;
    double yRel = localPosition.dy / box.size.height;
    
    setState(() {
      _pinPosition = Offset(xRel, yRel);
    });
  }

  Future<List<String>> _uploadPhotos(List<XFile> photos, String projectId) async {
    List<String> urls = [];
    for (var photo in photos) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${photo.name}';
        final filePath = '$projectId/mediciones/$fileName';
        
        await supabase.storage.from('project-files').upload(
          filePath,
          File(photo.path),
        );
        
        final signedUrl = await supabase.storage.from('project-files').createSignedUrl(filePath, 31536000); // 1 año de validez
        urls.add(signedUrl);
      } catch (e) {
        print('Error subiendo foto: $e');
      }
    }
    return urls;
  }

  Future<void> _saveMeasurement() async {
    if (_nombreElementoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del elemento es obligatorio.')),
      );
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final String projectId = widget.projectData['id'];
      
      // 1. Subir fotos físicas al Storage
      final urlsElemento = await _uploadPhotos(_fotosElemento, projectId);
      final urlsMedidas = await _uploadPhotos(_fotosMedidas, projectId);
      final allUrls = [...urlsElemento, ...urlsMedidas];

      final Map<String, dynamic> formData = {
        'ubicacion': _ubicacion,
        'nombre_elemento': _nombreElementoCtrl.text.trim(),
        'observaciones': _observacionesCtrl.text.trim(),
        'fotos_elemento': urlsElemento,
        'fotos_medidas': urlsMedidas,
      };

      if (_pinPosition != null && _blueprintUrl != null) {
        formData['pin_ubicacion'] = {
          'x': _pinPosition!.dx,
          'y': _pinPosition!.dy,
          'blueprint_url': _blueprintUrl,
        };
      }

      final insertData = {
        'project_id': widget.projectData['id'],
        'nombre': _nombreElementoCtrl.text.trim(),
        'status': 'completada',
        'measurement_data': formData,
        'attached_files': allUrls,
        'measured_by': supabase.auth.currentUser?.id,
        'measurement_date': DateTime.now().toIso8601String(),
      };

      // 1. Insertar la nueva medición
      await supabase.from('mediciones').insert(insertData);


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medición registrada!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        
        final bool? continuar = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Medición Guardada'),
            content: const Text('¿Deseas medir otro rótulo o elemento en este proyecto?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No, volver al proyecto'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sí, seguir midiendo'),
              ),
            ],
          ),
        );
        
        if (continuar == true) {
          setState(() {
            _nombreElementoCtrl.clear();
            _fotosElemento.clear();
            _fotosMedidas.clear();
            _pinPosition = null;
          });
        } else {
          Navigator.pop(context, true); // Retornar a MeasurementDetailScreen
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  Widget _buildPhotoSection(String title, bool isElemento) {
    final textTheme = Theme.of(context).textTheme;
    final list = isElemento ? _fotosElemento : _fotosMedidas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('${list.length}/5', style: TextStyle(color: list.length == 5 ? Colors.red : Colors.grey)),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _showPickerOptions(isElemento),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Añadir Fotos'),
              ),
            ),
          )
        else
          Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: list.length,
                itemBuilder: (ctx, idx) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(list[idx].path),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.redAccent),
                          onPressed: () {
                            setState(() { list.removeAt(idx); });
                          },
                        ),
                      )
                    ],
                  );
                },
              ),
              if (list.length < 5)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: () => _showPickerOptions(isElemento),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir más'),
                  ),
                )
            ],
          ),
      ],
    );
  }

  void _showPickerOptions(bool isElemento) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.blue),
                  ),
                  title: const Text('Tomar Foto', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Usar la cámara del dispositivo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImages(isElemento, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library, color: Colors.purple),
                  ),
                  title: const Text('Subir desde Galería', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Seleccionar múltiples fotos'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImages(isElemento, ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulario de Medición'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Datos Generales', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _ubicacion,
                decoration: InputDecoration(
                  labelText: 'Ubicación',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['Interior', 'Exterior'].map((String val) {
                  return DropdownMenuItem(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _ubicacion = val);
                },
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _nombreElementoCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre del elemento a medir',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _observacionesCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Ej: pared lisa, deteriorada, tomas descubiertas...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              _buildPhotoSection('Fotos del Elemento', true),
              const SizedBox(height: 32),
              _buildPhotoSection('Fotos de las Medidas', false),
              const SizedBox(height: 32),

              if (_blueprintUrl != null) ...[
                Text('Ubicación en el Plano', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                if (_availableBlueprints.length > 1) ...[
                  DropdownButtonFormField<String>(
                    value: _blueprintUrl,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Seleccionar plano',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _availableBlueprints.map((plano) {
                      final url = plano['blueprint_url'] as String;
                      final name = plano['name'] ?? plano['file_name'] ?? 'Plano ${_availableBlueprints.indexOf(plano) + 1}';
                      return DropdownMenuItem<String>(
                        value: url,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _blueprintUrl) {
                        setState(() {
                          _blueprintUrl = val;
                          _pinPosition = null; // Resetear pin al cambiar plano
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                
                Text('Toca la imagen para fijar el punto de medición', style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: GestureDetector(
                      onTapDown: _onBlueprintTap,
                      child: Stack(
                        children: [
                          Image.network(
                            _blueprintUrl!,
                            key: _imageKey,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                            },
                            errorBuilder: (ctx, err, stack) => const SizedBox(height: 200, child: Center(child: Text('Error cargando plano'))),
                          ),
                          if (_pinPosition != null && _imageKey.currentContext != null)
                            Positioned(
                              left: _pinPosition!.dx * (_imageKey.currentContext!.findRenderObject() as RenderBox).size.width - 12,
                              top: _pinPosition!.dy * (_imageKey.currentContext!.findRenderObject() as RenderBox).size.height - 24,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 24),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],

              ElevatedButton.icon(
                onPressed: _saveMeasurement,
                icon: const Icon(Icons.check_circle),
                label: const Text('Guardar Medición'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
    );
  }
}
