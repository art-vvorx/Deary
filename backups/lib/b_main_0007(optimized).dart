import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;

void main() {
  // Отключим отладочную печать перестроения виджетов для производительности
  debugPrintRebuildDirtyWidgets = false;
  // Запускаем приложение
  runApp(DiaryApp());
}

// Главный класс приложения, который оборачивает всё в MaterialApp
class DiaryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Мой дневник',
      debugShowCheckedModeBanner: false, // Убираем баннер отладки
      theme: ThemeData(
        primarySwatch: Colors.blue, // Основной цвет приложения
        useMaterial3: true, // Используем Material 3 дизайн
      ),
      home: DiaryScreen(), // Устанавливаем главный экран
    );
  }
}

// Главный экран дневника - отображает список всех записей
class DiaryScreen extends StatefulWidget {
  @override
  _DiaryScreenState createState() => _DiaryScreenState();
}

// Состояние главного экрана дневника
class _DiaryScreenState extends State<DiaryScreen> {
  List<DiaryEntry> entries = []; // Список всех записей дневника
  final ImagePicker _picker = ImagePicker(); // Для выбора изображений
  bool _isLoading = true; // Флаг загрузки (показываем спиннер)
  String? _storagePath; // Путь, где сохраняются записи

  @override
  void initState() {
    super.initState();
    // При создании экрана запускаем инициализацию
    _initializeApp();
  }

  // Основная функция инициализации приложения
  Future<void> _initializeApp() async {
    await _requestPermissions(); // Запрашиваем разрешения
    _storagePath = await _getStoragePath(); // Получаем путь сохранения
    await _loadEntries(); // Загружаем сохраненные записи
    setState(() {
      _isLoading = false; // Завершаем загрузку
    });
  }

  // Запрос разрешений для доступа к файлам
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Для Android 13+ нужно разрешение на фото
      await Permission.photos.request();
      
