import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

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
  bool _isLoading = true;
  String? _storagePath;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    _storagePath = await _getStoragePath();
    await _loadEntries();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.photos.request();
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        await Permission.storage.request();
      }
      await Permission.manageExternalStorage.request();
    }
  }

  Future<String> _getStoragePath() async {
    if (Platform.isAndroid) {
      try {
        String externalStoragePath = '/storage/emulated/0';
        final Directory externalDir = Directory(externalStoragePath);
        bool exists = await externalDir.exists();
        
        if (!exists) {
          externalStoragePath = '/sdcard';
          final Directory sdcardDir = Directory(externalStoragePath);
          exists = await sdcardDir.exists();
          
          if (!exists) {
            externalStoragePath = '/storage/sdcard0';
          }
        }
        
        final Directory dearyDir = Directory(path.join(externalStoragePath, 'Deary'));
        if (!await dearyDir.exists()) {
          try {
            await dearyDir.create(recursive: true);
          } catch (e) {
            final dir = await getApplicationDocumentsDirectory();
            return path.join(dir.path, 'Deary');
          }
        }
        
        return dearyDir.path;
      } catch (e) {
        final dir = await getApplicationDocumentsDirectory();
        return path.join(dir.path, 'Deary');
      }
    } else if (Platform.isWindows) {
      final homeDir = Directory(Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Public');
      final dearyDir = Directory(path.join(homeDir.path, 'Deary'));
      if (!await dearyDir.exists()) {
        await dearyDir.create(recursive: true);
      }
      return dearyDir.path;
    } else {
      final homeDir = await getApplicationSupportDirectory();
      final dearyDir = Directory(path.join(homeDir.path, 'Deary'));
      if (!await dearyDir.exists()) {
        await dearyDir.create(recursive: true);
      }
      return dearyDir.path;
    }
  }

  Future<void> _loadEntries() async {
    if (_storagePath == null) return;
    
    final entriesFilePath = path.join(_storagePath!, 'entries.json');
    final File entriesFile = File(entriesFilePath);
    
    if (!await entriesFile.exists()) {
      setState(() {
        entries = [];
      });
      return;
    }

    try {
      final jsonString = await entriesFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      List<DiaryEntry> loadedEntries = [];
      
      for (var json in jsonList) {
        final entry = DiaryEntry.fromJson(json);
        
        if (entry.imagePath != null && entry.imagePath!.isNotEmpty) {
          final file = File(entry.imagePath!);
          if (!await file.exists()) {
            entry.imagePath = null;
          }
        }
        
        loadedEntries.add(entry);
      }

      setState(() {
        entries = loadedEntries;
      });
    } catch (e) {
      setState(() {
        entries = [];
      });
    }
  }

  Future<void> _saveEntries() async {
    if (_storagePath == null) return;
    
    final entriesFilePath = path.join(_storagePath!, 'entries.json');
    final File entriesFile = File(entriesFilePath);
    
    final entriesJson = entries.map((entry) => entry.toJson()).toList();
    await entriesFile.writeAsString(jsonEncode(entriesJson));
  }

  Future<void> _addNewEntry() async {
    final result = await Navigator.of(context).push<DiaryEntry?>(
      MaterialPageRoute(
        builder: (context) => AddEntryScreen(storagePath: _storagePath),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      setState(() {
        entries.insert(0, result);
      });
      await _saveEntries();
    }
  }
  
  void _launchDonateURL() async {
    try {
      final url = Uri.parse('https://revolut.me/bulatnikow');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Ошибка: $e');
    }
  }
  
  void _launchMyURL() async {
    try {
      final url = Uri.parse('https://taplink.cc/b9v6r');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Ошибка: $e');
    }
  }

  void _deleteEntry(int index) async {
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
            onPressed: () async {
              final entry = entries[index];
              
              if (entry.imagePath != null && entry.imagePath!.isNotEmpty) {
                try {
                  await File(entry.imagePath!).delete();
                } catch (e) {}
              }
              
              setState(() {
                entries.removeAt(index);
              });
              await _saveEntries();
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
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Инициализация приложения...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Мой дневник'),
        centerTitle: true,
		actions: [
          // Кнопка информации (i) и доната справа
          IconButton(
            icon: Icon(Icons.monetization_on),
            onPressed: _launchDonateURL,
		  ),
		  IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _launchMyURL,
		  ),
		],
      ),
      body: entries.isEmpty
          ? Center(
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
            )
          : ListView.builder(
              padding: EdgeInsets.only(bottom: 100),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return DiaryCard(
                  entry: entry,
                  onDelete: () => _deleteEntry(index),
                );
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 15),
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
  final String id;
  String title;
  String text;
  String? imagePath;
  DateTime date;

  DiaryEntry({
    String? id,
    required this.title,
    required this.text,
    this.imagePath,
    required this.date,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'imagePath': imagePath,
      'date': date.toIso8601String(),
    };
  }

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
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

  // Форматирование даты с ведущими нулями
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Color(0xFFEEEEEE),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ЗАГОЛОВОК
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: SelectableText(
              entry.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
              maxLines: null,
            ),
          ),
          
          // Изображение если есть
          if (entry.imagePath != null && entry.imagePath!.isNotEmpty)
            _buildImageWithAspectRatio(entry.imagePath!),
          
          // Текст записи если есть
          if (entry.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, entry.imagePath != null ? 12 : 0, 16, 8),
              child: Container(
                width: double.infinity,
                child: SelectableText(
                  entry.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            )
          else if (entry.imagePath != null)
            SizedBox(height: 8),
          
          // ДАТА И КНОПКА УДАЛЕНИЯ - в самом низу справа
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Дата с форматированием
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDate(entry.date), // Используем отформатированную дату
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // Кнопка удаления
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20),
                  color: Colors.red[500],
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithAspectRatio(String imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Container(
        color: Colors.grey[100],
        constraints: BoxConstraints(
          maxHeight: 400,
        ),
        child: Align(
          alignment: Alignment.center,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class AddEntryScreen extends StatefulWidget {
  final String? storagePath;
  
  AddEntryScreen({this.storagePath});

  @override
  _AddEntryScreenState createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        if (widget.storagePath != null) {
          final fileName = path.basename(image.path);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newFileName = 'photo_${timestamp}_$fileName';
          final destPath = path.join(widget.storagePath!, newFileName);
          
          try {
            await File(image.path).copy(destPath);
            setState(() {
              _imagePath = destPath;
            });
          } catch (e) {
            setState(() {
              _imagePath = image.path;
            });
          }
        } else {
          setState(() {
            _imagePath = image.path;
          });
        }
      }
    } catch (e) {
      // Ошибка при выборе изображения
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

  Widget _buildPreviewImage() {
    if (_imagePath == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Colors.grey[100],
              constraints: BoxConstraints(
                maxHeight: 400,
              ),
              child: Center(
                child: Image.file(
                  File(_imagePath!),
                  fit: BoxFit.contain,
                ),
              ),
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
    );
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
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            Text(
              'Добавить фотографию (необязательно)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),

            _buildPreviewImage(),

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

            if (widget.storagePath != null)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Запись сохранится в папку Deary\n${widget.storagePath}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 5),
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