import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/models/agent_context.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';

void main() {
  group('Agent response models', () {
    test('parse valid response', () {
      final response = AgentResponse.fromJson(const {
        'success': true,
        'sessionId': 's1',
        'language': 'roman_ur',
        'reply': 'Aap ki performance stable hai.',
        'navigation': {
          'target': 'care_plan_detail',
          'params': {'carePlanId': 'cp1'},
        },
        'referencedEntities': [
          {'type': 'care_plan', 'id': 'cp1'},
        ],
      });

      expect(response.sessionId, 's1');
      expect(response.language, 'roman_ur');
      expect(response.reply, 'Aap ki performance stable hai.');
      expect(response.navigation?.target, 'care_plan_detail');
      expect(response.navigation?.params['carePlanId'], 'cp1');
      expect(response.referencedEntities.single.type, 'care_plan');
    });

    test('parse null navigation', () {
      final response = AgentResponse.fromJson(const {
        'success': true,
        'sessionId': 's1',
        'language': 'en',
        'reply': 'Your next task is ready.',
        'navigation': null,
        'referencedEntities': [],
      });

      expect(response.navigation, isNull);
      expect(response.referencedEntities, isEmpty);
    });

    test('malformed response fails safely', () {
      expect(
        () => AgentResponse.fromJson(const {
          'success': true,
          'sessionId': 's1',
          'language': 'en',
        }),
        throwsFormatException,
      );
    });

    test('unsupported response language is rejected', () {
      expect(
        () => AgentResponse.fromJson(const {
          'success': true,
          'sessionId': 's1',
          'language': 'fr',
          'reply': 'Bonjour',
          'navigation': null,
          'referencedEntities': [],
        }),
        throwsFormatException,
      );
    });

    test('referenced entities accept only supported semantic ids', () {
      final response = AgentResponse.fromJson(const {
        'success': true,
        'sessionId': 's1',
        'language': 'ur',
        'reply': 'ٹھیک ہے۔',
        'navigation': null,
        'referencedEntities': [
          {'type': 'care_plan', 'id': 'cp1'},
          {'type': 'care_gap', 'id': 'gap-1'},
        ],
      });

      expect(response.referencedEntities.map((item) => item.type), [
        'care_plan',
        'care_gap',
      ]);
    });

    test('unsupported referenced entity type is rejected', () {
      expect(
        () => AgentResponse.fromJson(const {
          'success': true,
          'sessionId': 's1',
          'language': 'en',
          'reply': 'Done.',
          'navigation': null,
          'referencedEntities': [
            {'type': 'appointment', 'id': 'a1'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('malformed referenced entity id is rejected', () {
      expect(
        () => AgentResponse.fromJson(const {
          'success': true,
          'sessionId': 's1',
          'language': 'en',
          'reply': 'Done.',
          'navigation': null,
          'referencedEntities': [
            {'type': 'care_gap', 'id': '../gap'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('Agent request', () {
    test('serializes only semantic context', () {
      final request = AgentRequest(
        sessionId: 's1',
        message: 'Ye 85% kyun hai?',
        context: const AgentScreenContext(
          screenId: 'simulation',
          entity: AgentEntityContext(type: 'care_plan', id: 'cp1'),
        ),
      );

      final json = request.toJson();
      expect(json, containsPair('sessionId', 's1'));
      expect(json, containsPair('message', 'Ye 85% kyun hai?'));
      expect(json, isNot(contains('userId')));
      expect(json, isNot(contains('language')));
      expect(json.toString(), isNot(contains('medicine')));
      expect(json.toString(), isNot(contains('dose')));
      expect(json.toString(), isNot(contains('frequency')));
      expect(json.toString(), isNot(contains('score')));
      expect(json.toString(), isNot(contains('status')));
      expect(json['context'], {
        'screenId': 'simulation',
        'entity': {'type': 'care_plan', 'id': 'cp1'},
      });
    });
  });
}
