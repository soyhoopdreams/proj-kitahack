import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyA9V4Z6jkq3y61R6xa85jiCgZ4rOQoFOb0';

  // ---- 1: VISION: ANALYZE FLOOD IMAGES ----
  Future<Map<String, dynamic>> analyzeFloodImage(File imageFile) async {
    final model = GenerativeModel(
      model: 'gemini-3-pro-preview',
      apiKey: _apiKey,
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
    final model = GenerativeModel(
      model: 'gemini-3-pro-preview', 
      apiKey: _apiKey,
      // CRITICAL: System Instruction for Safety
      systemInstruction: Content.system(
        "You are a strict Flood Safety Officer (NADMA Malaysia compliant). "
        "Rules: "
        "1. If water is rising, tell users to seek high ground immediately. "
        "2. Do NOT give medical advice; tell them to call 999. "
        "3. Keep answers under 2 sentences. Be urgent."
        "4. If asked about driving through water, say NO."
      ),
    );

    try {
      final response = await model.generateContent([Content.text(userMessage)]);
      return response.text ?? "System Error. Evacuate to high ground.";
    } catch (e) {
      return "Connection unstable. Seek high ground immediately.";
    }
  }
}