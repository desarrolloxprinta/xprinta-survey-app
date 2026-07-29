import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'installation_form_screen.dart';
import 'installation_signature_screen.dart';
import '../main.dart'; // supabase
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final installationFilesProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, projectId) async {
  try {
    final response = await supabase
        .from('files')
        .select('*')
        .eq('project_id', projectId)
        .order('uploaded_at', ascending: false);
    
    List<Map<String, dynamic>> filesWithUrls = [];
    for (var file in response) {
      final String path = file['storage_path'];
      final String bucket = file['bucket'] ?? 'project-files';
      final String publicUrl = supabase.storage.from(bucket).getPublicUrl(path);
      var f = Map<String, dynamic>.from(file);
      f['public_url'] = publicUrl;
      filesWithUrls.add(f);
    }
    return filesWithUrls;
  } catch (e) {
    return [];
  }
});

final projectMeasurementsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, projectId) async {
  try {
    final response = await supabase
        .from('mediciones')
        .select('*')
        .eq('project_id', projectId)
        .order('measurement_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
});

final projectInstallationsProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, projectId) async {
  try {
    final response = await supabase
        .from('instalaciones')
        .select('*')
        .eq('project_id', projectId)
        .order('installation_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    return [];
  }
});

class InstallationDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> projectData;

  const InstallationDetailScreen({super.key, required this.projectData});

  @override
  ConsumerState<InstallationDetailScreen> createState() => _InstallationDetailScreenState();
}

class _InstallationDetailScreenState extends ConsumerState<InstallationDetailScreen> {
  final GlobalKey _imageKey = GlobalKey();
  String? _selectedBlueprintUrl;
  Map<String, dynamic>? _selectedPinData;

  @override
  void initState() {
    super.initState();
    if (widget.projectData['planos_tecnicos'] != null && widget.projectData['planos_tecnicos'] is List) {
      List planos = widget.projectData['planos_tecnicos'];
      for (var plano in planos) {
        if (plano is Map && plano['blueprint_url'] != null && plano['blueprint_url'].toString().trim().isNotEmpty) {
          _selectedBlueprintUrl = plano['blueprint_url'].toString();
          break;
        }
      }
    }
  }

  Future<void> _scheduleInstallationVisit(BuildContext context, WidgetRef ref) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!context.mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;
    if (!context.mounted) return;

    final DateTime scheduledDateTime = DateTime(
      date.year, date.month, date.day, time.hour, time.minute,
    );

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      await supabase.from('projects').update({
        'installation_phase': 'visita_agendada_instalacion',
        'scheduled_installation_date': scheduledDateTime.toIso8601String(),
      }).eq('id', widget.projectData['id']);

      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Visita de instalación agendada correctamente', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context, true); // Pop screen to refresh
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al agendar: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  String _formatSlug(String slug) {
    if (slug.isEmpty) return slug;
    final Map<String, String> dict = {
      'rotulo_sin_luz': 'Rótulo sin luz',
      'rotulo_luminoso': 'Rótulo luminoso',
      'vinilo': 'Vinilo',
      'letras_corporeas': 'Letras corpóreas',
      'banderola': 'Banderola',
      'impresion_digital': 'Impresión digital',
      'lonas': 'Lonas',
      'placa_metacrilato': 'Placa metacrilato',
      'senyaletica': 'Señalética',
      'escaparate': 'Escaparate'
    };
    if (dict.containsKey(slug)) return dict[slug]!;
    
    final words = slug.replaceAll('_', ' ').split(' ');
    if (words.isEmpty) return slug;
    words[0] = words[0].substring(0, 1).toUpperCase() + words[0].substring(1);
    return words.join(' ');
  }

