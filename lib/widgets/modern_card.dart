import 'package:flutter/material.dart';

class ModernCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20), // Padding más generoso
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20), // --radius-xl: 1.25rem (20px)
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!, // --color-border: var(--color-neutral-300)
                width: 1.0,
              ),
              boxShadow: [
                // Sombra Neumórfica muy suave y difusa
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withOpacity(0.4) 
                      : const Color(0xFFFA8029).withOpacity(0.06), // Sombra tintada con el color primario
                  blurRadius: 32,
                  spreadRadius: 4,
                  offset: const Offset(0, 16),
                ),
                if (!isDark) // Highlight sutil arriba para dar volumen
                  const BoxShadow(
                    color: Colors.white,
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: Offset(0, -4),
                  ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
