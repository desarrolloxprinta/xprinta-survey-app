import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../main.dart';
import '../../providers/user_documents_provider.dart';
import '../../widgets/modern_card.dart';

const List<String> documentTypes = [
  'DNI',
  'Pasaporte',
  'Permiso de conducir',
  'Permiso de trabajo',
  'Certificado de salud',
  'Formación en seguridad',
  'Permiso de trabajo en altura',
  'Permiso eléctrico',
  'Otros'
];

class UploadDocumentScreen extends ConsumerStatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  ConsumerState<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends ConsumerState<UploadDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _selectedType = documentTypes.first;
  final _titleCtrl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;
  final _notesCtrl = TextEditingController();
  
  List<File> _selectedFiles = [];
  bool _isUploading = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.paths.where((p) => p != null).map((p) => File(p!)));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes adjuntar al menos un archivo', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No autenticado');

      List<Map<String, dynamic>> uploadedFilesMeta = [];

      for (var file in _selectedFiles) {
        final ext = file.path.split('.').last;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = '${user.id}/${timestamp}_document.$ext';

        final bytes = await file.readAsBytes();
        await supabase.storage.from('user-documents').uploadBinary(filename, bytes);
        
        final url = supabase.storage.from('user-documents').getPublicUrl(filename);
        
        uploadedFilesMeta.add({
          'name': file.path.split('/').last,
          'url': url,
          'path': filename,
        });
      }

      await supabase.from('user_documents').insert({
        'user_id': user.id,
        'document_type': _selectedType,
        'title': _titleCtrl.text,
        'issue_date': _issueDate?.toIso8601String(),
        'expiry_date': _expiryDate?.toIso8601String(),
        'notes': _notesCtrl.text,
        'files': uploadedFilesMeta,
      });

      ref.invalidate(userDocumentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento subido correctamente', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isExpiry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) {
          _expiryDate = picked;
        } else {
          _issueDate = picked;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir Documento')),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ModernCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tipo de documento', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              isExpanded: true,
                              items: documentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedType = val);
                              },
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 16),
                            const Text('Título descriptivo *', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _titleCtrl,
                              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Ej. DNI Reverso'),
                              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Fecha Emisión', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _selectDate(context, false),
                                        icon: const Icon(Icons.calendar_today, size: 16),
                                        label: Text(_issueDate != null ? "${_issueDate!.day}/${_issueDate!.month}/${_issueDate!.year}" : 'Seleccionar'),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Fecha Caducidad', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _selectDate(context, true),
                                        icon: const Icon(Icons.calendar_today, size: 16),
                                        label: Text(_expiryDate != null ? "${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}" : 'Seleccionar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Notas adicionales', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Observaciones...'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ModernCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Archivos Adjuntos *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            const Text('Soporta PDF, JPG, PNG, WEBP (Máx. 10MB/archivo)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Seleccionar Archivos'),
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            ),
                            if (_selectedFiles.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ..._selectedFiles.map((f) => ListTile(
                                leading: const Icon(Icons.file_present),
                                title: Text(f.path.split('/').last, overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => setState(() => _selectedFiles.remove(f)),
                                ),
                              ))
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Guardar Documento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
