import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts the plugin's one instance on a [MemoryTaskStorage], on Wi-Fi: since
/// 9.6 it reads connectivity as it starts, and holds its tasks without a
/// network. Call it before setting [HttpOverrides.global], which the test
/// binding replaces.
FileDownloader memoryFileDownloader() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (call) async => ['wifi'],
    )
    ..setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
  return FileDownloader(persistentStorage: MemoryTaskStorage());
}

/// background_downloader's task database in memory. The plugin keeps its
/// records in files, written by an isolate that outlives a test; this keeps
/// them in the test. It is given to the first `FileDownloader(...)` call of a
/// test file, which the plugin keeps as its one instance.
final class MemoryTaskStorage implements PersistentStorage {
  final Map<String, TaskRecord> _records = {};
  final Map<String, Task> _paused = {};
  final Map<String, ResumeData> _resume = {};

  /// How long a read of a task record takes; the record it answers with is
  /// the one there was when the read began.
  Duration? lag;

  @override
  (String, int) get currentDatabaseVersion => ('memory', 1);

  @override
  Future<(String, int)> get storedDatabaseVersion async => ('memory', 1);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> storeTaskRecord(TaskRecord record) async =>
      _records[record.taskId] = record;

  @override
  Future<TaskRecord?> retrieveTaskRecord(String taskId) async {
    final record = _records[taskId];
    if (lag case final lag?) await Future<void>.delayed(lag);
    return record;
  }

  @override
  Future<List<TaskRecord>> retrieveAllTaskRecords() async => [
    ..._records.values,
  ];

  @override
  Future<void> removeTaskRecord(String? taskId) async =>
      _remove(_records, taskId);

  @override
  Future<void> storePausedTask(Task task) async => _paused[task.taskId] = task;

  @override
  Future<Task?> retrievePausedTask(String taskId) async => _paused[taskId];

  @override
  Future<List<Task>> retrieveAllPausedTasks() async => [..._paused.values];

  @override
  Future<void> removePausedTask(String? taskId) async =>
      _remove(_paused, taskId);

  @override
  Future<void> storeResumeData(ResumeData resumeData) async =>
      _resume[resumeData.taskId] = resumeData;

  @override
  Future<ResumeData?> retrieveResumeData(String taskId) async =>
      _resume[taskId];

  @override
  Future<List<ResumeData>> retrieveAllResumeData() async => [..._resume.values];

  @override
  Future<void> removeResumeData(String? taskId) async =>
      _remove(_resume, taskId);

  static void _remove(Map<String, Object> map, String? key) =>
      key == null ? map.clear() : map.remove(key);
}
