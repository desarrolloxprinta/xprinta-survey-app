import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart'; // supabase
import '../../widgets/modern_card.dart';
import '../../core/notification_service.dart';
import '../measurement_detail_screen.dart';

final projectsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await supabase
      .from('projects')
      .select('id, nombre, direccion, measurement_phase, measurement_assigned_date, scheduled_visit_date, descripcion, cliente_nombre_apellido, cliente_nombre_local, cliente_telefono, elementos, planos_tecnicos, form_data, form_template_id, companies(nombre), mediciones(id, nombre)')
      .order('measurement_assigned_date', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(response);
});

class MeasurementsTab extends ConsumerStatefulWidget {
  const MeasurementsTab({super.key});

  @override
  ConsumerState<MeasurementsTab> createState() => _MeasurementsTabState();
}

class _MeasurementsTabState extends ConsumerState<MeasurementsTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final projectsAsync = ref.watch(projectsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(projectsProvider);
        // Esperar a que el provider se resuelva de nuevo
        await ref.read(projectsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
        children: [
          Text(
          'Proyectos Asignados',
          style: textTheme.titleLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona un rótulo para medir',
          style: textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 24),
        
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o dirección...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
        const SizedBox(height: 24),
        
        projectsAsync.when(
          skipLoadingOnRefresh: false,
          data: (allProjects) {
            final projects = allProjects.where((p) {
              final nombre = (p['nombre'] ?? '').toLowerCase();
              final direccion = (p['direccion'] ?? '').toLowerCase();
              return nombre.contains(_searchQuery) || direccion.contains(_searchQuery);
            }).toList();

            if (projects.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_turned_in, size: 64, color: Theme.of(context).primaryColor.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text('No tienes proyectos pendientes', style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              );
            }

            final asignados = projects.where((p) => (p['measurement_phase'] ?? '') == 'asignado_medicion' || (p['measurement_phase'] ?? '') == 'desconocido').toList();
            final agendados = projects.where((p) => (p['measurement_phase'] ?? '') == 'visita_agendada').toList();
            final medidos = projects.where((p) => (p['measurement_phase'] ?? '') == 'medicion_realizada').toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHorizontalSection(context, 'Visitas Agendadas', agendados, ref),
                _buildHorizontalSection(context, 'Proyectos Asignados', asignados, ref),
                _buildHorizontalSection(context, 'Proyectos Medidos', medidos, ref),
              ],
            );
          },
          loading: () => _buildShimmerLoader(context),
          error: (err, stack) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('Error al cargar proyectos: $err', style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalSection(BuildContext context, String title, List<Map<String, dynamic>> projects, WidgetRef ref) {
    if (projects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 16),
        SizedBox(
          height: 380, // Aumentado para evitar overflow con la nueva caja de mediciones
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: projects.length,
            itemBuilder: (context, index) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 400 + (index * 150).clamp(0, 900)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(50 * (1 - value), 0),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16),
                  child: _buildProjectCardFor(context, projects[index], ref),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildShimmerLoader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShimmerSection(context),
        _buildShimmerSection(context),
      ],
    );
  }

  Widget _buildShimmerSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerLoading(
          child: Container(
            width: 200,
            height: 28,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          ),
        ),
        SizedBox(
          height: 380, // Aumentado en concordancia con el listView principal
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (ctx, idx) => ShimmerLoading(
              child: Container(
                width: 300,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildProjectCardFor(BuildContext context, Map<String, dynamic> p, WidgetRef ref) {
    // Mapeo de Fase
    String phaseStr = p['measurement_phase'] ?? 'desconocido';
    String statusLabel;
    Color statusColor;
    
    switch(phaseStr) {
      case 'asignado_medicion':
        statusLabel = 'Asignado a medición';
        statusColor = Colors.blue;
        break;
      case 'visita_agendada':
        statusLabel = 'Visita Agendada';
        statusColor = Colors.orange;
        break;
      case 'medicion_realizada':
        statusLabel = 'Medición realizada';
        statusColor = Colors.green;
        break;
      default:
        statusLabel = 'Asignado a medición'; // Fallback
        statusColor = Colors.blue;
    }
    
    // Mapeo de Workspace (companies)
    String workspaceName = 'Workspace desconocido';
    if (p['companies'] != null && p['companies']['nombre'] != null) {
      workspaceName = p['companies']['nombre'];
    }

    // Mapeo de Fecha y Recordatorios
    String assignedDateStr = 'Sin fecha';
    if (p['measurement_assigned_date'] != null) {
        assignedDateStr = p['measurement_assigned_date'].toString().substring(0, 10);
    }

    String? scheduledDateStr;
    if (phaseStr == 'visita_agendada' && p['scheduled_visit_date'] != null) {
      // Si hay visita agendada, formatear la fecha
      DateTime visitDate = DateTime.parse(p['scheduled_visit_date'].toString()).toLocal();
      scheduledDateStr = '${visitDate.day.toString().padLeft(2, '0')}/${visitDate.month.toString().padLeft(2, '0')}/${visitDate.year} ${visitDate.hour.toString().padLeft(2, '0')}:${visitDate.minute.toString().padLeft(2, '0')}';
      
      // Programar recordatorio local silenciosamente
      NotificationService().scheduleVisitReminder(
        p['id'].toString(), 
        p['nombre'] ?? 'Proyecto', 
        visitDate
      );
    }

    // Extraer mediciones realizadas
    int measurementsCount = 0;
    List<String> measuredNames = [];
    if (p['mediciones'] != null && p['mediciones'] is List) {
      final mList = p['mediciones'] as List;
      measurementsCount = mList.length;
      for (var m in mList) {
        if (m is Map && m['nombre'] != null && m['nombre'].toString().isNotEmpty) {
          measuredNames.add(m['nombre'].toString());
        }
      }
    }

    return _buildProjectCard(
      context,
      id: p['id'].toString(),
      title: p['nombre'] ?? 'Sin nombre',
      workspace: workspaceName,
      address: p['direccion'] ?? 'Sin dirección',
      assignedDate: assignedDateStr,
      scheduledDate: scheduledDateStr,
      status: statusLabel,
      statusColor: statusColor,
      measurementsCount: measurementsCount,
      measuredNames: measuredNames,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MeasurementDetailScreen(projectData: p),
          ),
        );
        if (result == true) {
          ref.invalidate(projectsProvider); // Recargar proyectos si hubo cambios
        }
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, {
    required String id,
    required String title,
    required String workspace,
    required String address,
    required String assignedDate,
    String? scheduledDate,
    required String status,
    required Color statusColor,
    required int measurementsCount,
    required List<String> measuredNames,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ModernCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pill de Estatus estilo Neumórfico
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? statusColor.withOpacity(0.15) : statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: isDark ? statusColor : statusColor.withOpacity(0.9), 
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_ios, color: textTheme.bodyMedium?.color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Hero(
            tag: 'title-$id',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                title,
                style: textTheme.titleLarge?.copyWith(fontSize: 19, letterSpacing: -0.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.business_outlined, color: textTheme.bodyMedium?.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  workspace,
                  style: textTheme.bodyMedium?.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, color: textTheme.bodyMedium?.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: textTheme.bodyMedium?.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Fecha de Asignación
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: textTheme.bodyMedium?.color?.withOpacity(0.6), size: 16),
              const SizedBox(width: 8),
              Text(
                'Asignado: $assignedDate',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
          
          if (measurementsCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text('$measurementsCount mediciones realizadas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                    ],
                  ),
                  if (measuredNames.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      measuredNames.join(', '),
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
          
          if (scheduledDate != null) ...[
            const SizedBox(height: 8),
            // Fecha Agendada Destacada
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.alarm, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Visita: $scheduledDate',
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }
  
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(opacity: _animation.value, child: child),
      child: widget.child,
    );
  }
}
