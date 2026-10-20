import 'package:duo_guitar/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const DuoGuitarApp());
}

class DuoGuitarApp extends StatelessWidget {
  const DuoGuitarApp({super.key});

  @override
  Widget build(BuildContext context) {
    const wood = Color(0xFF1A120B);
    const amber = Color(0xFFE0A100);
    return MaterialApp(
      title: '双琴',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: wood,
        colorScheme: const ColorScheme.dark(
          primary: amber,
          surface: wood,
        ),
      ),
      home: const HomePage(),
    );
  }
}
