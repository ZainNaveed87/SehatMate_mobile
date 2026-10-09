import 'package:flutter/widgets.dart';
import '../../../localization/app_language.dart';
import '../../../localization/language_scope.dart';

String copilotText(BuildContext context, String key) {
  final entry = _strings[key];
  if (entry == null) return key;
  return entry[switch (context.appLanguage) {
    AppLanguage.english => 0,
    AppLanguage.urdu => 1,
    AppLanguage.romanUrdu => 2,
  }];
}

const _strings = <String, List<String>>{
  'guided':['Guiding you · Open chat','رہنمائی · چیٹ کھولیں','Rehnumai · Chat kholein'],
  'expand':['Expand chat','چیٹ بڑی کریں','Chat bari karein'],
  'memory': ['Agent memory', 'ایجنٹ کی یادداشت', 'Agent ki yaaddasht'],
  'memory_review': [
    'Review Agent memory',
    'ایجنٹ کی یادداشت دیکھیں',
    'Agent ki yaaddasht dekhein',
  ],
  'minimize': ['Minimize Agent', 'ایجنٹ کو چھوٹا کریں', 'Agent chhota karein'],
  'minimize_voice': [
    'Minimize voice',
    'آواز کی ونڈو چھوٹی کریں',
    'Voice window chhoti karein',
  ],
  'return_voice': [
    'Return to voice',
    'آواز پر واپس جائیں',
    'Voice par wapas jayein',
  ],
  'mute': ['Mute', 'مائیک بند کریں', 'Mic band karein'],
  'unmute': ['Unmute', 'مائیک کھولیں', 'Mic kholein'],
  'pause': ['Pause', 'روکیں', 'Rokein'],
  'resume': ['Resume', 'جاری رکھیں', 'Jari rakhein'],
  'stop': ['Stop guidance', 'رہنمائی بند کریں', 'Rehnumai band karein'],
  'walkthrough_next': ['Next control', 'اگلا کنٹرول', 'Agla control'],
  'walkthrough_previous': ['Previous control', 'پچھلا کنٹرول', 'Pichla control'],
  'succeeded': ['Step completed.', 'مرحلہ مکمل ہوا۔', 'Marhala mukammal hua.'],
  'duplicate': [
    'This step was already handled.',
    'یہ مرحلہ پہلے مکمل ہو چکا ہے۔',
    'Yeh marhala pehle mukammal ho chuka hai.',
  ],
  'stale_context': [
    'The screen changed. Ask again from the current step.',
    'اسکرین بدل گئی ہے۔ موجودہ مرحلے سے دوبارہ پوچھیں۔',
    'Screen badal gayi hai. Maujooda marhalay se dobara poochein.',
  ],
  'cancelled': [
    'Guidance stopped.',
    'رہنمائی بند ہو گئی۔',
    'Rehnumai band ho gayi.',
  ],
  'workflow_paused': [
    'Guidance paused.',
    'رہنمائی رکی ہوئی ہے۔',
    'Rehnumai ruki hui hai.',
  ],
  'action_failed': [
    'This step could not be completed. Review the screen.',
    'یہ مرحلہ مکمل نہیں ہو سکا۔ اسکرین دیکھیں۔',
    'Yeh marhala mukammal nahi ho saka. Screen dekhein.',
  ],
  'unavailable': [
    'This step is unavailable. Review the current screen.',
    'یہ مرحلہ دستیاب نہیں ہے۔ موجودہ اسکرین دیکھیں۔',
    'Yeh marhala dastiyab nahi hai. Maujooda screen dekhein.',
  ],
  'review_change': [
    'Review this change',
    'اس تبدیلی کا جائزہ لیں',
    'Is tabdeeli ka jaiza lein',
  ],
  'save_notice': [
    'This step may save your Reality Check answers or advance the care-plan workflow.',
    'یہ مرحلہ آپ کے ریئلٹی چیک کے جواب محفوظ کر سکتا ہے یا نگہداشت کے اگلے مرحلے پر لے جا سکتا ہے۔',
    'Yeh marhala aap ke Reality Check jawab mehfooz kar sakta hai ya care plan ke aglay marhalay par le ja sakta hai.',
  ],
  'remember_question': [
    'Remember this for future help?',
    'آئندہ مدد کے لیے یہ بات یاد رکھیں؟',
    'Aainda madad ke liye yeh baat yaad rakhein?',
  ],
  'not_now': ['Not now', 'ابھی نہیں', 'Abhi nahi'],
  'remember': ['Remember', 'یاد رکھیں', 'Yaad rakhein'],
  'memory_failed': [
    'This preference could not be remembered. Please try again.',
    'یہ ترجیح محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
    'Yeh pasand mehfooz nahi ho saki. Dobara koshish karein.',
  ],
  'memory_help': [
    'Review or forget saved preferences and constraints.',
    'محفوظ ترجیحات اور پابندیاں دیکھیں یا مٹا دیں۔',
    'Mehfooz pasand aur pabandiyan dekhein ya mita dein.',
  ],
  'memory_unavailable': [
    'Agent memory is unavailable. Please try again.',
    'ایجنٹ کی یادداشت دستیاب نہیں ہے۔ دوبارہ کوشش کریں۔',
    'Agent ki yaaddasht dastiyab nahi hai. Dobara koshish karein.',
  ],
  'memory_empty': [
    'No saved Agent memory.',
    'ایجنٹ کی کوئی یادداشت محفوظ نہیں ہے۔',
    'Agent ki koi yaaddasht mehfooz nahi hai.',
  ],
  'inferred': [
    'Inferred; not a confirmed fact',
    'اندازہ؛ تصدیق شدہ حقیقت نہیں',
    'Andaza; tasdeeq shuda haqeeqat nahi',
  ],
  'confirmed_memory': [
    'Saved with your confirmation',
    'آپ کی تصدیق کے ساتھ محفوظ',
    'Aap ki tasdeeq ke sath mehfooz',
  ],
  'forget': ['Forget', 'مٹا دیں', 'Mita dein'],
  'forget_failed': [
    'This memory could not be forgotten. Try again.',
    'یہ یادداشت مٹ نہیں سکی۔ دوبارہ کوشش کریں۔',
    'Yeh yaaddasht mit nahi saki. Dobara koshish karein.',
  ],
  'show_issue': [
    'Show affected section',
    'متعلقہ حصہ دکھائیں',
    'Mutaliqa hissa dikhayein',
  ],
  'review_routine': [
    'Review routine',
    'معمول کا جائزہ لیں',
    'Mamool ka jaiza lein',
  ],
  'review_caregiver': [
    'Review caregiver support',
    'نگہداشت کی مدد دیکھیں',
    'Caregiver ki madad dekhein',
  ],
  'review_reminders': [
    'Review reminders',
    'یاد دہانیاں دیکھیں',
    'Yaad dehaniyan dekhein',
  ],
  'open_care_gap': [
    'Open related care gap',
    'متعلقہ نگہداشت کا مسئلہ کھولیں',
    'Mutaliqa care gap kholein',
  ],
  'open_reality_check': [
    'Open Reality Check',
    'ریئلٹی چیک کھولیں',
    'Reality Check kholein',
  ],
  'keep_current_setup': [
    'Keep current setup',
    'موجودہ ترتیب رکھیں',
    'Maujooda tarteeb rakhein',
  ],
  'professional_review': [
    'Ask your healthcare professional before changing treatment.',
    'علاج بدلنے سے پہلے اپنے معالج سے پوچھیں۔',
    'Ilaj badalne se pehle apne doctor se poochein.',
  ],
  'timing_availability': [
    'A scheduled task overlaps your confirmed availability constraint.',
    'ایک کام کا وقت آپ کی تصدیق شدہ مصروفیت سے ٹکراتا ہے۔',
    'Aik kaam ka waqt aap ki tasdeeq shuda masroofiyat se takrata hai.',
  ],
  'overlapping_schedule': [
    'Two scheduled tasks share the same time.',
    'دو کام ایک ہی وقت پر ہیں۔',
    'Do kaam aik hi waqt par hain.',
  ],
  'repeated_missed_tasks': [
    'Verified task history shows repeated missed tasks.',
    'تصدیق شدہ ریکارڈ میں کئی کام رہ گئے ہیں۔',
    'Tasdeeq shuda record mein kai kaam reh gaye hain.',
  ],
  'unresolved_care_gap': [
    'A verified care gap still needs attention.',
    'نگہداشت کے ایک تصدیق شدہ مسئلے پر توجہ درکار ہے۔',
    'Care ke aik tasdeeq shuda maslay par tawajjoh darkar hai.',
  ],
  'incomplete_reality_check': [
    'Some Reality Check answers are incomplete.',
    'ریئلٹی چیک کے کچھ جواب نامکمل ہیں۔',
    'Reality Check ke kuch jawab namukammal hain.',
  ],
  'caregiver_preference_unmet': [
    'Caregiver support does not match your confirmed preference.',
    'نگہداشت کی مدد آپ کی تصدیق شدہ ترجیح کے مطابق نہیں ہے۔',
    'Caregiver ki madad aap ki tasdeeq shuda pasand ke mutabiq nahi hai.',
  ],
  'overdue_follow_up': [
    'A verified follow-up is overdue.',
    'ایک تصدیق شدہ فالو اپ کا وقت گزر چکا ہے۔',
    'Aik tasdeeq shuda follow-up ka waqt guzar chuka hai.',
  ],
};
