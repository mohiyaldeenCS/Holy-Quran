import 'package:background_downloader/background_downloader.dart';

/// background_downloader's task database in memory. The plugin keeps its
/// records in files, written by an isolate that outlives a test; this keeps
/// them in the test. It is given to the first `FileDownloader(...)` call of a
/// test file, which the plugin keeps as its one instance.
final class MemoryTaskStorage implements PersistentStorage {
  final Map<String, TaskRecord> _records = {};
  final Map<String, Task> _paused = {};
  final Map<String, ResumeData> _resume = {};

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
  Future<TaskRecord?> retrieveTaskRecord(String taskId) async =>
      _records[taskId];

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
