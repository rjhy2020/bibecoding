import 'package:flutter/material.dart';

class FontWarmUp extends StatelessWidget {
  const FontWarmUp({super.key});
  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: Text(
        '가나다라마바사아자차카타파하',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