      // Для старых версий Android нужно разрешение на хранилище
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        await Permission.storage.request();
      }
      
      // Для Android 11+ может потребоваться управление файлами
      await Permission.manageExternalStorage.request();
    }
  }

  // Получение пути для сохранения файлов
  Future<String> _getStoragePath() async {
    if (Platform.isAndroid) {
      try {
        // Основной путь к внешнему хранилищу на Android
        String externalStoragePath = '/storage/emulated/0';
        
        // Проверяем существует ли этот путь
        final Directory externalDir = Directory(externalStoragePath);
        bool exists = await externalDir.exists();
        
        // Если не существует, пробуем альтернативные пути
        if (!exists) {
          externalStoragePath = '/sdcard';
          final Directory sdcardDir = Directory(externalStoragePath);
          exists = await sdcardDir.exists();
          
          if (!exists) {
            externalStoragePath = '/storage/sdcard0';
          }
        }
        
        // Создаем папку Deary для нашего приложения
        final Directory dearyDir = Directory(path.join(externalStoragePath, 'Deary'));
        if (!await dearyDir.exists()) {
          try {
            await dearyDir.create(recursive: true);
          } catch (e) {
            // Если не получается, используем папку приложения
            final dir = await getApplicationDocumentsDirectory();
            return path.join(dir.path, 'Deary');
          }
        }
        
        return dearyDir.path;
      } catch (e) {
        // При ошибке используем папку приложения
        final dir = await getApplicationDocumentsDirectory();
        return path.join(dir.path, 'Deary');
      }
    } else if (Platform.isWindows) {
      // Для Windows используем папку пользователя
      final homeDir = Directory(Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Public');
      final dearyDir = Directory(path.join(homeDir.path, 'Deary'));
      if (!await dearyDir.exists()) {
        await dearyDir.create(recursive: true);
      }
      return dearyDir.path;
    } else {
      // Для других платформ (iOS, macOS, Linux)
      final homeDir = await getApplicationSupportDirectory();
      final dearyDir = Directory(path.join(homeDir.path, 'Deary'));
      if (!await dearyDir.exists()) {
        await dearyDir.create(recursive: true);
      }
      return dearyDir.path;
    }
  }

  // Загрузка записей из файла
  Future<void> _loadEntries() async {
    if (_storagePath == null) return;
    
    final entriesFilePath = path.join(_storagePath!, 'entries.json');
    final File entriesFile = File(entriesFilePath);
    
    // Если файл не существует, создаем пустой список
    if (!await entriesFile.exists()) {
      setState(() {
        entries = [];
      });
      return;
    }

    try {
      // Читаем JSON файл
      final jsonString = await entriesFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      List<DiaryEntry> loadedEntries = [];
      
      // Преобразуем JSON в объекты DiaryEntry
      for (var json in jsonList) {
        final entry = DiaryEntry.fromJson(json);
        
        // Проверяем существует ли файл изображения
        if (entry.imagePath != null && entry.imagePath!.isNotEmpty) {
          final file = File(entry.imagePath!);
          if (!await file.exists()) {
            entry.imagePath = null; // Если файл не найден, убираем ссылку
          }
        }
        
        loadedEntries.add(entry);
      }

      setState(() {
        entries = loadedEntries;
      });
    } catch (e) {
      // При ошибке загрузки начинаем с пустого списка
      setState(() {
        entries = [];
      });
    }
  }

  // Сохранение записей в файл
  Future<void> _saveEntries() async {
    if (_storagePath == null) return;
    
    final entriesFilePath = path.join(_storagePath!, 'entries.json');
    final File entriesFile = File(entriesFilePath);
    
    // Преобразуем записи в JSON и сохраняем
    final entriesJson = entries.map((entry) => entry.toJson()).toList();
    await entriesFile.writeAsString(jsonEncode(entriesJson));
  }

  // Добавление новой записи
  Future<void> _addNewEntry() async {
    // Открываем экран добавления записи и ждем результат
    final result = await Navigator.of(context).push<DiaryEntry?>(
      MaterialPageRoute(
        builder: (context) => AddEntryScreen(storagePath: _storagePath),
        fullscreenDialog: true, // Открываем как диалог
      ),
    );

    // Если пользователь сохранил запись, добавляем ее
    if (result != null) {
      setState(() {
        entries.insert(0, result); // Добавляем в начало списка
      });
      await _saveEntries(); // Сохраняем изменения
    }
  }

  // Удаление записи по индексу
  void _deleteEntry(int index) async {
    // Показываем диалог подтверждения удаления
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
              
              // Если у записи есть изображение, удаляем файл
              if (entry.imagePath != null && entry.imagePath!.isNotEmpty) {
                try {
                  await File(entry.imagePath!).delete();
                } catch (e) {}
              }
              
              // Удаляем запись из списка
              setState(() {
                entries.removeAt(index);
              });
              await _saveEntries(); // Сохраняем изменения
              Navigator.pop(context); // Закрываем диалог
              
              // Показываем уведомление об удалении
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
    // Показываем экран загрузки если данные еще не готовы
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(), // Кружок загрузки
              SizedBox(height: 20),
              Text('Инициализация приложения...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // Убрали кнопку информации из AppBar
      appBar: AppBar(
        title: Text('Мой дневник'),
        centerTitle: true,
      ),
      
      // Тело приложения
      body: entries.isEmpty
          // Если записей нет - показываем приветственный экран
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
          // Если есть записи - показываем список
          : ListView.builder(
              padding: EdgeInsets.only(bottom: 80), // Добавили отступ снизу для кнопки
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return DiaryCard(
                  entry: entry,
                  onDelete: () => _deleteEntry(index),
                );
              },
            ),
      
      // Кнопка добавления записи
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 20), // Отступ снизу для кнопки
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

// Класс, представляющий одну запись в дневнике
class DiaryEntry {
  final String id; // Уникальный идентификатор записи
  String title; // Заголовок записи
  String text; // Текст записи
  String? imagePath; // Путь к изображению (может быть null)
  DateTime date; // Дата создания записи

  // Конструктор с автоматической генерацией ID если не указан
  DiaryEntry({
    String? id,
    required this.title,
    required this.text,
    this.imagePath,
    required this.date,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // Преобразование записи в JSON для сохранения
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'imagePath': imagePath,
      'date': date.toIso8601String(), // Дата в стандартном формате
    };
  }

  // Создание записи из JSON
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'],
      text: json['text'],
      imagePath: json['imagePath'],
      date: DateTime.parse(json['date']), // Парсим дату из строки
    );
  }
}

// Виджет карточки для отображения одной записи
class DiaryCard extends StatelessWidget {
  final DiaryEntry entry; // Запись для отображения
  final VoidCallback onDelete; // Функция удаления записи

  DiaryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16), // Отступы вокруг карточки
      elevation: 3, // Тень под карточкой
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Закругленные углы
      ),
      color: Color(0xFFEEEEEE), // Светло-серый фон
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок и дата - ВЫРОВНЕНЫ В ОДНУ ЛИНИЮ
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center, // Выравниваем по центру вертикально
              children: [
                // Заголовок - занимает доступное пространство слева
                Expanded(
                  child: SelectableText(
                    entry.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                    maxLines: 2,
                  ),
                ),
                
                // Дата и кнопка удаления - справа в одну линию
                Container(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Дата в красивом контейнере
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
                      SizedBox(width: 8), // Небольшой отступ между датой и кнопкой
                      
                      // Кнопка удаления
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 20),
                        color: Colors.grey[500],
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(), // Убираем лишние отступы
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Изображение если есть
          if (entry.imagePath != null && entry.imagePath!.isNotEmpty)
            _buildImageWithAspectRatio(entry.imagePath!),
          
          // Текст записи если есть
          if (entry.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, entry.imagePath != null ? 12 : 0, 16, 16),
              child: Container(
                width: double.infinity,
                child: SelectableText(
                  entry.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5, // Межстрочный интервал
                    color: Colors.grey[800],
                  ),
                ),
              ),
            )
          else if (entry.imagePath != null)
            SizedBox(height: 16), // Отступ если есть только изображение
        ],
      ),
    );
  }

  // Виджет для отображения изображения с сохранением пропорций
  Widget _buildImageWithAspectRatio(String imagePath) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Container(
        color: Colors.grey[100], // Фон вокруг изображения
        constraints: BoxConstraints(
          maxHeight: 400, // Максимальная высота изображения
        ),
        child: Align(
          alignment: Alignment.center,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain, // Сохраняем пропорции изображения
          ),
        ),
      ),
    );
  }
}

// Экран для добавления новой записи
class AddEntryScreen extends StatefulWidget {
  final String? storagePath; // Путь для сохранения файлов
  
  AddEntryScreen({this.storagePath});

  @override
  _AddEntryScreenState createState() => _AddEntryScreenState();
}

// Состояние экрана добавления записи
class _AddEntryScreenState extends State<AddEntryScreen> {
  final TextEditingController _titleController = TextEditingController(); // Для заголовка
  final TextEditingController _textController = TextEditingController(); // Для текста
  String? _imagePath; // Путь к выбранному изображению
  final ImagePicker _picker = ImagePicker(); // Для выбора изображений

  // Выбор изображения из галереи
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Качество изображения (85%)
      );

      if (image != null) {
        if (widget.storagePath != null) {
          // Создаем уникальное имя файла с timestamp
          final fileName = path.basename(image.path);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newFileName = 'photo_${timestamp}_$fileName';
          final destPath = path.join(widget.storagePath!, newFileName);
          
          try {
            // Копируем файл в папку приложения
            await File(image.path).copy(destPath);
            setState(() {
              _imagePath = destPath;
            });
          } catch (e) {
            // Если не удалось скопировать, используем оригинальный путь
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

  // Удаление выбранного изображения
  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  // Сохранение записи
  void _saveEntry() {
    // Проверяем что заголовок не пустой
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Введите заголовок'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Создаем новую запись
    final entry = DiaryEntry(
      title: _titleController.text.trim(),
      text: _textController.text.trim(),
      imagePath: _imagePath,
      date: DateTime.now(),
    );

    // Возвращаемся на главный экран с записью
    Navigator.of(context).pop(entry);
  }

  @override
  void dispose() {
    // Очищаем контроллеры при закрытии экрана
    _titleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // Виджет для отображения превью изображения
  Widget _buildPreviewImage() {
    if (_imagePath == null) return SizedBox.shrink(); // Пустой виджет если нет изображения

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // Изображение с закругленными углами
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
          // Кнопка удаления изображения поверх изображения
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
          onPressed: () => Navigator.of(context).pop(), // Закрыть экран
        ),
        actions: [
          // Кнопка сохранения в AppBar
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
            // Поле для ввода заголовка
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

            // Заголовок для секции фотографий
            Text(
              'Добавить фотографию (необязательно)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 12),

            // Превью фотографии
            _buildPreviewImage(),

            // Кнопка выбора фотографии
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

            // Поле для ввода текста записи
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

            // Информация о сохранении
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

            // Большая кнопка сохранения внизу
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