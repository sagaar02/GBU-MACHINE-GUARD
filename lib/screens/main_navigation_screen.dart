import 'package:flutter/material.dart';
import '../controllers/machine_controller.dart';
import '../widgets/emergency_stop_overlay.dart';
import 'dashboard_screen.dart';
import 'sensors_screen.dart';
import 'alerts_screen.dart';
import 'controls_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final MachineController controller;

  const MainNavigationScreen({
    super.key,
    required this.controller,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const yellowAccent = Color(0xFFF5D400);
    const navBg = Color(0xFF151619);
    const borderCol = Color(0xFF22242B);
    const unselectedColor = Color(0xFFA0A0A0);

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final unackCount = widget.controller.alerts.where((a) => !a.isAcknowledged).length;

        return Scaffold(
          backgroundColor: const Color(0xFF08090B),
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: [
                  // 0. Home
                  DashboardScreen(
                    controller: widget.controller,
                    onNavigateToTab: _onTabTapped,
                  ),
                  // 1. Sensors
                  SensorsScreen(controller: widget.controller),
                  // 2. Alerts
                  AlertsScreen(controller: widget.controller),
                  // 3. Controls
                  ControlsScreen(controller: widget.controller),
                  // 4. Settings
                  SettingsScreen(controller: widget.controller),
                ],
              ),
              // Emergency Stop Overlay (Overlays above all tabs when emergency latched)
              if (widget.controller.isEmergencyActive)
                EmergencyStopOverlay(controller: widget.controller),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                color: navBg,
                border: Border(
                  top: BorderSide(color: borderCol, width: 1.0),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                backgroundColor: navBg,
                selectedItemColor: yellowAccent,
                unselectedItemColor: unselectedColor,
                selectedFontSize: 11,
                unselectedFontSize: 10,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_rounded, color: yellowAccent),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.speed_outlined),
                    activeIcon: Icon(Icons.speed_rounded, color: yellowAccent),
                    label: 'Sensors',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildAlertIcon(unackCount, false),
                    activeIcon: _buildAlertIcon(unackCount, true),
                    label: 'Alerts',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.tune_rounded),
                    activeIcon: Icon(Icons.tune_rounded, color: yellowAccent),
                    label: 'Controls',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings_rounded, color: yellowAccent),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertIcon(int badgeCount, bool isActive) {
    const yellowAccent = Color(0xFFF5D400);
    final color = isActive ? yellowAccent : const Color(0xFFA0A0A0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.notifications_rounded : Icons.notifications_none_rounded, color: color),
        if (badgeCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFFFF3D00),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
