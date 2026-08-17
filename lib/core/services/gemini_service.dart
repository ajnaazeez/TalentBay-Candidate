import 'package:google_generative_ai/google_generative_ai.dart';
import '../constants/app_constants.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  late final GenerativeModel _model;

  GeminiService._internal() {
    _model = GenerativeModel(
      model: AppConstants.geminiModel,
      apiKey: AppConstants.googleApiKey,
    );
  }

  Future<String?> enhanceText(String prompt) async {
    try {
      if (AppConstants.googleApiKey == 'YOUR_API_KEY') {
        throw Exception('API Key not configured');
      }

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text?.trim();
    } catch (e) {
      rethrow;
    }
  }
}
