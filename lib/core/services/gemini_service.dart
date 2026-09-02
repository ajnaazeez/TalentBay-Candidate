import 'package:cloud_functions/cloud_functions.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  final FirebaseFunctions _functions;

  GeminiService._internal()
      : _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<String?> enhanceText(
    String prompt, {
    String? type,
    Map<String, String>? context,
  }) async {
    try {
      final callable = _functions.httpsCallable('enhanceText');
      final response = await callable.call<Map<String, dynamic>>({
        'text': prompt,
        if (type != null) 'type': type,
        if (context != null) 'context': context,
      });

      final data = response.data;
      final enhancedText = data['enhancedText'] as String?;
      return enhancedText?.trim();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'Failed to enhance description');
    } catch (e) {
      rethrow;
    }
  }
}

