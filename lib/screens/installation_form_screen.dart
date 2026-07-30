import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import '../main.dart'; // supabase

class InstallationFormScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;

  const InstallationFormScreen({super.key, required this.projectData});

  @override
  State<InstallationFormScreen> createState() => _InstallationFormScreenState();
}

class _InstallationFormScreenState extends State<InstallationFormScreen> {
  String _ubicacion = 'Exterior';
  final TextEditingController _nombreElementoCtrl = TextEditingController();
  final TextEditingController _observacionesCtrl = TextEditingController();
  bool _materialRecibido = true;

  final ImagePicker _picker = ImagePicker();
  List<XFile> _fotosElemento = [];
  List<XFile> _fotosInstalacion = [];

  bool _isSaving = false;

  // Planos
  List<Map<String, dynamic>> _availableBlueprints = [];
  String? _blueprintUrl;
  Offset? _pinPosition;
  final GlobalKey _imageKey = GlobalKey();

  // Products
  String? _selectedProduct;
  List<String> _productOptions = [];

  @override
  void initState() {
    super.initState();
    List planos = [];
    if (widget.projectData['installation_blueprints'] != null && widget.projectData['installation_blueprints'] is List) {
      planos = widget.projectData['installation_blueprints'];
    } else if (widget.projectData['planos_tecnicos'] != null && widget.projectData['planos_tecnicos'] is List) {
      planos = widget.projectData['planos_tecnicos'];
    }
    
    for (var plano in planos) {
      if (plano is Map && plano['blueprint_url'] != null && plano['blueprint_url'].toString().trim().isNotEmpty) {
        _availableBlueprints.add(Map<String, dynamic>.from(plano));
      }
    }
    if (_availableBlueprints.isNotEmpty) {
      _blueprintUrl = _availableBlueprints.first['blueprint_url'];
    }

    if (widget.projectData['installation_products'] != null && widget.projectData['installation_products'] is List) {
      final prods = widget.projectData['installation_products'] as List;
      for (var p in prods) {
        if (p is Map && p['titulo'] != null && p['titulo'].toString().trim().isNotEmpty) {
          if (!_productOptions.contains(p['titulo'])) {
            _productOptions.add(p['titulo']);
          }
        }
      }
    }
    _productOptions.add('Otro (Especificar)');
    _selectedProduct = _productOptions.first;
    if (_selectedProduct != 'Otro (Especificar)') {
      _nombreElementoCtrl.text = _selectedProduct!;
      _updatePinForProduct(_selectedProduct!);
    }
  }

