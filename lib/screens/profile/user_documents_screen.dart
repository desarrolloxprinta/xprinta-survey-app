import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_documents_provider.dart';
import '../../widgets/modern_card.dart';
import 'upload_document_screen.dart';

class UserDocumentsScreen extends ConsumerWidget {
  const UserDocumentsScreen({super.key});

  Color _getStatusColor(String? expiryDate) {
    if (expiryDate == null) return Colors.green;
    final expiry = DateTime.parse(expiryDate);
    final diff = expiry.difference(DateTime.now()).inDays;
    
    if (diff < 0) return Colors.red;
    if (diff <= 30) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(String? expiryDate) {
    if (expiryDate == null) return 'Sin caducidad';
    final expiry = DateTime.parse(expiryDate);
    final diff = expiry.difference(DateTime.now()).inDays;
    
    if (diff < 0) return 'Caducado';
    if (diff <= 30) return 'Próximo a caducar ($diff días)';
    return 'Vigente';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(userDocumentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis Documentos')),
      body: docsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return const Center(child: Text('No has subido ningún documento.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final color = _getStatusColor(doc['expiry_date']);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ModernCard(
                  child: ListTile(
                    leading: Icon(Icons.description, color: color, size: 32),
                    title: Text(doc['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc['document_type']),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(_getStatusText(doc['expiry_date']), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                          ],
                        )
                      ],
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
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadDocumentScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Documento'),
      ),
    );
  }
}
