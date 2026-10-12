/// Read-only outcome metadata. It never supplies a value or authorizes a write.
class AgentMemoryReceipt {
  const AgentMemoryReceipt({
    required this.operation,
    required this.status,
    required this.key,
  });
  final String operation, status, key;
  factory AgentMemoryReceipt.fromJson(Object? value) {
    const keys = {
      'identity.name',
      'communication.language',
      'explanation.detail',
      'voice.preference',
      'accessibility.reduced_motion',
      'availability.constraint',
      'routine.barrier',
      'caregiver.preference',
      'workflow.preference',
    };
    if (value is! Map<String, dynamic> ||
        value.keys.any(
          (key) => !const {'operation', 'status', 'key'}.contains(key),
        ) ||
        !keys.contains(value['key']) ||
        !(value['operation'] == 'remember'
            ? const {
                'succeeded',
                'failed',
                'verification_failed',
                'cancelled',
              }.contains(value['status'])
            : value['operation'] == 'recall' &&
                  const {
                    'found',
                    'missing',
                    'failed',
                  }.contains(value['status']))) {
      throw const FormatException('Agent memory receipt is invalid.');
    }
    return AgentMemoryReceipt(
      operation: value['operation'] as String,
      status: value['status'] as String,
      key: value['key'] as String,
    );
  }
}
