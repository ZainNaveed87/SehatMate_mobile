import 'dart:convert';

class AgentTaskWorkflow {
  const AgentTaskWorkflow({required this.workflowId,required this.kind,required this.revision,required this.status,required this.title,this.confirmationId,this.planId});
  final String workflowId,kind,status;
  final int revision;
  final String? title,confirmationId,planId;
  static bool _closed(Map value,Set<String> keys)=>value.keys.every((k)=>keys.contains(k));
  static bool _token(Object? value)=>value is String&&RegExp(r'^[A-Za-z0-9_.:-]{1,80}$').hasMatch(value);
  factory AgentTaskWorkflow.fromJson(Object? value) {
    if(value is! Map<String,dynamic>||!_closed(value,{'workflowId','kind','revision','status','fields','awaitingField','confirmationId','expiresAt','completedReceipt'})||!_token(value['workflowId'])||value['kind']!='create_care_plan'||value['revision'] is! int||value['revision']<1||value['revision']>10000||!const {'collecting','awaiting_confirmation','completed','cancelled'}.contains(value['status'])||value['fields'] is! Map||!_closed(value['fields'],{'title'})||utf8.encode(jsonEncode(value)).length>2048)throw const FormatException('Invalid Agent task workflow');
    final fields=value['fields'] as Map, title=fields['title'],status=value['status'];
    if(title!=null&&(title is! String||title.runes.length<2||title.runes.length>80||title.trim()!=title||RegExp(r'[\x00-\x1f\x7f]').hasMatch(title)))throw const FormatException('Invalid task title');
    if(value['confirmationId']!=null&&!_token(value['confirmationId']))throw const FormatException('Invalid task confirmation');
    if(value['expiresAt']!=null&&(value['expiresAt'] is! String||value['expiresAt'].length>40||DateTime.tryParse(value['expiresAt'])==null))throw const FormatException('Invalid task expiry');
    if(value['awaitingField']!=null&&value['awaitingField']!='title')throw const FormatException('Invalid awaiting field');
    if(status=='collecting'&&(value['awaitingField']!='title'||title!=null||value['confirmationId']!=null))throw const FormatException('Invalid collecting state');
    if(status=='awaiting_confirmation'&&(title==null||value['confirmationId']==null||value['expiresAt']==null))throw const FormatException('Invalid confirmation state');
    String? planId;
    final receipt=value['completedReceipt'];
    if(status=='completed') {
      if(receipt is! Map||!_closed(receipt,{'confirmationId','planId','title'})||!_token(receipt['confirmationId'])||receipt['confirmationId']!=value['confirmationId']||receipt['planId'] is! String||!RegExp(r'^\d{1,20}$').hasMatch(receipt['planId'])||receipt['title']!=title)throw const FormatException('Invalid completed receipt');
      planId=receipt['planId'];
    }else if(receipt!=null){throw const FormatException('Unexpected completed receipt');}
    return AgentTaskWorkflow(workflowId:value['workflowId'],kind:value['kind'],revision:value['revision'],status:status,title:title,confirmationId:value['confirmationId'],planId:planId);
  }
}
