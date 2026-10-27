/// Widget tests for the loading, empty, error, and populated task-list states.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_list_view.dart';

Widget _wrap({
  bool loading = false,
  List<Task> tasks = const [],
  String? error,
  VoidCallback? onRetry,
  ValueChanged<Task>? onToggle,
  ValueChanged<Task>? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TaskListView(
        loading: loading,
        tasks: tasks,
        errorMessage: error,
        onRetry: onRetry ?? () {},
        onToggle: onToggle ?? (_) {},
        onDelete: onDelete ?? (_) {},
      ),
    ),
  );
}

void main() {
  const task = Task(id: 't1', title: 'Revisar seguridad', description: 'IDOR', completed: false);

  testWidgets('shows a spinner while loading', (tester) async {
    await tester.pumpWidget(_wrap(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.textContaining('Aún no tienes tareas'), findsOneWidget);
  });

  testWidgets('shows the error and retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(_wrap(error: 'Sin conexión', onRetry: () => retries++));
    expect(find.text('Sin conexión'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });

  testWidgets('shows tasks and forwards toggle/delete', (tester) async {
    Task? toggled;
    Task? deleted;
    await tester.pumpWidget(_wrap(
      tasks: const [task],
      onToggle: (t) => toggled = t,
      onDelete: (t) => deleted = t,
    ));
    expect(find.text('Revisar seguridad'), findsOneWidget);
    expect(find.text('IDOR'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.byTooltip('Eliminar tarea'));
    expect(toggled?.id, 't1');
    expect(deleted?.id, 't1');
  });
}
