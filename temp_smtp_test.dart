import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  const String scriptUrl = "https://script.google.com/macros/s/AKfycbzTt-kfOChCFgnhc2GT8imN2Mgt2k9n437JSE-OsUou8zH4Wi0rdji_zTXyDhl0HIQedQ/exec";

  final response = await http.post(
    Uri.parse(scriptUrl),
    body: json.encode({
      "email": "asifabdullapa@gmail.com",
      "otp": "12345",
    }),
  );

  print("Got response status: ${response.statusCode}");
  print("Got response body: ${response.body}");
}
