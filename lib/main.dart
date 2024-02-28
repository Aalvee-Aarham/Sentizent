import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
// import 'package:universal_html/html.dart' as universal_html;

import 'package:flutter/material.dart';
import 'package:csv/csv.dart' as csv;
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

List<List<dynamic>> coordinateList = [
  ["Time", "X", "Y"]
];

const int grid = 20;

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isRecording = false; // Flag to track whether recording is active or not

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
      ),
      endDrawer: Drawer(
        child: Container(
          color: Colors.black,
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.close, color: Colors.white),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (!isRecording) {
                          coordinateList = [
                            ["Time", "X", "Y"]
                          ];
                        }
                        isRecording = !isRecording;
                        Timer.periodic(Duration(seconds: 1), (_) {
                          if (isRecording) {
                            final timestamp = DateTime.now();
                            final timeString =
                                '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';

                            coordinateList.add([
                              '${timestamp.hour}:${timestamp.minute}:${timestamp.second}'
                            ]);
                          }
                        });
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.white,
                      onPrimary: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                    ),
                    child: !isRecording
                        ? const Text('Start Recording')
                        : const Text("Stop Recording"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _CoordinateDetectorState.exportCoordinates(context);
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.white,
                      onPrimary: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                    ),
                    child: const Text('Export Data'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: CoordinateDetector(isRecording: isRecording),
      ),
    );
  }
}

class CoordinateDetector extends StatefulWidget {
  final isRecording;
  const CoordinateDetector({Key? key, required this.isRecording})
      : super(key: key);

  @override
  _CoordinateDetectorState createState() => _CoordinateDetectorState();
}

class _CoordinateDetectorState extends State<CoordinateDetector> {
  String coordinates = '';
  double size = 0;
  DateTime? lastUpdateTime;
  Timer? _timer;

  Offset? _currentLocalOffset;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (screenWidth < screenHeight) {
      size = screenWidth * 0.95;
    } else {
      size = screenHeight * 0.95;
    }

    return GestureDetector(
      onTapDown: _onPointerDown,
      onTapUp: _onPointerUp,
      onPanStart: _onPointerDown,
      onPanEnd: _onPointerUp,
      onPanUpdate: _onPointerMove,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(size * .15)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .15),
          child: Image.asset(
            'assets/graph.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void _onPointerDown(details) {
    if (!widget.isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please Start Recording'),
        duration: Duration(milliseconds: 700),
      ));
      return;
    }
    _currentLocalOffset = details.localPosition;
    _startTimer();
  }

  void _onPointerUp(details) {
    _stopTimer();
    if (_currentLocalOffset != null) {
      _updateCoordinates(_currentLocalOffset!, size);
    }
  }

  void _onPointerMove(details) {
    _currentLocalOffset = details.localPosition;
  }

  void _startTimer() {
    if (_timer == null) {
      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        if (widget.isRecording && _currentLocalOffset != null) {
          _updateCoordinates(_currentLocalOffset!, size);
        }
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateCoordinates(Offset localOffset, double size) {
    final center = Offset(size / 2, size / 2);

    final dx = localOffset.dx - center.dx;
    final dy = (localOffset.dy - center.dy) * -1;

    final x = (dx / (size / grid)).round();
    final y = (dy / (size / grid)).round();

    if (x < 11 && x > -11 && y < 11 && y > -11) {
      final timestamp = DateTime.now();
      final timeString =
          '${timestamp.hour}:${timestamp.minute}:${timestamp.second}';
      final newCoordinates = '($x, $y) at $timeString';
      print(newCoordinates);

      setState(() {
        coordinates = newCoordinates;
      });

      coordinateList.add(
          ['${timestamp.hour}:${timestamp.minute}:${timestamp.second}', x, y]);
    }
  }

  static void exportCoordinates(context) async {
    final List<List<dynamic>> rows = processList(coordinateList);

    final csvData = const csv.ListToCsvConverter().convert(rows);
    print(csvData);
    final String now = DateFormat('dd/MM/yyyy_HH:mm:ss').format(DateTime.now());
    final String fileName = 'coordinates_$now.csv';

    final List<int> bytes = utf8.encode(csvData);

    if (io.Platform.isIOS) {
      // For iOS
      final io.Directory? directory = await getApplicationDocumentsDirectory();
      if (directory != null) {
        final String path = '${directory.path}/$fileName';
        final io.File file = io.File(path);
        await file.writeAsBytes(bytes);
        // Handle the file as required for iOS, like sharing or saving it locally.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File saved to iOS directory: $path'),
        ));
      } else {
        print('Error accessing iOS directory.');
      }
    } else {
      // For web
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final href = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: href)
        ..setAttribute("download", fileName)
        ..click();

      html.Url.revokeObjectUrl(href);
    }
  }
}

List<List<dynamic>> processList(List<List<dynamic>> inputList) {
  Map<String, List<dynamic>> timestampMap = {};

  for (var entry in inputList) {
    String timestamp = entry[0];

    if (timestampMap.containsKey(timestamp)) {
      if (entry.length > 1 && timestampMap[timestamp]!.length == 1) {
        timestampMap[timestamp] = entry;
      }
    } else {
      timestampMap[timestamp] = entry;
    }
  }

  List<List<dynamic>> resultList = timestampMap.values.toList();
  return resultList;
}
