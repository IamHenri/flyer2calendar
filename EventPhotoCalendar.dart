import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:device_calendar/device_calendar.dart';
import 'dart:io';
import 'package:intl/intl.dart';

void main() {
  runApp(EventCaptureApp());
}

class EventCaptureApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EventCaptureScreen(),
    );
  }
}

class EventCaptureScreen extends StatefulWidget {
  @override
  _EventCaptureScreenState createState() => _EventCaptureScreenState();
}

class _EventCaptureScreenState extends State<EventCaptureScreen> {
  File? _image;
  String _eventTitle = "";
  String _eventArtist = "";
  List<DateTime> _eventDates = [];
  DateTime? _selectedDate;
  final ImagePicker _picker = ImagePicker();
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _extractText();
    }
  }

  Future<void> _extractText() async {
    if (_image == null) return;
    String text = await TesseractOcr.extractText(_image!.path);
    setState(() {
      _eventTitle = _parseTitle(text);
      _eventArtist = _parseArtist(text);
      _eventDates = _parseDates(text);
      _selectedDate = _eventDates.isNotEmpty ? _eventDates.first : null;
    });
  }

  String _parseTitle(String text) {
    return text.split('\n').first;
  }

  String _parseArtist(String text) {
    RegExp artistPattern = RegExp(r'avec\s([A-Za-z\s]+)');
    Match? match = artistPattern.firstMatch(text);
    return match != null ? match.group(1)! : "Artiste inconnu";
  }

  List<DateTime> _parseDates(String text) {
    RegExp datePattern = RegExp(r'\d{1,2} [A-Za-z]+ \d{4}');
    Iterable<Match> matches = datePattern.allMatches(text);
    return matches.map((match) {
      return DateFormat("d MMMM yyyy", 'fr_FR').parse(match.group(0)!);
    }).toList();
  }

  Future<void> _addEventToCalendar() async {
    if (_selectedDate == null) return;
    var permissionsGranted = await _calendarPlugin.requestPermissions();
    if (permissionsGranted.isSuccess) {
      var calendarsResult = await _calendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data!.isNotEmpty) {
        final calendar = calendarsResult.data!.first;
        final event = Event(calendar.id,
            title: _eventTitle,
            start: _selectedDate!,
            end: _selectedDate!.add(Duration(hours: 2)));
        await _calendarPlugin.createOrUpdateEvent(event);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Capture d’événement')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null ? Image.file(_image!) : Text("Prenez une photo de l'affiche"),
            ElevatedButton(onPressed: _pickImage, child: Text("Prendre une photo")),
            if (_eventTitle.isNotEmpty) ...[
              TextField(
                decoration: InputDecoration(labelText: "Titre de l'événement"),
                controller: TextEditingController(text: _eventTitle),
                onChanged: (value) => _eventTitle = value,
              ),
              TextField(
                decoration: InputDecoration(labelText: "Artiste"),
                controller: TextEditingController(text: _eventArtist),
                onChanged: (value) => _eventArtist = value,
              ),
              if (_eventDates.isNotEmpty) ...[
                DropdownButton<DateTime>(
                  value: _selectedDate,
                  items: _eventDates.map((date) {
                    return DropdownMenuItem(
                      value: date,
                      child: Text(DateFormat('d MMMM yyyy', 'fr_FR').format(date)),
                    );
                  }).toList(),
                  onChanged: (DateTime? newValue) {
                    setState(() {
                      _selectedDate = newValue;
                    });
                  },
                ),
              ],
              ElevatedButton(onPressed: _addEventToCalendar, child: Text("Ajouter au calendrier")),
            ],
          ],
        ),
      ),
    );
  }
}
