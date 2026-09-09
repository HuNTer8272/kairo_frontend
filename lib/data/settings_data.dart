import 'package:flutter/material.dart';

import '../models/setting_item.dart';

/// Items shown in the left rail of the settings sidebar.
const List<SettingItem> kSettings = [
  SettingItem(Icons.tune_rounded, 'Controls'),
  SettingItem(Icons.speed_rounded, 'Dynamics'),
  SettingItem(Icons.bolt_rounded, 'Charging'),
  SettingItem(Icons.route_rounded, 'Autopilot'),
  SettingItem(Icons.lock_outline_rounded, 'Locks'),
  SettingItem(Icons.light_mode_outlined, 'Lights'),
  SettingItem(Icons.airline_seat_recline_normal_rounded, 'Seats'),
  SettingItem(Icons.monitor_outlined, 'Display'),
  SettingItem(Icons.schedule_rounded, 'Schedule'),
  SettingItem(Icons.health_and_safety_outlined, 'Safety'),
  SettingItem(Icons.build_outlined, 'Service'),
  SettingItem(Icons.system_update_alt_rounded, 'Software'),
];
