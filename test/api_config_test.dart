import 'package:flutter_test/flutter_test.dart';
import 'package:house_rent/config/api_config.dart';

void main() {
  test('builds an exact server image variant for Haven storage assets', () {
    final url = ApiConfig.optimizedImageUrl(
      '${ApiConfig.storageBase}/house_images/photo.webp',
      width: 600,
      height: 400,
      quality: 75,
    );
    final uri = Uri.parse(url);

    expect(uri.path, '/api/assets/image');
    expect(uri.queryParameters['path'], 'house_images/photo.webp');
    expect(uri.queryParameters['w'], '600');
    expect(uri.queryParameters['h'], '400');
    expect(uri.queryParameters['q'], '75');
  });

  test('does not proxy an external image through Haven', () {
    const external = 'https://images.example.com/photo.jpg';
    expect(ApiConfig.optimizedImageUrl(external, width: 600), external);
  });
}
