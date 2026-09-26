import 'dart:io';

Future<bool> hasInternet() async {
  final result = await InternetAddress.lookup('google.com')
      .timeout(const Duration(seconds: 5));
  return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
}