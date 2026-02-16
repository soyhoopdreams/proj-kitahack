import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static String? _apiKey = dotenv.env['GEMINI_API_KEY'];

  // ---- 1: VISION: ANALYZE FLOOD IMAGES ----
  Future<Map<String, dynamic>> analyzeFloodImage(File imageFile) async {
    if (_apiKey == null) {
      throw Exception("API Key not found in .env file");
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey!,
    );

    final prompt = TextPart(
      "Analyze this image for flood detection. "
      "Return ONLY a raw JSON string (no markdown, no backticks) with this structure: "
      "{ \"isFlood\": true/false, \"severity\": 1-5, \"depth\": \"estimated depth in meters\", \"description\": \"short summary\" }. "
      "If it is not a flood, set isFlood to false."
    );

    final imageBytes = await imageFile.readAsBytes();
    final imagePart = DataPart('image/jpeg', imageBytes);

    try {
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      String? responseText = response.text;

      if (responseText != null) {
        responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(responseText);
      }

      throw Exception("Empty response from AI");
    } catch (e) {
      print("AI Error: $e");
      return {"isFlood": false, "description": "Error analyzing image"};
    }
  }

  // ---- 2: CHAT: SAFETY ADVISOR ----
  Future<String> getSafetyAdvice(String userMessage) async {
    if (_apiKey == null) {
      throw Exception("API Key not found in .env file");
    }
    
    final model = GenerativeModel(
      model: 'gemini-2.5-flash', 
      apiKey: _apiKey!,
      // CRITICAL: System Instruction for Safety
      systemInstruction: Content.system(
        "You are the official AI Crisis Response Officer for Kuala Lumpur, Malaysia. "
        "Your responses must align with NADMA (National Disaster Management Agency) and Bomba guidelines. "
        
        "CRITICAL RULES:"
        "1. TONE: Urgent, authoritative, and direct. No polite filler like 'I hope you are safe'."
        "2. LOCATION AWARENESS: If the user mentions 'Masjid Jamek' or 'Kampung Baru', prioritize flash flood warnings."
        "3. PROHIBITIONS: Never suggest driving through water. Never give medical prescriptions (only First Aid)."
        "4. LANGUAGE: Use simple English mixed with common Malaysian terms if needed (e.g., 'Move to higher ground', 'Avoid longkang')."
        
        "SCENARIO RESPONSES:"
        "- If stuck in car: 'Abandon vehicle immediately. Climb to high ground. Do not wait.'"
        "- If water rising in house: 'Switch off main power (TNB). Move family to roof/highest floor. Hang white cloth if trapped.'"
      ),
    );

    try {
      final response = await model.generateContent([Content.text(userMessage)]);
      return response.text ?? "System Error. Evacuate to high ground.";
    } catch (e) {
      return "⚠️ OFFLINE MODE: Network unreachable.\n\n"
             "OFFICIAL FLOOD PROTOCOL:\n"
             "1. Turn off electricity immediately.\n"
             "2. Move to the highest floor.\n"
             "3. Do not walk through moving water.\n"
             "4. Keep this phone dry for emergency signal.";
    }
  }
}