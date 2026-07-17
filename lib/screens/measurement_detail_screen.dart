import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'measurement_form_screen.dart';
import 'signature_screen.dart';
import '../../main.dart'; // Para supabase
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

final technicianFilesProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, projectId) async {
  try {
    final response = await supabase
        .from('files')
        .select('*')
        .eq('project_id', projectId)
        .eq('category', 'fichero_tecnico')
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

final formTemplateProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String>((ref, templateId) async {
  try {
    final response = await supabase.from('form_templates').select('fields').eq('id', templateId).maybeSingle();
    return response;
  } catch (e) {
    return null;
  }
});

class MeasurementDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> projectData;

  const MeasurementDetailScreen({super.key, required this.projectData});

  Future<void> _scheduleVisit(BuildContext context, WidgetRef ref) async {
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
        'measurement_phase': 'visita_agendada',
        'scheduled_visit_date': scheduledDateTime.toIso8601String(),
      }).eq('id', projectData['id']);

      if (context.mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Visita agendada correctamente', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final projectName = projectData['nombre'] ?? 'Proyecto sin nombre';
    final workspaceName = (projectData['companies'] != null) ? projectData['companies']['nombre'] : 'Workspace desconocido';
    final address = projectData['direccion'] ?? 'Sin dirección asignada';
    final description = projectData['descripcion'] ?? 'No hay comentarios adicionales.';
    
    final filesAsync = ref.watch(technicianFilesProvider(projectData['id'].toString()));
    final clientName = projectData['cliente_nombre_apellido'] ?? '';
    final clientLocal = projectData['cliente_nombre_local'] ?? '';
    final phone = projectData['cliente_telefono'] ?? '';
    
    String contactDisplay = 'Sin contacto asignado';
    if (clientName.isNotEmpty && clientLocal.isNotEmpty) {
      contactDisplay = '$clientName ($clientLocal)';
    } else if (clientName.isNotEmpty) {
      contactDisplay = clientName;
    } else if (clientLocal.isNotEmpty) {
      contactDisplay = clientLocal;
    }

    // Parsear elementos si es una lista o string
    List<String> elementos = [];
    if (projectData['elementos'] != null) {
      if (projectData['elementos'] is List) {
        elementos = List<String>.from(projectData['elementos']);
      }
    }

    // Extraer campos dinámicos (form_data + form_templates)
    final Map<String, dynamic> formData = projectData['form_data'] ?? {};
    final String? formTemplateId = projectData['form_template_id'];
    final templateAsync = formTemplateId != null ? ref.watch(formTemplateProvider(formTemplateId)) : const AsyncValue.data(null);
    final Map<String, dynamic>? formTemplates = templateAsync.value;
    
    List<Widget> dynamicFieldsWidgets = [];
    if (formTemplates != null && formTemplates['fields'] != null) {
      final List fields = formTemplates['fields'];
      for (var field in fields) {
        if (field is Map && (field['visibleForTecnico'] == null || field['visibleForTecnico'] == true)) {
          final String fieldId = field['id'] ?? '';
          final String fieldLabel = field['label'] ?? fieldId;
          final value = formData[fieldId];
          
          if (value != null && value.toString().trim().isNotEmpty && field['type'] != 'title') {
            dynamicFieldsWidgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fieldLabel, style: textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(value.toString(), style: textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Proyecto'),
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
                  tag: 'title-${projectData['id']}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      projectName,
                      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Tarjeta de Info
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
                      _buildInfoRow(Icons.location_on, 'Dirección', address, textTheme),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.person, 'Contacto', contactDisplay, textTheme),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.phone, 'Teléfono', phone, textTheme),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Ficheros de Trabajo para Técnico
                filesAsync.when(
                  data: (files) {
                    if (files.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ficheros de Trabajo para Técnico', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Column(
                          children: files.map((f) {
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Theme.of(context).primaryColor.withOpacity(0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.1))),
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
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
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Guardado en Descargas: $filename', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
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
                
                // Elementos a Fabricar
                if (elementos.isNotEmpty) ...[
                  Text('Elementos a Medir / Fabricar', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: elementos.map((e) => Chip(
                      label: Text(e),
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      side: BorderSide.none,
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Comentarios
                Text('Descripción / Comentarios', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(description, style: textTheme.bodyMedium),
                ),

                if (dynamicFieldsWidgets.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Información Técnica Adicional', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: dynamicFieldsWidgets,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Bottom CTA
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (projectData['measurement_phase'] != 'medicion_realizada') ...[
                    OutlinedButton.icon(
                      onPressed: () => _scheduleVisit(context, ref),
                      icon: const Icon(Icons.calendar_month),
                      label: Text(projectData['measurement_phase'] == 'visita_agendada' ? 'Reprogramar Visita' : 'Agendar Visita'),
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
                          builder: (context) => MeasurementFormScreen(projectData: projectData),
                        ),
                      );
                      if (result == true) {
                        Navigator.pop(context, true); // Propagate success back to Dashboard
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar Medición'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
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
                        MaterialPageRoute(builder: (ctx) => SignatureScreen(projectData: projectData)),
                      ).then((result) {
                        if (result == true) {
                          Navigator.pop(context, true);
                        }
                      });
                    },
                    icon: const Icon(Icons.draw),
                    label: const Text('Finalizar y Firmar Albarán'),
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

