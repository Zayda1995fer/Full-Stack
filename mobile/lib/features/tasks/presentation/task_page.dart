/// Main screen: the signed-in user's tasks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/task.dart';
import 'task_controller.dart';
import 'task_form_dialog.dart';
import 'task_list_view.dart';

enum _MenuAction { logout, logoutAll }

/// Shows the task list with create, toggle, edit, and delete actions.
class TaskPage extends ConsumerStatefulWidget {
  /// Creates the task page.
  const TaskPage({super.key});

  @override
  ConsumerState<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends ConsumerState<TaskPage> {
  @override
  void initState() {
    super.initState();
    // Providers cannot be modified while the widget tree is building.
    Future.microtask(() => ref.read(taskControllerProvider.notifier).load());
  }

  TaskController get _tasks => ref.read(taskControllerProvider.notifier);

  void _showError(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final result = await showTaskFormDialog(context);
    if (result == null) return;
    _showError(await _tasks.add(result.title, result.description));
  }

  Future<void> _edit(Task task) async {
    final result = await showTaskFormDialog(context, initial: task);
    if (result == null) return;
    _showError(await _tasks.edit(task, result.title, result.description));
  }

  Future<void> _delete(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: Text('"${task.title}" se eliminará de forma permanente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _showError(await _tasks.delete(task));
  }

  Future<void> _onMenu(_MenuAction action) async {
    final auth = ref.read(authControllerProvider.notifier);
    switch (action) {
      case _MenuAction.logout:
        await auth.logout();
      case _MenuAction.logoutAll:
        await auth.logoutAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis tareas'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : _tasks.load,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _onMenu(_MenuAction.logout),
          ),
          PopupMenuButton<_MenuAction>(
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _MenuAction.logoutAll,
                child: Text('Cerrar sesión en todos los dispositivos'),
              ),
            ],
          ),
        ],
      ),
      body: TaskListView(
        loading: state.loading,
        tasks: state.tasks,
        errorMessage: state.errorMessage,
        onRetry: _tasks.load,
        onToggle: (task) async => _showError(await _tasks.toggle(task)),
        onDelete: _delete,
        onEdit: _edit,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.loading || state.errorMessage != null ? null : _add,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}
