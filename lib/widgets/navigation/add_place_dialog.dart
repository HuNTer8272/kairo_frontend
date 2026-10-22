import 'package:flutter/material.dart';

/// A short prompt for the new place's name before opening the full address
/// editor — same two-step flow as Google Maps' "Add a label".
Future<String?> showAddPlaceDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add a place'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. School, Gym'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Next'),
        ),
      ],
    ),
  );
}
