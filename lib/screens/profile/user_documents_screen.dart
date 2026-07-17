import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart'; // supabase
import '../../providers/user_documents_provider.dart';
import '../../widgets/modern_card.dart';
import 'upload_document_screen.dart';

class UserDocumentsScreen extends ConsumerWidget {
  const UserDocumentsScreen({super.key});

  Color _getStatusColor(String? expiryDate) {
    if (expiryDate == null) return Colors.green;
    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return Colors.green;
    final diff = expiry.difference(DateTime.now()).inDays;
    
    if (diff < 0) return Colors.red;
    if (diff <= 30) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(String? expiryDate) {
    if (expiryDate == null) return 'Sin caducidad';
    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return 'Fecha inválida';
    final diff = expiry.difference(DateTime.now()).inDays;
    
    if (diff < 0) return 'Caducado';
    if (diff <= 30) return 'Próximo a caducar ($diff días)';
    return 'Vigente';
  }

  void _showDocumentDetails(BuildContext context, WidgetRef ref, Map<String, dynamic> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final files = List<Map<String, dynamic>>.from(doc['files'] ?? []);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      doc['title'] ?? 'Documento',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Detalles
              Text('Tipo de documento:', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
              Text('${doc['document_type']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              
              if (doc['expiry_date'] != null) ...[
                Text('Estado:', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: _getStatusColor(doc['expiry_date']), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(doc['expiry_date']),
                      style: TextStyle(color: _getStatusColor(doc['expiry_date']), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              if (doc['notes'] != null && doc['notes'].toString().isNotEmpty) ...[
                Text('Notas:', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                Text(doc['notes']),
                const SizedBox(height: 16),
              ],
              
              const Divider(),
              const SizedBox(height: 8),
              const Text('Archivos Adjuntos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (files.isEmpty) const Text('No hay archivos adjuntos'),
              ...files.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ModernCard(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.download, color: Theme.of(context).primaryColor),
                    ),
                    title: Text(f['name'] ?? 'Archivo', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final url = f['url'];
                      if (url != null) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                  ),
                ),
              )),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                      onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edición próximamente. Por ahora, elimina y vuelve a subir.')));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Eliminar'),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Eliminar documento'),
                            content: const Text('¿Estás seguro de que deseas eliminar este documento de forma permanente?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true), 
                                child: const Text('Eliminar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                           try {
                             await supabase.from('user_documents').delete().eq('id', doc['id']);
                             ref.invalidate(userDocumentsProvider);
                             if (context.mounted) {
                               Navigator.pop(context); // Cierra bottom sheet
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento eliminado correctamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                             }
                           } catch(e) {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                             }
                           }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(userDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Documentos')),
      body: docsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No hay documentos', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final color = _getStatusColor(doc['expiry_date']);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  onTap: () => _showDocumentDetails(context, ref, doc),
                  borderRadius: BorderRadius.circular(16),
                  child: ModernCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.description, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc['title'] ?? 'Documento', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doc['document_type'] ?? '',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getStatusText(doc['expiry_date']), 
                                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          Icon(Icons.more_vert, color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadDocumentScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Subir Documento', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
