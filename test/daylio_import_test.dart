import 'package:flutter_test/flutter_test.dart';

import 'package:neurostatus/services/daylio_import_service.dart';

void main() {
  final service = DaylioImportService();

  test('maps the 5-point Daylio mood scale to 1-5', () {
    expect(service.mapMood('horrible'), 1);
    expect(service.mapMood('mauvais'), 2);
    expect(service.mapMood('mouais'), 3);
    expect(service.mapMood('bien'), 4);
    expect(service.mapMood('super'), 5);
    expect(service.mapMood('inconnu'), isNull);
  });

  test('maps known Daylio tags to Neurostatus emotions', () {
    expect(service.mapEmotion('anxieux'), 'Anxiété');
    expect(service.mapEmotion('stressé'), 'Anxiété');
    expect(service.mapEmotion('en colère'), 'Colère');
    expect(service.mapEmotion('détendu'), 'Sérénité');
  });

  test('turns unmapped tags into a capitalized custom emotion', () {
    expect(service.mapEmotion('incertain'), 'Incertitude');
    expect(service.mapEmotion('mauvaise nuit'), 'Mauvaise nuit');
    expect(service.mapEmotion('un-tag-inconnu'), 'Un-tag-inconnu');
  });
}
