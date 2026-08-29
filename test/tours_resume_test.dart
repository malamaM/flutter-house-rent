import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/screens/home/app_shell.dart';

void main() {
  test('Tours only resumes a recently viewed reel', () {
    final now = DateTime(2026, 8, 29, 12);

    expect(shouldResetTours(null, now), isFalse);
    expect(shouldResetTours(now.subtract(const Duration(seconds: 45)), now),
        isFalse);
    expect(shouldResetTours(now.subtract(const Duration(minutes: 2)), now),
        isTrue);
    expect(
        shouldResetTours(now.subtract(const Duration(hours: 1)), now), isTrue);
  });
}
