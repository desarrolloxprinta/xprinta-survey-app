import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart'; // authStateProvider
import '../../core/constants.dart'; // supabase
import '../../widgets/modern_card.dart';
import '../../providers/profile_provider.dart';
import '../profile/user_documents_screen.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  Future<void> _signOut(WidgetRef ref) async {
    await supabase.auth.signOut();
    ref.read(authStateProvider.notifier).setLoggedIn(false);
  }

  Widget _buildSectionTitle(String title, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? 'tecnico@ejemplo.com';
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final profileAsync = ref.watch(userProfileProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
      children: [
        Text(
          'Mi Perfil',
          style: textTheme.titleLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 24),
        profileAsync.when(
          data: (profile) {
            final avatarUrl = profile['avatar_url'] as String?;
            final nombre = profile['nombre'] ?? 'Técnico Operativo';
            final rol = profile['role'] ?? 'Técnico';
            
            return ModernCard(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 2),
                      image: avatarUrl != null 
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    ),
                    child: avatarUrl == null
                      ? Center(
                          child: Image.asset(
                            'assets/images/isotiposmall.png',
                            height: 40,
                          ),
                        )
                      : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombre,
                    style: textTheme.titleLarge?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email,
                    style: textTheme.bodyMedium?.copyWith(fontSize: 16),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text('Error al cargar perfil: $e'),
        ),
        const SizedBox(height: 32),
        _buildSectionTitle('Información personal', textTheme),
        profileAsync.whenOrNull(
          data: (profile) => ModernCard(
            child: Column(
              children: [
                _buildListTile(Icons.person_outline, 'Nombre Completo', profile['nombre'] ?? 'Desconocido'),
                const Divider(height: 1),
                _buildListTile(Icons.email_outlined, 'Correo Electrónico', email),
                const Divider(height: 1),
                _buildListTile(Icons.badge_outlined, 'Rol', profile['role'] ?? 'Técnico'),
              ],
            ),
          ),
        ) ?? const SizedBox.shrink(),
        const SizedBox(height: 24),
        _buildSectionTitle('Archivos', textTheme),
        ModernCard(
          child: Column(
            children: [
              _buildListTile(Icons.insert_drive_file_outlined, 'Mis Documentos', 'DNI, Pasaportes, Permisos y Albaranes', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const UserDocumentsScreen()));
              }),
              const Divider(height: 1),
              _buildListTile(Icons.cloud_download_outlined, 'Descargas Locales', 'Archivos cacheados en el dispositivo'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Seguridad', textTheme),
        ModernCard(
          child: Column(
            children: [
              _buildListTile(Icons.lock_outline, 'Cambiar Contraseña', 'Actualiza tu clave de acceso'),
              const Divider(height: 1),
              _buildListTile(Icons.security, 'Autenticación Biométrica', 'Activa FaceID / Huella dactilar'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _signOut(ref),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, size: 20),
                SizedBox(width: 8),
                Text('Cerrar Sesión'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
