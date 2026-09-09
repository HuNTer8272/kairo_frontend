import 'package:flutter/material.dart';

import '../models/dock_item.dart';

/// Icons shown in the bottom dock, left to right.
/// Index 0 (car) and the last index (apps) are handled specially by
/// [VehicleDashboard] — everything in between opens its own screen file.
const List<DockItem> kDockItems = [
  DockItem(Icons.directions_car_filled_rounded, 'Car'),
  DockItem(Icons.phone_rounded, 'Phone'),
  // DockItem(Icons.graphic_eq_rounded, 'Voice'),
  DockItem(Icons.bluetooth_rounded, 'Bluetooth'),
  DockItem(Icons.music_note_rounded, 'Music'),
  // DockItem(Icons.auto_awesome_rounded, 'Assistant'),
  // DockItem(Icons.movie_rounded, 'Theater'),
  DockItem(Icons.apps_rounded, 'Apps'),
];
