import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/services/auth_service.dart';

void main() {
  test('auth user is decoded and displays initials', () {
    final user = AuthUser.fromJson(const {
      'id': 7,
      'name': 'Zain Ahmed',
      'email': 'zain@example.com',
    });

    expect(user.id, '7');
    expect(user.name, 'Zain Ahmed');
    expect(user.email, 'zain@example.com');
    expect(user.initials, 'ZA');
  });

  test('single-name user displays one initial', () {
    const user = AuthUser(
      id: '8',
      name: 'Zain',
      email: 'zain@example.com',
    );

    expect(user.initials, 'Z');
  });
}
