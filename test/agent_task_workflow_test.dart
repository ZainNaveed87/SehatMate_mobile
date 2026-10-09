import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sehatmate_ai/features/agent/models/agent_response.dart';
import 'package:sehatmate_ai/features/agent/controllers/agent_controller.dart';
import 'package:sehatmate_ai/features/agent/models/agent_request.dart';
class NeverClient implements AgentClient{int calls=0;@override Future<AgentResponse> send(AgentRequest r)async{calls++;throw StateError('unexpected');}}
Map<String,dynamic> snapshot({String title='Ali',String confirmation='confirm-1'})=>{'workflowId':'workflow-1','kind':'create_care_plan','revision':2,'status':'awaiting_confirmation','fields':{'title':title},'confirmationId':confirmation,'expiresAt':'2999-01-01T00:00:00.000Z'};
Map<String,dynamic> envelope(Map<String,dynamic> task)=>{'success':true,'sessionId':'501','language':'roman_ur','reply':'Naam confirm karein.','referencedEntities':[],'actionStatus':'awaiting_confirmation','confirmation':{'confirmationId':task['confirmationId'],'kind':'create_care_plan','message':'Naam confirm karein.'},'taskWorkflow':task};
void main(){
 test('strict creation metadata and confirmation kind survive the shared voice path',()async{
 SharedPreferences.setMockInitialValues({});final client=NeverClient();final agent=AgentController(client:client);
 await agent.acceptVoiceResult(AgentResponse.fromJson(envelope(snapshot())),transcript:'اصل آواز');
 expect(agent.taskWorkflow!.title,'Ali');expect(agent.pendingConfirmation!.kind,'create_care_plan');
 await agent.acceptVoiceResult(AgentResponse.fromJson(envelope(snapshot(title:'Zain',confirmation:'confirm-2'))));
 expect(agent.taskWorkflow!.title,'Zain');expect(agent.pendingConfirmation!.confirmationId,'confirm-2');expect(client.calls,0);agent.dispose();expect(agent.taskWorkflow,null);
 });
 test('malformed workflow and cross-workflow confirmation fail closed',(){
 for(final task in [ {...snapshot(),'kind':'clinical_change'},{...snapshot(),'revision':0},{...snapshot(),'fields':{'title':'Ali','dose':20}},{...snapshot(),'fields':{'title':'x'*81}}]){expect(()=>AgentResponse.fromJson(envelope(task)),throwsFormatException);}
 final wrong=envelope(snapshot());(wrong['confirmation'] as Map)['confirmationId']='wrong';expect(()=>AgentResponse.fromJson(wrong),throwsFormatException);
 });
}
