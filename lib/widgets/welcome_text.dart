import 'package:flutter/material.dart';
import 'package:house_rent/services/app_data_service.dart';
import 'package:house_rent/theme/app_colors.dart';

class WelcomeText extends StatefulWidget {
  const WelcomeText({Key? key}) : super(key: key);

  @override
  State<WelcomeText> createState() => _WelcomeTextState();
}

class _WelcomeTextState extends State<WelcomeText> {
  String firstName = 'there';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    try {
      final user = await SessionService.currentUser();
      final value = user?['first_name'];
      if (value != null && mounted) setState(() => firstName = value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hello, $firstName',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 8),
          Text('Your next place\nstarts here.',
              style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 10),
          Text('Quality homes to rent across Zambia.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
