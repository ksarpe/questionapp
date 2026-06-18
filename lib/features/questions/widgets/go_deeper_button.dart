import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The glowing "wejdz glebiej" pill. Tapping it opens the "Smaczki" panel from
/// the bottom.
class GoDeeperButton extends StatelessWidget {
  const GoDeeperButton({super.key, required this.onTap});

  final VoidCallback onTap;

  static const label = 'WEJDŹ GŁĘBIEJ';
  static const _radius = BorderRadius.all(Radius.circular(30));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: _radius,

              border: Border.fromBorderSide(
                BorderSide(color: Color.fromARGB(255, 35, 2, 112)),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, color: AppTheme.spark, size: 20),
                  SizedBox(width: 10),
                  _Label(),
                  SizedBox(width: 10),
                  _SparkDot(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label();

  @override
  Widget build(BuildContext context) {
    return const Text(
      GoDeeperButton.label,
      style: TextStyle(
        color: AppTheme.ink,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _SparkDot extends StatelessWidget {
  const _SparkDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: AppTheme.spark,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x808B5CF6), blurRadius: 6)],
      ),
    );
  }
}
