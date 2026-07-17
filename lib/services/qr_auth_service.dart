import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QrAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Procesa un token capturado del código QR
  Future<void> loginWithQrToken(String token) async {
    try {
      debugPrint('Llamando a Edge Function mobile-link-auth con token: $token');
      
      final response = await _supabase.functions.invoke(
        'mobile-link-auth',
        body: {'token': token},
      );

      if (response.status != 200) {
        throw Exception('Error al validar el código QR: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;

      if (accessToken == null || refreshToken == null) {
        throw Exception('Respuesta inválida del servidor (tokens ausentes)');
      }

      // En supabase_flutter, setSession permite establecer ambos tokens
      // Si la firma cambia en alguna versión, la alternativa es usar recoverSession(refreshToken)
      try {
        await _supabase.auth.setSession(accessToken);
      } catch (e) {
        // En caso de que requiriera un enfoque diferente
        await _supabase.auth.recoverSession(refreshToken);
      }
      
      debugPrint('Sesión establecida correctamente con QR');
    } catch (e) {
      debugPrint('Error en loginWithQrToken: $e');
      rethrow;
    }
  }

  /// Extrae el token de una URL o deep link tipo xprinta://link?token=XYZ
  String? extractTokenFromUrl(String urlString) {
    try {
      final uri = Uri.parse(urlString);
      if (uri.scheme == 'xprinta' && uri.host == 'link') {
        return uri.queryParameters['token'];
      }
    } catch (e) {
      debugPrint('Error parseando URL del QR: $e');
    }
    return null;
  }
}
