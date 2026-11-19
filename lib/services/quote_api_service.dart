import 'dart:convert';
import 'package:http/http.dart' as http;

class QuoteApiService {
  static const String _endpoint = 'https://dummyjson.com/quotes/random';

  Future<String> fetchDailyQuote() async {
    try {
      final response = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final quote = data['quote'] as String? ??
            'Konsistensi kecil setiap hari membawa hasil besar.';
        final author = data['author'] as String? ?? 'Jiwoo';
        return '"$quote" — $author';
      }
      return 'Fokus pada langkah hari ini, evaluasi perlahan, dan terus bertumbuh.';
    } catch (_) {
      return 'Tetap tenang dan selesaikan satu prioritas utama hari ini.';
    }
  }
}
