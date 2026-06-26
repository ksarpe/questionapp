import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The brief placeholder shown while a reveal RPC is in flight on the slot.
class RevealingIndicator extends StatelessWidget {
  const RevealingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.spark,
          ),
        ),
      ],
    );
  }
}
