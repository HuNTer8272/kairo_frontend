import 'package:flutter/material.dart';

/// A single icon in the bottom dock (car, phone, bluetooth, ...).
class DockItem {
  const DockItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
