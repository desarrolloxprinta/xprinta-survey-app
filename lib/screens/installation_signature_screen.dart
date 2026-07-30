import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import '../main.dart'; // supabase

class InstallationSignatureScreen extends StatefulWidget {
  final Map<String, dynamic> projectData;
  const InstallationSignatureScreen({super.key, required this.projectData});

  @override
  State<InstallationSignatureScreen> createState() => _InstallationSignatureScreenState();
}

class _InstallationSignatureScreenState extends State<InstallationSignatureScreen> {
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

  String _formatSlug(String slug) {
    if (slug.isEmpty) return slug;
    final Map<String, String> dict = {
      'rotulo_sin_luz': 'Rótulo sin luz',
      'rotulo_luminoso': 'Rótulo luminoso',
      'vinilo': 'Vinilo decorativo / publicitario',
      'letras_corporeas': 'Letras corpóreas',
      'banderola': 'Banderola de fachada',
      'impresion_digital': 'Impresión digital',
      'lonas': 'Lona publicitaria Frontlit',
      'placa_metacrilato': 'Placa metacrilato',
      'senyaletica': 'Señalética corporativa',
      'escaparate': 'Rotulación de escaparate'
    };
    if (dict.containsKey(slug)) return dict[slug]!;
    
    final words = slug.replaceAll('_', ' ').split(' ');
    if (words.isEmpty) return slug;
    words[0] = words[0].substring(0, 1).toUpperCase() + words[0].substring(1);
    return words.join(' ');
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
      if (!serviceEnabled) throw Exception('GPS desactivado. Actívalo para generar el comprobante.');
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
      final dateStr = DateTime.now().toLocal().toString().substring(0, 16);
      final signatureImage = pw.MemoryImage(signatureImageBytes);

      // Fonts
      final fontHeading = await PdfGoogleFonts.questrialRegular();
      final fontBody = await PdfGoogleFonts.manropeRegular();
      final fontBodyBold = await PdfGoogleFonts.manropeBold();

      // Logo & Colors
      final logoData = await rootBundle.load('assets/images/logo-xprinta-blanco.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      final colorPrimary = PdfColor.fromHex('#fa8029'); // Orange Xprinta
      final colorDark = PdfColor.fromHex('#252930');
      final colorLight = PdfColor.fromHex('#f7f7f7');
      final colorGrey = PdfColor.fromHex('#5f6062');

      // Prepare items table data from installation_products
      List<Map<String, dynamic>> products = [];
      if (widget.projectData['installation_products'] != null && widget.projectData['installation_products'] is List) {
        products = List<Map<String, dynamic>>.from(widget.projectData['installation_products']);
      }

      final clientName = widget.projectData['cliente_nombre_apellido'] ?? 'Cliente';
      final clientLocal = widget.projectData['cliente_nombre_local'] ?? '';
      final address = widget.projectData['direccion'] ?? 'Dirección de instalación';
      final workspace = (widget.projectData['companies'] != null) ? widget.projectData['companies']['nombre'] : 'Xprinta';

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
                  // Solo el logo, sin texto

                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // 1. Datos del proyecto y dirección de entrega
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
                    pw.Text('DATOS DE ENTREGA E INSTALACIÓN', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Proyecto / Referencia', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                              pw.Text(widget.projectData['nombre'] ?? 'Sin referencia', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 6),
                              pw.Text('Empresa / Workspace', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                              pw.Text(workspace, style: pw.TextStyle(fontSize: 11)),
                            ]
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Cliente / Contacto', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                              pw.Text('$clientName ${clientLocal.isNotEmpty ? "($clientLocal)" : ""}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 6),
                              pw.Text('Dirección de Instalación', style: pw.TextStyle(color: colorGrey, fontSize: 10)),
                              pw.Text(address, style: pw.TextStyle(fontSize: 11)),
                            ]
                          ),
                        ),
                      ]
                    )
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // 2. Tabla de Elementos Instalados
              pw.Text('PRODUCTOS Y ELEMENTOS INSTALADOS', style: pw.TextStyle(font: fontHeading, fontSize: 14, color: colorDark, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              
              if (products.isNotEmpty)
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: colorDark),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Descripción del Elemento / Trabajo', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Cantidad', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    ...products.map((prod) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(prod['titulo'] ?? '', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 2),
                                pw.Text(prod['descripcion'] ?? '', style: const pw.TextStyle(fontSize: 8)),
                              ]
                            )
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(prod['cantidad']?.toString() ?? '1', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      );
                    }),
                  ],
                )
              else
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: pw.Text('Instalación general y rótulos del proyecto', style: const pw.TextStyle(fontSize: 10)),
                ),

              pw.SizedBox(height: 20),

              // 3. Texto legal de conformidad
              pw.Text(
                'Mediante la presente firma, el abajo firmante (cliente o representante autorizado) declara su entera conformidad con los trabajos de instalación descritos anteriormente. Se certifica que los elementos han sido entregados, instalados y revisados, y que se encuentran en perfectas condiciones de funcionamiento y acabado, de acuerdo a las especificaciones del proyecto contratado.',
                style: const pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.justify,
              ),

              pw.SizedBox(height: 40),
              // 3. Declaración de Conformidad Legal (eIDAS / Ley 6/2020)
              pw.Text('DECLARACIÓN DE CONFORMIDAD Y RECEPCIÓN', style: pw.TextStyle(font: fontHeading, fontSize: 14, color: colorDark, fontWeight: pw.FontWeight.bold)),
              pw.Divider(color: colorPrimary, thickness: 2),
              pw.SizedBox(height: 8),
              pw.Text(
                'Por la presente, el abajo firmante, en calidad de cliente, responsable o persona autorizada en el lugar de la entrega, certifica que los elementos y productos descritos en este documento han sido entregados e instalados satisfactoriamente por el equipo técnico de Xprinta, quedando comprobado su correcto funcionamiento, montaje y acabado.',
                style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Este comprobante digital inmutable firmado electrónicamente conforme al Reglamento (UE) Nº 910/2014 (eIDAS) y Ley 6/2020 vincula la firma con las coordenadas GPS y la marca de tiempo de finalización.',
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 24),

              // 4. Datos del Firmante, Ratings y Firma
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RESPONSABLE RECEPTOR', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.SizedBox(height: 6),
                        pw.Text('Nombre y Apellidos:', style: pw.TextStyle(color: colorGrey, fontSize: 9)),
                        pw.Text(_nameCtrl.text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        pw.Text('DNI / NIE:', style: pw.TextStyle(color: colorGrey, fontSize: 9)),
                        pw.Text(_dniCtrl.text, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 12),
                        pw.Text('SELLO DE TIEMPO Y GPS', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.SizedBox(height: 4),
                        pw.Text('Fecha: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Coordenadas: ${position.latitude}, ${position.longitude}', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 12),
                        pw.Text('VALORACIÓN DEL SERVICIO', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: colorGrey, width: 0.5)),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Puntualidad: $_ratingPuntualidad / 5', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('Calidad de Atención: $_ratingCalidad / 5', style: const pw.TextStyle(fontSize: 9)),
                              pw.Text('Limpieza de Trabajo: $_ratingLimpieza / 5', style: const pw.TextStyle(fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('FIRMA Y CONFORMIDAD', style: pw.TextStyle(color: colorPrimary, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          height: 120,
                          width: double.infinity,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Center(
                            child: pw.Image(signatureImage),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Conforme con la entrega e instalación', style: pw.TextStyle(color: colorGrey, fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final projectId = widget.projectData['id'];

      // Storage upload - Usamos nombre único para evitar problemas de caché en el navegador
      final filename = 'comprobante_instalacion_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final path = 'instalaciones/$projectId/$filename';
      
      await supabase.storage.from('project-files').uploadBinary(
        path,
        pdfBytes,
      );

      // Intentar borrar el registro anterior en BBDD para que no se duplique en la lista
      try {
        await supabase.from('files').delete().match({
          'project_id': projectId,
          'category': 'comprobante_instalacion',
        });
      } catch (_) {}

      // Save file record
      await supabase.from('files').insert({
        'project_id': projectId,
        'category': 'comprobante_instalacion',
        'filename': 'Comprobante de Instalación',
        'storage_path': path,
        'bucket': 'project-files',
        'size_bytes': pdfBytes.length,
      });

      // Update project phase to instalacion_realizada
      await supabase.from('projects').update({
        'installation_phase': 'instalacion_realizada',
        'installation_completed_date': DateTime.now().toIso8601String(),
        'rating_puntualidad': _ratingPuntualidad,
        'rating_calidad': _ratingCalidad,
        'rating_limpieza': _ratingLimpieza,
      }).eq('id', projectId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comprobante de Instalación generado y guardado.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar comprobante: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Widget _buildRatingSection(String title, int value, Function(int) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            return IconButton(
              iconSize: 32,
              icon: Icon(
                starValue <= value ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () => onSelected(starValue),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firma del Comprobante de Instalación'), elevation: 0),
      body: _isGenerating 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Datos de Recepción e Instalación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre y Apellidos del Responsable',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _dniCtrl,
                decoration: InputDecoration(
                  labelText: 'DNI / NIE / NIF',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Sección de 3 valoraciones
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.15)),
                ),
                child: Column(
                  children: [
                    Text('Valoración del Servicio de Instalación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor)),
                    const SizedBox(height: 16),
                    _buildRatingSection('1. Puntualidad en la entrega/cita', _ratingPuntualidad, (val) => setState(() => _ratingPuntualidad = val)),
                    const Divider(height: 20),
                    _buildRatingSection('2. Calidad de Atención y Montaje', _ratingCalidad, (val) => setState(() => _ratingCalidad = val)),
                    const Divider(height: 20),
                    _buildRatingSection('3. Limpieza tras la instalación', _ratingLimpieza, (val) => setState(() => _ratingLimpieza = val)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Texto legal explicativo en la app
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mediante la presente firma, declaras tu entera conformidad con los trabajos de instalación. Certificas que los elementos han sido instalados y revisados en perfectas condiciones según lo acordado.',
                        style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text('Firma Digital del Receptor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Signature(
                  controller: _signatureController,
                  height: 200,
                  backgroundColor: Colors.grey.shade100,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _signatureController.clear(),
                    child: const Text('Limpiar Firma'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _generateAndUploadPdf,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Generar Comprobante y Finalizar', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
    );
  }
}
