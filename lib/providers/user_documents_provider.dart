import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';

final userDocumentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return [];

  final response = await supabase
      .from('user_documents')
      .select('*')
      .eq('user_id', user.id)
      .order('expiry_date', ascending: true);
      
  return List<Map<String, dynamic>>.from(response);
});
