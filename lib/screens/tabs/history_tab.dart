import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart'; // supabase
import '../../widgets/modern_card.dart';
import '../measurement_history_detail_screen.dart';

import '../installation_history_detail_screen.dart';

final historyProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];
  
  // Fetch mediciones
  final medicionesFuture = supabase
      .from('mediciones')
      .select('*, projects(id, nombre, direccion, companies(id, nombre, logo_url))')
      .eq('measured_by', user.id);
      
  // Fetch instalaciones
  final instalacionesFuture = supabase
      .from('instalaciones')
      .select('*, projects(id, nombre, direccion, companies(id, nombre, logo_url))')
      .eq('installed_by', user.id);
      
  final results = await Future.wait([medicionesFuture, instalacionesFuture]);
  
  final mediciones = List<Map<String, dynamic>>.from(results[0]).map((m) {
    return {
      ...m,
      'history_type': 'medicion',
      'history_date': m['measurement_date'],
    };
  }).toList();
  
  final instalaciones = List<Map<String, dynamic>>.from(results[1]).map((i) {
    return {
      ...i,
      'history_type': 'instalacion',
      'history_date': i['installation_date'] ?? i['created_at'],
    };
  }).toList();
  
  final combined = [...mediciones, ...instalaciones];
  
  // Sort by date descending
  combined.sort((a, b) {
    final dateA = DateTime.tryParse(a['history_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateB = DateTime.tryParse(b['history_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return dateB.compareTo(dateA);
  });
      
  return combined;
});

class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  String _searchQuery = '';
  String? _selectedWorkspaceId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final historyAsync = ref.watch(historyProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
      children: [
        Text(
          'Historial de Actividad',
          style: textTheme.titleLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'Explora tus tomas de medida e instalaciones',
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
            hintText: 'Buscar por proyecto o rótulo...',
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
        const SizedBox(height: 16),
        
        historyAsync.when(
          data: (allMeasurements) {
            // Extraer workspaces únicos
            final Map<String, Map<String, dynamic>> workspacesMap = {};
            for (var m in allMeasurements) {
              final proj = m['projects'] as Map<String, dynamic>?;
              if (proj != null && proj['companies'] != null) {
                final comp = proj['companies'] as Map<String, dynamic>;
                final compId = comp['id'].toString();
                if (!workspacesMap.containsKey(compId)) {
                  workspacesMap[compId] = comp;
                }
              }
            }
            final workspaces = workspacesMap.values.toList();

            // Filtrar mediciones
            final filteredMeasurements = allMeasurements.where((m) {
              final nombreElemento = (m['nombre'] ?? '').toLowerCase();
              final proj = m['projects'] as Map<String, dynamic>?;
              final nombreProyecto = (proj?['nombre'] ?? '').toLowerCase();
              
              bool matchesSearch = nombreElemento.contains(_searchQuery) || nombreProyecto.contains(_searchQuery);
              bool matchesWorkspace = true;
              
              if (_selectedWorkspaceId != null) {
                final comp = proj?['companies'] as Map<String, dynamic>?;
                if (comp == null || comp['id'].toString() != _selectedWorkspaceId) {
                  matchesWorkspace = false;
                }
              }
              
              return matchesSearch && matchesWorkspace;
            }).toList();

            // Agrupar por proyecto
            final Map<String, List<Map<String, dynamic>>> groupedByProject = {};
            final Map<String, Map<String, dynamic>> projectDataMap = {};
            
            for (var m in filteredMeasurements) {
              final proj = m['projects'] as Map<String, dynamic>?;
              if (proj != null) {
                final projId = proj['id'].toString();
                if (!groupedByProject.containsKey(projId)) {
                  groupedByProject[projId] = [];
                  projectDataMap[projId] = proj;
                }
                groupedByProject[projId]!.add(m);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (workspaces.isNotEmpty) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Todos'),
                          selected: _selectedWorkspaceId == null,
                          onSelected: (selected) {
                            setState(() {
                              _selectedWorkspaceId = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ...workspaces.map((w) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(w['nombre'] ?? 'Desconocido'),
                              selected: _selectedWorkspaceId == w['id'].toString(),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedWorkspaceId = selected ? w['id'].toString() : null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (groupedByProject.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 64, color: Theme.of(context).primaryColor.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('No hay actividad para mostrar', style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupedByProject.keys.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final projId = groupedByProject.keys.elementAt(index);
                      final projData = projectDataMap[projId]!;
                      final measurements = groupedByProject[projId]!;
                      return _buildProjectGroupCard(context, projData, measurements);
                    },
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('Error al cargar historial: $err', style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectGroupCard(BuildContext context, Map<String, dynamic> project, List<Map<String, dynamic>> measurements) {
    final textTheme = Theme.of(context).textTheme;
    
    final projectName = project['nombre'] ?? 'Proyecto desconocido';
    final company = project['companies'] as Map<String, dynamic>?;
    final companyName = company?['nombre'] ?? 'Workspace desconocido';
    final logoUrl = company?['logo_url']?.toString();

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (logoUrl != null && logoUrl.isNotEmpty)
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Icon(Icons.business, size: 16, color: Colors.grey[400]),
                    ),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                  child: Icon(Icons.business, size: 16, color: Theme.of(context).primaryColor),
                ),
              Expanded(
                child: Text(
                  companyName,
                  style: textTheme.bodySmall?.copyWith(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            projectName,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          
          ...measurements.map((m) {
            final isInstalacion = m['history_type'] == 'instalacion';
            final elementTitle = m['nombre'] ?? (isInstalacion ? 'Instalación de proyecto' : 'Elemento sin nombre');
            
            String dateStr = '';
            if (m['history_date'] != null) {
              final date = DateTime.parse(m['history_date'].toString()).toLocal();
              dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
            }
            
            return InkWell(
              onTap: () {
                if (isInstalacion) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InstallationHistoryDetailScreen(installationData: m),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MeasurementHistoryDetailScreen(measurementData: m),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isInstalacion ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isInstalacion ? Icons.handyman : Icons.straighten,
                        size: 16,
                        color: isInstalacion ? Colors.orange : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(elementTitle, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isInstalacion ? Colors.orange : Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isInstalacion ? 'INST' : 'MED',
                                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (dateStr.isNotEmpty)
                            Text(dateStr, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: Colors.grey[500]),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