  void _showPinDetailDialog(BuildContext context, String nombre, Map<String, dynamic> data) {
    final textTheme = Theme.of(context).textTheme;
    final ubicacion = data['ubicacion'] ?? 'No especificada';
    final observaciones = data['observaciones'] ?? 'Sin observaciones';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(nombre, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ubicación: $ubicacion', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Observaciones:', style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(observaciones, style: textTheme.bodyMedium),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final projectIdStr = widget.projectData['id'].toString();
    final projectName = widget.projectData['nombre'] ?? 'Proyecto sin nombre';
    final workspaceName = (widget.projectData['companies'] != null) ? widget.projectData['companies']['nombre'] : 'Workspace desconocido';
    final address = widget.projectData['direccion'] ?? 'Sin dirección asignada';
    final description = widget.projectData['descripcion'] ?? 'No hay comentarios adicionales.';
    
    final filesAsync = ref.watch(installationFilesProvider(projectIdStr));
    final measurementsAsync = ref.watch(projectMeasurementsProvider(projectIdStr));
    final installationsAsync = ref.watch(projectInstallationsProvider(projectIdStr));

    final clientName = widget.projectData['cliente_nombre_apellido'] ?? '';
    final clientLocal = widget.projectData['cliente_nombre_local'] ?? '';
    final phone = widget.projectData['cliente_telefono'] ?? '';
    
    String contactDisplay = 'Sin contacto asignado';
    if (clientName.isNotEmpty && clientLocal.isNotEmpty) {
      contactDisplay = '$clientName ($clientLocal)';
    } else if (clientName.isNotEmpty) {
      contactDisplay = clientName;
    } else if (clientLocal.isNotEmpty) {
      contactDisplay = clientLocal;
    }

    List<String> elementos = [];
    if (widget.projectData['elementos'] != null) {
      if (widget.projectData['elementos'] is List) {
        elementos = List<String>.from(widget.projectData['elementos']);
      }
    }

    List<Map<String, dynamic>> availableBlueprints = [];
    if (widget.projectData['planos_tecnicos'] != null && widget.projectData['planos_tecnicos'] is List) {
      for (var plano in widget.projectData['planos_tecnicos']) {
        if (plano is Map && plano['blueprint_url'] != null && plano['blueprint_url'].toString().trim().isNotEmpty) {
          availableBlueprints.add(Map<String, dynamic>.from(plano));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha de Instalación'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Cabecera Principal
                Hero(
                  tag: 'inst-title-${widget.projectData['id']}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      projectName,
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tarjeta de Info del Proyecto
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.business, 'Workspace', workspaceName, textTheme),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.location_on, 'Dirección de Instalación', address, textTheme),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.person, 'Contacto en Obra', contactDisplay, textTheme),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.phone, 'Teléfono', phone, textTheme),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 1. Ficheros del Administrador / Técnico
                filesAsync.when(
                  data: (files) {
                    if (files.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Archivos y Planos del Proyecto (Admin)', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Column(
                          children: files.map((f) {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.purple.withOpacity(0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.purple.withOpacity(0.2))),
                              child: ListTile(
                                leading: const Icon(Icons.folder_zip_outlined, color: Colors.purple),
                                title: Text(f['filename'] ?? 'Documento', style: const TextStyle(fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.download),
                                onTap: () async {
                                  if (f['storage_path'] != null) {
                                    try {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Descargando archivo...')));
                                      final String path = f['storage_path'];
                                      final String bucket = f['bucket'] ?? 'project-files';
                                      final bytes = await supabase.storage.from(bucket).download(path);
                                      
                                      Directory? dir;
                                      if (Platform.isAndroid) {
                                        dir = Directory('/storage/emulated/0/Download');
                                      } else {
                                        dir = await getApplicationDocumentsDirectory();
                                      }
                                      
                                      final filename = f['filename'] ?? path.split('/').last;
                                      final file = File('${dir.path}/$filename');
                                      await file.writeAsBytes(bytes);
                                      
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Guardado en Descargas: $filename', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al descargar: $e')));
                                      }
                                    }
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const Padding(padding: EdgeInsets.only(bottom: 24), child: Center(child: CircularProgressIndicator())),
                  error: (e, st) => const SizedBox.shrink(),
                ),

                // 2. Plano Técnico con Marcadores/Pins Precargados de Mediciones
                measurementsAsync.when(
                  data: (mediciones) {
                    // Extraer los pins precargados
                    List<Map<String, dynamic>> pins = [];
                    for (var m in mediciones) {
                      final data = m['measurement_data'];
                      if (data is Map && data['pin_ubicacion'] != null && data['pin_ubicacion'] is Map) {
                        final pin = Map<String, dynamic>.from(data['pin_ubicacion']);
                        pins.add({
                          'nombre': m['nombre'] ?? 'Elemento medido',
                          'x': pin['x'],
                          'y': pin['y'],
                          'blueprint_url': pin['blueprint_url'],
                          'data': data,
                        });
                      }
                    }

                    if (availableBlueprints.isEmpty && _selectedBlueprintUrl == null) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Planos y Ubicación de Elementos', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            if (pins.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Text('${pins.length} puntos precargados', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        if (availableBlueprints.length > 1) ...[
                          DropdownButtonFormField<String>(
                            value: _selectedBlueprintUrl,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Seleccionar plano',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: availableBlueprints.map((plano) {
                              final url = plano['blueprint_url'] as String;
                              final name = plano['name'] ?? plano['file_name'] ?? 'Plano ${availableBlueprints.indexOf(plano) + 1}';
                              return DropdownMenuItem<String>(
                                value: url,
                                child: Text(name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedBlueprintUrl = val);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        Text('Toca sobre un marcador para ver la información precargada por el medidor', style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        const SizedBox(height: 12),

                        if (_selectedBlueprintUrl != null)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.purple.withOpacity(0.4), width: 2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Stack(
                                children: [
                                  Image.network(
                                    _selectedBlueprintUrl!,
                                    key: _imageKey,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                                    },
                                    errorBuilder: (ctx, err, stack) => const SizedBox(height: 200, child: Center(child: Text('Error cargando plano'))),
                                  ),
                                  // Renderizar marcadores/pins precargados sobre el plano
                                  ...pins.where((p) => p['blueprint_url'] == _selectedBlueprintUrl || pins.length == 1).map((p) {
                                    final double xRel = (p['x'] as num).toDouble();
                                    final double yRel = (p['y'] as num).toDouble();
                                    
                                    return Positioned(
                                      left: xRel * 300 - 14, // Posición aproximada para la escala inicial
                                      top: yRel * 200 - 28,
                                      child: GestureDetector(
                                        onTap: () => _showPinDetailDialog(context, p['nombre'], p['data']),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                          ),
                                          child: const Icon(Icons.location_on, color: Colors.red, size: 28),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),

                // 3. Productos / Elementos a Instalar
                if (elementos.isNotEmpty) ...[
                  Text('Elementos a Instalar', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: elementos.map((e) => Chip(
                      avatar: const Icon(Icons.build, size: 16, color: Colors.purple),
                      label: Text(_formatSlug(e)),
                      backgroundColor: Colors.purple.withOpacity(0.1),
                      side: BorderSide.none,
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // 4. Bloque de Instalaciones Realizadas
                installationsAsync.when(
                  data: (instalaciones) {
                    if (instalaciones.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Instalaciones Registradas (${instalaciones.length})', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Column(
                          children: instalaciones.map((inst) {
                            final data = inst['installation_data'] ?? {};
                            final bool materialRecibido = data['material_recibido'] == true;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(inst['nombre'] ?? 'Elemento instalado', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: materialRecibido ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          materialRecibido ? 'Material Xprinta: Sí' : 'Material Xprinta: No',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: materialRecibido ? Colors.green : Colors.orange),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (data['ubicacion'] != null) ...[
                                    const SizedBox(height: 6),
                                    Text('Ubicación: ${data['ubicacion']}', style: textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
                                  ],
                                  if (data['observaciones'] != null && data['observaciones'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text('Notas: ${data['observaciones']}', style: textTheme.bodySmall),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),

                // Descripción / Comentarios
                Text('Instrucciones / Comentarios', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(description, style: textTheme.bodyMedium),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          
          // Bottom CTA Actions
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.projectData['installation_phase'] != 'instalacion_realizada') ...[
                    OutlinedButton.icon(
                      onPressed: () => _scheduleInstallationVisit(context, ref),
                      icon: const Icon(Icons.calendar_month, color: Colors.orange),
                      label: Text(widget.projectData['installation_phase'] == 'visita_agendada_instalacion' ? 'Reprogramar Visita de Instalación' : 'Agendar Visita de Instalación'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InstallationFormScreen(projectData: widget.projectData),
                        ),
                      );
                      if (result == true) {
                        ref.invalidate(projectInstallationsProvider(projectIdStr));
                        ref.invalidate(installationProjectsProvider);
                      }
                    },
                    icon: const Icon(Icons.build),
                    label: const Text('Agregar Instalación'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (ctx) => InstallationSignatureScreen(projectData: widget.projectData)),
                      ).then((result) {
                        if (result == true) {
                          Navigator.pop(context, true);
                        }
                      });
                    },
                    icon: const Icon(Icons.history_edu),
                    label: const Text('Finalizar y Firmar Comprobante de Instalación'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, TextTheme textTheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
