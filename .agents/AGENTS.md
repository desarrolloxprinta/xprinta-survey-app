# Reglas de Proyecto: Xprinta Survey

## 1. Identidad Visual (Regla de Oro)
- **Logotipos e Iconografía:** Nunca utilices iconos estándar de Material (ej. `Icons.architecture` o `Icons.business`) para representar la identidad de la marca.
- Siempre usa los activos oficiales alojados en `assets/images/`:
  - `logo-xprinta-blanco.png`: Usar sobre fondos oscuros o cristalinos.
  - `logo-xprina-azul.png`: Usar sobre fondos claros.
  - `isotiposmall.png`: Usar cuando falte espacio (avatares, iconos pequeños).
- **Ejemplo de uso en código:** `Image.asset('assets/images/logo-xprinta-blanco.png', height: 80)`

## 2. Arquitectura de Navegación
- **Autenticación:** Utilizar siempre `ref.read(authStateProvider.notifier).setLoggedIn(bool)` para las transiciones. No usar `Navigator.pushReplacement` para login/logout.

## 3. Estilos y UI
- Mantener los estilos 2026: bordes redondeados, efectos de cristal (`AnimatedGlassContainer`), gradientes y transiciones fluidas.
