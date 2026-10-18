import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/state/app_info.dart';

void main() {
  test('the displayed version drops a zero patch, and only that', () {
    expect(displayVersion('1.0.0'), '1.0');
    expect(displayVersion('1.1.0'), '1.1');
    expect(displayVersion('1.10.0'), '1.10');
    expect(displayVersion('1.1.1'), '1.1.1');
    expect(displayVersion('2.0.10'), '2.0.10');
    expect(displayVersion('1.0'), '1.0');
  });
}
