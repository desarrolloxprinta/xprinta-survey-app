import 'package:flutter/material.dart';
import '../widgets/glass_bottom_nav.dart';
import 'tabs/measurements_tab.dart';
import 'tabs/history_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/support_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _tabs = const [
    MeasurementsTab(),
    HistoryTab(),
    ProfileTab(),
    SupportTab(),
  ];

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Fondo base decorativo opcional (gradiente sutil)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                    ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                    : const [Color(0xFFF5F5F5), Color(0xFFE5E7EB)],
              ),
            ),
          ),
          
          // Contenido de la pestaña con desvanecimiento (Fade)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: SizedBox(
              key: ValueKey<int>(_currentIndex),
              width: double.infinity,
              height: double.infinity,
              child: _tabs[_currentIndex],
            ),
          ),
          
          // Barra de Navegación Flotante
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassBottomNav(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
            ),
          ),
        ],
      ),
    );
  }
}
