import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import '../../main.dart'; // supabase

class SignatureScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const SignatureScreen({super.key, required this.projectData});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _nameCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isGenerating = false;
  int _ratingPuntualidad = 0;
  int _ratingCalidad = 0;
  int _ratingLimpieza = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dniCtrl.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _generateAndUploadPdf() async {
    if (_nameCtrl.text.isEmpty || _dniCtrl.text.isEmpty || _signatureController.isEmpty || _ratingPuntualidad == 0 || _ratingCalidad == 0 || _ratingLimpieza == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor rellena nombre, DNI, firma y todas las valoraciones.')));
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS desactivado. Actívalo para generar el albarán.');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Permiso GPS denegado.');
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Signature Image
      final signatureImageBytes = await _signatureController.toPngBytes();
      if (signatureImageBytes == null) throw Exception('Error procesando firma');

      // PDF Generation
      final pdf = pw.Document();
      final dateStr = DateTime.now().toLocal().toString();
      final signatureImage = pw.MemoryImage(signatureImageBytes);

      // Fonts
      final fontHeading = await PdfGoogleFonts.questrialRegular();
      final fontBody = await PdfGoogleFonts.manropeRegular();
      final fontBodyBold = await PdfGoogleFonts.manropeBold();

      // Logo & Colors
      final logoData = await rootBundle.load('assets/images/logo-xprinta-blanco.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      final colorPrimary = PdfColor.fromHex('#fa8029');
      final colorDark = PdfColor.fromHex('#252930');
      final colorLight = PdfColor.fromHex('#f7f7f7');
      final colorGrey = PdfColor.fromHex('#5f6062');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: fontBody, bold: fontBodyBold),
          header: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(20),
              margin: const pw.EdgeInsets.only(bottom: 20),
              decoration: pw.BoxDecoration(
                color: colorDark,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(logoImage, height: 40),
                  pw.Text(
                    'ALBARÁN DE MEDICIÓN',
                    style: pw.TextStyle(
                      font: fontHeading,
                      fontSize: 20,
                      color: colorPrimary,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: colorLight,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DATOS DEL PROYECTO', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Referencia', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                              pw.Text(widget.projectData['nombre'] ?? 'Sin referencia', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            ]
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Instalación / Cliente', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                              pw.Text(widget.projectData['direccion'] ?? 'Sin dirección', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            ]
                          ),
                        ),
                      ]
                    )
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text('DECLARACIÓN DE CONFORMIDAD', style: pw.TextStyle(font: fontHeading, fontSize: 16, color: colorDark, fontWeight: pw.FontWeight.bold)),
              pw.Divider(color: colorPrimary, thickness: 2),
              pw.SizedBox(height: 12),
              pw.Text(
                'Por la presente, el abajo firmante, en calidad de responsable o persona autorizada en el lugar de la instalación, certifica que el equipo técnico de Xprinta ha accedido a las instalaciones indicadas para realizar las labores de medición técnica correspondientes al proyecto referenciado.',
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Se declara que los trabajos de inspección y toma de datos se han ejecutado de forma satisfactoria. Este documento electrónico sirve como resguardo y comprobante inmutable de la visita.',
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
              pw.SizedBox(height: 32),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DATOS DEL FIRMANTE', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Text('Nombre y Apellidos:', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                        pw.Text(_nameCtrl.text, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text('DNI / NIE:', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                        pw.Text(_dniCtrl.text, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 16),
                        pw.Text('SELLO DE TIEMPO Y GPS', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Text('Fecha de firma:', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                        pw.Text(dateStr, style: pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 8),
                        pw.Text('Coordenadas GPS:', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                        pw.Text('${position.latitude}, ${position.longitude}', style: pw.TextStyle(fontSize: 11)),
                        pw.SizedBox(height: 16),
                        pw.Text('VALORACIÓN DEL CLIENTE', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: colorGrey, width: 0.5),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Puntualidad: $_ratingPuntualidad / 5', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('Calidad de atención: $_ratingCalidad / 5', style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('Limpieza: $_ratingLimpieza / 5', style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 16),
                        pw.Text('DECLARACIÓN DE CONFORMIDAD Y VALIDEZ LEGAL', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'De conformidad con el Reglamento (UE) nº 910/2014 (eIDAS) y la Ley 6/2020 reguladora de determinados aspectos de los servicios electrónicos de confianza, la presente firma electrónica recoge el consentimiento expreso del cliente, vinculando su identidad, sello de tiempo y coordenadas GPS a la conformidad de los trabajos de medición descritos en este documento.',
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('FIRMA DIGITALIZADA', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 12),
                        pw.Container(
                          height: 140,
                          width: double.infinity,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 1),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          ),
                          child: pw.Center(child: pw.Image(signatureImage)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Text(
                  'Este documento ha sido generado automáticamente por el sistema de Gestión Xprinta y tiene plena validez legal como comprobante de asistencia.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      
      // Upload to Supabase Storage
      final projectId = widget.projectData['id'];
      final filename = 'albaran_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = 'albaranes/$projectId/$filename';
      
      await supabase.storage.from('project-files').uploadBinary(path, bytes);
      
      // Register in files table
      await supabase.from('files').insert({
        'project_id': projectId,
        'category': 'albaran_medicion',
        'filename': 'Albarán de Medición',
        'storage_path': path,
        'bucket': 'project-files',
        'size_bytes': bytes.length,
        'mime_type': 'application/pdf',
        'uploaded_by': supabase.auth.currentUser?.id,
      });

      // Update project phase to medicion_realizada
      await supabase.from('projects').update({
        'measurement_phase': 'medicion_realizada',
        'measurement_completed_date': DateTime.now().toIso8601String(),
        'client_rating': _ratingCalidad, // Retained for fallback
        'rating_puntualidad': _ratingPuntualidad,
        'rating_calidad': _ratingCalidad,
        'rating_limpieza': _ratingLimpieza,
      }).eq('id', projectId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Albarán generado y guardado.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _buildRatingRow(String label, int currentRating, Function(int) onUpdate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Row(
            children: List.generate(5, (index) {
              return InkWell(
                onTap: () => onUpdate(index + 1),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    index < currentRating ? Icons.star : Icons.star_border,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firma de Albarán'), elevation: 0),
      body: _isGenerating 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text('DECLARACIÓN DE CONFORMIDAD', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Por la presente, el abajo firmante, en calidad de responsable o persona autorizada en el lugar de la instalación, certifica que el equipo técnico de Xprinta ha accedido a las instalaciones indicadas para realizar las labores de medición técnica correspondientes al proyecto referenciado.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Se declara que los trabajos de inspección y toma de datos se han ejecutado de forma satisfactoria. Este documento electrónico sirve como resguardo y comprobante inmutable de la visita.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre y Apellidos del Responsable', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dniCtrl,
                decoration: const InputDecoration(labelText: 'DNI / NIE', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),
              const Text('Valoración del Servicio:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildRatingRow('Puntualidad', _ratingPuntualidad, (val) => setState(() => _ratingPuntualidad = val)),
                    _buildRatingRow('Calidad de atención', _ratingCalidad, (val) => setState(() => _ratingCalidad = val)),
                    _buildRatingRow('Limpieza', _ratingLimpieza, (val) => setState(() => _ratingLimpieza = val)),
                  ],
                ),
              ),
              if (_ratingPuntualidad == 0 || _ratingCalidad == 0 || _ratingLimpieza == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Center(child: Text('Selecciona al menos una estrella en cada aspecto', style: TextStyle(color: Colors.red, fontSize: 12))),
                ),
              const SizedBox(height: 32),
              const Text('Firma en el recuadro:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Signature(
                    controller: _signatureController,
                    height: 250,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _signatureController.clear(),
                    icon: const Icon(Icons.clear),
                    label: const Text('Limpiar Firma'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _generateAndUploadPdf,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Generar Albarán y Finalizar', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
    );
  }
}
