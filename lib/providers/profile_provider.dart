import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';

final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('No autenticado');

  final response = await supabase
      .from('users')
      .select('nombre, email, avatar_url, role')
      .eq('id', user.id)
      .maybeSingle();

  if (response == null) {
    return {
      'nombre': 'Usuario',
      'email': user.email,
      'avatar_url': null,
      'role': 'Desconocido'
    };
  }
  return response;
});
