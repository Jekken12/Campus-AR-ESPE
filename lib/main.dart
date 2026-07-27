import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/campus_graph_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CampusGraphRepository.instance.load();
  runApp(const CampusArApp());
}

class CampusArApp extends StatelessWidget {
  const CampusArApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus AR ESPE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00a8ff),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xff181b22),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
