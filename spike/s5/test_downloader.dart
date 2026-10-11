import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

/// background_downloader's desktop downloader, set up to run under
/// `flutter test` (spike/s5/background_downloader_probe_test.dart says
/// why each step is needed). Undo with [stopDesktopDownloaderForTests].
Future<FileDownloader> startDesktopDownloaderForTests(Directory temp) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux;
  final downloader = FileDownloader(persistentStorage: MemoryTaskStorage());
  await downloader.ready;
  await downloader.configure(
    globalConfig: (Config.tempFilePath, '${temp.path}/partial'),
  );
  return downloader;
}

void stopDesktopDownloaderForTests() =>
    debugDefaultTargetPlatformOverride = null;

/// background_downloader's task database in memory. Its default store
/// finds its directory through path_provider in a background isolate,
/// which never answers under `flutter test`.
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

  static void _remove(Map<String, Object> map, String? key) {
    if (key == null) {
      map.clear();
    } else {
      map.remove(key);
    }
  }
}
