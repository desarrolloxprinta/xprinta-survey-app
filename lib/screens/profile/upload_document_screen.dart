import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../main.dart';
import '../../providers/user_documents_provider.dart';
import '../../widgets/modern_card.dart';

const Map<String, String> documentTypeMap = {
  'DNI': 'dni',
  'Pasaporte': 'passport',
  'Permiso de conducir': 'driving_license',
  'Permiso de trabajo': 'work_permit',
  'Certificado de salud': 'health_certificate',
  'Formación en seguridad': 'safety_training',
  'Permiso de trabajo en altura': 'height_work_permit',
  'Permiso eléctrico': 'electrical_permit',
  'Otros': 'otros',
};
final List<String> documentTypes = documentTypeMap.keys.toList();

class UploadDocumentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existingDoc;

  const UploadDocumentScreen({super.key, this.existingDoc});

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
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingDoc != null) {
      final doc = widget.existingDoc!;
      if (doc['document_type'] != null) {
        final key = documentTypeMap.entries.firstWhere((e) => e.value == doc['document_type'], orElse: () => const MapEntry('Otros', 'otros')).key;
        _selectedType = key;
      }
      _titleCtrl.text = doc['title'] ?? '';
      _notesCtrl.text = doc['notes'] ?? '';
      if (doc['issue_date'] != null) _issueDate = DateTime.tryParse(doc['issue_date']);
      if (doc['expiry_date'] != null) _expiryDate = DateTime.tryParse(doc['expiry_date']);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (result != null) {
      final newFiles = result.paths.where((p) => p != null).map((p) => File(p!)).toList();
      setState(() {
        _selectedFiles.addAll(newFiles);
      });
      
      // Auto-analyze first selected file if it's an image
      if (newFiles.isNotEmpty && _issueDate == null && _expiryDate == null) {
        _analyzeDocumentWithAI(newFiles.first);
      }
    }
  }

  Future<void> _analyzeDocumentWithAI(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) return;

    setState(() => _isAnalyzing = true);
    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      String mimeType = 'image/jpeg';
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'webp') mimeType = 'image/webp';

      final response = await supabase.functions.invoke('analyze-document', body: {
        'imageBase64': base64Image,
        'mimeType': mimeType,
        'documentType': _selectedType,
      });

      if (response.data != null) {
        final data = response.data;
        if (data['error'] != null) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('IA: ${data['error']}')));
        } else {
           if (mounted) {
             setState(() {
               if (data['issue_date'] != null) _issueDate = DateTime.tryParse(data['issue_date']);
               if (data['expiry_date'] != null) _expiryDate = DateTime.tryParse(data['expiry_date']);
             });
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fechas autocompletadas por IA ✨'), backgroundColor: Colors.green));
           }
        }
      }
    } catch (e) {
      debugPrint('Error en IA: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty && widget.existingDoc == null) {
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
      
      List<Map<String, dynamic>> finalFiles = [];
      if (widget.existingDoc != null && widget.existingDoc!['files'] != null) {
        finalFiles.addAll(List<Map<String, dynamic>>.from(widget.existingDoc!['files']));
      }
      finalFiles.addAll(uploadedFilesMeta);

      final data = {
        'document_type': documentTypeMap[_selectedType],
        'title': _titleCtrl.text,
        'issue_date': _issueDate?.toIso8601String(),
        'expiry_date': _expiryDate?.toIso8601String(),
        'notes': _notesCtrl.text,
        'files': finalFiles,
      };

      if (widget.existingDoc == null) {
        data['user_id'] = user.id;
        await supabase.from('user_documents').insert(data);
      } else {
        await supabase.from('user_documents').update(data).eq('id', widget.existingDoc!['id']);
      }

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
    final isEditing = widget.existingDoc != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar Documento' : 'Subir Documento')),
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
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _selectDate(context, false),
                                          icon: const Icon(Icons.calendar_today, size: 16),
                                          label: Text(_issueDate != null ? "${_issueDate!.day}/${_issueDate!.month}/${_issueDate!.year}" : 'Seleccionar'),
                                        ),
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
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: null, // Bloqueado, solo IA puede rellenarlo
                                          icon: const Icon(Icons.lock, size: 16),
                                          label: Text(_expiryDate != null ? "${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}" : 'Automático por IA'),
                                        ),
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
                            if (isEditing)
                              const Padding(
                                padding: EdgeInsets.only(top: 4.0),
                                child: Text('Sube nuevos archivos para añadirlos a los existentes.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                            const SizedBox(height: 8),
                            const Text('Soporta PDF, JPG, PNG, WEBP (Máx. 10MB/archivo)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _pickFiles,
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text('Seleccionar Archivos'),
                              ),
                            ),
                            if (_isAnalyzing)
                              const Padding(
                                padding: EdgeInsets.only(top: 16.0),
                                child: Row(
                                  children: [
                                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                    SizedBox(width: 12),
                                    Text('Analizando documento con IA...', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                  ],
                                ),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _submit,
                        child: _isUploading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar Documento'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
