import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  debugPrintRebuildDirtyWidgets = false;
  runApp(DiaryApp());
}

class DiaryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой дневник',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: DiaryScreen(),
    );
  }
}

class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> entries = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getStringList('diary_entries') ?? [];

    setState(() {
      entries = entriesJson.map((json) {
        final map = jsonDecode(json);
        return DiaryEntry.fromJson(map);
      }).toList();
    });
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = entries.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList('diary_entries', entriesJson);
  }

  Future<void> _addNewEntry() async {
    final result = await Navigator.of(context).push<DiaryEntry?>(
      MaterialPageRoute(
        builder: (context) => AddEntryScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      setState(() {
        entries.insert(0, result);
      });
      _saveEntries();
    }
  }

  void _deleteEntry(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить запись?'),
        content: Text('Вы уверены, что хотите удалить эту запись?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                entries.removeAt(index);
              });
              _saveEntries();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Запись удалена'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мой дневник'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = entries[index];
                  return Dismissible(
                    key: Key('${entry.date.millisecondsSinceEpoch}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      _deleteEntry(index);
                      return false; // Не удаляем сразу, показываем диалог
                    },
                    child: DiaryCard(
                      entry: entry,
                      onDelete: () => _deleteEntry(index),
                    ),
                  );
                },
                childCount: entries.length,
              ),
            ),
          ),
          if (entries.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.book,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Пока нет записей',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Нажмите кнопку ниже,\nчтобы создать первую запись',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _addNewEntry,
          icon: Icon(Icons.add),
          label: Text('Добавить запись'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

class DiaryEntry {
  String title;
  String text;
  String? imagePath;
  DateTime date;

  DiaryEntry({
    required this.title,
    required this.text,
    this.imagePath,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'text': text,
      'imagePath': imagePath,
      'date': date.toIso8601String(),
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      title: json['title'],
      text: json['text'],
      imagePath: json['imagePath'],
      date: DateTime.parse(json['date']),
    );
  }
}

class DiaryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onDelete;

  DiaryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.imagePath != null && entry.imagePath!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.file(
                File(entry.imagePath!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${entry.date.day}.${entry.date.month}.${entry.date.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20),
                          color: Colors.grey[500],
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (entry.text.isNotEmpty)
                  Text(
                    entry.text,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.grey[800],
                    ),
                  ),
                if (entry.text.isEmpty) SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddEntryScreen extends StatefulWidget {
  @override
  _AddEntryScreenState createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  void _saveEntry() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Введите заголовок'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final entry = DiaryEntry(
      title: _titleController.text.trim(),
      text: _textController.text.trim(),
      imagePath: _imagePath,
      date: DateTime.now(),
    );

    Navigator.of(context).pop(entry);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Новая запись'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: Text(
              'Сохранить',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Поле для заголовка
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Заголовок*',
                hintText: 'Например: Поход в музей 11 сентября',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: TextStyle(fontSize: 18),
              maxLines: 2,
            ),
            SizedBox(height: 20),

            // Блок для добавления фотографии
            Text(
              'Добавить фотографию (необязательно)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),

            if (_imagePath != null)
              Container(
                margin: EdgeInsets.only(bottom: 16),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_imagePath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 18,
                        child: IconButton(
                          icon: Icon(Icons.close, size: 18),
                          color: Colors.white,
                          onPressed: _removeImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.photo),
              label: Text(_imagePath == null ? 'Выбрать фото' : 'Изменить фото'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Поле для текста
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Текст записи (необязательно)',
                hintText: 'Напишите о своих впечатлениях...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              style: TextStyle(fontSize: 16),
              maxLines: 10,
              keyboardType: TextInputType.multiline,
            ),
            SizedBox(height: 30),

            // Кнопка сохранения внизу
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveEntry,
                icon: Icon(Icons.save),
                label: Text(
                  'Сохранить запись',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 56),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}