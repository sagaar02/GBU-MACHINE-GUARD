import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../controllers/machine_controller.dart';
import '../services/bluetooth_service.dart';

class ConnectionBadge extends StatelessWidget {
  final MachineController controller;

  const ConnectionBadge({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = controller.connectionState == DeviceBtState.connected;
    final isConnecting = controller.connectionState == DeviceBtState.connecting;

    Color statusColor;
    String statusLabel;

    if (isConnected) {
      statusColor = const Color(0xFF00E676); // Vibrant Green
      statusLabel = 'Connected';
    } else if (isConnecting) {
      statusColor = const Color(0xFFF5D400); // Industrial Yellow
      statusLabel = 'Connecting...';
    } else {
      statusColor = const Color(0xFFFF3D00); // Red
      statusLabel = 'Disconnected';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showConnectDialog(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isConnecting)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5D400)),
                  ),
                )
              else
                Icon(
                  Icons.bluetooth,
                  color: statusColor,
                  size: 15,
                ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConnectDialog(BuildContext context) async {
    List<BluetoothDevice> pairedDevices =
        await controller.bluetoothService.getPairedDevices();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151619),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.bluetooth_searching, color: Color(0xFFF5D400)),
            SizedBox(width: 8),
            Text(
              'Select Bluetooth Device',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target node: EdgeAI_Predictive_Node',
                style: TextStyle(color: Color(0xFFA0A0A0), fontSize: 11),
              ),
              const SizedBox(height: 10),
              if (pairedDevices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'No paired devices found. Please pair the ESP32 in Android System Settings first.',
                    style: TextStyle(color: Color(0xFFFF3D00), fontSize: 11),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pairedDevices.length,
                    itemBuilder: (context, index) {
                      final dev = pairedDevices[index];
                      final isTarget = dev.name == BluetoothService.targetDeviceName;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.memory,
                          color: isTarget ? const Color(0xFFF5D400) : const Color(0xFFA0A0A0),
                        ),
                        title: Text(
                          dev.name ?? 'Unknown Device',
                          style: TextStyle(
                            color: isTarget ? const Color(0xFFF5D400) : Colors.white,
                            fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          dev.address,
                          style: const TextStyle(color: Color(0xFFA0A0A0), fontSize: 10),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          controller.connect(dev.address);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (controller.connectionState == DeviceBtState.connected)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.disconnect();
              },
              child: const Text('Disconnect', style: TextStyle(color: Color(0xFFFF3D00))),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA0A0A0))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.connect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5D400),
              foregroundColor: Colors.black,
            ),
            child: const Text('Auto Connect Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
