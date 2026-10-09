import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/core/app_routes.dart';
import 'package:sehatmate_ai/widgets/app_shell.dart';
import 'package:sehatmate_ai/services/care_plan_service.dart';
void main(){test('major routes use actual form identities and typed owned entity context',(){
 for(final entry in {AppRoutes.carePlanNew:'care_plan_new',AppRoutes.carePlanUpload:'care_plan_upload',AppRoutes.carePlanReview:'care_plan_review',AppRoutes.familyNew:'family_member_new',AppRoutes.simpleCare:'simple_care',AppRoutes.teachBack:'teach_back',AppRoutes.doctorQuestions:'doctor_questions',AppRoutes.documentViewer:'document_viewer'}.entries){expect(agentContextForRoute(entry.key)?.screenId,entry.value);}
 expect(agentContextForRoute(AppRoutes.carePlanUpload,arguments:const CarePlanUploadArgs(planId:'17'))!.entity!.id,'17');
 expect(agentContextForRoute(AppRoutes.auth),null);
});}
