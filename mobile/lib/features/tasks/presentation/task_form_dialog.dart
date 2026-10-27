/// Dialog to create or edit a task, with client-side validation.
library;

import 'package:flutter/material.dart';

import '../domain/task.dart';

/// Values returned by [TaskFormDialog].
class TaskFormResult {
  /// Creates a result.
  const TaskFormResult(this.title, this.description);

  /// Task title.
  final String title;

  /// Optional description.
  final String? description;
}

/// Shows the form. Pass [initial] to edit an existing task.
Future<TaskFormResult?> showTaskFormDialog(
  BuildContext context, {
  Task? initial,
}) {
  return showDialog<TaskFormResult>(
    context: context,
    builder: (_) => TaskFormDialog(initial: initial),
  );
}

/// Create/edit form. Validation mirrors the server's Zod schema
/// (title 1–120, description up to 2000) but the server validates again.
class TaskFormDialog extends StatefulWidget {
  /// Creates the dialog.
  const TaskFormDialog({super.key, this.initial});

  /// Task being edited, or null to create a new one.
  final Task? initial;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.initial?.description ?? '');

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      TaskFormResult(_title.text.trim(), _description.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Editar tarea' : 'Nueva tarea'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El título es obligatorio.' : null,
            ),
            TextFormField(
              controller: _description,
              maxLength: 2000,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
