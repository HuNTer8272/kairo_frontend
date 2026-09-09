import 'package:flutter/material.dart';

class TopStatusBar extends StatelessWidget {
  const TopStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        children: [
          const Text('P R N D', style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 2.4,
            color: Color(0xFF676A6D),
          )),
          const SizedBox(width: 24),
          const Icon(Icons.battery_5_bar_rounded, size: 23),
          const SizedBox(width: 6),
          const Text('80%', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.lock_open_rounded),
          ),
          const Icon(Icons.person_rounded, size: 22),
          const SizedBox(width: 8),
          const Text('Guest', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600,
            color: Color(0xFF5E6063),
          )),
          const SizedBox(width: 18),
          const Icon(Icons.radio_button_checked_rounded, size: 22),
          const Spacer(),
          const Text('12:00 pm', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600,
          )),
          const SizedBox(width: 28),
          const Text('22°C', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600,
          )),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3B3D),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PASSENGER\nAIRBAG ON',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white, fontSize: 8, height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
