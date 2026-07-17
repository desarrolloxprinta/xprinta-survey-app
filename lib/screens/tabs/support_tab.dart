import 'package:flutter/material.dart';
import '../../widgets/modern_card.dart';

class SupportTab extends StatelessWidget {
  const SupportTab({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 120),
      children: [
        Text(
          'Soporte Xprinta',
          style: textTheme.titleLarge?.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'Contacta con los administradores de tu red',
          style: textTheme.bodyMedium?.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 24),
        
        ModernCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                child: Image.asset('assets/images/isotiposmall.png', height: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Soporte Central',
                      style: textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'soporte@xprinta.net',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.email, color: Theme.of(context).primaryColor),
                onPressed: () {
                  // TODO: Lanza url_launcher a mailto:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Abriendo correo...')),
                  );
                },
              )
            ],
          ),
        ),
      ],
    );
  }
}