  void _updatePinForProduct(String productName) {
    if (productName == 'Otro (Especificar)') {
      setState(() => _pinPosition = null);
      return;
    }

    String? productId;
    if (widget.projectData['installation_products'] != null && widget.projectData['installation_products'] is List) {
      final prods = widget.projectData['installation_products'] as List;
      for (var p in prods) {
        if (p is Map && p['titulo'] == productName) {
          productId = p['id']?.toString();
          break;
        }
      }
    }

    final targetTitle = productName.trim().toLowerCase();
    final targetId = productId?.trim().toLowerCase();

    for (var blueprint in _availableBlueprints) {
      if (blueprint['dots'] != null && blueprint['dots'] is List) {
        final dots = blueprint['dots'] as List;
        for (var dot in dots) {
          if (dot is Map && dot['product_id'] != null) {
            final dotProductId = dot['product_id'].toString().trim().toLowerCase();
            if ((targetId != null && dotProductId == targetId) || dotProductId == targetTitle) {
              setState(() {
                _blueprintUrl = blueprint['blueprint_url'];
                _pinPosition = Offset(
                  (dot['x'] as num).toDouble() / 100,
                  (dot['y'] as num).toDouble() / 100,
                );
              });
              return;
            }
          }
        }
      }
    }
    
    // Clear pin if no matching dot is found
    setState(() => _pinPosition = null);
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
              _fotosInstalacion.addAll(selectedImages);
              if (_fotosInstalacion.length > 5) _fotosInstalacion = _fotosInstalacion.sublist(0, 5);
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
              if (_fotosInstalacion.length < 5) _fotosInstalacion.add(image);
            }
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Eliminado _onBlueprintTap porque ahora es solo indicador visual
  Future<List<String>> _uploadPhotos(List<XFile> photos, String projectId) async {
    List<String> urls = [];
    for (var photo in photos) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${photo.name}';
        final filePath = '$projectId/instalaciones/$fileName';
        
        await supabase.storage.from('project-files').upload(
          filePath,
          File(photo.path),
        );
        
        final signedUrl = await supabase.storage.from('project-files').createSignedUrl(filePath, 31536000);
        urls.add(signedUrl);
      } catch (e) {
        print('Error subiendo foto instalación: $e');
      }
    }
    return urls;
  }

  Future<void> _saveInstallation() async {
    if (_nombreElementoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del elemento instalado es obligatorio.')),
      );
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final String projectId = widget.projectData['id'];
      
      final urlsElemento = await _uploadPhotos(_fotosElemento, projectId);
      final urlsInstalacion = await _uploadPhotos(_fotosInstalacion, projectId);
      final allUrls = [...urlsElemento, ...urlsInstalacion];

      final Map<String, dynamic> formData = {
        'ubicacion': _ubicacion,
        'nombre_elemento': _nombreElementoCtrl.text.trim(),
        'observaciones': _observacionesCtrl.text.trim(),
        'material_recibido': _materialRecibido,
        'fotos_elemento': urlsElemento,
        'fotos_instalacion': urlsInstalacion,
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
        'installation_data': formData,
        'attached_files': allUrls,
        'installed_by': supabase.auth.currentUser?.id,
        'installation_date': DateTime.now().toIso8601String(),
      };

      await supabase.from('instalaciones').insert(insertData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Instalación registrada correctamente!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
        );
        
        final String? continuar = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Instalación Guardada'),
            content: const Text('¿Deseas registrar otra instalación o elemento en este proyecto?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'volver'),
                child: const Text('Volver al proyecto'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'albaran'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Generar Albarán'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'otra'),
                child: const Text('Añadir otra'),
              ),
            ],
          ),
        );
        
        if (continuar == 'otra') {
          setState(() {
            _nombreElementoCtrl.clear();
            _observacionesCtrl.clear();
            _fotosElemento.clear();
            _fotosInstalacion.clear();
            _pinPosition = null;
          });
        } else if (continuar == 'albaran') {
          Navigator.pop(context, 'albaran');
        } else {
          Navigator.pop(context, true);
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
    final list = isElemento ? _fotosElemento : _fotosInstalacion;

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
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
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
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.camera_alt, color: Theme.of(context).primaryColor),
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
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library, color: Colors.blue),
                  ),
                  title: const Text('Subir desde Galería', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Seleccionar fotos registradas'),
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
        title: const Text('Formulario de Instalación'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Datos de la Instalación', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
              
              DropdownButtonFormField<String>(
                value: _selectedProduct,
                decoration: InputDecoration(
                  labelText: 'Elemento a instalar',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _productOptions.map((String val) {
                  return DropdownMenuItem(value: val, child: Text(val));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedProduct = val;
                      if (val != 'Otro (Especificar)') {
                        _nombreElementoCtrl.text = val;
                        _updatePinForProduct(val);
                      } else {
                        _nombreElementoCtrl.clear();
                      }
                    });
                  }
                },
              ),
              if (_selectedProduct == 'Otro (Especificar)') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _nombreElementoCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre del elemento instalado',
                    hintText: 'Ej: Rótulo de entrada, Vinilo escaparate...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // Switcher de Recepción de Material por parte de Xprinta
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Material recibido por parte de central Xprinta',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _materialRecibido ? 'Sí, el material fue entregado/recibido' : 'No, pendiente o material propio',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _materialRecibido,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _materialRecibido = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _observacionesCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Observaciones de montaje',
                  hintText: 'Ej: Montaje completado con tacos de 8mm, iluminación probada...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              _buildPhotoSection('Fotos del Elemento Instalado', true),
              const SizedBox(height: 32),
              _buildPhotoSection('Fotos del Resultado / Ángulos', false),
              const SizedBox(height: 32),

              if (_blueprintUrl != null) ...[
                Text('Ubicación en el Plano', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
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
                          _pinPosition = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
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
                        if (_pinPosition != null)
                          Positioned.fill(
                            child: Align(
                              alignment: FractionalOffset(_pinPosition!.dx, _pinPosition!.dy),
                              child: Transform.translate(
                                offset: const Offset(0, -14),
                                child: Icon(Icons.location_on, color: Theme.of(context).primaryColor, size: 28),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],

              ElevatedButton.icon(
                onPressed: _saveInstallation,
                icon: const Icon(Icons.check_circle),
                label: const Text('Guardar Instalación'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
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
