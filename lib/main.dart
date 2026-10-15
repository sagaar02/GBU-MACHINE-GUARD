import 'package:flutter/material.dart';
import 'controllers/machine_controller.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GbuApp());
}

class GbuApp extends StatefulWidget {
  const GbuApp({super.key});

  @override
  State<GbuApp> createState() => _GbuAppState();
}

class _GbuAppState extends State<GbuApp> {
  late final MachineController _machineController;

  @override
  void initState() {
    super.initState();
    _machineController = MachineController();
  }

  @override
  void dispose() {
    _machineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yellowPrimary = Color(0xFFF5D400); // Industrial Yellow Accent
    const greenConnected = Color(0xFF00E676); // Vibrant Green
    const bgDark = Color(0xFF08090B); // Industrial Dark Background
    const cardBg = Color(0xFF151619); // Distinct Dark Card Surface

    return MaterialApp(
      title: 'GBU Predictive Maintenance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        colorScheme: const ColorScheme.dark(
          primary: yellowPrimary,
          secondary: greenConnected,
          surface: cardBg,
          error: Color(0xFFFF3D00),
          onPrimary: Colors.black,
          onSurface: Colors.white,
        ),
        cardColor: cardBg,
        dialogTheme: const DialogThemeData(
          backgroundColor: cardBg,
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: const Color(0xFF22242B),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: cardBg,
          selectedItemColor: yellowPrimary,
          unselectedItemColor: Color(0xFFA0A0A0),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: TextStyle(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      ),
      home: MainNavigationScreen(controller: _machineController),
    );
  }
}
