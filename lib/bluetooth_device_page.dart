import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:fl_chart/fl_chart.dart';

class BluetoothDevicePage extends StatefulWidget {
  final BluetoothDevice device;

  BluetoothDevicePage({required this.device});

  @override
  _BluetoothDevicePageState createState() => _BluetoothDevicePageState();
}

class _BluetoothDevicePageState extends State<BluetoothDevicePage> {
  bool isConnected = false;
  BluetoothCharacteristic? _notificationCharacteristic;
  List<Map<String, dynamic>> receivedDataList = [];
  double pitch = 0.0, roll = 0.0, yaw = 0.0;

  List<FlSpot> accelX = [], accelY = [], accelZ = [];
  List<FlSpot> gyroX = [], gyroY = [], gyroZ = [];
  int dataIndex = 0;
  double minY = 0, maxY = 0;

  final int maxDataPoints = 30;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  Future<void> _connectToDevice() async {
    try {
      await widget.device.connect();
      setState(() => isConnected = true);
      _discoverServices();
    } catch (e) {
      debugPrint("❌ Failed to connect: $e");
    }
  }

  Future<void> _discoverServices() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          _notificationCharacteristic = characteristic;
          _subscribeToNotifications(characteristic);
          return;
        }
      }
    }
  }

  void _subscribeToNotifications(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(true);
      characteristic.value.listen((value) {
        String receivedString = utf8.decode(value);
        debugPrint("🔔 Notification Received: $receivedString");

        try {
          Map<String, dynamic> jsonData = json.decode(receivedString);
          setState(() {
            receivedDataList.insert(0, jsonData);
            pitch = jsonData["pitch"]?.toDouble() ?? 0.0;
            roll = jsonData["roll"]?.toDouble() ?? 0.0;
            yaw = jsonData["yaw"]?.toDouble() ?? 0.0;
            _updateGraphData(jsonData);
          });
        } catch (e) {
          debugPrint("❌ JSON Parsing Error: $e");
        }
      });
    } catch (e) {
      debugPrint("❌ Error subscribing to notifications: $e");
    }
  }

  void _updateGraphData(Map<String, dynamic> data) {
    double newAccelX = data["accel_x"] ?? 0;
    double newAccelY = data["accel_y"] ?? 0;
    double newAccelZ = data["accel_z"] ?? 0;
    double newGyroX = data["gyro_x"] ?? 0;
    double newGyroY = data["gyro_y"] ?? 0;
    double newGyroZ = data["gyro_z"] ?? 0;

    accelX.add(FlSpot(dataIndex.toDouble(), newAccelX));
    accelY.add(FlSpot(dataIndex.toDouble(), newAccelY));
    accelZ.add(FlSpot(dataIndex.toDouble(), newAccelZ));
    gyroX.add(FlSpot(dataIndex.toDouble(), newGyroX));
    gyroY.add(FlSpot(dataIndex.toDouble(), newGyroY));
    gyroZ.add(FlSpot(dataIndex.toDouble(), newGyroZ));

    if (accelX.length > maxDataPoints) accelX.removeAt(0);
    if (accelY.length > maxDataPoints) accelY.removeAt(0);
    if (accelZ.length > maxDataPoints) accelZ.removeAt(0);
    if (gyroX.length > maxDataPoints) gyroX.removeAt(0);
    if (gyroY.length > maxDataPoints) gyroY.removeAt(0);
    if (gyroZ.length > maxDataPoints) gyroZ.removeAt(0);

    List<double> allValues = [...accelX.map((e) => e.y), ...gyroX.map((e) => e.y)];
    if (allValues.isNotEmpty) {
      minY = allValues.reduce((a, b) => a < b ? a : b);
      maxY = allValues.reduce((a, b) => a > b ? a : b);
    }
    dataIndex++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name.isNotEmpty ? widget.device.name : "Unknown Device"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _discoverServices),
          IconButton(icon: const Icon(Icons.bluetooth_disabled), onPressed: _disconnectFromDevice),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: ModelViewer(
                key: ValueKey("$pitch-$roll-$yaw"),
                src: 'assets/car.glb',
                alt: "3D Car Model",
                autoRotate: false,
                disableZoom: false,
                cameraOrbit: "${yaw}deg ${pitch}deg ${roll}deg",
                backgroundColor: Colors.transparent,
              ),
            ),
            _buildSensorGrid("Acceleration", pitch, roll, yaw),
            SizedBox(height: 300, child: _buildMinimalChart("Acceleration", accelX, accelY, accelZ)),
            _buildSensorGrid("Gyroscope", gyroX.isNotEmpty ? gyroX.last.y : 0, gyroY.isNotEmpty ? gyroY.last.y : 0, gyroZ.isNotEmpty ? gyroZ.last.y : 0),
            SizedBox(height: 300, child: _buildMinimalChart("Gyroscope", gyroX, gyroY, gyroZ)),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalChart(String title, List<FlSpot> x, List<FlSpot> y, List<FlSpot> z) {
    if (x.isEmpty || y.isEmpty || z.isEmpty) {
      return Center(child: Text("Waiting for data...", style: TextStyle(color: Colors.white)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white, fontSize: 18)),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
          child: SizedBox(
            height: 180,
            child: LineChart(LineChartData(
              minX: x.first.x,
              maxX: x.last.x,
              minY: minY - 1,
              maxY: maxY + 1,
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                _buildAreaChartData(x, Colors.red),
                _buildAreaChartData(y, Colors.green),
                _buildAreaChartData(z, Colors.blue),
              ],
            )),
          ),
        ),
      ],
    );
  }

  LineChartBarData _buildAreaChartData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      barWidth: 1,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(show: true, colors: [color.withOpacity(0.3), Colors.transparent]),
      dotData: FlDotData(show: false),
    );
  }

  Widget _buildSensorGrid(String title, double x, double y, double z) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.white, fontSize: 18)),
        Row(
          children: [for (var axis in ["X", "Y", "Z"]) _buildSensorBox(axis, x)],
        ),
      ],
    );
  }

  Widget _buildSensorBox(String axis, double value) {
    return Expanded(child: Card(color: Colors.grey[900], child: Padding(padding: EdgeInsets.all(12.0), child: Column(children: [Text(axis), Text(value.toString())]))));
  }
}
