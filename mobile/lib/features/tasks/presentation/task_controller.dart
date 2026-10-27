/// Task-list state and actions, kept outside the widgets.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';

/// Immutable snapshot of the task screen.
class TaskState {
  /// Creates a task state.
  const TaskState({
    this.loading = false,
    this.tasks = const [],
    this.errorMessage,
  });

  /// Whether the list is being (re)loaded.
  final bool loading;

  /// Loaded tasks.
  final List<Task> tasks;

  /// Safe error message from the last load, if it failed.
  final String? errorMessage;
}

/// Loads and mutates the signed-in user's tasks.
class TaskController extends Notifier<TaskState> {
  @override
  TaskState build() => const TaskState(loading: true);

  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  /// Loads the first page of tasks.
  Future<void> load() async {
    state = const TaskState(loading: true);
    try {
      final tasks = await _repo.list();
      if (ref.mounted) state = TaskState(tasks: tasks);
    } on ApiException catch (e) {
      if (ref.mounted) state = TaskState(errorMessage: e.message);
    }
  }

  /// Creates a task. Returns a safe error message, or null on success.
  Future<String?> add(String title, String? description) {
    return _mutate(() async {
      final task = await _repo.create(title, description);
      if (!ref.mounted) return;
      state = TaskState(tasks: [task, ...state.tasks]);
    });
  }

  /// Toggles completion.
  Future<String?> toggle(Task task) {
    return _mutate(() async {
      final updated = await _repo.setCompleted(task, !task.completed);
      if (!ref.mounted) return;
      _replace(updated);
    });
  }

  /// Edits title and description.
  Future<String?> edit(Task task, String title, String? description) {
    return _mutate(() async {
      final updated = await _repo.edit(task, title, description);
      if (!ref.mounted) return;
      _replace(updated);
    });
  }

  /// Deletes a task.
  Future<String?> delete(Task task) {
    return _mutate(() async {
      await _repo.delete(task.id);
      if (!ref.mounted) return;
      state = TaskState(
        tasks: state.tasks.where((t) => t.id != task.id).toList(),
      );
    });
  }

  void _replace(Task updated) {
    state = TaskState(
      tasks: [
        for (final t in state.tasks) t.id == updated.id ? updated : t,
      ],
    );
  }

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }
}

/// Task-list state for the signed-in user.
final taskControllerProvider =
    NotifierProvider<TaskController, TaskState>(TaskController.new);
