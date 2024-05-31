import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? bytes;
  bool isTextRecognized = false;
  String recognizedText = "";

  List<Color> colors = [Colors.pink, Colors.red, Colors.black, Colors.yellow];
  Color selectedColor = Colors.black;
  double strokeWidth = 5;
  List<DrawingPoint?> drawingPoints = [];

  int fps = 0;
  int frameCount = 0;

  @override
  void initState() {
    super.initState();
    _startFPSCounter();
  }

  void _startFPSCounter() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        fps = frameCount;
        frameCount = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    frameCount++;

    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 50),
          Row(
            children: [
              Slider(
                min: 0,
                max: 40,
                value: strokeWidth,
                onChanged: (val) => setState(() => strokeWidth = val),
              ),
              ElevatedButton.icon(
                onPressed: () => setState(() => drawingPoints = []),
                icon: const Icon(Icons.clear),
                label: const Text("Clear Board"),
              ),
              Text('$fps FPS', style: const TextStyle(fontSize: 18)),
            ],
          ),
          drawableCanvas(),
          if (isTextRecognized) Text(recognizedText),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: colors.map((color) => _buildColorChose(color)).toList(),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final controller = ScreenshotController();
          final bytes = await controller.captureFromWidget(Material(child: drawableCanvas()));
          setState(() {
            this.bytes = bytes;
          });
          await saveImage(bytes);
          await textRecognize(bytes);
        },
        child: const Icon(Icons.clear),
      ),
    );
  }

  Future<void> textRecognize(Uint8List bytes) async {
    final appStorage = await getApplicationDocumentsDirectory();
    final file = File('${appStorage.path}/image.png');
    await file.writeAsBytes(bytes);
    final inputImage = InputImage.fromFile(file);

    final textRecognizer = TextRecognizer();

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      if(recognizedText.text != ""){

        print("RECOGNIZED TEXT: ${recognizedText.text}");
      }else
        print("NO RECOGNIZED TEXT");
      setState(() {
        isTextRecognized = true;
        this.recognizedText = recognizedText.text;
      });
    } catch (e) {
      print('Error during text recognition: $e');
    } finally {
      textRecognizer.close();
    }
  }

  Future<void> saveImage(Uint8List bytes) async {
    final appStorage = await getApplicationDocumentsDirectory();
    final file = File('${appStorage.path}/image.png');
    await file.writeAsBytes(bytes);
  }

  Widget drawableCanvas() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(0),
        child: GestureDetector(
          onPanStart: (details) {
            _addDrawingPoint(details.localPosition);
          },
          onPanUpdate: (details) {
            _addDrawingPoint(details.localPosition);
          },
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _DrawingPainter(drawingPoints),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black,
                ),
              ),
              height: 500,
              width: 300,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildColorChose(Color color) {
    bool isSelected = selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => selectedColor = color),
      child: Container(
        height: isSelected ? 47 : 40,
        width: isSelected ? 47 : 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
      ),
    );
  }

  void _onPanEnd(DragEndDetails details) {
    drawingPoints.add(null);
  }

  void _addDrawingPoint(Offset offset) {
    setState(() {
      drawingPoints.add(
        DrawingPoint(
          offset,
          _createPaint(),
        ),
      );
    });
  }

  Paint _createPaint() {
    return Paint()
      ..color = selectedColor
      ..isAntiAlias = true
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> drawingPoints;

  _DrawingPainter(this.drawingPoints);

  @override
  void paint(Canvas canvas, Size size) {
    List<Offset> offsetsList = [];
    for (int i = 0; i < drawingPoints.length - 1; i++) {
      if (drawingPoints[i] != null && drawingPoints[i + 1] != null) {
        canvas.drawLine(
          drawingPoints[i]!.offset,
          drawingPoints[i + 1]!.offset,
          drawingPoints[i]!.paint,
        );
      } else if (drawingPoints[i] != null && drawingPoints[i + 1] == null) {
        offsetsList.clear();
        offsetsList.add(drawingPoints[i]!.offset);
        canvas.drawPoints(
          PointMode.points,
          offsetsList,
          drawingPoints[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint(this.offset, this.paint);
}
