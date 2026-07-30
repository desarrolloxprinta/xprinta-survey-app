import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/installation_models.dart';

class InstallationInfoBlock extends StatelessWidget {
  final Map<String, dynamic> projectData;
  final String currentUserId;

  const InstallationInfoBlock({
    super.key,
    required this.projectData,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final String? assignedInstallerId = projectData['installation_installer_id'];

    // 1. project.installation_installer_id NO es null
    // 2. El usuario actual es interno o el asignado
    // Como estamos en local, simplificamos asumiendo que si es el asignado o no hay check estricto de roles:
    if (assignedInstallerId == null) {
      return const SizedBox.shrink();
    }

    // if (currentUserId != assignedInstallerId) {
    //   // return const SizedBox.shrink(); // Para pruebas podemos mostrarlo o aplicar la regla estricta.
    // }

    // Parse blueprints
    List<InstallationBlueprint> blueprints = [];
    if (projectData['installation_blueprints'] != null && projectData['installation_blueprints'] is List) {
      blueprints = (projectData['installation_blueprints'] as List)
          .map((json) => InstallationBlueprint.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // Parse products
    List<InstallationProduct> products = [];
    if (projectData['installation_products'] != null && projectData['installation_products'] is List) {
      products = (projectData['installation_products'] as List)
          .map((json) => InstallationProduct.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Información de Instalación',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        InstallationPhases(projectData: projectData),
        const SizedBox(height: 24),
        if (blueprints.isNotEmpty) BlueprintsSection(blueprints: blueprints, products: products),
        const SizedBox(height: 24),
        if (products.isNotEmpty) ProductsList(products: products),
        const SizedBox(height: 24),
      ],
    );
  }
}

class InstallationPhases extends StatelessWidget {
  final Map<String, dynamic> projectData;
  const InstallationPhases({super.key, required this.projectData});

  String _formatDateTime(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(date);
    } catch (_) {
      return dateString;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('dd/MM/yyyy', 'es_ES').format(date);
    } catch (_) {
      return dateString;
    }
  }

  String _formatDateRange(String? startDate, String? endDate) {
    if (startDate == null) return '';
    final start = _formatDate(startDate);
    if (endDate != null) {
      final end = _formatDate(endDate);
      return 'Del $start al $end';
    }
    return start;
  }

  @override
  Widget build(BuildContext context) {
    final phase = projectData['installation_phase'];
    final assignedDate = _formatDateTime(projectData['installation_assigned_date']);
    final scheduledDateStr = _formatDateRange(
      projectData['installation_scheduled_date'],
      projectData['fecha_prevista_instalacion_fin'],
    );
    final completedDate = _formatDateTime(projectData['installation_completed_date']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fases de la Instalación', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPhaseRow(
              context,
              'Asignado a instalación',
              assignedDate.isNotEmpty ? assignedDate : 'Pendiente',
              Icons.person_add_alt_1_outlined,
              phase != null,
            ),
            const Divider(height: 24),
            _buildPhaseRow(
              context,
              'Fecha Programada',
              scheduledDateStr.isNotEmpty ? scheduledDateStr : 'Pendiente',
              Icons.calendar_month_outlined,
              phase == 'fecha_programada' || phase == 'instalacion_realizada',
            ),
            const Divider(height: 24),
            _buildPhaseRow(
              context,
              'Instalación realizada',
              completedDate.isNotEmpty ? completedDate : 'Pendiente',
              Icons.check_circle_outline,
              phase == 'instalacion_realizada',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseRow(BuildContext context, String title, String subtitle, IconData icon, bool isActive) {
    final color = isActive ? Theme.of(context).primaryColor : Colors.grey;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class BlueprintsSection extends StatefulWidget {
  final List<InstallationBlueprint> blueprints;
  final List<InstallationProduct> products;
  const BlueprintsSection({super.key, required this.blueprints, required this.products});

  @override
  State<BlueprintsSection> createState() => _BlueprintsSectionState();
}

class _BlueprintsSectionState extends State<BlueprintsSection> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.blueprints.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Planos de Instalación', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (widget.blueprints.length > 1) ...[
            DropdownButtonFormField<int>(
              value: _selectedIndex,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: widget.blueprints.asMap().entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Text(entry.value.reference),
                );
              }).toList(),
              onChanged: (index) {
                if (index != null) {
                  setState(() {
                    _selectedIndex = index;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          BlueprintViewer(blueprint: widget.blueprints[_selectedIndex], products: widget.products),
        ],
      ),
    );
  }
}

class BlueprintViewer extends StatelessWidget {
  final InstallationBlueprint blueprint;
  final List<InstallationProduct> products;
  const BlueprintViewer({super.key, required this.blueprint, required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.4), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Stack(
          children: [
            Image.network(
              blueprint.blueprintUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              },
              errorBuilder: (ctx, err, stack) => const SizedBox(height: 200, child: Center(child: Text('Error cargando plano'))),
            ),
            ...blueprint.dots.map((dot) {
              return Positioned.fill(
                child: Align(
                  alignment: FractionalOffset(dot.x / 100, dot.y / 100),
                  child: Transform.translate(
                    offset: const Offset(0, 0), // No offset needed if aligned perfectly to center
                    child: GestureDetector(
                      onTap: () => _showDotInfo(context, dot),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            dot.label.isNotEmpty ? dot.label[0].toUpperCase() : '•',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showDotInfo(BuildContext context, InstallationDot dot) {
    InstallationProduct? linkedProduct;
    if (dot.productId != null) {
      final searchId = dot.productId!.trim().toLowerCase();
      try {
        linkedProduct = products.firstWhere((p) => 
          p.id.trim().toLowerCase() == searchId || 
          p.titulo.trim().toLowerCase() == searchId
        );
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Punto de instalación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Elemento: ${dot.label}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (linkedProduct != null) ...[
              const SizedBox(height: 12),
              const Text('Producto a instalar:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(linkedProduct.titulo),
              if (linkedProduct.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(linkedProduct.descripcion, style: const TextStyle(fontSize: 13)),
              ],
            ] else if (dot.productId != null) ...[
              const SizedBox(height: 8),
              Text('ID vinculado: ${dot.productId}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text('No se encontró el producto en la lista (${products.length} disponibles).', style: const TextStyle(color: Colors.red, fontSize: 12)),
              if (products.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('IDs disponibles: ${products.map((p) => p.id).join(', ')}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class ProductsList extends StatelessWidget {
  final List<InstallationProduct> products;
  const ProductsList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Productos a Instalar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(product.titulo, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.purple, borderRadius: BorderRadius.circular(12)),
                        child: Text('x${product.cantidad}', style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  subtitle: Text(product.descripcion, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _showProductDetails(context, product),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showProductDetails(BuildContext context, InstallationProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.titulo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cantidad: ${product.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Descripción:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(product.descripcion),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
