import 'package:flutter/material.dart';

/// A single entry in the left-hand list of the settings sidebar
/// (Controls, Dynamics, Charging, ...).
class SettingItem {
  const SettingItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
