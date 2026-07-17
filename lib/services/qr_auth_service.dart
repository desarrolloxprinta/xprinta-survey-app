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
      final emailOtp = data['email_otp'] as String?;
      final email = data['email'] as String?;

      if (emailOtp == null || email == null) {
        throw Exception('Respuesta inválida del servidor (OTP ausente)');
      }

      // Validar el OTP mágicamente generado por el servidor
      final authResponse = await _supabase.auth.verifyOTP(
        type: OtpType.magiclink,
        token: emailOtp,
        email: email,
      );

      if (authResponse.session == null) {
        throw Exception('No se pudo establecer la sesión con el código proporcionado');
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
