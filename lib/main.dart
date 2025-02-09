import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pneumonia Detection',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pneumonia Detection')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is Pneumonia?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Pneumonia is an infection that inflames the air sacs in one or both lungs. '
              'It is caused by bacteria, viruses, or fungi. Symptoms include cough, fever, and difficulty breathing.',
              style: TextStyle(fontSize: 16),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UploadScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: Text('Upload DICOM File'),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _fileName;
  Uint8List? _fileBytes;
  img.Image? _image;
  bool _isLoading = false;

  // Function to pick a DICOM file
  Future<void> _pickDicomFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['dcm'],
    );

    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
        _fileBytes = result.files.single.bytes;
        _decodeImage();
      });
    }
  }

  // Try to decode image from DICOM file bytes
  void _decodeImage() {
    if (_fileBytes != null) {
      try {
        img.Image? decodedImage = img.decodeImage(_fileBytes!);
        if (decodedImage != null) {
          setState(() {
            _image = decodedImage;
          });
        } else {
          print('Failed to decode image');
        }
      } catch (e) {
        print('Error decoding image: $e');
      }
    }
  }

  // Function to show a loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Processing, please wait...'),
            ],
          ),
        );
      },
    );
  }

  // Function to send the picked file to the Flask API
  Future<void> _sendDicomFile() async {
    if (_fileBytes != null) {
      setState(() {
        _isLoading = true;
      });

      _showLoadingDialog(); // Show loading dialog

      try {
        final uri = Uri.parse('https://gwx51b25-5001.inc1.devtunnels.ms/predict');
        final request = http.MultipartRequest('POST', uri)
          ..files.add(http.MultipartFile.fromBytes('file', _fileBytes!, filename: _fileName));

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        Navigator.pop(context); // Close loading dialog

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(responseBody);
          String message = data['message'];
          List<dynamic> coordinates = data['coor'] ?? [];

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Prediction Result'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Message: $message'),
                  if (coordinates.isNotEmpty) Text('Coordinates: ${coordinates.join(', ')}'),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } catch (e) {
        Navigator.pop(context); // Close loading dialog in case of error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to get response from the server: $e'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload DICOM File')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Upload DICOM Image for Pneumonia Detection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickDicomFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: Text('Pick DICOM File'),
            ),
            SizedBox(height: 20),
            if (_fileName != null)
              Text(
                'Selected file: $_fileName',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            SizedBox(height: 20),
            _image != null
                ? Image.memory(
                    Uint8List.fromList(img.encodeJpg(_image!)),
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(child: Text('Failed to load image'));
                    },
                  )
                : Container(),
            Spacer(),
            ElevatedButton(
              onPressed: _sendDicomFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: Text('Send to Flask API'),
            ),
          ],
        ),
      ),
    );
  }
}