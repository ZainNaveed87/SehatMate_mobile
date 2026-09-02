import 'app_language.dart';

class AppStrings {
  AppStrings._();

  static const Map<String, Map<AppLanguage, String>> _values = {
    // Core navigation
    'app_name': {
      AppLanguage.english: 'SehatMate',
      AppLanguage.urdu: 'صحت میٹ',
      AppLanguage.romanUrdu: 'SehatMate',
    },
    'home': {
      AppLanguage.english: 'Home',
      AppLanguage.urdu: 'ہوم',
      AppLanguage.romanUrdu: 'Home',
    },
    'plans': {
      AppLanguage.english: 'Plans',
      AppLanguage.urdu: 'منصوبے',
      AppLanguage.romanUrdu: 'Plans',
    },
    'calendar': {
      AppLanguage.english: 'Calendar',
      AppLanguage.urdu: 'کیلنڈر',
      AppLanguage.romanUrdu: 'Calendar',
    },
    'family_care': {
      AppLanguage.english: 'Family Care',
      AppLanguage.urdu: 'خاندانی نگہداشت',
      AppLanguage.romanUrdu: 'Family Care',
    },
    'more': {
      AppLanguage.english: 'More',
      AppLanguage.urdu: 'مزید',
      AppLanguage.romanUrdu: 'Mazeed',
    },

    'dashboard': {
      AppLanguage.english: 'Dashboard',
      AppLanguage.urdu: 'ڈیش بورڈ',
      AppLanguage.romanUrdu: 'Dashboard',
    },
    'family': {
      AppLanguage.english: 'Family',
      AppLanguage.urdu: 'خاندان',
      AppLanguage.romanUrdu: 'Family',
    },
    'teach_back': {
      AppLanguage.english: 'Teach-Back',
      AppLanguage.urdu: 'سمجھ کی جانچ',
      AppLanguage.romanUrdu: 'Samajh Check',
    },
    'patient_profile': {
      AppLanguage.english: 'Patient Profile',
      AppLanguage.urdu: 'مریض کی پروفائل',
      AppLanguage.romanUrdu: 'Patient Profile',
    },
    'logout': {
      AppLanguage.english: 'Logout',
      AppLanguage.urdu: 'لاگ آؤٹ',
      AppLanguage.romanUrdu: 'Logout',
    },
    'guest_user': {
      AppLanguage.english: 'Guest User',
      AppLanguage.urdu: 'مہمان صارف',
      AppLanguage.romanUrdu: 'Guest User',
    },
    'demo_access': {
      AppLanguage.english: 'Demo access',
      AppLanguage.urdu: 'ڈیمو رسائی',
      AppLanguage.romanUrdu: 'Demo access',
    },
    'care_simulation': {
      AppLanguage.english: 'Care Simulation',
      AppLanguage.urdu: 'نگہداشت کی سیمیولیشن',
      AppLanguage.romanUrdu: 'Care Simulation',
    },
    'simple_care_mode': {
      AppLanguage.english: 'Simple Care Mode',
      AppLanguage.urdu: 'سادہ نگہداشت موڈ',
      AppLanguage.romanUrdu: 'Simple Care Mode',
    },

    // Common actions
    'back': {
      AppLanguage.english: 'Back',
      AppLanguage.urdu: 'واپس',
      AppLanguage.romanUrdu: 'Wapas',
    },
    'continue': {
      AppLanguage.english: 'Continue',
      AppLanguage.urdu: 'جاری رکھیں',
      AppLanguage.romanUrdu: 'Jari rakhein',
    },
    'save': {
      AppLanguage.english: 'Save',
      AppLanguage.urdu: 'محفوظ کریں',
      AppLanguage.romanUrdu: 'Save karein',
    },
    'cancel': {
      AppLanguage.english: 'Cancel',
      AppLanguage.urdu: 'منسوخ',
      AppLanguage.romanUrdu: 'Cancel',
    },
    'done': {
      AppLanguage.english: 'Done',
      AppLanguage.urdu: 'مکمل',
      AppLanguage.romanUrdu: 'Ho gaya',
    },
    'open': {
      AppLanguage.english: 'Open',
      AppLanguage.urdu: 'کھولیں',
      AppLanguage.romanUrdu: 'Kholein',
    },
    'edit': {
      AppLanguage.english: 'Edit',
      AppLanguage.urdu: 'ترمیم',
      AppLanguage.romanUrdu: 'Edit',
    },
    'delete': {
      AppLanguage.english: 'Delete',
      AppLanguage.urdu: 'حذف کریں',
      AppLanguage.romanUrdu: 'Delete karein',
    },
    'retry': {
      AppLanguage.english: 'Try again',
      AppLanguage.urdu: 'دوبارہ کوشش کریں',
      AppLanguage.romanUrdu: 'Dobara koshish karein',
    },
    'refresh': {
      AppLanguage.english: 'Refresh',
      AppLanguage.urdu: 'تازہ کریں',
      AppLanguage.romanUrdu: 'Refresh karein',
    },
    'get_started': {
      AppLanguage.english: 'Get Started',
      AppLanguage.urdu: 'شروع کریں',
      AppLanguage.romanUrdu: 'Shuru karein',
    },
    'start_care_plan': {
      AppLanguage.english: 'Start Care Plan',
      AppLanguage.urdu: 'نگہداشت منصوبہ شروع کریں',
      AppLanguage.romanUrdu: 'Care Plan shuru karein',
    },
    'see_how_it_works': {
      AppLanguage.english: 'See How It Works',
      AppLanguage.urdu: 'دیکھیں یہ کیسے کام کرتا ہے',
      AppLanguage.romanUrdu: 'Dekhein yeh kaise kaam karta hai',
    },
    'view_demo_dashboard': {
      AppLanguage.english: 'View Demo Dashboard',
      AppLanguage.urdu: 'ڈیمو ڈیش بورڈ دیکھیں',
      AppLanguage.romanUrdu: 'Demo Dashboard dekhein',
    },
    'open_menu': {
      AppLanguage.english: 'Open menu',
      AppLanguage.urdu: 'مینو کھولیں',
      AppLanguage.romanUrdu: 'Menu kholein',
    },
    'close_menu': {
      AppLanguage.english: 'Close menu',
      AppLanguage.urdu: 'مینو بند کریں',
      AppLanguage.romanUrdu: 'Menu band karein',
    },
    'good': {
      AppLanguage.english: 'Good',
      AppLanguage.urdu: 'اچھا',
      AppLanguage.romanUrdu: 'Achha',
    },
    'call': {
      AppLanguage.english: 'Call',
      AppLanguage.urdu: 'کال کریں',
      AppLanguage.romanUrdu: 'Call karein',
    },
    'call_phone': {
      AppLanguage.english: 'Call {phone}',
      AppLanguage.urdu: '{phone} پر کال کریں',
      AppLanguage.romanUrdu: '{phone} par call karein',
    },
    'name': {
      AppLanguage.english: 'Name',
      AppLanguage.urdu: 'نام',
      AppLanguage.romanUrdu: 'Name',
    },
    'relationship': {
      AppLanguage.english: 'Relationship',
      AppLanguage.urdu: 'رشتہ',
      AppLanguage.romanUrdu: 'Relationship',
    },
    'phone_number': {
      AppLanguage.english: 'Phone number',
      AppLanguage.urdu: 'فون نمبر',
      AppLanguage.romanUrdu: 'Phone number',
    },
    'availability': {
      AppLanguage.english: 'Availability',
      AppLanguage.urdu: 'دستیابی',
      AppLanguage.romanUrdu: 'Availability',
    },
    'available': {
      AppLanguage.english: 'Available',
      AppLanguage.urdu: 'دستیاب',
      AppLanguage.romanUrdu: 'Available',
    },
    'required_field': {
      AppLanguage.english: 'Required',
      AppLanguage.urdu: 'ضروری',
      AppLanguage.romanUrdu: 'Zaroori',
    },
    'not_set': {
      AppLanguage.english: 'Not set',
      AppLanguage.urdu: 'سیٹ نہیں',
      AppLanguage.romanUrdu: 'Set nahi',
    },
    'task_updated': {
      AppLanguage.english: 'Task updated',
      AppLanguage.urdu: 'کام update ہو گیا',
      AppLanguage.romanUrdu: 'Task update ho gaya',
    },
    'error_invalid_plan_list': {
      AppLanguage.english: 'The server returned an invalid plan list.',
      AppLanguage.urdu: 'Server نے invalid plan list واپس کی۔',
      AppLanguage.romanUrdu: 'Server ne invalid plan list wapas ki.',
    },
    'error_invalid_care_plan': {
      AppLanguage.english: 'The server returned an invalid care plan.',
      AppLanguage.urdu: 'Server نے invalid care plan واپس کیا۔',
      AppLanguage.romanUrdu: 'Server ne invalid care plan wapas kiya.',
    },
    'error_invalid_task_outcome': {
      AppLanguage.english: 'The server returned an invalid task outcome.',
      AppLanguage.urdu: 'Server نے invalid task outcome واپس کیا۔',
      AppLanguage.romanUrdu: 'Server ne invalid task outcome wapas kiya.',
    },
    'error_document_empty_or_too_large': {
      AppLanguage.english:
          'The document is empty or exceeds the 20 MB limit.',
      AppLanguage.urdu:
          'Document خالی ہے یا 20 MB limit سے زیادہ ہے۔',
      AppLanguage.romanUrdu:
          'Document khali hai ya 20 MB limit se zyada hai.',
    },
    'error_invalid_document': {
      AppLanguage.english: 'The server returned an invalid document.',
      AppLanguage.urdu: 'Server نے invalid document واپس کیا۔',
      AppLanguage.romanUrdu: 'Server ne invalid document wapas kiya.',
    },
    'error_missing_document_id': {
      AppLanguage.english: 'The server did not return a document ID.',
      AppLanguage.urdu: 'Server نے document ID واپس نہیں کی۔',
      AppLanguage.romanUrdu: 'Server ne document ID wapas nahi ki.',
    },
    'error_invalid_safety_check': {
      AppLanguage.english: 'The server returned an invalid safety check.',
      AppLanguage.urdu: 'Server نے invalid safety check واپس کیا۔',
      AppLanguage.romanUrdu: 'Server ne invalid safety check wapas kiya.',
    },
    'error_label_image_empty_or_too_large': {
      AppLanguage.english:
          'The label image is empty or exceeds the 10 MB limit.',
      AppLanguage.urdu:
          'Label image خالی ہے یا 10 MB limit سے زیادہ ہے۔',
      AppLanguage.romanUrdu:
          'Label image khali hai ya 10 MB limit se zyada hai.',
    },
    'error_invalid_ingredient_evidence': {
      AppLanguage.english:
          'The server returned invalid ingredient evidence.',
      AppLanguage.urdu:
          'Server نے invalid ingredient evidence واپس کیا۔',
      AppLanguage.romanUrdu:
          'Server ne invalid ingredient evidence wapas kiya.',
    },
    'error_invalid_routine_profile': {
      AppLanguage.english: 'The server returned an invalid routine profile.',
      AppLanguage.urdu: 'Server نے invalid routine profile واپس کی۔',
      AppLanguage.romanUrdu: 'Server ne invalid routine profile wapas ki.',
    },
    'error_invalid_care_gap': {
      AppLanguage.english: 'The server returned an invalid care gap.',
      AppLanguage.urdu: 'Server نے invalid care gap واپس کیا۔',
      AppLanguage.romanUrdu: 'Server ne invalid care gap wapas kiya.',
    },
    'error_enter_professional_answer': {
      AppLanguage.english:
          'Enter the answer you received from your healthcare professional.',
      AppLanguage.urdu:
          'Healthcare professional سے ملا ہوا جواب درج کریں۔',
      AppLanguage.romanUrdu:
          'Healthcare professional se mila hua jawab enter karein.',
    },
    'error_sign_in_to_continue': {
      AppLanguage.english: 'Please sign in to continue.',
      AppLanguage.urdu: 'جاری رکھنے کے لیے sign in کریں۔',
      AppLanguage.romanUrdu: 'Jari rakhne ke liye sign in karein.',
    },
    'error_care_plan_request_failed': {
      AppLanguage.english: 'The care plan request could not be completed.',
      AppLanguage.urdu: 'Care plan request مکمل نہیں ہو سکی۔',
      AppLanguage.romanUrdu: 'Care plan request complete nahi ho saki.',
    },
    'error_invalid_server_response': {
      AppLanguage.english: 'The server returned an invalid response.',
      AppLanguage.urdu: 'Server نے invalid response واپس کیا۔',
      AppLanguage.romanUrdu: 'Server ne invalid response wapas kiya.',
    },
    'error_server_timeout': {
      AppLanguage.english:
          'The server took too long to respond. Please try again.',
      AppLanguage.urdu:
          'Server نے جواب دینے میں بہت وقت لیا۔ دوبارہ کوشش کریں۔',
      AppLanguage.romanUrdu:
          'Server ne jawab dene mein bohat waqt liya. Dobara koshish karein.',
    },
    'error_server_connection': {
      AppLanguage.english:
          'Could not connect to the server. Check your internet connection.',
      AppLanguage.urdu:
          'Server سے connect نہیں ہو سکا۔ اپنی internet connection check کریں۔',
      AppLanguage.romanUrdu:
          'Server se connect nahi ho saka. Apni internet connection check karein.',
    },
    'error_api_connection': {
      AppLanguage.english:
          'Could not connect to the server. Check the API URL and internet connection.',
      AppLanguage.urdu:
          'Server سے connect نہیں ہو سکا۔ API URL اور internet connection check کریں۔',
      AppLanguage.romanUrdu:
          'Server se connect nahi ho saka. API URL aur internet connection check karein.',
    },
    'error_request_failed': {
      AppLanguage.english: 'The request could not be completed.',
      AppLanguage.urdu: 'Request مکمل نہیں ہو سکی۔',
      AppLanguage.romanUrdu: 'Request complete nahi ho saki.',
    },
    'error_upload_failed_try_again': {
      AppLanguage.english: 'Upload failed. Please try again.',
      AppLanguage.urdu: 'Upload ناکام ہو گیا۔ دوبارہ کوشش کریں۔',
      AppLanguage.romanUrdu: 'Upload fail ho gaya. Dobara koshish karein.',
    },
    'error_invalid_profile': {
      AppLanguage.english: 'The server returned an invalid profile.',
      AppLanguage.urdu: 'Server نے invalid profile واپس کی۔',
      AppLanguage.romanUrdu: 'Server ne invalid profile wapas ki.',
    },
    'error_google_client_not_configured': {
      AppLanguage.english: 'Google Web Client ID is not configured.',
      AppLanguage.urdu: 'Google Web Client ID configured نہیں ہے۔',
      AppLanguage.romanUrdu: 'Google Web Client ID configured nahi hai.',
    },
    'error_google_unsupported': {
      AppLanguage.english:
          'Google Sign-In is not supported on this platform.',
      AppLanguage.urdu:
          'اس platform پر Google Sign-In supported نہیں ہے۔',
      AppLanguage.romanUrdu:
          'Is platform par Google Sign-In supported nahi hai.',
    },
    'error_google_missing_token': {
      AppLanguage.english: 'Google did not return a valid ID token.',
      AppLanguage.urdu: 'Google نے valid ID token واپس نہیں کیا۔',
      AppLanguage.romanUrdu: 'Google ne valid ID token wapas nahi kiya.',
    },
    'error_google_cancelled': {
      AppLanguage.english: 'Google Sign-In was cancelled.',
      AppLanguage.urdu: 'Google Sign-In cancel ہو گیا۔',
      AppLanguage.romanUrdu: 'Google Sign-In cancel ho gaya.',
    },
    'error_google_config_incorrect_full': {
      AppLanguage.english:
          'Google Sign-In configuration is incorrect. Check the package name, SHA-1 and Web Client ID.',
      AppLanguage.urdu:
          'Google Sign-In configuration درست نہیں۔ Package name، SHA-1 اور Web Client ID check کریں۔',
      AppLanguage.romanUrdu:
          'Google Sign-In configuration theek nahi. Package name, SHA-1 aur Web Client ID check karein.',
    },
    'error_google_device_config': {
      AppLanguage.english:
          'Google Sign-In is not configured correctly on this device.',
      AppLanguage.urdu:
          'اس device پر Google Sign-In درست configure نہیں ہے۔',
      AppLanguage.romanUrdu:
          'Is device par Google Sign-In theek configure nahi hai.',
    },
    'error_google_ui_unavailable': {
      AppLanguage.english: 'Google Sign-In screen could not be opened.',
      AppLanguage.urdu: 'Google Sign-In screen نہیں کھل سکی۔',
      AppLanguage.romanUrdu: 'Google Sign-In screen nahi khul saki.',
    },
    'error_google_failed': {
      AppLanguage.english: 'Google Sign-In failed. Please try again.',
      AppLanguage.urdu: 'Google Sign-In ناکام ہو گیا۔ دوبارہ کوشش کریں۔',
      AppLanguage.romanUrdu:
          'Google Sign-In fail ho gaya. Dobara koshish karein.',
    },
    'error_google_config_incorrect_short': {
      AppLanguage.english:
          'Google Sign-In configuration is incorrect. Check the Web Client ID.',
      AppLanguage.urdu:
          'Google Sign-In configuration درست نہیں۔ Web Client ID check کریں۔',
      AppLanguage.romanUrdu:
          'Google Sign-In configuration theek nahi. Web Client ID check karein.',
    },
    'error_google_init_failed': {
      AppLanguage.english: 'Google Sign-In could not be initialized.',
      AppLanguage.urdu: 'Google Sign-In initialize نہیں ہو سکا۔',
      AppLanguage.romanUrdu: 'Google Sign-In initialize nahi ho saka.',
    },
    'error_api_url_not_configured': {
      AppLanguage.english:
          'API URL is not configured. Run the app with --dart-define=API_BASE_URL=https://your-domain.com/api',
      AppLanguage.urdu:
          'API URL configured نہیں ہے۔ App کو --dart-define=API_BASE_URL=https://your-domain.com/api کے ساتھ چلائیں۔',
      AppLanguage.romanUrdu:
          'API URL configured nahi hai. App ko --dart-define=API_BASE_URL=https://your-domain.com/api ke saath chalayein.',
    },
    'error_invalid_session': {
      AppLanguage.english: 'The server did not return a valid session.',
      AppLanguage.urdu: 'Server نے valid session واپس نہیں کیا۔',
      AppLanguage.romanUrdu: 'Server ne valid session wapas nahi kiya.',
    },


    'page_load_failed': {
  AppLanguage.english:
      "This page didn't load",

  AppLanguage.urdu:
      'یہ صفحہ لوڈ نہیں ہو سکا',

  AppLanguage.romanUrdu:
      'Yeh page load nahi ho saka',
},

'page_load_failed_description': {
  AppLanguage.english:
      'Something went wrong on our end. You can try refreshing or head back home.',

  AppLanguage.urdu:
      'کچھ غلط ہو گیا ہے۔ آپ دوبارہ کوشش کر سکتے ہیں یا ہوم پر واپس جا سکتے ہیں۔',

  AppLanguage.romanUrdu:
      'Kuch ghalat ho gaya hai. Aap dobara try kar sakte hain ya Home par wapas ja sakte hain.',
},

'go_home': {
  AppLanguage.english:
      'Go home',

  AppLanguage.urdu:
      'ہوم پر جائیں',

  AppLanguage.romanUrdu:
      'Home par jayein',
},
    'page_not_found': {
      AppLanguage.english: 'Page not found',
      AppLanguage.urdu: 'صفحہ نہیں ملا',
      AppLanguage.romanUrdu: 'Page nahi mila',
    },
    'page_not_found_description': {
      AppLanguage.english:
          "The page you're looking for doesn't exist or has been moved.",
      AppLanguage.urdu:
          'آپ جس صفحے کو تلاش کر رہے ہیں وہ موجود نہیں ہے یا منتقل ہو چکا ہے۔',
      AppLanguage.romanUrdu:
          'Jis page ko aap dhoondh rahe hain woh mojood nahi ya move ho chuka hai.',
    },

    // Main product areas
    'care_plans': {
      AppLanguage.english: 'Care Plans',
      AppLanguage.urdu: 'نگہداشت کے منصوبے',
      AppLanguage.romanUrdu: 'Care Plans',
    },
    'instructions': {
      AppLanguage.english: 'Instructions',
      AppLanguage.urdu: 'ہدایات',
      AppLanguage.romanUrdu: 'Hidayaat',
    },
    'schedule': {
      AppLanguage.english: 'Schedule',
      AppLanguage.urdu: 'شیڈول',
      AppLanguage.romanUrdu: 'Schedule',
    },
    'dressing': {
      AppLanguage.english: 'Dressing',
      AppLanguage.urdu: 'ڈریسنگ',
      AppLanguage.romanUrdu: 'Dressing',
    },
    'travel': {
      AppLanguage.english: 'Travel',
      AppLanguage.urdu: 'سفر',
      AppLanguage.romanUrdu: 'Travel',
    },
    'simulation': {
      AppLanguage.english: 'Simulation',
      AppLanguage.urdu: 'سیمیولیشن',
      AppLanguage.romanUrdu: 'Simulation',
    },
    'care_gaps': {
      AppLanguage.english: 'Care Gaps',
      AppLanguage.urdu: 'نگہداشت کی کمی',
      AppLanguage.romanUrdu: 'Care Gaps',
    },
    'documents': {
      AppLanguage.english: 'Documents',
      AppLanguage.urdu: 'دستاویزات',
      AppLanguage.romanUrdu: 'Documents',
    },
    'reality_check': {
      AppLanguage.english: 'Reality Check',
      AppLanguage.urdu: 'عملی جائزہ',
      AppLanguage.romanUrdu: 'Reality Check',
    },
    'progress': {
      AppLanguage.english: 'Progress',
      AppLanguage.urdu: 'پیش رفت',
      AppLanguage.romanUrdu: 'Progress',
    },
    'notifications': {
      AppLanguage.english: 'Notifications',
      AppLanguage.urdu: 'اطلاعات',
      AppLanguage.romanUrdu: 'Notifications',
    },
    'settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.urdu: 'ترتیبات',
      AppLanguage.romanUrdu: 'Settings',
    },
    'doctor_questions': {
      AppLanguage.english: 'Doctor Questions',
      AppLanguage.urdu: 'ڈاکٹر سے سوالات',
      AppLanguage.romanUrdu: 'Doctor se sawalat',
    },

    // Landing
    'landing_nav_how_it_works': {
      AppLanguage.english: 'How It Works',
      AppLanguage.urdu: 'یہ کیسے کام کرتا ہے',
      AppLanguage.romanUrdu: 'Kaise kaam karta hai',
    },
    'landing_nav_features': {
      AppLanguage.english: 'Features',
      AppLanguage.urdu: 'خصوصیات',
      AppLanguage.romanUrdu: 'Features',
    },
    'landing_nav_safety': {
      AppLanguage.english: 'Safety',
      AppLanguage.urdu: 'حفاظت',
      AppLanguage.romanUrdu: 'Safety',
    },
    'landing_nav_faq': {
      AppLanguage.english: 'FAQ',
      AppLanguage.urdu: 'عام سوالات',
      AppLanguage.romanUrdu: 'FAQ',
    },
    'landing_problem_eyebrow': {
      AppLanguage.english: 'The problem',
      AppLanguage.urdu: 'مسئلہ',
      AppLanguage.romanUrdu: 'Masla',
    },
    'landing_problem_title': {
      AppLanguage.english:
          'Care plans are written for ideal days, not real ones.',
      AppLanguage.urdu:
          'نگہداشت منصوبے مثالی دنوں کے لیے لکھے جاتے ہیں، حقیقی دنوں کے لیے نہیں۔',
      AppLanguage.romanUrdu:
          'Care plans ideal dinon ke liye likhe jate hain, real dinon ke liye nahi.',
    },
    'landing_problem_description': {
      AppLanguage.english:
          "Patients leave the hospital with clear instructions and still miss doses, appointments and dressings — not because they don't care, but because daily life gets in the way.",
      AppLanguage.urdu:
          'مریض ہسپتال سے واضح ہدایات کے ساتھ نکلتے ہیں، پھر بھی خوراکیں، اپائنٹمنٹس اور ڈریسنگز رہ جاتی ہیں۔ وجہ لاپرواہی نہیں بلکہ روزمرہ زندگی کی رکاوٹیں ہوتی ہیں۔',
      AppLanguage.romanUrdu:
          'Patients hospital se clear instructions ke saath nikalte hain, phir bhi doses, appointments aur dressings miss ho jati hain. Wajah care ki kami nahi, daily life ki rukawatein hoti hain.',
    },
    'landing_how_it_works_eyebrow': {
      AppLanguage.english: 'How it works',
      AppLanguage.urdu: 'یہ کیسے کام کرتا ہے',
      AppLanguage.romanUrdu: 'Kaise kaam karta hai',
    },
    'landing_how_it_works_title': {
      AppLanguage.english:
          "From doctor's instructions to a plan that fits real life.",
      AppLanguage.urdu:
          'ڈاکٹر کی ہدایات سے ایک ایسا منصوبہ جو حقیقی زندگی میں فٹ آئے۔',
      AppLanguage.romanUrdu:
          'Doctor ki instructions se aisa plan jo real life mein fit aaye.',
    },
    'landing_features_eyebrow': {
      AppLanguage.english: 'Features',
      AppLanguage.urdu: 'خصوصیات',
      AppLanguage.romanUrdu: 'Features',
    },
    'landing_features_title': {
      AppLanguage.english:
          'Everything a family needs to keep the plan on track.',
      AppLanguage.urdu:
          'خاندان کو منصوبہ درست رکھنے کے لیے جو کچھ چاہیے۔',
      AppLanguage.romanUrdu:
          'Family ko plan track par rakhne ke liye jo kuch chahiye.',
    },
    'landing_safety_eyebrow': {
      AppLanguage.english: 'Responsible AI',
      AppLanguage.urdu: 'ذمہ دار AI',
      AppLanguage.romanUrdu: 'Responsible AI',
    },
    'landing_safety_title': {
      AppLanguage.english: 'We are not replacing the doctor.',
      AppLanguage.urdu: 'ہم ڈاکٹر کی جگہ نہیں لے رہے۔',
      AppLanguage.romanUrdu: 'Hum doctor ki jagah nahi le rahe.',
    },
    'landing_safety_description': {
      AppLanguage.english:
          'SehatMate helps organize and understand an existing care plan. It does not diagnose conditions, prescribe treatment or change doses.',
      AppLanguage.urdu:
          'صحت میٹ موجودہ نگہداشت منصوبہ منظم اور سمجھنے میں مدد دیتا ہے۔ یہ تشخیص، علاج تجویز، یا خوراک تبدیل نہیں کرتا۔',
      AppLanguage.romanUrdu:
          'SehatMate existing care plan organize aur samajhne mein madad deta hai. Yeh diagnosis, treatment prescribe, ya dose change nahi karta.',
    },
    'landing_faq_eyebrow': {
      AppLanguage.english: 'FAQ',
      AppLanguage.urdu: 'عام سوالات',
      AppLanguage.romanUrdu: 'FAQ',
    },
    'landing_faq_title': {
      AppLanguage.english: 'Common questions',
      AppLanguage.urdu: 'عام سوالات',
      AppLanguage.romanUrdu: 'Common questions',
    },
    'landing_hero_badge': {
      AppLanguage.english: 'Care-plan support, not diagnosis',
      AppLanguage.urdu: 'نگہداشت منصوبے کی مدد، تشخیص نہیں',
      AppLanguage.romanUrdu: 'Care-plan support, diagnosis nahi',
    },
    'landing_hero_title': {
      AppLanguage.english:
          'Make every care plan easier to follow at home.',
      AppLanguage.urdu:
          'ہر نگہداشت منصوبے پر گھر میں عمل آسان بنائیں۔',
      AppLanguage.romanUrdu:
          'Har care plan ko ghar par follow karna asan banayein.',
    },
    'landing_hero_description': {
      AppLanguage.english:
          'SehatMate AI helps identify real-life barriers that can make doctor-prescribed care difficult to follow, so patients and families can prepare before problems happen.',
      AppLanguage.urdu:
          'صحت میٹ AI حقیقی زندگی کی رکاوٹیں پہچاننے میں مدد دیتا ہے جو ڈاکٹر کی دی ہوئی نگہداشت پر عمل مشکل بنا سکتی ہیں، تاکہ مسئلہ آنے سے پہلے مریض اور خاندان تیاری کر سکیں۔',
      AppLanguage.romanUrdu:
          'SehatMate AI real-life barriers pehchanne mein madad deta hai jo doctor-prescribed care follow karna mushkil bana sakti hain, taa ke patient aur family pehle se tayyar ho saken.',
    },
    'landing_demo_note': {
      AppLanguage.english:
          'Demo experience with sample data. No real medical records required.',
      AppLanguage.urdu:
          'نمونہ ڈیٹا کے ساتھ ڈیمو تجربہ۔ حقیقی طبی ریکارڈز کی ضرورت نہیں۔',
      AppLanguage.romanUrdu:
          'Sample data ke saath demo experience. Real medical records ki zaroorat nahi.',
    },
    'demo_morning_medicine': {
      AppLanguage.english: 'Morning Medicine',
      AppLanguage.urdu: 'صبح کی دوا',
      AppLanguage.romanUrdu: 'Morning Medicine',
    },
    'demo_afternoon_medicine': {
      AppLanguage.english: 'Afternoon Medicine',
      AppLanguage.urdu: 'دوپہر کی دوا',
      AppLanguage.romanUrdu: 'Afternoon Medicine',
    },
    'demo_lab_visit_wednesday': {
      AppLanguage.english: 'Lab Visit — Wednesday',
      AppLanguage.urdu: 'لیب وزٹ — بدھ',
      AppLanguage.romanUrdu: 'Lab Visit — Wednesday',
    },
    'landing_problem_timing_title': {
      AppLanguage.english: 'Timing clashes',
      AppLanguage.urdu: 'وقت کا ٹکراؤ',
      AppLanguage.romanUrdu: 'Timing clashes',
    },
    'landing_problem_timing_body': {
      AppLanguage.english:
          'Doses land while the patient is out of home or asleep.',
      AppLanguage.urdu:
          'خوراکیں ایسے وقت آتی ہیں جب مریض گھر سے باہر یا سو رہا ہوتا ہے۔',
      AppLanguage.romanUrdu:
          'Doses us waqt aati hain jab patient ghar se bahar ya so raha hota hai.',
    },
    'landing_problem_help_title': {
      AppLanguage.english: 'Missing help',
      AppLanguage.urdu: 'مدد دستیاب نہیں',
      AppLanguage.romanUrdu: 'Madad missing',
    },
    'landing_problem_help_body': {
      AppLanguage.english:
          'Tasks need assistance at times when no caregiver is free.',
      AppLanguage.urdu:
          'کاموں کے لیے اس وقت مدد چاہیے جب کوئی caregiver فارغ نہیں ہوتا۔',
      AppLanguage.romanUrdu:
          'Tasks ko us waqt madad chahiye jab koi caregiver free nahi hota.',
    },
    'landing_problem_unclear_title': {
      AppLanguage.english: 'Unclear instructions',
      AppLanguage.urdu: 'غیر واضح ہدایات',
      AppLanguage.romanUrdu: 'Unclear instructions',
    },
    'landing_problem_unclear_body': {
      AppLanguage.english:
          'Handwritten notes leave families guessing about timings.',
      AppLanguage.urdu:
          'ہاتھ سے لکھی ہوئی ہدایات کی وجہ سے خاندان وقت کے بارے میں اندازہ لگاتا رہتا ہے۔',
      AppLanguage.romanUrdu:
          'Handwritten notes ki wajah se families timing ka andaza lagati rehti hain.',
    },
    'step_number': {
      AppLanguage.english: 'Step {number}',
      AppLanguage.urdu: 'مرحلہ {number}',
      AppLanguage.romanUrdu: 'Step {number}',
    },
    'landing_how_upload_title': {
      AppLanguage.english: 'Upload documents',
      AppLanguage.urdu: 'دستاویزات اپ لوڈ کریں',
      AppLanguage.romanUrdu: 'Documents upload karein',
    },
    'landing_how_upload_body': {
      AppLanguage.english:
          'Prescriptions, discharge summaries and follow-up slips.',
      AppLanguage.urdu:
          'نسخے، ڈسچارج خلاصے اور فالو اَپ سلپس۔',
      AppLanguage.romanUrdu:
          'Prescriptions, discharge summaries aur follow-up slips.',
    },
    'landing_how_verify_title': {
      AppLanguage.english: 'Verify extraction',
      AppLanguage.urdu: 'نکالی گئی معلومات کی تصدیق',
      AppLanguage.romanUrdu: 'Extraction verify karein',
    },
    'landing_how_verify_body': {
      AppLanguage.english:
          'You confirm every extracted instruction before it activates.',
      AppLanguage.urdu:
          'ہر نکالی گئی ہدایت فعال ہونے سے پہلے آپ تصدیق کرتے ہیں۔',
      AppLanguage.romanUrdu:
          'Har extracted instruction activate hone se pehle aap confirm karte hain.',
    },
    'landing_how_routine_title': {
      AppLanguage.english: 'Share your routine',
      AppLanguage.urdu: 'اپنی روٹین بتائیں',
      AppLanguage.romanUrdu: 'Apni routine batayein',
    },
    'landing_how_routine_body': {
      AppLanguage.english:
          'A short conversation about your day, help and transport.',
      AppLanguage.urdu:
          'آپ کے دن، مدد اور ٹرانسپورٹ کے بارے میں مختصر گفتگو۔',
      AppLanguage.romanUrdu:
          'Aap ke din, madad aur transport ke baare mein chhoti baat.',
    },
    'landing_how_simulation_title': {
      AppLanguage.english: 'See the simulation',
      AppLanguage.urdu: 'سیمیولیشن دیکھیں',
      AppLanguage.romanUrdu: 'Simulation dekhein',
    },
    'landing_how_simulation_body': {
      AppLanguage.english:
          'A 7-day view showing ready, risky and blocked tasks.',
      AppLanguage.urdu:
          '7 دن کا منظر جو تیار، خطرے والے اور رکے ہوئے کام دکھاتا ہے۔',
      AppLanguage.romanUrdu:
          '7-day view jo ready, risky aur blocked tasks dikhata hai.',
    },
    'landing_feature_simulation_body': {
      AppLanguage.english:
          'Walk through the next seven days before they happen and see exactly where the plan is likely to break.',
      AppLanguage.urdu:
          'اگلے سات دن پہلے سے دیکھیں اور سمجھیں کہ منصوبہ کہاں مشکل ہو سکتا ہے۔',
      AppLanguage.romanUrdu:
          'Agley seven days pehle se dekhein aur samjhein ke plan kahan mushkil ho sakta hai.',
    },
    'landing_feature_teach_back_body': {
      AppLanguage.english:
          "Explain tomorrow's care in your own words and see what was remembered, missed or needs verification.",
      AppLanguage.urdu:
          'کل کی نگہداشت اپنے الفاظ میں سمجھائیں اور دیکھیں کیا یاد رہا، کیا رہ گیا، یا کس چیز کی تصدیق چاہیے۔',
      AppLanguage.romanUrdu:
          'Kal ki care apne lafzon mein samjhayen aur dekhein kya yaad raha, kya miss hua, ya kya verify karna hai.',
    },
    'landing_feature_family_body': {
      AppLanguage.english:
          'Assign tasks to the people who actually help, with the minimum access they need.',
      AppLanguage.urdu:
          'کام انہی لوگوں کو دیں جو مدد کرتے ہیں، صرف ضروری رسائی کے ساتھ۔',
      AppLanguage.romanUrdu:
          'Tasks un logon ko assign karein jo waqai madad karte hain, sirf zaroori access ke saath.',
    },
    'landing_feature_simple_body': {
      AppLanguage.english:
          'One task at a time, large text and a listen button — built for elderly and low-literacy users.',
      AppLanguage.urdu:
          'ایک وقت میں ایک کام، بڑا متن اور سننے کا بٹن — بزرگ اور کم خواندہ صارفین کے لیے۔',
      AppLanguage.romanUrdu:
          'Aik waqt mein aik task, large text aur listen button — elderly aur low-literacy users ke liye.',
    },
    'landing_feature_languages_title': {
      AppLanguage.english: 'Urdu & Roman Urdu',
      AppLanguage.urdu: 'اردو اور Roman Urdu',
      AppLanguage.romanUrdu: 'Urdu & Roman Urdu',
    },
    'landing_feature_languages_body': {
      AppLanguage.english:
          'Switch the interface language so instructions are read the way the family speaks.',
      AppLanguage.urdu:
          'ایپ کی زبان بدلیں تاکہ ہدایات خاندان کی بولی کے مطابق پڑھی جائیں۔',
      AppLanguage.romanUrdu:
          'Interface language switch karein taa ke instructions family ki zaban mein parhi ja saken.',
    },
    'landing_feature_verification_title': {
      AppLanguage.english: 'Human verification',
      AppLanguage.urdu: 'انسانی تصدیق',
      AppLanguage.romanUrdu: 'Human verification',
    },
    'landing_feature_verification_body': {
      AppLanguage.english:
          'Nothing extracted by AI becomes part of the plan until a person confirms it.',
      AppLanguage.urdu:
          'AI سے نکالی گئی کوئی چیز تب تک منصوبے کا حصہ نہیں بنتی جب تک کوئی شخص تصدیق نہ کرے۔',
      AppLanguage.romanUrdu:
          'AI se extracted koi cheez plan ka hissa nahi banti jab tak insan confirm na kare.',
    },
    'landing_safety_verified': {
      AppLanguage.english:
          'Every extracted instruction is verified by a person before it is used.',
      AppLanguage.urdu:
          'ہر نکالی گئی ہدایت استعمال سے پہلے ایک شخص سے تصدیق ہوتی ہے۔',
      AppLanguage.romanUrdu:
          'Har extracted instruction use hone se pehle insan se verify hoti hai.',
    },
    'landing_safety_readiness': {
      AppLanguage.english:
          'Care Readiness reflects practical feasibility, not medical risk.',
      AppLanguage.urdu:
          'Care Readiness عملی امکان دکھاتی ہے، طبی خطرہ نہیں۔',
      AppLanguage.romanUrdu:
          'Care Readiness practical feasibility dikhati hai, medical risk nahi.',
    },
    'landing_safety_questions': {
      AppLanguage.english:
          'Unclear instructions become questions for a qualified healthcare professional.',
      AppLanguage.urdu:
          'غیر واضح ہدایات qualified healthcare professional کے لیے سوالات بن جاتی ہیں۔',
      AppLanguage.romanUrdu:
          'Unclear instructions qualified healthcare professional ke liye sawal ban jati hain.',
    },
    'landing_faq_medical_advice_q': {
      AppLanguage.english: 'Does SehatMate give medical advice?',
      AppLanguage.urdu: 'کیا صحت میٹ طبی مشورہ دیتا ہے؟',
      AppLanguage.romanUrdu: 'Kya SehatMate medical advice deta hai?',
    },
    'landing_faq_medical_advice_a': {
      AppLanguage.english:
          'No. It organizes instructions that a healthcare professional has already given, and helps you follow them at home.',
      AppLanguage.urdu:
          'نہیں۔ یہ healthcare professional کی پہلے سے دی ہوئی ہدایات کو منظم کرتا ہے اور گھر پر عمل میں مدد دیتا ہے۔',
      AppLanguage.romanUrdu:
          'Nahi. Yeh healthcare professional ki pehle se di hui instructions organize karta hai aur ghar par follow karne mein madad deta hai.',
    },
    'landing_faq_readiness_q': {
      AppLanguage.english: 'What does the Care Readiness score mean?',
      AppLanguage.urdu: 'Care Readiness score کا کیا مطلب ہے؟',
      AppLanguage.romanUrdu: 'Care Readiness score ka kya matlab hai?',
    },
    'landing_faq_readiness_a': {
      AppLanguage.english:
          'It shows how practical the care plan is against your daily routine, help and transport. It is not a medical risk score.',
      AppLanguage.urdu:
          'یہ دکھاتا ہے کہ آپ کی روزمرہ روٹین، مدد اور ٹرانسپورٹ کے مقابلے میں منصوبہ کتنا عملی ہے۔ یہ medical risk score نہیں ہے۔',
      AppLanguage.romanUrdu:
          'Yeh dikhata hai ke aap ki daily routine, help aur transport ke against care plan kitna practical hai. Yeh medical risk score nahi.',
    },
    'landing_faq_family_q': {
      AppLanguage.english: 'Can family members use it?',
      AppLanguage.urdu: 'کیا خاندان کے افراد اسے استعمال کر سکتے ہیں؟',
      AppLanguage.romanUrdu: 'Kya family members isay use kar sakte hain?',
    },
    'landing_faq_family_a': {
      AppLanguage.english:
          'Yes. Caregivers can be added with limited access and see only the tasks assigned to them.',
      AppLanguage.urdu:
          'جی ہاں۔ Caregivers کو محدود رسائی کے ساتھ شامل کیا جا سکتا ہے اور وہ صرف اپنے assigned tasks دیکھتے ہیں۔',
      AppLanguage.romanUrdu:
          'Ji haan. Caregivers limited access ke saath add ho sakte hain aur sirf assigned tasks dekhte hain.',
    },
    'landing_faq_privacy_q': {
      AppLanguage.english: 'Is my document data private?',
      AppLanguage.urdu: 'کیا میری دستاویزات کا ڈیٹا نجی ہے؟',
      AppLanguage.romanUrdu: 'Kya mera document data private hai?',
    },
    'landing_faq_privacy_a': {
      AppLanguage.english:
          'Documents stay linked to your care plan and can be deleted at any time from Settings.',
      AppLanguage.urdu:
          'دستاویزات آپ کے نگہداشت منصوبے سے منسلک رہتی ہیں اور Settings سے کبھی بھی حذف کی جا سکتی ہیں۔',
      AppLanguage.romanUrdu:
          'Documents aap ke care plan se linked rehte hain aur Settings se kisi bhi waqt delete ho sakte hain.',
    },
    'landing_faq_languages_q': {
      AppLanguage.english: 'Which languages are supported?',
      AppLanguage.urdu: 'کون سی زبانیں supported ہیں؟',
      AppLanguage.romanUrdu: 'Kaun si languages supported hain?',
    },
    'landing_faq_languages_a': {
      AppLanguage.english:
          'English, Urdu and Roman Urdu, with a simplified low-literacy care mode.',
      AppLanguage.urdu:
          'English، Urdu اور Roman Urdu، ساتھ میں آسان low-literacy care mode۔',
      AppLanguage.romanUrdu:
          'English, Urdu aur Roman Urdu, simplified low-literacy care mode ke saath.',
    },
    'landing_cta_title': {
      AppLanguage.english: 'Prepare the plan before the week begins.',
      AppLanguage.urdu: 'ہفتہ شروع ہونے سے پہلے منصوبہ تیار کریں۔',
      AppLanguage.romanUrdu: 'Hafta shuru hone se pehle plan tayyar karein.',
    },
    'landing_cta_description': {
      AppLanguage.english:
          'Upload the discharge documents, share the daily routine, and see where the care plan needs help.',
      AppLanguage.urdu:
          'ڈسچارج دستاویزات اپ لوڈ کریں، روزمرہ روٹین بتائیں، اور دیکھیں نگہداشت منصوبے کو کہاں مدد چاہیے۔',
      AppLanguage.romanUrdu:
          'Discharge documents upload karein, daily routine share karein, aur dekhein care plan ko kahan help chahiye.',
    },
    'landing_footer_description': {
      AppLanguage.english:
          'SehatMate helps organize and understand an existing care plan. It does not diagnose conditions or prescribe treatment.',
      AppLanguage.urdu:
          'صحت میٹ موجودہ نگہداشت منصوبہ منظم اور سمجھنے میں مدد دیتا ہے۔ یہ تشخیص یا علاج تجویز نہیں کرتا۔',
      AppLanguage.romanUrdu:
          'SehatMate existing care plan organize aur samajhne mein madad deta hai. Yeh diagnosis ya treatment prescribe nahi karta.',
    },
    'landing_footer_copyright': {
      AppLanguage.english:
          '© 2026 SehatMate AI. Demo product for presentation purposes.',
      AppLanguage.urdu:
          '© 2026 SehatMate AI۔ پریزنٹیشن کے لیے ڈیمو product۔',
      AppLanguage.romanUrdu:
          '© 2026 SehatMate AI. Presentation ke liye demo product.',
    },

    // Task outcomes
    'today_tasks': {
      AppLanguage.english: "Today's Tasks",
      AppLanguage.urdu: 'آج کے کام',
      AppLanguage.romanUrdu: 'Aaj ke tasks',
    },
    'upcoming': {
      AppLanguage.english: 'Upcoming',
      AppLanguage.urdu: 'آنے والا',
      AppLanguage.romanUrdu: 'Aane wala',
    },
    'pending': {
      AppLanguage.english: 'Pending',
      AppLanguage.urdu: 'باقی',
      AppLanguage.romanUrdu: 'Baqi',
    },
    'completed': {
      AppLanguage.english: 'Completed',
      AppLanguage.urdu: 'مکمل',
      AppLanguage.romanUrdu: 'Mukammal',
    },
    'missed': {
      AppLanguage.english: 'Missed',
      AppLanguage.urdu: 'رہ گیا',
      AppLanguage.romanUrdu: 'Reh gaya',
    },
    'skipped': {
      AppLanguage.english: 'Skipped',
      AppLanguage.urdu: 'چھوڑا گیا',
      AppLanguage.romanUrdu: 'Skip kiya',
    },
    'complete': {
      AppLanguage.english: 'Complete',
      AppLanguage.urdu: 'مکمل کریں',
      AppLanguage.romanUrdu: 'Complete karein',
    },
    'record_skipped': {
      AppLanguage.english: 'Record skipped',
      AppLanguage.urdu: 'چھوڑا ہوا درج کریں',
      AppLanguage.romanUrdu: 'Skip record karein',
    },
    'undo': {
      AppLanguage.english: 'Undo',
      AppLanguage.urdu: 'واپس کریں',
      AppLanguage.romanUrdu: 'Undo',
    },


// Auth
'back_to_home': {
  AppLanguage.english: 'Back to home',
  AppLanguage.urdu: 'ہوم پر واپس جائیں',
  AppLanguage.romanUrdu: 'Home par wapas jayein',
},

'sign_up': {
  AppLanguage.english: 'Sign Up',
  AppLanguage.urdu: 'اکاؤنٹ بنائیں',
  AppLanguage.romanUrdu: 'Sign Up',
},

'continue_as_guest': {
  AppLanguage.english: 'Continue as Guest',
  AppLanguage.urdu: 'مہمان کے طور پر جاری رکھیں',
  AppLanguage.romanUrdu: 'Guest ke taur par jari rakhein',
},

'continue_with_google': {
  AppLanguage.english: 'Continue with Google',
  AppLanguage.urdu: 'Google کے ساتھ جاری رکھیں',
  AppLanguage.romanUrdu: 'Google ke saath continue karein',
},

'or': {
  AppLanguage.english: 'or',
  AppLanguage.urdu: 'یا',
  AppLanguage.romanUrdu: 'ya',
},

'email': {
  AppLanguage.english: 'Email',
  AppLanguage.urdu: 'ای میل',
  AppLanguage.romanUrdu: 'Email',
},

'password': {
  AppLanguage.english: 'Password',
  AppLanguage.urdu: 'پاس ورڈ',
  AppLanguage.romanUrdu: 'Password',
},

'forgot_password': {
  AppLanguage.english: 'Forgot Password',
  AppLanguage.urdu: 'پاس ورڈ بھول گئے؟',
  AppLanguage.romanUrdu: 'Password bhool gaye?',
},

'password_reset_coming': {
  AppLanguage.english:
      'Password reset will be added with email delivery.',
  AppLanguage.urdu:
      'پاس ورڈ ری سیٹ کی سہولت ای میل کے ذریعے شامل کی جائے گی۔',
  AppLanguage.romanUrdu:
      'Password reset email ke zariye add kiya jayega.',
},

'your_password': {
  AppLanguage.english: 'Your password',
  AppLanguage.urdu: 'اپنا پاس ورڈ درج کریں',
  AppLanguage.romanUrdu: 'Apna password enter karein',
},

'full_name': {
  AppLanguage.english: 'Full name',
  AppLanguage.urdu: 'پورا نام',
  AppLanguage.romanUrdu: 'Full name',
},

'your_full_name': {
  AppLanguage.english: 'Your full name',
  AppLanguage.urdu: 'اپنا پورا نام درج کریں',
  AppLanguage.romanUrdu: 'Apna full name enter karein',
},

'password_min_8_hint': {
  AppLanguage.english: 'At least 8 characters',
  AppLanguage.urdu: 'کم از کم 8 حروف',
  AppLanguage.romanUrdu: 'Kam az kam 8 characters',
},

'create_account': {
  AppLanguage.english: 'Create Account',
  AppLanguage.urdu: 'اکاؤنٹ بنائیں',
  AppLanguage.romanUrdu: 'Account banayein',
},

'enter_valid_email': {
  AppLanguage.english: 'Enter a valid email address.',
  AppLanguage.urdu: 'درست ای میل ایڈریس درج کریں۔',
  AppLanguage.romanUrdu: 'Valid email address enter karein.',
},

'enter_password': {
  AppLanguage.english: 'Enter your password.',
  AppLanguage.urdu: 'اپنا پاس ورڈ درج کریں۔',
  AppLanguage.romanUrdu: 'Apna password enter karein.',
},

'enter_full_name': {
  AppLanguage.english: 'Enter your full name.',
  AppLanguage.urdu: 'اپنا پورا نام درج کریں۔',
  AppLanguage.romanUrdu: 'Apna full name enter karein.',
},

'password_min_8_error': {
  AppLanguage.english:
      'Password must contain at least 8 characters.',
  AppLanguage.urdu:
      'پاس ورڈ میں کم از کم 8 حروف ہونے چاہئیں۔',
  AppLanguage.romanUrdu:
      'Password mein kam az kam 8 characters hone chahiye.',
},

'sign_in_failed': {
  AppLanguage.english: 'Sign in failed. Please try again.',
  AppLanguage.urdu:
      'سائن اِن نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
  AppLanguage.romanUrdu:
      'Sign in nahi ho saka. Dobara try karein.',
},

'account_creation_failed': {
  AppLanguage.english:
      'Account creation failed. Please try again.',
  AppLanguage.urdu:
      'اکاؤنٹ نہیں بن سکا۔ دوبارہ کوشش کریں۔',
  AppLanguage.romanUrdu:
      'Account create nahi ho saka. Dobara try karein.',
},

'google_sign_in_failed': {
  AppLanguage.english:
      'Google Sign-In failed. Please try again.',
  AppLanguage.urdu:
      'Google سے سائن اِن نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
  AppLanguage.romanUrdu:
      'Google Sign-In nahi ho saka. Dobara try karein.',
},

'auth_incorrect_credentials': {
  AppLanguage.english: 'Incorrect email or password.',
  AppLanguage.urdu: 'ای میل یا پاس ورڈ درست نہیں ہے۔',
  AppLanguage.romanUrdu: 'Email ya password sahi nahi hai.',
},

'auth_account_exists': {
  AppLanguage.english:
      'An account with this email already exists.',
  AppLanguage.urdu:
      'اس ای میل کے ساتھ اکاؤنٹ پہلے سے موجود ہے۔',
  AppLanguage.romanUrdu:
      'Is email ke saath account pehle se maujood hai.',
},

'auth_request_failed': {
  AppLanguage.english:
      'Authentication could not be completed. Please try again.',
  AppLanguage.urdu:
      'سائن اِن کا عمل مکمل نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
  AppLanguage.romanUrdu:
      'Authentication complete nahi ho saki. Dobara try karein.',
},

'auth_explainer_title': {
  AppLanguage.english:
      'Doctor Instructions → SehatMate → Better Home Care',
  AppLanguage.urdu:
      'ڈاکٹر کی ہدایات → صحت میٹ → بہتر گھریلو نگہداشت',
  AppLanguage.romanUrdu:
      'Doctor Instructions → SehatMate → Behtar Home Care',
},

'auth_verified_instructions': {
  AppLanguage.english:
      'Verified instructions, never auto-activated',
  AppLanguage.urdu:
      'تصدیق شدہ ہدایات، خودکار طور پر کبھی فعال نہیں کی جاتیں',
  AppLanguage.romanUrdu:
      'Verified instructions kabhi automatically activate nahi hotin',
},

'auth_7_day_simulation': {
  AppLanguage.english:
      'A 7-day simulation of your real routine',
  AppLanguage.urdu:
      'آپ کی حقیقی روٹین کی 7 دن کی سیمیولیشن',
  AppLanguage.romanUrdu:
      'Aap ki real routine ki 7-day simulation',
},

'auth_family_access': {
  AppLanguage.english:
      'Family tasks with minimum necessary access',
  AppLanguage.urdu:
      'خاندانی کام صرف ضروری حد تک رسائی کے ساتھ',
  AppLanguage.romanUrdu:
      'Family tasks sirf zaroori access ke saath',
},

    // Onboarding and profile setup
    'onboarding_step_of_total': {
      AppLanguage.english: 'Step {step} of {total}',
      AppLanguage.urdu: 'مرحلہ {step} از {total}',
      AppLanguage.romanUrdu: 'Step {step} of {total}',
    },
    'go_to_dashboard': {
      AppLanguage.english: 'Go to Dashboard',
      AppLanguage.urdu: 'ڈیش بورڈ پر جائیں',
      AppLanguage.romanUrdu: 'Dashboard par jayein',
    },
    'onboarding_who_title': {
      AppLanguage.english: 'Who are you using SehatMate for?',
      AppLanguage.urdu: 'آپ صحت میٹ کس کے لیے استعمال کر رہے ہیں؟',
      AppLanguage.romanUrdu: 'Aap SehatMate kis ke liye use kar rahe hain?',
    },
    'onboarding_who_subtitle': {
      AppLanguage.english:
          'This helps us decide how much detail to show.',
      AppLanguage.urdu:
          'اس سے ہمیں سمجھ آتا ہے کہ کتنی تفصیل دکھانی ہے۔',
      AppLanguage.romanUrdu:
          'Is se humein samajh aata hai ke kitni detail dikhani hai.',
    },
    'onboarding_myself': {
      AppLanguage.english: 'Myself',
      AppLanguage.urdu: 'اپنے لیے',
      AppLanguage.romanUrdu: 'Mere liye',
    },
    'onboarding_myself_description': {
      AppLanguage.english: 'I am the patient following the care plan.',
      AppLanguage.urdu: 'میں وہ مریض ہوں جو نگہداشت منصوبے پر عمل کر رہا ہے۔',
      AppLanguage.romanUrdu: 'Main woh patient hoon jo care plan follow kar raha hai.',
    },
    'onboarding_someone_i_care_for': {
      AppLanguage.english: 'Someone I care for',
      AppLanguage.urdu: 'کسی عزیز کے لیے',
      AppLanguage.romanUrdu: 'Kisi apne ke liye',
    },
    'onboarding_someone_description': {
      AppLanguage.english: 'I am a family member or caregiver.',
      AppLanguage.urdu: 'میں خاندان کا فرد یا caregiver ہوں۔',
      AppLanguage.romanUrdu: 'Main family member ya caregiver hoon.',
    },
    'preferred_language': {
      AppLanguage.english: 'Preferred language',
      AppLanguage.urdu: 'پسندیدہ زبان',
      AppLanguage.romanUrdu: 'Preferred language',
    },
    'language_change_later_settings': {
      AppLanguage.english: 'You can change this later in Settings.',
      AppLanguage.urdu: 'آپ اسے بعد میں Settings میں بدل سکتے ہیں۔',
      AppLanguage.romanUrdu: 'Aap isay baad mein Settings mein change kar sakte hain.',
    },
    'accessibility': {
      AppLanguage.english: 'Accessibility',
      AppLanguage.urdu: 'آسان رسائی',
      AppLanguage.romanUrdu: 'Accessibility',
    },
    'accessibility_subtitle': {
      AppLanguage.english:
          'Choose how comfortable the interface should be to read and use.',
      AppLanguage.urdu:
          'منتخب کریں کہ interface پڑھنے اور استعمال کرنے میں کتنا آسان ہو۔',
      AppLanguage.romanUrdu:
          'Select karein ke interface parhna aur use karna kitna asan ho.',
    },
    'standard': {
      AppLanguage.english: 'Standard',
      AppLanguage.urdu: 'معمول',
      AppLanguage.romanUrdu: 'Standard',
    },
    'large_text': {
      AppLanguage.english: 'Large Text',
      AppLanguage.urdu: 'بڑا متن',
      AppLanguage.romanUrdu: 'Large Text',
    },
    'voice_guidance': {
      AppLanguage.english: 'Voice Guidance',
      AppLanguage.urdu: 'آواز سے رہنمائی',
      AppLanguage.romanUrdu: 'Voice Guidance',
    },
    'standard_accessibility_description': {
      AppLanguage.english: 'Normal text and full interface.',
      AppLanguage.urdu: 'عام متن اور مکمل interface۔',
      AppLanguage.romanUrdu: 'Normal text aur full interface.',
    },
    'large_text_description': {
      AppLanguage.english: 'Bigger text across the whole app.',
      AppLanguage.urdu: 'پوری ایپ میں بڑا متن۔',
      AppLanguage.romanUrdu: 'Poori app mein bigger text.',
    },
    'voice_guidance_description': {
      AppLanguage.english: 'Listen buttons on care tasks.',
      AppLanguage.urdu: 'نگہداشت tasks پر سننے کے بٹن۔',
      AppLanguage.romanUrdu: 'Care tasks par listen buttons.',
    },
    'simple_care_mode_description': {
      AppLanguage.english: 'One task at a time, very large buttons.',
      AppLanguage.urdu: 'ایک وقت میں ایک task، بہت بڑے بٹن۔',
      AppLanguage.romanUrdu: 'Aik waqt mein aik task, bohat bare buttons.',
    },
    'basic_setup': {
      AppLanguage.english: 'Basic setup',
      AppLanguage.urdu: 'بنیادی سیٹ اپ',
      AppLanguage.romanUrdu: 'Basic setup',
    },
    'basic_setup_subtitle': {
      AppLanguage.english: 'A few details to personalise the plan.',
      AppLanguage.urdu: 'منصوبے کو ذاتی بنانے کے لیے چند تفصیلات۔',
      AppLanguage.romanUrdu: 'Plan personalize karne ke liye kuch details.',
    },
    'patient_name': {
      AppLanguage.english: 'Patient name',
      AppLanguage.urdu: 'مریض کا نام',
      AppLanguage.romanUrdu: 'Patient name',
    },
    'age_group': {
      AppLanguage.english: 'Age group',
      AppLanguage.urdu: 'عمر کا گروپ',
      AppLanguage.romanUrdu: 'Age group',
    },
    'city': {
      AppLanguage.english: 'City',
      AppLanguage.urdu: 'شہر',
      AppLanguage.romanUrdu: 'City',
    },
    'caregiver_support_available': {
      AppLanguage.english: 'Caregiver support available',
      AppLanguage.urdu: 'Caregiver کی مدد دستیاب ہے',
      AppLanguage.romanUrdu: 'Caregiver support available hai',
    },
    'enter_valid_patient_name': {
      AppLanguage.english: 'Enter a valid patient name.',
      AppLanguage.urdu: 'درست مریض کا نام درج کریں۔',
      AppLanguage.romanUrdu: 'Valid patient name enter karein.',
    },
    'enter_valid_city': {
      AppLanguage.english: 'Enter a valid city.',
      AppLanguage.urdu: 'درست شہر درج کریں۔',
      AppLanguage.romanUrdu: 'Valid city enter karein.',
    },
    'onboarding_save_failed': {
      AppLanguage.english: 'Onboarding could not be saved. Please try again.',
      AppLanguage.urdu: 'Onboarding محفوظ نہیں ہو سکی۔ دوبارہ کوشش کریں۔',
      AppLanguage.romanUrdu: 'Onboarding save nahi ho saki. Dobara try karein.',
    },
    'age_under_18': {
      AppLanguage.english: 'Under 18',
      AppLanguage.urdu: '18 سے کم',
      AppLanguage.romanUrdu: 'Under 18',
    },
    'age_18_30': {
      AppLanguage.english: '18 – 30',
      AppLanguage.urdu: '18 – 30',
      AppLanguage.romanUrdu: '18 – 30',
    },
    'age_31_45': {
      AppLanguage.english: '31 – 45',
      AppLanguage.urdu: '31 – 45',
      AppLanguage.romanUrdu: '31 – 45',
    },
    'age_46_59': {
      AppLanguage.english: '46 – 59',
      AppLanguage.urdu: '46 – 59',
      AppLanguage.romanUrdu: '46 – 59',
    },
    'age_60_70': {
      AppLanguage.english: '60 – 70',
      AppLanguage.urdu: '60 – 70',
      AppLanguage.romanUrdu: '60 – 70',
    },
    'age_71_80': {
      AppLanguage.english: '71 – 80',
      AppLanguage.urdu: '71 – 80',
      AppLanguage.romanUrdu: '71 – 80',
    },
    'age_81_plus': {
      AppLanguage.english: '81+',
      AppLanguage.urdu: '81+',
      AppLanguage.romanUrdu: '81+',
    },
    'settings_subtitle': {
      AppLanguage.english: 'Language, accessibility and privacy.',
      AppLanguage.urdu: 'زبان، آسان رسائی اور privacy۔',
      AppLanguage.romanUrdu: 'Language, accessibility aur privacy.',
    },
    'settings_large_text_hint': {
      AppLanguage.english: 'Increase text size across the app',
      AppLanguage.urdu: 'پوری ایپ میں متن کا سائز بڑھائیں',
      AppLanguage.romanUrdu: 'Poori app mein text size barhayein',
    },
    'settings_voice_guidance_hint': {
      AppLanguage.english: 'Read instructions aloud where available',
      AppLanguage.urdu: 'جہاں دستیاب ہو ہدایات آواز سے پڑھیں',
      AppLanguage.romanUrdu: 'Jahan available ho instructions awaz se parhein',
    },
    'settings_simple_care_hint': {
      AppLanguage.english: 'Show one task at a time in plain language',
      AppLanguage.urdu: 'سادہ زبان میں ایک وقت میں ایک task دکھائیں',
      AppLanguage.romanUrdu: 'Simple zaban mein aik waqt mein aik task dikhayein',
    },
    'reduced_motion': {
      AppLanguage.english: 'Reduced motion',
      AppLanguage.urdu: 'کم حرکت',
      AppLanguage.romanUrdu: 'Reduced motion',
    },
    'settings_reduced_motion_hint': {
      AppLanguage.english: 'Minimise animations and transitions',
      AppLanguage.urdu: 'animations اور transitions کم کریں',
      AppLanguage.romanUrdu: 'Animations aur transitions kam karein',
    },
    'open_simple_care_view': {
      AppLanguage.english: 'Open Simple Care view',
      AppLanguage.urdu: 'Simple Care view کھولیں',
      AppLanguage.romanUrdu: 'Simple Care view kholein',
    },
    'privacy_and_data': {
      AppLanguage.english: 'Privacy & data',
      AppLanguage.urdu: 'Privacy اور ڈیٹا',
      AppLanguage.romanUrdu: 'Privacy & data',
    },
    'privacy_data_description': {
      AppLanguage.english:
          'Your documents and answers are used only to build and verify your care plan.',
      AppLanguage.urdu:
          'آپ کی دستاویزات اور جوابات صرف نگہداشت منصوبہ بنانے اور verify کرنے کے لیے استعمال ہوتے ہیں۔',
      AppLanguage.romanUrdu:
          'Aap ke documents aur answers sirf care plan banane aur verify karne ke liye use hote hain.',
    },
    'data_export_requested': {
      AppLanguage.english: 'Data export requested',
      AppLanguage.urdu: 'ڈیٹا export کی درخواست ہو گئی',
      AppLanguage.romanUrdu: 'Data export request ho gayi',
    },
    'account_deletion_demo_disabled': {
      AppLanguage.english: 'Account deletion is disabled in this demo.',
      AppLanguage.urdu: 'اس demo میں account deletion disabled ہے۔',
      AppLanguage.romanUrdu: 'Is demo mein account deletion disabled hai.',
    },
    'export_my_data': {
      AppLanguage.english: 'Export my data',
      AppLanguage.urdu: 'میرا ڈیٹا export کریں',
      AppLanguage.romanUrdu: 'Mera data export karein',
    },
    'delete_account': {
      AppLanguage.english: 'Delete account',
      AppLanguage.urdu: 'اکاؤنٹ حذف کریں',
      AppLanguage.romanUrdu: 'Account delete karein',
    },
    'settings_safety_note': {
      AppLanguage.english:
          'SehatMate supports understanding of an existing care plan. It does not provide medical advice or diagnosis.',
      AppLanguage.urdu:
          'صحت میٹ موجودہ نگہداشت منصوبہ سمجھنے میں مدد دیتا ہے۔ یہ طبی مشورہ یا تشخیص فراہم نہیں کرتا۔',
      AppLanguage.romanUrdu:
          'SehatMate existing care plan samajhne mein madad deta hai. Yeh medical advice ya diagnosis provide nahi karta.',
    },
    'enter_valid_name_and_city': {
      AppLanguage.english: 'Enter a valid name and city.',
      AppLanguage.urdu: 'درست نام اور شہر درج کریں۔',
      AppLanguage.romanUrdu: 'Valid name aur city enter karein.',
    },
    'profile_updated': {
      AppLanguage.english: 'Profile updated',
      AppLanguage.urdu: 'پروفائل update ہو گئی',
      AppLanguage.romanUrdu: 'Profile update ho gayi',
    },
    'profile_update_failed': {
      AppLanguage.english: 'Profile could not be updated.',
      AppLanguage.urdu: 'پروفائل update نہیں ہو سکی۔',
      AppLanguage.romanUrdu: 'Profile update nahi ho saki.',
    },
    'patient_profile_subtitle': {
      AppLanguage.english:
          'Used to check whether the care plan fits daily life.',
      AppLanguage.urdu:
          'اس سے دیکھا جاتا ہے کہ نگہداشت منصوبہ روزمرہ زندگی میں فٹ بیٹھتا ہے یا نہیں۔',
      AppLanguage.romanUrdu:
          'Is se check hota hai ke care plan daily life mein fit hota hai ya nahi.',
    },
    'update_reality_check': {
      AppLanguage.english: 'Update Reality Check',
      AppLanguage.urdu: 'Reality Check update کریں',
      AppLanguage.romanUrdu: 'Reality Check update karein',
    },
    'basic_details': {
      AppLanguage.english: 'Basic details',
      AppLanguage.urdu: 'بنیادی تفصیلات',
      AppLanguage.romanUrdu: 'Basic details',
    },
    'daily_routine_and_support': {
      AppLanguage.english: 'Daily routine & support',
      AppLanguage.urdu: 'روزمرہ روٹین اور مدد',
      AppLanguage.romanUrdu: 'Daily routine & support',
    },
    'caregiver_support': {
      AppLanguage.english: 'Caregiver support',
      AppLanguage.urdu: 'Caregiver کی مدد',
      AppLanguage.romanUrdu: 'Caregiver support',
    },
    'manage_caregivers': {
      AppLanguage.english: 'Manage caregivers',
      AppLanguage.urdu: 'Caregivers manage کریں',
      AppLanguage.romanUrdu: 'Caregivers manage karein',
    },
    'patient_profile_safety_note': {
      AppLanguage.english:
          'This profile stores practical living information only, never clinical assessments.',
      AppLanguage.urdu:
          'یہ profile صرف عملی زندگی کی معلومات محفوظ کرتی ہے، clinical assessments نہیں۔',
      AppLanguage.romanUrdu:
          'Yeh profile sirf practical living information store karti hai, clinical assessments nahi.',
    },
    'family_and_caregivers': {
      AppLanguage.english: 'Family & Caregivers',
      AppLanguage.urdu: 'خاندان اور caregivers',
      AppLanguage.romanUrdu: 'Family aur caregivers',
    },
    'family_caregivers_subtitle': {
      AppLanguage.english: 'People helping with this care plan.',
      AppLanguage.urdu: 'اس نگہداشت منصوبے میں مدد کرنے والے لوگ۔',
      AppLanguage.romanUrdu: 'Is care plan mein madad karne wale log.',
    },
    'add_caregiver': {
      AppLanguage.english: 'Add Caregiver',
      AppLanguage.urdu: 'Caregiver شامل کریں',
      AppLanguage.romanUrdu: 'Caregiver add karein',
    },
    'add_a_caregiver': {
      AppLanguage.english: 'Add a caregiver',
      AppLanguage.urdu: 'Caregiver شامل کریں',
      AppLanguage.romanUrdu: 'Caregiver add karein',
    },
    'add_caregiver_subtitle': {
      AppLanguage.english: 'They will only see what you allow.',
      AppLanguage.urdu: 'وہ صرف وہی دیکھیں گے جس کی آپ اجازت دیں گے۔',
      AppLanguage.romanUrdu: 'Woh sirf wohi dekhenge jis ki aap ijazat dein.',
    },
    'no_caregivers_yet': {
      AppLanguage.english: 'No caregivers yet',
      AppLanguage.urdu: 'ابھی کوئی caregiver نہیں',
      AppLanguage.romanUrdu: 'Abhi koi caregiver nahi',
    },
    'no_caregivers_yet_description': {
      AppLanguage.english:
          'Add a family member so care tasks can be shared.',
      AppLanguage.urdu:
          'خاندان کے فرد کو شامل کریں تاکہ نگہداشت کے کام share ہو سکیں۔',
      AppLanguage.romanUrdu:
          'Family member add karein taa ke care tasks share ho saken.',
    },
    'open_caregiver_view': {
      AppLanguage.english: 'Open caregiver view',
      AppLanguage.urdu: 'Caregiver view کھولیں',
      AppLanguage.romanUrdu: 'Caregiver view kholein',
    },
    'family_caregivers_safety_note': {
      AppLanguage.english:
          'Caregivers only see the tasks assigned to them. Medical details stay with the patient account.',
      AppLanguage.urdu:
          'Caregivers صرف اپنے assigned کام دیکھتے ہیں۔ طبی تفصیلات مریض کے اکاؤنٹ میں رہتی ہیں۔',
      AppLanguage.romanUrdu:
          'Caregivers sirf apne assigned tasks dekhte hain. Medical details patient account mein rehti hain.',
    },
    'helps_with': {
      AppLanguage.english: 'Helps with',
      AppLanguage.urdu: 'مدد کرتا ہے',
      AppLanguage.romanUrdu: 'Madad karta hai',
    },
    'assigned_tasks': {
      AppLanguage.english: 'Assigned tasks',
      AppLanguage.urdu: 'Assigned کام',
      AppLanguage.romanUrdu: 'Assigned tasks',
    },
    'access_permissions': {
      AppLanguage.english: 'Access permissions',
      AppLanguage.urdu: 'رسائی کی اجازتیں',
      AppLanguage.romanUrdu: 'Access permissions',
    },
    'caregiver_added': {
      AppLanguage.english: 'Caregiver added',
      AppLanguage.urdu: 'Caregiver شامل ہو گیا',
      AppLanguage.romanUrdu: 'Caregiver add ho gaya',
    },
    'caregiver_access_safety_note': {
      AppLanguage.english:
          'Caregiver access can be changed or removed at any time from the family page.',
      AppLanguage.urdu:
          'Caregiver access خاندان کے صفحے سے کسی بھی وقت تبدیل یا ختم کی جا سکتی ہے۔',
      AppLanguage.romanUrdu:
          'Caregiver access family page se kisi bhi waqt change ya remove ki ja sakti hai.',
    },
    'caregiver': {
      AppLanguage.english: 'Caregiver',
      AppLanguage.urdu: 'Caregiver',
      AppLanguage.romanUrdu: 'Caregiver',
    },
    'caregiver_view': {
      AppLanguage.english: 'Caregiver View',
      AppLanguage.urdu: 'Caregiver View',
      AppLanguage.romanUrdu: 'Caregiver View',
    },
    'caregiver_not_found': {
      AppLanguage.english: 'Caregiver not found',
      AppLanguage.urdu: 'Caregiver نہیں ملا',
      AppLanguage.romanUrdu: 'Caregiver nahi mila',
    },
    'caregiver_not_found_description': {
      AppLanguage.english: 'This caregiver has been removed.',
      AppLanguage.urdu: 'یہ caregiver remove ہو چکا ہے۔',
      AppLanguage.romanUrdu: 'Yeh caregiver remove ho chuka hai.',
    },
    'back_to_family': {
      AppLanguage.english: 'Back to Family',
      AppLanguage.urdu: 'خاندان پر واپس',
      AppLanguage.romanUrdu: 'Family par wapas',
    },
    'caregiver_tasks_title': {
      AppLanguage.english: "{name}'s tasks",
      AppLanguage.urdu: '{name} کے کام',
      AppLanguage.romanUrdu: '{name} ke tasks',
    },
    'caregiver_available_subtitle': {
      AppLanguage.english: '{relationship} · Available {availability}',
      AppLanguage.urdu: '{relationship} · دستیاب {availability}',
      AppLanguage.romanUrdu: '{relationship} · Available {availability}',
    },
    'no_tasks_assigned_yet': {
      AppLanguage.english: 'No tasks assigned yet',
      AppLanguage.urdu: 'ابھی کوئی task assigned نہیں',
      AppLanguage.romanUrdu: 'Abhi koi task assigned nahi',
    },
    'no_tasks_assigned_yet_description': {
      AppLanguage.english:
          'Assign a care task from the care gaps or schedule.',
      AppLanguage.urdu:
          'نگہداشت کی کمیوں یا schedule سے care task assign کریں۔',
      AppLanguage.romanUrdu:
          'Care gaps ya schedule se care task assign karein.',
    },
    'view_care_gaps': {
      AppLanguage.english: 'View Care Gaps',
      AppLanguage.urdu: 'Care Gaps دیکھیں',
      AppLanguage.romanUrdu: 'Care Gaps dekhein',
    },
    'caregiver_detail_safety_note': {
      AppLanguage.english:
          'Caregivers see assigned tasks only. Full medical details remain private to the patient.',
      AppLanguage.urdu:
          'Caregivers صرف assigned کام دیکھتے ہیں۔ مکمل طبی تفصیلات مریض تک private رہتی ہیں۔',
      AppLanguage.romanUrdu:
          'Caregivers sirf assigned tasks dekhte hain. Full medical details patient ke liye private rehti hain.',
    },
    'medicine_reminders': {
      AppLanguage.english: 'Medicine reminders',
      AppLanguage.urdu: 'ادویات کی یاددہانیاں',
      AppLanguage.romanUrdu: 'Medicine reminders',
    },
    'appointments': {
      AppLanguage.english: 'Appointments',
      AppLanguage.urdu: 'Appointments',
      AppLanguage.romanUrdu: 'Appointments',
    },
    'meals': {
      AppLanguage.english: 'Meals',
      AppLanguage.urdu: 'کھانے',
      AppLanguage.romanUrdu: 'Khanay',
    },
    'assigned_tasks_only': {
      AppLanguage.english: 'Assigned tasks only',
      AppLanguage.urdu: 'صرف assigned کام',
      AppLanguage.romanUrdu: 'Sirf assigned tasks',
    },
    'upload_documents': {
      AppLanguage.english: 'Upload Documents',
      AppLanguage.urdu: 'Documents upload کریں',
      AppLanguage.romanUrdu: 'Documents upload karein',
    },
    'upload_your_documents': {
      AppLanguage.english: 'Upload your documents',
      AppLanguage.urdu: 'اپنے documents upload کریں',
      AppLanguage.romanUrdu: 'Apne documents upload karein',
    },
    'upload_documents_subtitle': {
      AppLanguage.english:
          'PDF, JPG or PNG. You can add several documents to the same care plan.',
      AppLanguage.urdu:
          'PDF، JPG یا PNG۔ آپ ایک ہی care plan میں کئی documents شامل کر سکتے ہیں۔',
      AppLanguage.romanUrdu:
          'PDF, JPG ya PNG. Aap aik hi care plan mein kai documents add kar sakte hain.',
    },
    'drag_drop_documents_here': {
      AppLanguage.english: 'Drag and drop your documents here',
      AppLanguage.urdu: 'اپنے documents یہاں drag and drop کریں',
      AppLanguage.romanUrdu: 'Apne documents yahan drag and drop karein',
    },
    'document_file_limits': {
      AppLanguage.english: 'PDF, JPG or PNG up to 20 MB each.',
      AppLanguage.urdu: 'PDF، JPG یا PNG، ہر file 20 MB تک۔',
      AppLanguage.romanUrdu: 'PDF, JPG ya PNG, har file 20 MB tak.',
    },
    'choose_files': {
      AppLanguage.english: 'Choose files',
      AppLanguage.urdu: 'Files منتخب کریں',
      AppLanguage.romanUrdu: 'Files choose karein',
    },
    'use_camera': {
      AppLanguage.english: 'Use camera',
      AppLanguage.urdu: 'Camera استعمال کریں',
      AppLanguage.romanUrdu: 'Camera use karein',
    },
    'existing_document': {
      AppLanguage.english: 'Existing document',
      AppLanguage.urdu: 'موجودہ document',
      AppLanguage.romanUrdu: 'Existing document',
    },
    'uploading': {
      AppLanguage.english: 'Uploading…',
      AppLanguage.urdu: 'Upload ہو رہا ہے…',
      AppLanguage.romanUrdu: 'Upload ho raha hai…',
    },
    'uploaded': {
      AppLanguage.english: 'Uploaded',
      AppLanguage.urdu: 'Upload ہو گیا',
      AppLanguage.romanUrdu: 'Upload ho gaya',
    },
    'remove_file': {
      AppLanguage.english: 'Remove {file}',
      AppLanguage.urdu: '{file} remove کریں',
      AppLanguage.romanUrdu: '{file} remove karein',
    },
    'file_exceeds_20_mb_limit': {
      AppLanguage.english: '{file} exceeds the 20 MB limit.',
      AppLanguage.urdu: '{file} 20 MB limit سے زیادہ ہے۔',
      AppLanguage.romanUrdu: '{file} 20 MB limit se zyada hai.',
    },
    'captured_photo_exceeds_20_mb_limit': {
      AppLanguage.english: 'The captured photo exceeds the 20 MB limit.',
      AppLanguage.urdu: 'Captured photo 20 MB limit سے زیادہ ہے۔',
      AppLanguage.romanUrdu: 'Captured photo 20 MB limit se zyada hai.',
    },
    'camera_open_failed': {
      AppLanguage.english:
          'Could not open the camera. Please allow camera access and try again.',
      AppLanguage.urdu:
          'Camera نہیں کھل سکا۔ Camera access allow کریں اور دوبارہ کوشش کریں۔',
      AppLanguage.romanUrdu:
          'Camera nahi khul saka. Camera access allow karein aur dobara koshish karein.',
    },
    'document_extraction_failed_retry': {
      AppLanguage.english: 'Document extraction failed. Please retry.',
      AppLanguage.urdu: 'Document extraction ناکام ہو گئی۔ دوبارہ کوشش کریں۔',
      AppLanguage.romanUrdu:
          'Document extraction fail ho gayi. Dobara koshish karein.',
    },
    'upload_documents_safety_note': {
      AppLanguage.english:
          'Always verify extracted information against the original document. Nothing is added to your care plan automatically.',
      AppLanguage.urdu:
          'Extracted information ہمیشہ original document سے verify کریں۔ آپ کے care plan میں کچھ بھی خودکار طور پر شامل نہیں ہوتا۔',
      AppLanguage.romanUrdu:
          'Extracted information hamesha original document se verify karein. Aap ke care plan mein kuch bhi automatically add nahi hota.',
    },
    'processing_documents': {
      AppLanguage.english: 'Processing documents',
      AppLanguage.urdu: 'Documents process ہو رہے ہیں',
      AppLanguage.romanUrdu: 'Documents process ho rahe hain',
    },
    'processing_documents_description': {
      AppLanguage.english:
          'This usually takes a few moments. Nothing is activated until you verify it.',
      AppLanguage.urdu:
          'اس میں عموماً چند لمحے لگتے ہیں۔ جب تک آپ verify نہ کریں، کچھ activate نہیں ہوتا۔',
      AppLanguage.romanUrdu:
          'Is mein aam tor par chand lamhay lagte hain. Jab tak aap verify na karein, kuch activate nahi hota.',
    },
    'upload_step_uploading_documents': {
      AppLanguage.english: 'Uploading documents…',
      AppLanguage.urdu: 'Documents upload ہو رہے ہیں…',
      AppLanguage.romanUrdu: 'Documents upload ho rahe hain…',
    },
    'upload_step_reading_instructions': {
      AppLanguage.english: 'Reading your care instructions…',
      AppLanguage.urdu: 'آپ کی care instructions پڑھی جا رہی ہیں…',
      AppLanguage.romanUrdu: 'Aap ki care instructions parhi ja rahi hain…',
    },
    'upload_step_extracting_instructions': {
      AppLanguage.english: 'Extracting instructions…',
      AppLanguage.urdu: 'Instructions extract ہو رہی ہیں…',
      AppLanguage.romanUrdu: 'Instructions extract ho rahi hain…',
    },
    'upload_step_organizing_verified_plan': {
      AppLanguage.english: 'Organizing the verified care plan…',
      AppLanguage.urdu: 'Verified care plan organize ہو رہا ہے…',
      AppLanguage.romanUrdu: 'Verified care plan organize ho raha hai…',
    },
    'verify_instructions': {
      AppLanguage.english: 'Verify Instructions',
      AppLanguage.urdu: 'Instructions verify کریں',
      AppLanguage.romanUrdu: 'Instructions verify karein',
    },
    'review_extracted_instructions': {
      AppLanguage.english: 'Review extracted instructions',
      AppLanguage.urdu: 'Extracted instructions review کریں',
      AppLanguage.romanUrdu: 'Extracted instructions review karein',
    },
    'review_instructions_progress': {
      AppLanguage.english:
          '{reviewed} of {total} instructions reviewed · {verified} confirmed',
      AppLanguage.urdu:
          '{total} میں سے {reviewed} instructions review ہو چکی ہیں · {verified} confirmed',
      AppLanguage.romanUrdu:
          '{total} mein se {reviewed} instructions review ho chuki hain · {verified} confirmed',
    },
    'no_instructions_extracted_upload_clearer': {
      AppLanguage.english:
          'No instructions were extracted. Go back and upload a clearer document.',
      AppLanguage.urdu:
          'کوئی instructions extract نہیں ہوئیں۔ واپس جائیں اور clearer document upload کریں۔',
      AppLanguage.romanUrdu:
          'Koi instructions extract nahi huin. Wapas jayein aur clearer document upload karein.',
    },
    'review_instructions_safety_note': {
      AppLanguage.english:
          'Instructions are never activated automatically. Only items you confirm become part of the care plan.',
      AppLanguage.urdu:
          'Instructions کبھی automatically activate نہیں ہوتیں۔ صرف آپ کی confirmed items care plan کا حصہ بنتی ہیں۔',
      AppLanguage.romanUrdu:
          'Instructions kabhi automatically activate nahi hotin. Sirf aap ki confirmed items care plan ka hissa banti hain.',
    },
    'reviewed_against_original_document': {
      AppLanguage.english:
          'I have reviewed these instructions against the original document.',
      AppLanguage.urdu:
          'میں نے ان instructions کو original document کے ساتھ review کیا ہے۔',
      AppLanguage.romanUrdu:
          'Maine in instructions ko original document ke saath review kiya hai.',
    },
    'continue_to_schedule': {
      AppLanguage.english: 'Continue to Schedule',
      AppLanguage.urdu: 'Schedule پر جاری رکھیں',
      AppLanguage.romanUrdu: 'Schedule par jari rakhein',
    },
    'review_summary': {
      AppLanguage.english: 'Review summary',
      AppLanguage.urdu: 'Review summary',
      AppLanguage.romanUrdu: 'Review summary',
    },
    'instructions_found_count': {
      AppLanguage.english: '{count} found',
      AppLanguage.urdu: '{count} ملیں',
      AppLanguage.romanUrdu: '{count} found',
    },
    'instructions_confirmed_count': {
      AppLanguage.english: '{count} confirmed',
      AppLanguage.urdu: '{count} confirmed',
      AppLanguage.romanUrdu: '{count} confirmed',
    },
    'instructions_to_review_count': {
      AppLanguage.english: '{count} to review',
      AppLanguage.urdu: '{count} review باقی',
      AppLanguage.romanUrdu: '{count} review baqi',
    },
    'instructions_need_confirmation_count': {
      AppLanguage.english: '{count} need confirmation',
      AppLanguage.urdu: '{count} کو confirmation چاہیے',
      AppLanguage.romanUrdu: '{count} ko confirmation chahiye',
    },
    'review_summary_help': {
      AppLanguage.english:
          'Open an item only when you need its explanation or evidence. The original document remains the final reference.',
      AppLanguage.urdu:
          'Item صرف تب کھولیں جب explanation یا evidence چاہیے۔ Original document final reference رہتا ہے۔',
      AppLanguage.romanUrdu:
          'Item sirf tab kholein jab explanation ya evidence chahiye. Original document final reference rehta hai.',
    },
    'medicines': {
      AppLanguage.english: 'Medicines',
      AppLanguage.urdu: 'ادویات',
      AppLanguage.romanUrdu: 'Medicines',
    },
    'follow_ups': {
      AppLanguage.english: 'Follow-Ups',
      AppLanguage.urdu: 'Follow-Ups',
      AppLanguage.romanUrdu: 'Follow-Ups',
    },
    'lab_tests': {
      AppLanguage.english: 'Lab Tests',
      AppLanguage.urdu: 'Lab Tests',
      AppLanguage.romanUrdu: 'Lab Tests',
    },
    'care_tasks': {
      AppLanguage.english: 'Care Tasks',
      AppLanguage.urdu: 'Care Tasks',
      AppLanguage.romanUrdu: 'Care Tasks',
    },
    'other_instructions': {
      AppLanguage.english: 'Other Instructions',
      AppLanguage.urdu: 'دیگر instructions',
      AppLanguage.romanUrdu: 'Other instructions',
    },
    'uploaded_document': {
      AppLanguage.english: 'Uploaded document',
      AppLanguage.urdu: 'Uploaded document',
      AppLanguage.romanUrdu: 'Uploaded document',
    },
    'uploaded_document_source_page': {
      AppLanguage.english: 'Uploaded document — {source}',
      AppLanguage.urdu: 'Uploaded document — {source}',
      AppLanguage.romanUrdu: 'Uploaded document — {source}',
    },
    'source_label_value': {
      AppLanguage.english: 'Source: {source}',
      AppLanguage.urdu: 'Source: {source}',
      AppLanguage.romanUrdu: 'Source: {source}',
    },
    'verified': {
      AppLanguage.english: 'Verified',
      AppLanguage.urdu: 'Verified',
      AppLanguage.romanUrdu: 'Verified',
    },
    'details': {
      AppLanguage.english: 'Details',
      AppLanguage.urdu: 'تفصیلات',
      AppLanguage.romanUrdu: 'Details',
    },
    'corrected_original_preserved': {
      AppLanguage.english: 'Corrected · original preserved',
      AppLanguage.urdu: 'Corrected · original preserved',
      AppLanguage.romanUrdu: 'Corrected · original preserved',
    },
    'possible_duplicate_medicine': {
      AppLanguage.english: 'Possible duplicate medicine',
      AppLanguage.urdu: 'ممکنہ duplicate medicine',
      AppLanguage.romanUrdu: 'Possible duplicate medicine',
    },
    'remove_duplicate': {
      AppLanguage.english: 'Remove duplicate',
      AppLanguage.urdu: 'Duplicate remove کریں',
      AppLanguage.romanUrdu: 'Duplicate remove karein',
    },
    'checking': {
      AppLanguage.english: 'Checking…',
      AppLanguage.urdu: 'Check ہو رہا ہے…',
      AppLanguage.romanUrdu: 'Check ho raha hai…',
    },
    'check_sources': {
      AppLanguage.english: 'Check sources',
      AppLanguage.urdu: 'Sources check کریں',
      AppLanguage.romanUrdu: 'Sources check karein',
    },
    'view_sources': {
      AppLanguage.english: 'View sources',
      AppLanguage.urdu: 'Sources دیکھیں',
      AppLanguage.romanUrdu: 'Sources dekhein',
    },
    'doctor_confirmed': {
      AppLanguage.english: 'Doctor confirmed',
      AppLanguage.urdu: 'Doctor نے confirm کیا',
      AppLanguage.romanUrdu: 'Doctor ne confirm kiya',
    },
    'looks_correct': {
      AppLanguage.english: 'Looks correct',
      AppLanguage.urdu: 'درست لگتا ہے',
      AppLanguage.romanUrdu: 'Theek lagta hai',
    },
    'confirmed_correction_original_preserved': {
      AppLanguage.english:
          'Your confirmed correction is shown separately; the originally extracted instruction is preserved for traceability.',
      AppLanguage.urdu:
          'آپ کی confirmed correction الگ دکھائی گئی ہے؛ originally extracted instruction traceability کے لیے محفوظ ہے۔',
      AppLanguage.romanUrdu:
          'Aap ki confirmed correction alag dikhayi gayi hai; originally extracted instruction traceability ke liye preserved hai.',
    },
    'ingredient_label_needs_clearer_photo': {
      AppLanguage.english:
          'The ingredient label still needs a clearer photo.',
      AppLanguage.urdu:
          'Ingredient label کے لیے ابھی clearer photo چاہیے۔',
      AppLanguage.romanUrdu:
          'Ingredient label ke liye abhi clearer photo chahiye.',
    },
    'label_evidence_found': {
      AppLanguage.english:
          'Label evidence found: {ingredients}. Open details to compare it.',
      AppLanguage.urdu:
          'Label evidence ملا: {ingredients}۔ Compare کرنے کے لیے details کھولیں۔',
      AppLanguage.romanUrdu:
          'Label evidence mila: {ingredients}. Compare karne ke liye details kholein.',
    },
    'medicine_name_record_found': {
      AppLanguage.english:
          'A medicine-name record was found. This does not confirm the prescribed dose.',
      AppLanguage.urdu:
          'Medicine-name record ملا ہے۔ یہ prescribed dose confirm نہیں کرتا۔',
      AppLanguage.romanUrdu:
          'Medicine-name record mila hai. Yeh prescribed dose confirm nahi karta.',
    },
    'official_records_need_confirmation': {
      AppLanguage.english:
          'Official records were found, but the medicine instruction still needs confirmation.',
      AppLanguage.urdu:
          'Official records ملے ہیں، مگر medicine instruction کو اب بھی confirmation چاہیے۔',
      AppLanguage.romanUrdu:
          'Official records mile hain, magar medicine instruction ko ab bhi confirmation chahiye.',
    },
    'no_reliable_medicine_match': {
      AppLanguage.english:
          'No reliable medicine-name match was found. Add label evidence or ask a professional.',
      AppLanguage.urdu:
          'Reliable medicine-name match نہیں ملا۔ Label evidence شامل کریں یا professional سے پوچھیں۔',
      AppLanguage.romanUrdu:
          'Reliable medicine-name match nahi mila. Label evidence add karein ya professional se poochein.',
    },
    'critical_detail_unclear': {
      AppLanguage.english:
          'A medicine, amount, timing, or duration is not clear enough to confirm.',
      AppLanguage.urdu:
          'Medicine، amount، timing یا duration confirm کرنے کے لیے کافی clear نہیں۔',
      AppLanguage.romanUrdu:
          'Medicine, amount, timing, ya duration confirm karne ke liye kaafi clear nahi.',
    },
    'confirmed_against_original_document': {
      AppLanguage.english: 'Confirmed against the original document.',
      AppLanguage.urdu: 'Original document کے ساتھ confirm کیا گیا۔',
      AppLanguage.romanUrdu: 'Original document ke saath confirm kiya gaya.',
    },
    'compare_with_original_before_confirming': {
      AppLanguage.english:
          'Compare this item with the original document before confirming it.',
      AppLanguage.urdu:
          'Confirm کرنے سے پہلے اس item کو original document سے compare کریں۔',
      AppLanguage.romanUrdu:
          'Confirm karne se pehle is item ko original document se compare karein.',
    },
    'original_from_uploaded_document': {
      AppLanguage.english: 'Original from uploaded document',
      AppLanguage.urdu: 'Uploaded document سے original',
      AppLanguage.romanUrdu: 'Uploaded document se original',
    },
    'confirmed_corrected_version': {
      AppLanguage.english: 'Confirmed / corrected version',
      AppLanguage.urdu: 'Confirmed / corrected version',
      AppLanguage.romanUrdu: 'Confirmed / corrected version',
    },
    'what_needs_confirmation': {
      AppLanguage.english: 'What needs confirmation',
      AppLanguage.urdu: 'کس چیز کی confirmation چاہیے',
      AppLanguage.romanUrdu: 'Kis cheez ki confirmation chahiye',
    },
    'safety_critical_detail_unclear': {
      AppLanguage.english:
          'A safety-critical detail is unclear in the document.',
      AppLanguage.urdu:
          'Document میں safety-critical detail unclear ہے۔',
      AppLanguage.romanUrdu:
          'Document mein safety-critical detail unclear hai.',
    },
    'why_review_this_item': {
      AppLanguage.english: 'Why review this item',
      AppLanguage.urdu: 'یہ item کیوں review کریں',
      AppLanguage.romanUrdu: 'Yeh item kyun review karein',
    },
    'why_review_this_item_body': {
      AppLanguage.english:
          'Confirm the name, instruction and timing against the original document. AI confidence describes text recognition, not medical correctness.',
      AppLanguage.urdu:
          'Name، instruction اور timing کو original document سے confirm کریں۔ AI confidence text recognition بتاتا ہے، medical correctness نہیں۔',
      AppLanguage.romanUrdu:
          'Name, instruction aur timing ko original document se confirm karein. AI confidence text recognition batata hai, medical correctness nahi.',
    },
    'possible_readings': {
      AppLanguage.english: 'Possible readings',
      AppLanguage.urdu: 'ممکنہ readings',
      AppLanguage.romanUrdu: 'Possible readings',
    },
    'safety_note': {
      AppLanguage.english: 'Safety note',
      AppLanguage.urdu: 'Safety note',
      AppLanguage.romanUrdu: 'Safety note',
    },
    'add_label_photo': {
      AppLanguage.english: 'Add label photo',
      AppLanguage.urdu: 'Label photo شامل کریں',
      AppLanguage.romanUrdu: 'Label photo add karein',
    },
    'replace_label_photo': {
      AppLanguage.english: 'Replace label photo',
      AppLanguage.urdu: 'Label photo replace کریں',
      AppLanguage.romanUrdu: 'Label photo replace karein',
    },
    'doctor_question': {
      AppLanguage.english: "Doctor's question",
      AppLanguage.urdu: 'Doctor کا سوال',
      AppLanguage.romanUrdu: 'Doctor ka sawal',
    },
    'name_match_found': {
      AppLanguage.english: 'Name match found',
      AppLanguage.urdu: 'Name match ملا',
      AppLanguage.romanUrdu: 'Name match mila',
    },
    'needs_confirmation': {
      AppLanguage.english: 'Needs confirmation',
      AppLanguage.urdu: 'Confirmation چاہیے',
      AppLanguage.romanUrdu: 'Confirmation chahiye',
    },
    'not_verified': {
      AppLanguage.english: 'Not verified',
      AppLanguage.urdu: 'Verified نہیں',
      AppLanguage.romanUrdu: 'Verified nahi',
    },
    'trusted_source_check': {
      AppLanguage.english: 'Trusted-source check',
      AppLanguage.urdu: 'Trusted-source check',
      AppLanguage.romanUrdu: 'Trusted-source check',
    },
    'possible_interpretation_only': {
      AppLanguage.english: 'Possible interpretation only: {interpretation}',
      AppLanguage.urdu: 'صرف possible interpretation: {interpretation}',
      AppLanguage.romanUrdu:
          'Sirf possible interpretation: {interpretation}',
    },
    'ask_prefix': {
      AppLanguage.english: 'Ask: {question}',
      AppLanguage.urdu: 'پوچھیں: {question}',
      AppLanguage.romanUrdu: 'Poochein: {question}',
    },
    'sources_checked': {
      AppLanguage.english: 'Sources checked',
      AppLanguage.urdu: 'Sources checked',
      AppLanguage.romanUrdu: 'Sources checked',
    },
    'trusted_health_source': {
      AppLanguage.english: 'Trusted health source',
      AppLanguage.urdu: 'Trusted health source',
      AppLanguage.romanUrdu: 'Trusted health source',
    },
    'trusted_database_safety_note': {
      AppLanguage.english:
          'Trusted databases can check a medicine name, but they cannot prove what unclear handwriting means or confirm a patient-specific dose. The original instruction is never changed automatically.',
      AppLanguage.urdu:
          'Trusted databases medicine name check کر سکتے ہیں، مگر unclear handwriting کا مطلب prove یا patient-specific dose confirm نہیں کر سکتے۔ Original instruction کبھی automatically change نہیں ہوتی۔',
      AppLanguage.romanUrdu:
          'Trusted databases medicine name check kar sakte hain, magar unclear handwriting ka matlab prove ya patient-specific dose confirm nahi kar sakte. Original instruction kabhi automatically change nahi hoti.',
    },
    'broadly_consistent': {
      AppLanguage.english: 'Broadly consistent',
      AppLanguage.urdu: 'مجموعی طور پر consistent',
      AppLanguage.romanUrdu: 'Overall consistent',
    },
    'purpose_not_stated': {
      AppLanguage.english: 'Purpose not stated',
      AppLanguage.urdu: 'Purpose stated نہیں',
      AppLanguage.romanUrdu: 'Purpose stated nahi',
    },
    'ingredient_label_evidence': {
      AppLanguage.english: 'Ingredient-label evidence',
      AppLanguage.urdu: 'Ingredient-label evidence',
      AppLanguage.romanUrdu: 'Ingredient-label evidence',
    },
    'brand_on_package': {
      AppLanguage.english: 'Brand on package',
      AppLanguage.urdu: 'Package پر brand',
      AppLanguage.romanUrdu: 'Package par brand',
    },
    'active_ingredients': {
      AppLanguage.english: 'Active ingredients',
      AppLanguage.urdu: 'Active ingredients',
      AppLanguage.romanUrdu: 'Active ingredients',
    },
    'form': {
      AppLanguage.english: 'Form',
      AppLanguage.urdu: 'Form',
      AppLanguage.romanUrdu: 'Form',
    },
    'manufacturer': {
      AppLanguage.english: 'Manufacturer',
      AppLanguage.urdu: 'Manufacturer',
      AppLanguage.romanUrdu: 'Manufacturer',
    },
    'evidence_sources': {
      AppLanguage.english: 'Evidence sources',
      AppLanguage.urdu: 'Evidence sources',
      AppLanguage.romanUrdu: 'Evidence sources',
    },
    'ingredient_evidence_safety_note': {
      AppLanguage.english:
          'This evidence checks package identity and common-purpose consistency only. It does not confirm the prescribed dose or prove what the doctor intended.',
      AppLanguage.urdu:
          'یہ evidence صرف package identity اور common-purpose consistency check کرتا ہے۔ یہ prescribed dose confirm یا doctor کی نیت prove نہیں کرتا۔',
      AppLanguage.romanUrdu:
          'Yeh evidence sirf package identity aur common-purpose consistency check karta hai. Yeh prescribed dose confirm ya doctor ka intended meaning prove nahi karta.',
    },
    'ingredient_checking_sign_in_required': {
      AppLanguage.english:
          'Ingredient-label checking is available after sign in.',
      AppLanguage.urdu:
          'Ingredient-label checking sign in کے بعد available ہے۔',
      AppLanguage.romanUrdu:
          'Ingredient-label checking sign in ke baad available hai.',
    },
    'label_image_exceeds_10_mb_limit': {
      AppLanguage.english: 'The label image exceeds the 10 MB limit.',
      AppLanguage.urdu: 'Label image 10 MB limit سے زیادہ ہے۔',
      AppLanguage.romanUrdu: 'Label image 10 MB limit se zyada hai.',
    },
    'trusted_source_page_open_failed': {
      AppLanguage.english: 'Could not open this trusted-source page.',
      AppLanguage.urdu: 'یہ trusted-source page نہیں کھل سکا۔',
      AppLanguage.romanUrdu: 'Yeh trusted-source page nahi khul saka.',
    },
    'trusted_source_checking_sign_in_required': {
      AppLanguage.english:
          'Trusted-source checking is available after sign in.',
      AppLanguage.urdu:
          'Trusted-source checking sign in کے بعد available ہے۔',
      AppLanguage.romanUrdu:
          'Trusted-source checking sign in ke baad available hai.',
    },
    'remove_duplicate_instruction_question': {
      AppLanguage.english: 'Remove duplicate instruction?',
      AppLanguage.urdu: 'Duplicate instruction remove کریں؟',
      AppLanguage.romanUrdu: 'Duplicate instruction remove karein?',
    },
    'remove_duplicate_instruction_body': {
      AppLanguage.english:
          'This removes the duplicate "{title}" from SehatMate, including any schedule rows created from this duplicate. It does not change the original prescription or mean that a medicine should be stopped.',
      AppLanguage.urdu:
          'یہ duplicate "{title}" کو SehatMate سے remove کرتا ہے، اس duplicate سے بنی schedule rows سمیت۔ یہ original prescription کو change نہیں کرتا اور اس کا مطلب یہ نہیں کہ medicine روکنی چاہیے۔',
      AppLanguage.romanUrdu:
          'Yeh duplicate "{title}" ko SehatMate se remove karta hai, is duplicate se bani schedule rows samait. Yeh original prescription ko change nahi karta aur is ka matlab yeh nahi ke medicine rokni chahiye.',
    },
    'duplicate_instruction_removed': {
      AppLanguage.english: 'Duplicate instruction removed from SehatMate.',
      AppLanguage.urdu: 'Duplicate instruction SehatMate سے remove ہو گئی۔',
      AppLanguage.romanUrdu:
          'Duplicate instruction SehatMate se remove ho gayi.',
    },
    'instruction_saved_as_verified': {
      AppLanguage.english: 'Instruction saved as verified.',
      AppLanguage.urdu: 'Instruction verified کے طور پر save ہو گئی۔',
      AppLanguage.romanUrdu:
          'Instruction verified ke tor par save ho gayi.',
    },
    'instruction_marked_as_unclear': {
      AppLanguage.english: 'Instruction marked as unclear.',
      AppLanguage.urdu: 'Instruction unclear mark ہو گئی۔',
      AppLanguage.romanUrdu: 'Instruction unclear mark ho gayi.',
    },
    'the_timing': {
      AppLanguage.english: 'the timing',
      AppLanguage.urdu: 'timing',
      AppLanguage.romanUrdu: 'timing',
    },
    'the_timing_value': {
      AppLanguage.english: 'the timing {timing}',
      AppLanguage.urdu: 'timing {timing}',
      AppLanguage.romanUrdu: 'timing {timing}',
    },
    'doctor_question_confirm_instruction_template': {
      AppLanguage.english:
          'Please confirm the exact name, instruction and {timing} for {title} against the original document.',
      AppLanguage.urdu:
          'براہ کرم original document کے مطابق {title} کا exact name، instruction اور {timing} confirm کریں۔',
      AppLanguage.romanUrdu:
          'Please original document ke mutabiq {title} ka exact name, instruction aur {timing} confirm karein.',
    },
    'medicine_name': {
      AppLanguage.english: 'Medicine name',
      AppLanguage.urdu: 'Medicine name',
      AppLanguage.romanUrdu: 'Medicine name',
    },
    'timing_unclear': {
      AppLanguage.english: 'Timing unclear',
      AppLanguage.urdu: 'Timing unclear',
      AppLanguage.romanUrdu: 'Timing unclear',
    },
    'confirmation_required': {
      AppLanguage.english: 'Confirmation required',
      AppLanguage.urdu: 'Confirmation required',
      AppLanguage.romanUrdu: 'Confirmation required',
    },
    'question_saved': {
      AppLanguage.english: 'Question saved',
      AppLanguage.urdu: 'سوال save ہو گیا',
      AppLanguage.romanUrdu: 'Question save ho gaya',
    },
    'question_saved_description': {
      AppLanguage.english:
          'Added to Doctor Questions. The prescription has not been changed.',
      AppLanguage.urdu:
          'Doctor Questions میں شامل ہو گیا۔ Prescription change نہیں ہوئی۔',
      AppLanguage.romanUrdu:
          'Doctor Questions mein add ho gaya. Prescription change nahi hui.',
    },
    'question_to_ask': {
      AppLanguage.english: 'Question to ask',
      AppLanguage.urdu: 'پوچھنے کا سوال',
      AppLanguage.romanUrdu: 'Poochne ka sawal',
    },
    'record_professional_response_before_confirming': {
      AppLanguage.english:
          'Record the doctor or pharmacist response before confirming this instruction.',
      AppLanguage.urdu:
          'اس instruction کو confirm کرنے سے پہلے doctor یا pharmacist کا response record کریں۔',
      AppLanguage.romanUrdu:
          'Is instruction ko confirm karne se pehle doctor ya pharmacist ka response record karein.',
    },
    'open_doctor_questions': {
      AppLanguage.english: 'Open Doctor Questions',
      AppLanguage.urdu: 'Doctor Questions کھولیں',
      AppLanguage.romanUrdu: 'Doctor Questions kholein',
    },
    'question_copied': {
      AppLanguage.english: 'Question copied.',
      AppLanguage.urdu: 'سوال copy ہو گیا۔',
      AppLanguage.romanUrdu: 'Question copy ho gaya.',
    },
    'copy_question': {
      AppLanguage.english: 'Copy question',
      AppLanguage.urdu: 'سوال copy کریں',
      AppLanguage.romanUrdu: 'Question copy karein',
    },
    'instruction_updated_and_confirmed': {
      AppLanguage.english: 'Instruction updated and confirmed',
      AppLanguage.urdu: 'Instruction update اور confirm ہو گئی',
      AppLanguage.romanUrdu:
          'Instruction update aur confirm ho gayi',
    },
    'title_and_instruction_required': {
      AppLanguage.english: 'Title and instruction are required.',
      AppLanguage.urdu: 'Title اور instruction ضروری ہیں۔',
      AppLanguage.romanUrdu: 'Title aur instruction zaroori hain.',
    },
    'edit_instruction': {
      AppLanguage.english: 'Edit instruction',
      AppLanguage.urdu: 'Instruction edit کریں',
      AppLanguage.romanUrdu: 'Instruction edit karein',
    },
    'save_correction_after_professional_confirmation': {
      AppLanguage.english:
          'Only save a correction after the doctor or pharmacist has confirmed the unclear detail.',
      AppLanguage.urdu:
          'Correction صرف doctor یا pharmacist کی unclear detail confirm کرنے کے بعد save کریں۔',
      AppLanguage.romanUrdu:
          'Correction sirf doctor ya pharmacist ki unclear detail confirm karne ke baad save karein.',
    },
    'correct_text_to_match_original': {
      AppLanguage.english:
          'Correct the text so it exactly matches the original document.',
      AppLanguage.urdu:
          'Text کو درست کریں تاکہ یہ original document سے exactly match ہو۔',
      AppLanguage.romanUrdu:
          'Text ko theek karein taa ke yeh original document se exactly match ho.',
    },
    'original_from_document_read_only': {
      AppLanguage.english: 'Original from document · read-only',
      AppLanguage.urdu: 'Document سے original · read-only',
      AppLanguage.romanUrdu: 'Document se original · read-only',
    },
    'title': {
      AppLanguage.english: 'Title',
      AppLanguage.urdu: 'Title',
      AppLanguage.romanUrdu: 'Title',
    },
    'instruction': {
      AppLanguage.english: 'Instruction',
      AppLanguage.urdu: 'Instruction',
      AppLanguage.romanUrdu: 'Instruction',
    },
    'timing': {
      AppLanguage.english: 'Timing',
      AppLanguage.urdu: 'Timing',
      AppLanguage.romanUrdu: 'Timing',
    },
    'save_and_confirm': {
      AppLanguage.english: 'Save and confirm',
      AppLanguage.urdu: 'Save اور confirm کریں',
      AppLanguage.romanUrdu: 'Save aur confirm karein',
    },
    'simple_care': {
      AppLanguage.english: 'Simple Care',
      AppLanguage.urdu: 'سادہ نگہداشت',
      AppLanguage.romanUrdu: 'Simple Care',
    },
    'next_thing_to_do': {
      AppLanguage.english: 'Next thing to do',
      AppLanguage.urdu: 'اگلا کام',
      AppLanguage.romanUrdu: 'Agla kaam',
    },
    'nothing_left_today': {
      AppLanguage.english: 'Nothing left for today',
      AppLanguage.urdu: 'آج کے لیے کچھ باقی نہیں',
      AppLanguage.romanUrdu: 'Aaj ke liye kuch baqi nahi',
    },
    'marked_as_done': {
      AppLanguage.english: 'Marked as done',
      AppLanguage.urdu: 'مکمل کے طور پر نشان لگا دیا',
      AppLanguage.romanUrdu: 'Done mark ho gaya',
    },
    'mark_as_done': {
      AppLanguage.english: 'Mark as done',
      AppLanguage.urdu: 'مکمل نشان لگائیں',
      AppLanguage.romanUrdu: 'Done mark karein',
    },
    'rest_of_today': {
      AppLanguage.english: 'Rest of today',
      AppLanguage.urdu: 'آج کا باقی حصہ',
      AppLanguage.romanUrdu: 'Aaj ka baqi hissa',
    },
    'need_help': {
      AppLanguage.english: 'Need help?',
      AppLanguage.urdu: 'مدد چاہیے؟',
      AppLanguage.romanUrdu: 'Madad chahiye?',
    },
    'contact_family': {
      AppLanguage.english: 'Contact family',
      AppLanguage.urdu: 'خاندان سے رابطہ کریں',
      AppLanguage.romanUrdu: 'Family se rabta karein',
    },
    'medical_emergency_contact_professional': {
      AppLanguage.english:
          'For any medical emergency, contact a healthcare professional immediately.',
      AppLanguage.urdu:
          'کسی بھی medical emergency میں فوراً healthcare professional سے رابطہ کریں۔',
      AppLanguage.romanUrdu:
          'Kisi bhi medical emergency mein foran healthcare professional se rabta karein.',
    },
    'understanding_recorded': {
      AppLanguage.english: 'Understanding recorded',
      AppLanguage.urdu: 'سمجھ ریکارڈ ہو گئی',
      AppLanguage.romanUrdu: 'Understanding record ho gayi',
    },
    'understanding_score_summary': {
      AppLanguage.english:
          'Understanding score: {score}% — clear on medicines, review the visit preparation once more.',
      AppLanguage.urdu:
          'Understanding score: {score}% — ادویات واضح ہیں، visit کی تیاری ایک بار پھر review کریں۔',
      AppLanguage.romanUrdu:
          'Understanding score: {score}% — medicines clear hain, visit preparation aik dafa aur review karein.',
    },
    'teach_back_title': {
      AppLanguage.english: 'Explain the plan in your own words',
      AppLanguage.urdu: 'منصوبہ اپنے الفاظ میں سمجھائیں',
      AppLanguage.romanUrdu: 'Plan apne lafzon mein samjhayen',
    },
    'current_understanding_score': {
      AppLanguage.english: 'Current understanding score: {score}%',
      AppLanguage.urdu: 'موجودہ understanding score: {score}%',
      AppLanguage.romanUrdu: 'Current understanding score: {score}%',
    },
    'question_counter_caps': {
      AppLanguage.english: 'QUESTION {current} OF {total}',
      AppLanguage.urdu: 'سوال {current} از {total}',
      AppLanguage.romanUrdu: 'QUESTION {current} OF {total}',
    },
    'type_or_speak_answer': {
      AppLanguage.english: 'Type your answer, or speak it aloud',
      AppLanguage.urdu: 'اپنا جواب لکھیں یا آواز سے بولیں',
      AppLanguage.romanUrdu: 'Apna answer type karein, ya zor se bolein',
    },
    'voice_capture_demo_unavailable': {
      AppLanguage.english: 'Voice capture is not connected in this demo.',
      AppLanguage.urdu: 'اس demo میں voice capture connected نہیں ہے۔',
      AppLanguage.romanUrdu: 'Is demo mein voice capture connected nahi hai.',
    },
    'speak_answer': {
      AppLanguage.english: 'Speak answer',
      AppLanguage.urdu: 'جواب بولیں',
      AppLanguage.romanUrdu: 'Answer bolein',
    },
    'what_plan_says': {
      AppLanguage.english: 'What the plan says',
      AppLanguage.urdu: 'منصوبہ کیا کہتا ہے',
      AppLanguage.romanUrdu: 'Plan kya kehta hai',
    },
    'finish': {
      AppLanguage.english: 'Finish',
      AppLanguage.urdu: 'ختم کریں',
      AppLanguage.romanUrdu: 'Finish',
    },
    'teach_back_safety_note': {
      AppLanguage.english:
          'This check measures understanding of the care plan only. It is not a medical assessment.',
      AppLanguage.urdu:
          'یہ check صرف نگہداشت منصوبے کی سمجھ ناپتا ہے۔ یہ medical assessment نہیں ہے۔',
      AppLanguage.romanUrdu:
          'Yeh check sirf care plan ki understanding measure karta hai. Yeh medical assessment nahi.',
    },
    'teach_back_prompt_morning_medicine': {
      AppLanguage.english: 'When will you take your morning medicine?',
      AppLanguage.urdu: 'آپ صبح کی دوا کب لیں گے؟',
      AppLanguage.romanUrdu: 'Aap morning medicine kab lenge?',
    },
    'teach_back_plan_morning_medicine': {
      AppLanguage.english: 'Every morning at 8:00 AM, after breakfast.',
      AppLanguage.urdu: 'ہر صبح 8:00 AM پر، ناشتے کے بعد۔',
      AppLanguage.romanUrdu: 'Har subah 8:00 AM par, breakfast ke baad.',
    },
    'teach_back_prompt_hospital_visit': {
      AppLanguage.english: 'What will you do before your hospital visit?',
      AppLanguage.urdu: 'Hospital visit سے پہلے آپ کیا کریں گے؟',
      AppLanguage.romanUrdu: 'Hospital visit se pehle aap kya karenge?',
    },
    'teach_back_plan_hospital_visit': {
      AppLanguage.english:
          'Fast overnight and arrive by 10:00 AM with a confirmed ride.',
      AppLanguage.urdu:
          'رات بھر fasting کریں اور confirmed ride کے ساتھ 10:00 AM تک پہنچیں۔',
      AppLanguage.romanUrdu:
          'Raat bhar fast karein aur confirmed ride ke saath 10:00 AM tak pohanchein.',
    },
    'teach_back_prompt_dressing_help': {
      AppLanguage.english: 'Who helps you with dressing changes?',
      AppLanguage.urdu: 'Dressing change میں آپ کی مدد کون کرتا ہے؟',
      AppLanguage.romanUrdu: 'Dressing changes mein aap ki madad kaun karta hai?',
    },
    'teach_back_plan_dressing_help': {
      AppLanguage.english:
          'Ahmed helps with the dressing in the evening.',
      AppLanguage.urdu:
          'Ahmed شام کو dressing میں مدد کرتا ہے۔',
      AppLanguage.romanUrdu:
          'Ahmed evening mein dressing mein madad karta hai.',
    },
    'demo_evening_medicine': {
      AppLanguage.english: 'Evening Medicine',
      AppLanguage.urdu: 'شام کی دوا',
      AppLanguage.romanUrdu: 'Evening Medicine',
    },
    'demo_dressing': {
      AppLanguage.english: 'Dressing',
      AppLanguage.urdu: 'ڈریسنگ',
      AppLanguage.romanUrdu: 'Dressing',
    },
    'demo_blood_pressure_check': {
      AppLanguage.english: 'Blood Pressure Check',
      AppLanguage.urdu: 'بلڈ پریشر check',
      AppLanguage.romanUrdu: 'Blood Pressure Check',
    },
    'demo_lab_visit': {
      AppLanguage.english: 'Lab Visit',
      AppLanguage.urdu: 'لیب وزٹ',
      AppLanguage.romanUrdu: 'Lab Visit',
    },
    'demo_hospital_follow_up': {
      AppLanguage.english: 'Hospital Follow-Up',
      AppLanguage.urdu: 'Hospital Follow-Up',
      AppLanguage.romanUrdu: 'Hospital Follow-Up',
    },
    'demo_note_patient_away': {
      AppLanguage.english: 'Patient is usually away from home',
      AppLanguage.urdu: 'مریض عموماً گھر سے باہر ہوتا ہے',
      AppLanguage.romanUrdu: 'Patient aam tor par ghar se bahar hota hai',
    },
    'demo_note_caregiver_required': {
      AppLanguage.english: 'Caregiver required',
      AppLanguage.urdu: 'Caregiver درکار ہے',
      AppLanguage.romanUrdu: 'Caregiver required hai',
    },
    'demo_note_timing_verification': {
      AppLanguage.english: 'Timing needs verification',
      AppLanguage.urdu: 'وقت کی تصدیق درکار ہے',
      AppLanguage.romanUrdu: 'Timing verification darkar hai',
    },
    'demo_note_record_reading': {
      AppLanguage.english: 'Record reading in the app',
      AppLanguage.urdu: 'Reading ایپ میں record کریں',
      AppLanguage.romanUrdu: 'Reading app mein record karein',
    },
    'demo_note_caregiver_unavailable': {
      AppLanguage.english: 'Usual caregiver unavailable',
      AppLanguage.urdu: 'معمول کا caregiver دستیاب نہیں',
      AppLanguage.romanUrdu: 'Usual caregiver available nahi',
    },
    'demo_note_no_transport': {
      AppLanguage.english: 'No transport confirmed',
      AppLanguage.urdu: 'Transport confirm نہیں',
      AppLanguage.romanUrdu: 'Transport confirm nahi',
    },
    'demo_note_overlaps_away': {
      AppLanguage.english: 'Overlaps with time away from home',
      AppLanguage.urdu: 'گھر سے باہر ہونے کے وقت سے ٹکراتا ہے',
      AppLanguage.romanUrdu: 'Ghar se bahar hone ke waqt se overlap karta hai',
    },
    'demo_note_caregiver_available': {
      AppLanguage.english: 'Caregiver available',
      AppLanguage.urdu: 'Caregiver دستیاب ہے',
      AppLanguage.romanUrdu: 'Caregiver available hai',
    },
    'demo_note_transport_not_arranged': {
      AppLanguage.english: 'Transport not arranged yet',
      AppLanguage.urdu: 'Transport ابھی arrange نہیں ہوا',
      AppLanguage.romanUrdu: 'Transport abhi arrange nahi hua',
    },
    'demo_reality_wake_question': {
      AppLanguage.english: 'When do you usually wake up?',
      AppLanguage.urdu: 'آپ عموماً کب جاگتے ہیں؟',
      AppLanguage.romanUrdu: 'Aap aam tor par kab jagte hain?',
    },
    'demo_reality_leave_question': {
      AppLanguage.english: 'When do you usually leave home?',
      AppLanguage.urdu: 'آپ عموماً گھر سے کب نکلتے ہیں؟',
      AppLanguage.romanUrdu: 'Aap aam tor par ghar se kab nikalte hain?',
    },
    'demo_reality_return_question': {
      AppLanguage.english: 'When do you usually return home?',
      AppLanguage.urdu: 'آپ عموماً گھر کب واپس آتے ہیں؟',
      AppLanguage.romanUrdu: 'Aap aam tor par ghar kab wapas aate hain?',
    },
    'demo_reality_assistance_question': {
      AppLanguage.english: "Do any care tasks need someone's assistance?",
      AppLanguage.urdu: 'کیا کسی care task کے لیے کسی کی مدد چاہیے؟',
      AppLanguage.romanUrdu: 'Kya kisi care task ke liye kisi ki madad chahiye?',
    },
    'demo_reality_helper_question': {
      AppLanguage.english: 'Who is usually available to help?',
      AppLanguage.urdu: 'مدد کے لیے عموماً کون دستیاب ہوتا ہے؟',
      AppLanguage.romanUrdu: 'Madad ke liye aam tor par kaun available hota hai?',
    },
    'demo_reality_helper_times_question': {
      AppLanguage.english:
          'At what times is that person usually available?',
      AppLanguage.urdu:
          'وہ شخص عموماً کن اوقات میں دستیاب ہوتا ہے؟',
      AppLanguage.romanUrdu:
          'Woh shakhs aam tor par kin auqat mein available hota hai?',
    },
    'demo_reality_travel_question': {
      AppLanguage.english: 'How do you usually travel to your clinic?',
      AppLanguage.urdu: 'آپ عموماً clinic کیسے جاتے ہیں؟',
      AppLanguage.romanUrdu: 'Aap aam tor par clinic kaise jate hain?',
    },
    'demo_reality_medicines_question': {
      AppLanguage.english: 'Have all prescribed medicines been obtained?',
      AppLanguage.urdu: 'کیا تمام prescribed medicines حاصل ہو گئی ہیں؟',
      AppLanguage.romanUrdu: 'Kya tamam prescribed medicines mil gayi hain?',
    },
    'demo_reality_reading_question': {
      AppLanguage.english:
          'Can the written instructions be read comfortably?',
      AppLanguage.urdu:
          'کیا لکھی ہوئی ہدایات آسانی سے پڑھی جا سکتی ہیں؟',
      AppLanguage.romanUrdu:
          'Kya written instructions asani se parhi ja sakti hain?',
    },
    'demo_option_before_6_am': {
      AppLanguage.english: 'Before 6 AM',
      AppLanguage.urdu: '6 AM سے پہلے',
      AppLanguage.romanUrdu: 'Before 6 AM',
    },
    'demo_option_6_8_am': {
      AppLanguage.english: '6 – 8 AM',
      AppLanguage.urdu: '6 – 8 AM',
      AppLanguage.romanUrdu: '6 – 8 AM',
    },
    'demo_option_8_10_am': {
      AppLanguage.english: '8 – 10 AM',
      AppLanguage.urdu: '8 – 10 AM',
      AppLanguage.romanUrdu: '8 – 10 AM',
    },
    'demo_option_after_10_am': {
      AppLanguage.english: 'After 10 AM',
      AppLanguage.urdu: '10 AM کے بعد',
      AppLanguage.romanUrdu: 'After 10 AM',
    },
    'demo_option_stay_home': {
      AppLanguage.english: 'I stay at home',
      AppLanguage.urdu: 'میں گھر پر رہتا ہوں',
      AppLanguage.romanUrdu: 'Main ghar par rehta hoon',
    },
    'demo_option_before_9_am': {
      AppLanguage.english: 'Before 9 AM',
      AppLanguage.urdu: '9 AM سے پہلے',
      AppLanguage.romanUrdu: 'Before 9 AM',
    },
    'demo_option_9_12_pm': {
      AppLanguage.english: '9 AM – 12 PM',
      AppLanguage.urdu: '9 AM – 12 PM',
      AppLanguage.romanUrdu: '9 AM – 12 PM',
    },
    'demo_option_after_12_pm': {
      AppLanguage.english: 'After 12 PM',
      AppLanguage.urdu: '12 PM کے بعد',
      AppLanguage.romanUrdu: 'After 12 PM',
    },
    'demo_option_before_3_pm': {
      AppLanguage.english: 'Before 3 PM',
      AppLanguage.urdu: '3 PM سے پہلے',
      AppLanguage.romanUrdu: 'Before 3 PM',
    },
    'demo_option_3_6_pm': {
      AppLanguage.english: '3 – 6 PM',
      AppLanguage.urdu: '3 – 6 PM',
      AppLanguage.romanUrdu: '3 – 6 PM',
    },
    'demo_option_after_6_pm': {
      AppLanguage.english: 'After 6 PM',
      AppLanguage.urdu: '6 PM کے بعد',
      AppLanguage.romanUrdu: 'After 6 PM',
    },
    'demo_option_yes_dressing': {
      AppLanguage.english: 'Yes, dressing',
      AppLanguage.urdu: 'جی، dressing',
      AppLanguage.romanUrdu: 'Haan, dressing',
    },
    'demo_option_yes_medicines': {
      AppLanguage.english: 'Yes, medicines',
      AppLanguage.urdu: 'جی، medicines',
      AppLanguage.romanUrdu: 'Haan, medicines',
    },
    'demo_option_yes_travel': {
      AppLanguage.english: 'Yes, travel',
      AppLanguage.urdu: 'جی، travel',
      AppLanguage.romanUrdu: 'Haan, travel',
    },
    'demo_option_no_assistance': {
      AppLanguage.english: 'No assistance needed',
      AppLanguage.urdu: 'مدد کی ضرورت نہیں',
      AppLanguage.romanUrdu: 'Madad ki zaroorat nahi',
    },
    'son': {
      AppLanguage.english: 'Son',
      AppLanguage.urdu: 'بیٹا',
      AppLanguage.romanUrdu: 'Beta',
    },
    'daughter': {
      AppLanguage.english: 'Daughter',
      AppLanguage.urdu: 'بیٹی',
      AppLanguage.romanUrdu: 'Beti',
    },
    'spouse': {
      AppLanguage.english: 'Spouse',
      AppLanguage.urdu: 'شریک حیات',
      AppLanguage.romanUrdu: 'Shareek-e-hayat',
    },
    'neighbour_or_friend': {
      AppLanguage.english: 'Neighbour or friend',
      AppLanguage.urdu: 'پڑوسی یا دوست',
      AppLanguage.romanUrdu: 'Neighbour ya friend',
    },
    'weekends_only': {
      AppLanguage.english: 'Weekends only',
      AppLanguage.urdu: 'صرف weekends',
      AppLanguage.romanUrdu: 'Sirf weekends',
    },
    'family_car': {
      AppLanguage.english: 'Family car',
      AppLanguage.urdu: 'Family car',
      AppLanguage.romanUrdu: 'Family car',
    },
    'rickshaw_or_taxi': {
      AppLanguage.english: 'Rickshaw or taxi',
      AppLanguage.urdu: 'رکشہ یا taxi',
      AppLanguage.romanUrdu: 'Rickshaw ya taxi',
    },
    'public_transport': {
      AppLanguage.english: 'Public transport',
      AppLanguage.urdu: 'Public transport',
      AppLanguage.romanUrdu: 'Public transport',
    },
    'walking': {
      AppLanguage.english: 'Walking',
      AppLanguage.urdu: 'پیدل',
      AppLanguage.romanUrdu: 'Paidal',
    },
    'demo_option_some_medicines_missing': {
      AppLanguage.english: 'Some are missing',
      AppLanguage.urdu: 'کچھ موجود نہیں',
      AppLanguage.romanUrdu: 'Kuch missing hain',
    },
    'demo_option_yes_easily': {
      AppLanguage.english: 'Yes, easily',
      AppLanguage.urdu: 'جی، آسانی سے',
      AppLanguage.romanUrdu: 'Haan, asani se',
    },
    'demo_option_with_difficulty': {
      AppLanguage.english: 'With difficulty',
      AppLanguage.urdu: 'مشکل سے',
      AppLanguage.romanUrdu: 'Mushkil se',
    },
    'demo_option_someone_reads': {
      AppLanguage.english: 'Someone reads them for me',
      AppLanguage.urdu: 'کوئی میرے لیے پڑھتا ہے',
      AppLanguage.romanUrdu: 'Koi mere liye parhta hai',
    },
    'care_calendar': {
      AppLanguage.english: 'Care Calendar',
      AppLanguage.urdu: 'نگہداشت کیلنڈر',
      AppLanguage.romanUrdu: 'Care Calendar',
    },
    'care_calendar_subtitle': {
      AppLanguage.english: 'Everything scheduled for this care plan.',
      AppLanguage.urdu: 'اس نگہداشت منصوبے کے لیے scheduled ہر چیز۔',
      AppLanguage.romanUrdu: 'Is care plan ke liye scheduled har cheez.',
    },
    'week': {
      AppLanguage.english: 'Week',
      AppLanguage.urdu: 'ہفتہ',
      AppLanguage.romanUrdu: 'Week',
    },
    'month': {
      AppLanguage.english: 'Month',
      AppLanguage.urdu: 'مہینہ',
      AppLanguage.romanUrdu: 'Month',
    },
    'task_count': {
      AppLanguage.english: '{count} task(s)',
      AppLanguage.urdu: '{count} task(s)',
      AppLanguage.romanUrdu: '{count} task(s)',
    },
    'no_tasks_this_day': {
      AppLanguage.english: 'No tasks this day',
      AppLanguage.urdu: 'اس دن کوئی task نہیں',
      AppLanguage.romanUrdu: 'Is din koi task nahi',
    },
    'nothing_scheduled_for_date': {
      AppLanguage.english: 'Nothing is scheduled for this date.',
      AppLanguage.urdu: 'اس تاریخ کے لیے کچھ scheduled نہیں ہے۔',
      AppLanguage.romanUrdu: 'Is date ke liye kuch scheduled nahi hai.',
    },
    'mon_initial': {
      AppLanguage.english: 'M',
      AppLanguage.urdu: 'پ',
      AppLanguage.romanUrdu: 'M',
    },
    'tue_initial': {
      AppLanguage.english: 'T',
      AppLanguage.urdu: 'م',
      AppLanguage.romanUrdu: 'T',
    },
    'wed_initial': {
      AppLanguage.english: 'W',
      AppLanguage.urdu: 'ب',
      AppLanguage.romanUrdu: 'W',
    },
    'thu_initial': {
      AppLanguage.english: 'T',
      AppLanguage.urdu: 'ج',
      AppLanguage.romanUrdu: 'T',
    },
    'fri_initial': {
      AppLanguage.english: 'F',
      AppLanguage.urdu: 'ج',
      AppLanguage.romanUrdu: 'F',
    },
    'sat_initial': {
      AppLanguage.english: 'S',
      AppLanguage.urdu: 'ہ',
      AppLanguage.romanUrdu: 'S',
    },
    'sun_initial': {
      AppLanguage.english: 'S',
      AppLanguage.urdu: 'ا',
      AppLanguage.romanUrdu: 'S',
    },
    'notifications_subtitle': {
      AppLanguage.english: 'Care reminders and updates.',
      AppLanguage.urdu: 'نگہداشت reminders اور updates۔',
      AppLanguage.romanUrdu: 'Care reminders aur updates.',
    },
    'mark_all_read': {
      AppLanguage.english: 'Mark all read',
      AppLanguage.urdu: 'سب کو read نشان لگائیں',
      AppLanguage.romanUrdu: 'Sab read mark karein',
    },
    'nothing_new': {
      AppLanguage.english: 'Nothing new',
      AppLanguage.urdu: 'کچھ نیا نہیں',
      AppLanguage.romanUrdu: 'Kuch naya nahi',
    },
    'all_caught_up': {
      AppLanguage.english: "You're all caught up.",
      AppLanguage.urdu: 'آپ سب catch up کر چکے ہیں۔',
      AppLanguage.romanUrdu: 'Aap all caught up hain.',
    },
    'yesterday': {
      AppLanguage.english: 'Yesterday',
      AppLanguage.urdu: 'گزشتہ کل',
      AppLanguage.romanUrdu: 'Kal',
    },
    'demo_notification_medicine_due': {
      AppLanguage.english: 'Medicine due soon',
      AppLanguage.urdu: 'دوا جلد due ہے',
      AppLanguage.romanUrdu: 'Medicine soon due hai',
    },
    'demo_notification_transport_unresolved': {
      AppLanguage.english: 'Transport unresolved',
      AppLanguage.urdu: 'Transport unresolved ہے',
      AppLanguage.romanUrdu: 'Transport unresolved hai',
    },
    'demo_notification_caregiver_completed': {
      AppLanguage.english: 'Ahmed completed a caregiver task',
      AppLanguage.urdu: 'Ahmed نے caregiver task مکمل کیا',
      AppLanguage.romanUrdu: 'Ahmed ne caregiver task complete kiya',
    },
    'demo_notification_teach_back_completed': {
      AppLanguage.english: 'Teach-Back completed',
      AppLanguage.urdu: 'Teach-Back مکمل',
      AppLanguage.romanUrdu: 'Teach-Back complete',
    },
    'demo_notification_30_minutes_remaining': {
      AppLanguage.english: '30 minutes remaining',
      AppLanguage.urdu: '30 minutes باقی',
      AppLanguage.romanUrdu: '30 minutes baqi',
    },
    'demo_notification_visit_no_transport': {
      AppLanguage.english:
          "Tomorrow's hospital visit has no confirmed transport",
      AppLanguage.urdu:
          'کل کے hospital visit کے لیے transport confirm نہیں',
      AppLanguage.romanUrdu:
          'Kal ke hospital visit ke liye transport confirm nahi',
    },
    'demo_notification_dressing_completed': {
      AppLanguage.english: 'Dressing assistance marked completed',
      AppLanguage.urdu: 'Dressing assistance completed نشان لگی',
      AppLanguage.romanUrdu: 'Dressing assistance completed mark hui',
    },
    'demo_notification_understanding_recorded': {
      AppLanguage.english: 'Understanding score recorded at 76%',
      AppLanguage.urdu: 'Understanding score 76% پر record ہوا',
      AppLanguage.romanUrdu: 'Understanding score 76% par record hua',
    },
    'documents_subtitle': {
      AppLanguage.english: 'Every document used to build your care plans.',
      AppLanguage.urdu: 'آپ کے نگہداشت منصوبے بنانے کے لیے استعمال ہونے والی ہر document۔',
      AppLanguage.romanUrdu: 'Aap ke care plans banane ke liye use hone wala har document.',
    },
    'upload': {
      AppLanguage.english: 'Upload',
      AppLanguage.urdu: 'اپ لوڈ',
      AppLanguage.romanUrdu: 'Upload',
    },
    'no_documents_yet': {
      AppLanguage.english: 'No documents yet',
      AppLanguage.urdu: 'ابھی کوئی documents نہیں',
      AppLanguage.romanUrdu: 'Abhi koi documents nahi',
    },
    'upload_prescription_or_discharge': {
      AppLanguage.english:
          'Upload a prescription or discharge summary to get started.',
      AppLanguage.urdu:
          'شروع کرنے کے لیے prescription یا discharge summary اپ لوڈ کریں۔',
      AppLanguage.romanUrdu:
          'Shuru karne ke liye prescription ya discharge summary upload karein.',
    },
    'upload_document': {
      AppLanguage.english: 'Upload document',
      AppLanguage.urdu: 'Document اپ لوڈ کریں',
      AppLanguage.romanUrdu: 'Document upload karein',
    },
    'document_pages_summary': {
      AppLanguage.english: '{type} · {pages} page(s) · {date}',
      AppLanguage.urdu: '{type} · {pages} page(s) · {date}',
      AppLanguage.romanUrdu: '{type} · {pages} page(s) · {date}',
    },
    'document_preview_demo_unavailable': {
      AppLanguage.english:
          'Document preview is not available in this demo.',
      AppLanguage.urdu:
          'اس demo میں document preview دستیاب نہیں ہے۔',
      AppLanguage.romanUrdu:
          'Is demo mein document preview available nahi hai.',
    },
    'document_removed': {
      AppLanguage.english: 'Document removed',
      AppLanguage.urdu: 'Document remove ہو گیا',
      AppLanguage.romanUrdu: 'Document remove ho gaya',
    },
    'view': {
      AppLanguage.english: 'View',
      AppLanguage.urdu: 'دیکھیں',
      AppLanguage.romanUrdu: 'View',
    },
    'documents_safety_note': {
      AppLanguage.english:
          'Documents are stored only to build and verify your care plan.',
      AppLanguage.urdu:
          'Documents صرف آپ کا care plan بنانے اور verify کرنے کے لیے stored ہوتے ہیں۔',
      AppLanguage.romanUrdu:
          'Documents sirf aap ka care plan banane aur verify karne ke liye stored hote hain.',
    },
    'tasks_completed': {
      AppLanguage.english: 'Tasks completed',
      AppLanguage.urdu: 'Tasks مکمل',
      AppLanguage.romanUrdu: 'Tasks completed',
    },
    'gaps_resolved': {
      AppLanguage.english: 'Gaps resolved',
      AppLanguage.urdu: 'Gaps resolve ہوئے',
      AppLanguage.romanUrdu: 'Gaps resolved',
    },
    'understanding': {
      AppLanguage.english: 'Understanding',
      AppLanguage.urdu: 'سمجھ',
      AppLanguage.romanUrdu: 'Understanding',
    },
    'care_progress': {
      AppLanguage.english: 'Care Progress',
      AppLanguage.urdu: 'نگہداشت کی پیش رفت',
      AppLanguage.romanUrdu: 'Care Progress',
    },
    'care_progress_subtitle': {
      AppLanguage.english:
          'How practical the care plan has become over time.',
      AppLanguage.urdu:
          'وقت کے ساتھ care plan کتنا practical ہوا۔',
      AppLanguage.romanUrdu:
          'Waqt ke saath care plan kitna practical hua.',
    },
    'care_readiness_trend': {
      AppLanguage.english: 'Care readiness trend',
      AppLanguage.urdu: 'Care readiness trend',
      AppLanguage.romanUrdu: 'Care readiness trend',
    },
    'understanding_score': {
      AppLanguage.english: 'Understanding score',
      AppLanguage.urdu: 'Understanding score',
      AppLanguage.romanUrdu: 'Understanding score',
    },
    'latest_teach_back_basis': {
      AppLanguage.english: 'Based on your latest Teach-Back session.',
      AppLanguage.urdu: 'آپ کے تازہ ترین Teach-Back session کی بنیاد پر۔',
      AppLanguage.romanUrdu: 'Aap ke latest Teach-Back session ki bunyaad par.',
    },
    'most_common_barriers': {
      AppLanguage.english: 'Most common barriers',
      AppLanguage.urdu: 'سب سے عام رکاوٹیں',
      AppLanguage.romanUrdu: 'Most common barriers',
    },
    'transport': {
      AppLanguage.english: 'Transport',
      AppLanguage.urdu: 'Transport',
      AppLanguage.romanUrdu: 'Transport',
    },
    'caregiver_availability': {
      AppLanguage.english: 'Caregiver availability',
      AppLanguage.urdu: 'Caregiver availability',
      AppLanguage.romanUrdu: 'Caregiver availability',
    },
    'medicine_access': {
      AppLanguage.english: 'Medicine access',
      AppLanguage.urdu: 'Medicine access',
      AppLanguage.romanUrdu: 'Medicine access',
    },
    'times_count': {
      AppLanguage.english: '{count} time(s)',
      AppLanguage.urdu: '{count} time(s)',
      AppLanguage.romanUrdu: '{count} time(s)',
    },
    'progress_demo_safety_note': {
      AppLanguage.english:
          'These metrics describe care-plan feasibility and understanding, not clinical outcomes.',
      AppLanguage.urdu:
          'یہ metrics care-plan feasibility اور understanding دکھاتے ہیں، clinical outcomes نہیں۔',
      AppLanguage.romanUrdu:
          'Yeh metrics care-plan feasibility aur understanding dikhate hain, clinical outcomes nahi.',
    },
    'week_number': {
      AppLanguage.english: 'Week {number}',
      AppLanguage.urdu: 'ہفتہ {number}',
      AppLanguage.romanUrdu: 'Week {number}',
    },





    // Language settings
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.urdu: 'زبان',
      AppLanguage.romanUrdu: 'Language',
    },
    'choose_language': {
      AppLanguage.english: 'Choose app language',
      AppLanguage.urdu: 'ایپ کی زبان منتخب کریں',
      AppLanguage.romanUrdu: 'App ki language select karein',
    },
    'language_description': {
      AppLanguage.english:
          'The app, Voice Agent and spoken replies will follow this language.',
      AppLanguage.urdu:
          'ایپ، وائس ایجنٹ اور بولے گئے جوابات اسی زبان کے مطابق ہوں گے۔',
      AppLanguage.romanUrdu:
          'App, Voice Agent aur spoken replies isi language ke mutabiq hon ge.',
    },
    'english': {
      AppLanguage.english: 'English',
      AppLanguage.urdu: 'English',
      AppLanguage.romanUrdu: 'English',
    },
    'urdu': {
      AppLanguage.english: 'اردو',
      AppLanguage.urdu: 'اردو',
      AppLanguage.romanUrdu: 'اردو',
    },
    'roman_urdu': {
      AppLanguage.english: 'Roman Urdu',
      AppLanguage.urdu: 'Roman Urdu',
      AppLanguage.romanUrdu: 'Roman Urdu',
    },
    'language_changed': {
      AppLanguage.english: 'Language changed.',
      AppLanguage.urdu: 'زبان تبدیل ہو گئی۔',
      AppLanguage.romanUrdu: 'Language change ho gayi.',
    },


    // Dashboard
    'there': {
      AppLanguage.english: 'there',
      AppLanguage.urdu: 'دوست',
      AppLanguage.romanUrdu: 'dost',
    },
    'good_morning': {
      AppLanguage.english: 'Good morning',
      AppLanguage.urdu: 'صبح بخیر',
      AppLanguage.romanUrdu: 'Subah bakhair',
    },
    'good_afternoon': {
      AppLanguage.english: 'Good afternoon',
      AppLanguage.urdu: 'دوپہر بخیر',
      AppLanguage.romanUrdu: 'Dopahar bakhair',
    },
    'good_evening': {
      AppLanguage.english: 'Good evening',
      AppLanguage.urdu: 'شام بخیر',
      AppLanguage.romanUrdu: 'Shaam bakhair',
    },
    'greeting_name': {
      AppLanguage.english: '{greeting}, {name}',
      AppLanguage.urdu: '{greeting}، {name}',
      AppLanguage.romanUrdu: '{greeting}, {name}',
    },
    'dashboard_overview_today': {
      AppLanguage.english: "Here's your care overview for today.",
      AppLanguage.urdu: 'یہ آج کے لیے آپ کی نگہداشت کا خلاصہ ہے۔',
      AppLanguage.romanUrdu: 'Yeh aaj ke liye aap ki care ka overview hai.',
    },
    'upload_new_care_plan': {
      AppLanguage.english: 'Upload New Care Plan',
      AppLanguage.urdu: 'نیا نگہداشت منصوبہ اپ لوڈ کریں',
      AppLanguage.romanUrdu: 'Naya Care Plan upload karein',
    },
    'dashboard_saved_offline': {
      AppLanguage.english:
          'Saved offline. SehatMate will sync this outcome automatically.',
      AppLanguage.urdu:
          'آف لائن محفوظ ہو گیا۔ صحت میٹ اسے خودکار طور پر سنک کر دے گا۔',
      AppLanguage.romanUrdu:
          'Offline save ho gaya. SehatMate is outcome ko automatically sync kar dega.',
    },
    'dashboard_conflict_restored': {
      AppLanguage.english:
          'This task changed on another device. Latest server status restored.',
      AppLanguage.urdu:
          'یہ کام دوسرے ڈیوائس پر تبدیل ہوا تھا۔ تازہ ترین سرور اسٹیٹس بحال کر دیا گیا ہے۔',
      AppLanguage.romanUrdu:
          'Yeh task doosre device par change hua tha. Latest server status restore kar diya gaya hai.',
    },
    'dashboard_offline_changes_waiting': {
      AppLanguage.english: 'Offline · {count} change(s) waiting to sync.',
      AppLanguage.urdu: 'آف لائن · {count} تبدیلیاں سنک ہونے کی منتظر ہیں۔',
      AppLanguage.romanUrdu: 'Offline · {count} changes sync hone ka wait kar rahi hain.',
    },
    'dashboard_offline_saved_data': {
      AppLanguage.english: 'Offline · showing the latest saved care data.',
      AppLanguage.urdu: 'آف لائن · تازہ ترین محفوظ نگہداشت ڈیٹا دکھایا جا رہا ہے۔',
      AppLanguage.romanUrdu: 'Offline · latest saved care data dikhaya ja raha hai.',
    },
    'dashboard_syncing': {
      AppLanguage.english: 'Syncing care changes and reminders…',
      AppLanguage.urdu: 'نگہداشت کی تبدیلیاں اور ریمائنڈرز سنک ہو رہے ہیں…',
      AppLanguage.romanUrdu: 'Care changes aur reminders sync ho rahe hain…',
    },
    'dashboard_changes_waiting': {
      AppLanguage.english: '{count} change(s) waiting to sync.',
      AppLanguage.urdu: '{count} تبدیلیاں سنک ہونے کی منتظر ہیں۔',
      AppLanguage.romanUrdu: '{count} changes sync hone ka wait kar rahi hain.',
    },
    'sync_now': {
      AppLanguage.english: 'Sync now',
      AppLanguage.urdu: 'ابھی سنک کریں',
      AppLanguage.romanUrdu: 'Abhi sync karein',
    },
    'continue_setup': {
      AppLanguage.english: 'Continue setup',
      AppLanguage.urdu: 'سیٹ اپ جاری رکھیں',
      AppLanguage.romanUrdu: 'Setup jari rakhein',
    },
    'care_plan_setup_incomplete': {
      AppLanguage.english: 'Care plan setup incomplete',
      AppLanguage.urdu: 'نگہداشت منصوبے کا سیٹ اپ نامکمل ہے',
      AppLanguage.romanUrdu: 'Care plan setup abhi mukammal nahi',
    },
    'setup_progress_count': {
      AppLanguage.english: 'Setup {completed} of {total} complete',
      AppLanguage.urdu: 'سیٹ اپ {completed} از {total} مکمل',
      AppLanguage.romanUrdu: 'Setup {completed} of {total} complete',
    },
    'next_step': {
      AppLanguage.english: 'Next: {step}',
      AppLanguage.urdu: 'اگلا مرحلہ: {step}',
      AppLanguage.romanUrdu: 'Agla step: {step}',
    },
    'setup_step_upload': {
      AppLanguage.english: 'Upload & extract documents',
      AppLanguage.urdu: 'دستاویزات اپ لوڈ اور نکالیں',
      AppLanguage.romanUrdu: 'Documents upload aur extract karein',
    },
    'setup_step_review': {
      AppLanguage.english: 'Review & verify instructions',
      AppLanguage.urdu: 'ہدایات کا جائزہ اور تصدیق',
      AppLanguage.romanUrdu: 'Instructions review aur verify karein',
    },
    'setup_step_schedule': {
      AppLanguage.english: 'Set up schedule',
      AppLanguage.urdu: 'شیڈول ترتیب دیں',
      AppLanguage.romanUrdu: 'Schedule set karein',
    },
    'setup_step_reality': {
      AppLanguage.english: 'Complete Reality Check',
      AppLanguage.urdu: 'عملی جائزہ مکمل کریں',
      AppLanguage.romanUrdu: 'Reality Check complete karein',
    },
    'setup_step_simulation': {
      AppLanguage.english: 'Run care simulation',
      AppLanguage.urdu: 'نگہداشت سیمیولیشن چلائیں',
      AppLanguage.romanUrdu: 'Care simulation run karein',
    },
    'setup_step_care_gaps': {
      AppLanguage.english: 'Resolve care gaps',
      AppLanguage.urdu: 'نگہداشت کی کمی دور کریں',
      AppLanguage.romanUrdu: 'Care gaps resolve karein',
    },
    'setup_step_activate': {
      AppLanguage.english: 'Activate care plan',
      AppLanguage.urdu: 'نگہداشت منصوبہ فعال کریں',
      AppLanguage.romanUrdu: 'Care plan activate karein',
    },
    'setup_step_complete': {
      AppLanguage.english: 'Setup complete',
      AppLanguage.urdu: 'سیٹ اپ مکمل',
      AppLanguage.romanUrdu: 'Setup complete',
    },
    'setup_label_documents': {
      AppLanguage.english: 'Documents',
      AppLanguage.urdu: 'دستاویزات',
      AppLanguage.romanUrdu: 'Documents',
    },
    'setup_label_review': {
      AppLanguage.english: 'Review',
      AppLanguage.urdu: 'جائزہ',
      AppLanguage.romanUrdu: 'Review',
    },
    'setup_label_schedule': {
      AppLanguage.english: 'Schedule',
      AppLanguage.urdu: 'شیڈول',
      AppLanguage.romanUrdu: 'Schedule',
    },
    'setup_label_reality': {
      AppLanguage.english: 'Reality',
      AppLanguage.urdu: 'عملی جائزہ',
      AppLanguage.romanUrdu: 'Reality',
    },
    'setup_label_simulation': {
      AppLanguage.english: 'Simulation',
      AppLanguage.urdu: 'سیمیولیشن',
      AppLanguage.romanUrdu: 'Simulation',
    },
    'setup_label_care_gaps': {
      AppLanguage.english: 'Care Gaps',
      AppLanguage.urdu: 'نگہداشت کی کمیاں',
      AppLanguage.romanUrdu: 'Care Gaps',
    },
    'setup_label_activate': {
      AppLanguage.english: 'Activate',
      AppLanguage.urdu: 'فعال کریں',
      AppLanguage.romanUrdu: 'Activate',
    },
    'setup_step_counter': {
      AppLanguage.english: 'Step {current} of {total} · {label}',
      AppLanguage.urdu: 'مرحلہ {current} از {total} · {label}',
      AppLanguage.romanUrdu: 'Step {current} of {total} · {label}',
    },
    'setup_completed_steps_help': {
      AppLanguage.english:
          'Completed steps can be opened again for review. Future steps unlock in order.',
      AppLanguage.urdu:
          'مکمل مراحل دوبارہ جائزے کے لیے کھولے جا سکتے ہیں۔ آئندہ مراحل ترتیب سے کھلتے ہیں۔',
      AppLanguage.romanUrdu:
          'Completed steps review ke liye dobara khol sakte hain. Future steps order mein unlock hote hain.',
    },
    'care_readiness': {
      AppLanguage.english: 'Care Readiness',
      AppLanguage.urdu: 'نگہداشت کی تیاری',
      AppLanguage.romanUrdu: 'Care Readiness',
    },
    'active_plans_count': {
      AppLanguage.english: '{count} active plan(s)',
      AppLanguage.urdu: '{count} فعال نگہداشت منصوبے',
      AppLanguage.romanUrdu: '{count} active plan(s)',
    },
    'completed_count': {
      AppLanguage.english: '{count} completed',
      AppLanguage.urdu: '{count} مکمل',
      AppLanguage.romanUrdu: '{count} complete',
    },
    'current_unresolved': {
      AppLanguage.english: 'Current unresolved',
      AppLanguage.urdu: 'موجودہ غیر حل شدہ',
      AppLanguage.romanUrdu: 'Abhi unresolved',
    },
    'task_completion': {
      AppLanguage.english: 'Task Completion',
      AppLanguage.urdu: 'کاموں کی تکمیل',
      AppLanguage.romanUrdu: 'Task Completion',
    },
    'decided_tasks_today': {
      AppLanguage.english: 'Decided tasks today',
      AppLanguage.urdu: 'آج کے طے شدہ کام',
      AppLanguage.romanUrdu: 'Aaj ke decided tasks',
    },
    'smart_routine_insight': {
      AppLanguage.english: 'Smart routine insight',
      AppLanguage.urdu: 'سمارٹ روٹین کی بصیرت',
      AppLanguage.romanUrdu: 'Smart routine insight',
    },
    'learned_preference_message': {
      AppLanguage.english:
          'For flexible {period} reminders, your learned preference is around {time}.',
      AppLanguage.urdu:
          'لچکدار {period} ریمائنڈرز کے لیے آپ کی سیکھی گئی ترجیح تقریباً {time} ہے۔',
      AppLanguage.romanUrdu:
          'Flexible {period} reminders ke liye aap ki learned preference taqreeban {time} hai.',
    },
    'routine_confidence_signals': {
      AppLanguage.english: '{confidence} confidence · {count} routine signals.',
      AppLanguage.urdu: '{confidence} اعتماد · {count} روٹین سگنلز۔',
      AppLanguage.romanUrdu: '{confidence} confidence · {count} routine signals.',
    },
    'review_with_adapt_my_plan': {
      AppLanguage.english: 'Review with Adapt My Plan',
      AppLanguage.urdu: 'Adapt My Plan کے ساتھ جائزہ لیں',
      AppLanguage.romanUrdu: 'Adapt My Plan ke saath review karein',
    },
    'routine_learning_safety_note': {
      AppLanguage.english:
          'Routine learning can suggest practical timing only for flexible reminders. Verified clinician instructions are not changed automatically.',
      AppLanguage.urdu:
          'روٹین لرننگ صرف لچکدار ریمائنڈرز کے لیے عملی وقت تجویز کرتی ہے۔ تصدیق شدہ طبی ہدایات خودکار طور پر تبدیل نہیں ہوتیں۔',
      AppLanguage.romanUrdu:
          'Routine learning sirf flexible reminders ke liye practical timing suggest karti hai. Verified clinician instructions automatically change nahi hotin.',
    },
    'todays_care': {
      AppLanguage.english: "Today's Care",
      AppLanguage.urdu: 'آج کی نگہداشت',
      AppLanguage.romanUrdu: 'Aaj ki Care',
    },
    'one_outcome_per_reminder': {
      AppLanguage.english: 'One real outcome record per scheduled reminder.',
      AppLanguage.urdu: 'ہر مقررہ ریمائنڈر کے لیے ایک حقیقی نتیجہ ریکارڈ ہوتا ہے۔',
      AppLanguage.romanUrdu: 'Har scheduled reminder ka aik real outcome record hota hai.',
    },
    'open_calendar': {
      AppLanguage.english: 'Open calendar',
      AppLanguage.urdu: 'کیلنڈر کھولیں',
      AppLanguage.romanUrdu: 'Calendar kholein',
    },
    'no_care_tasks_today': {
      AppLanguage.english: 'No care tasks are scheduled for today.',
      AppLanguage.urdu: 'آج کے لیے کوئی نگہداشت کا کام مقرر نہیں ہے۔',
      AppLanguage.romanUrdu: 'Aaj ke liye koi care task scheduled nahi hai.',
    },
    'overdue': {
      AppLanguage.english: 'Overdue',
      AppLanguage.urdu: 'وقت گزر گیا',
      AppLanguage.romanUrdu: 'Overdue',
    },
    'morning': {
      AppLanguage.english: 'Morning',
      AppLanguage.urdu: 'صبح',
      AppLanguage.romanUrdu: 'Subah',
    },
    'afternoon': {
      AppLanguage.english: 'Afternoon',
      AppLanguage.urdu: 'دوپہر',
      AppLanguage.romanUrdu: 'Dopahar',
    },
    'evening': {
      AppLanguage.english: 'Evening',
      AppLanguage.urdu: 'شام',
      AppLanguage.romanUrdu: 'Shaam',
    },
    'night': {
      AppLanguage.english: 'Night',
      AppLanguage.urdu: 'رات',
      AppLanguage.romanUrdu: 'Raat',
    },
    'guest_dashboard': {
      AppLanguage.english: 'Guest dashboard',
      AppLanguage.urdu: 'مہمان ڈیش بورڈ',
      AppLanguage.romanUrdu: 'Guest dashboard',
    },
    'guest_dashboard_subtitle': {
      AppLanguage.english:
          'Sign in to use real task outcomes across your care plans.',
      AppLanguage.urdu:
          'اپنے نگہداشت منصوبوں میں حقیقی task outcomes استعمال کرنے کے لیے سائن اِن کریں۔',
      AppLanguage.romanUrdu:
          'Apne care plans mein real task outcomes use karne ke liye sign in karein.',
    },
    'demo_tasks_count': {
      AppLanguage.english: '{count} demo tasks',
      AppLanguage.urdu: '{count} ڈیمو کام',
      AppLanguage.romanUrdu: '{count} demo tasks',
    },
    'sign_in': {
      AppLanguage.english: 'Sign in',
      AppLanguage.urdu: 'سائن اِن',
      AppLanguage.romanUrdu: 'Sign in',
    },


    // Care Plans + New Care Plan
    'care_plans_subtitle': {
      AppLanguage.english: 'Every plan built from verified doctor instructions.',
      AppLanguage.urdu: 'ہر منصوبہ تصدیق شدہ ڈاکٹر کی ہدایات سے بنایا جاتا ہے۔',
      AppLanguage.romanUrdu: 'Har plan verified doctor instructions se banta hai.',
    },
    'new_care_plan': {
      AppLanguage.english: 'New Care Plan',
      AppLanguage.urdu: 'نیا نگہداشت منصوبہ',
      AppLanguage.romanUrdu: 'Naya Care Plan',
    },
    'active': {
      AppLanguage.english: 'Active',
      AppLanguage.urdu: 'فعال',
      AppLanguage.romanUrdu: 'Active',
    },
    'draft': {
      AppLanguage.english: 'Draft',
      AppLanguage.urdu: 'مسودہ',
      AppLanguage.romanUrdu: 'Draft',
    },
    'ready': {
      AppLanguage.english: 'Ready',
      AppLanguage.urdu: 'تیار',
      AppLanguage.romanUrdu: 'Ready',
    },
    'at_risk': {
      AppLanguage.english: 'At Risk',
      AppLanguage.urdu: 'خطرے میں',
      AppLanguage.romanUrdu: 'At Risk',
    },
    'blocked': {
      AppLanguage.english: 'Blocked',
      AppLanguage.urdu: 'رکا ہوا',
      AppLanguage.romanUrdu: 'Blocked',
    },
    'unclear': {
      AppLanguage.english: 'Unclear',
      AppLanguage.urdu: 'غیر واضح',
      AppLanguage.romanUrdu: 'Unclear',
    },
    'resolved': {
      AppLanguage.english: 'Resolved',
      AppLanguage.urdu: 'حل ہو گیا',
      AppLanguage.romanUrdu: 'Resolve ho gaya',
    },
    'processing': {
      AppLanguage.english: 'Processing',
      AppLanguage.urdu: 'پروسیسنگ جاری ہے',
      AppLanguage.romanUrdu: 'Processing',
    },
    'needs_attention': {
      AppLanguage.english: 'Needs Attention',
      AppLanguage.urdu: 'توجہ درکار ہے',
      AppLanguage.romanUrdu: 'Tawajjo darkar hai',
    },
    'needs_review': {
      AppLanguage.english: 'Needs Review',
      AppLanguage.urdu: 'جائزہ درکار ہے',
      AppLanguage.romanUrdu: 'Review darkar hai',
    },
    'reality_check_required': {
      AppLanguage.english: 'Reality Check Required',
      AppLanguage.urdu: 'عملی جائزہ درکار ہے',
      AppLanguage.romanUrdu: 'Reality Check zaroori hai',
    },
    'open_status': {
      AppLanguage.english: 'Open',
      AppLanguage.urdu: 'کھلا',
      AppLanguage.romanUrdu: 'Open',
    },
    'previously_blocking': {
      AppLanguage.english: 'Previously blocking',
      AppLanguage.urdu: 'پہلے رکاوٹ تھا',
      AppLanguage.romanUrdu: 'Pehle blocking tha',
    },
    'in_progress': {
      AppLanguage.english: 'In progress',
      AppLanguage.urdu: 'جاری ہے',
      AppLanguage.romanUrdu: 'Jari hai',
    },
    'saving': {
      AppLanguage.english: 'Saving…',
      AppLanguage.urdu: 'محفوظ ہو رہا ہے…',
      AppLanguage.romanUrdu: 'Save ho raha hai…',
    },
    'retry_needed': {
      AppLanguage.english: 'Retry needed',
      AppLanguage.urdu: 'دوبارہ کوشش درکار ہے',
      AppLanguage.romanUrdu: 'Retry zaroori hai',
    },
    'unsaved_changes': {
      AppLanguage.english: 'Unsaved changes',
      AppLanguage.urdu: 'غیر محفوظ تبدیلیاں',
      AppLanguage.romanUrdu: 'Unsaved changes',
    },
    'save_changes': {
      AppLanguage.english: 'Save changes',
      AppLanguage.urdu: 'تبدیلیاں محفوظ کریں',
      AppLanguage.romanUrdu: 'Changes save karein',
    },
    'clear_selection': {
      AppLanguage.english: 'Clear selection',
      AppLanguage.urdu: 'انتخاب ختم کریں',
      AppLanguage.romanUrdu: 'Selection clear karein',
    },
    'select_all': {
      AppLanguage.english: 'Select all',
      AppLanguage.urdu: 'سب منتخب کریں',
      AppLanguage.romanUrdu: 'Sab select karein',
    },
    'delete_selected_count': {
      AppLanguage.english: 'Delete selected ({count})',
      AppLanguage.urdu: 'منتخب شدہ حذف کریں ({count})',
      AppLanguage.romanUrdu: 'Selected delete karein ({count})',
    },
    'delete_all_section': {
      AppLanguage.english: 'Delete all {section}',
      AppLanguage.urdu: 'تمام {section} حذف کریں',
      AppLanguage.romanUrdu: 'Sab {section} delete karein',
    },
    'care_plans_load_failed': {
      AppLanguage.english: 'Care plans could not be loaded.',
      AppLanguage.urdu: 'نگہداشت کے منصوبے لوڈ نہیں ہو سکے۔',
      AppLanguage.romanUrdu: 'Care plans load nahi ho sake.',
    },
    'delete_care_plan_question': {
      AppLanguage.english: 'Delete care plan?',
      AppLanguage.urdu: 'نگہداشت منصوبہ حذف کریں؟',
      AppLanguage.romanUrdu: 'Care plan delete karein?',
    },
    'delete_care_plan_description': {
      AppLanguage.english:
          '{plan} and its uploaded documents, extracted instructions, schedule, and answers will be permanently deleted.',
      AppLanguage.urdu:
          '{plan} اور اس کی اپ لوڈ شدہ دستاویزات، نکالی گئی ہدایات، شیڈول اور جوابات مستقل طور پر حذف ہو جائیں گے۔',
      AppLanguage.romanUrdu:
          '{plan} aur us ke uploaded documents, extracted instructions, schedule aur answers permanently delete ho jayen ge.',
    },
    'delete_plan': {
      AppLanguage.english: 'Delete plan',
      AppLanguage.urdu: 'منصوبہ حذف کریں',
      AppLanguage.romanUrdu: 'Plan delete karein',
    },
    'care_plan_deleted': {
      AppLanguage.english: 'Care plan and its reminders deleted.',
      AppLanguage.urdu: 'نگہداشت منصوبہ اور اس کے ریمائنڈرز حذف ہو گئے۔',
      AppLanguage.romanUrdu: 'Care plan aur us ke reminders delete ho gaye.',
    },
    'delete_all_plans_question': {
      AppLanguage.english: 'Delete all plans in this section?',
      AppLanguage.urdu: 'اس حصے کے تمام منصوبے حذف کریں؟',
      AppLanguage.romanUrdu: 'Is section ke sab plans delete karein?',
    },
    'delete_selected_plans_question': {
      AppLanguage.english: 'Delete selected plans?',
      AppLanguage.urdu: 'منتخب شدہ منصوبے حذف کریں؟',
      AppLanguage.romanUrdu: 'Selected plans delete karein?',
    },
    'bulk_delete_description': {
      AppLanguage.english:
          '{count} care plan(s) and their reminders will be permanently deleted.',
      AppLanguage.urdu:
          '{count} نگہداشت منصوبے اور ان کے ریمائنڈرز مستقل طور پر حذف ہو جائیں گے۔',
      AppLanguage.romanUrdu:
          '{count} care plan(s) aur un ke reminders permanently delete ho jayen ge.',
    },
    'selected_care_plans_deleted': {
      AppLanguage.english: 'Selected care plans deleted.',
      AppLanguage.urdu: 'منتخب شدہ نگہداشت منصوبے حذف ہو گئے۔',
      AppLanguage.romanUrdu: 'Selected care plans delete ho gaye.',
    },
    'complete_plan_question': {
      AppLanguage.english: 'Complete this plan now?',
      AppLanguage.urdu: 'کیا یہ منصوبہ ابھی مکمل کرنا ہے؟',
      AppLanguage.romanUrdu: 'Kya yeh plan abhi complete karna hai?',
    },
    'complete_plan_description': {
      AppLanguage.english:
          'Future reminders for this plan will be removed. You can still view it under Completed.',
      AppLanguage.urdu:
          'اس منصوبے کے آئندہ ریمائنڈرز ہٹا دیے جائیں گے۔ آپ اسے Completed میں پھر بھی دیکھ سکتے ہیں۔',
      AppLanguage.romanUrdu:
          'Is plan ke future reminders remove ho jayen ge. Aap isay Completed mein phir bhi dekh sakte hain.',
    },
    'complete_plan': {
      AppLanguage.english: 'Complete plan',
      AppLanguage.urdu: 'منصوبہ مکمل کریں',
      AppLanguage.romanUrdu: 'Plan complete karein',
    },
    'no_care_plans_here': {
      AppLanguage.english: 'No care plans here yet',
      AppLanguage.urdu: 'ابھی یہاں کوئی نگہداشت منصوبہ نہیں ہے',
      AppLanguage.romanUrdu: 'Abhi yahan koi care plan nahi hai',
    },
    'no_care_plan_in_state': {
      AppLanguage.english: "You don't have a care plan in this state yet.",
      AppLanguage.urdu: 'اس حالت میں ابھی کوئی نگہداشت منصوبہ موجود نہیں ہے۔',
      AppLanguage.romanUrdu: 'Is state mein abhi koi care plan nahi hai.',
    },
    'create_care_plan': {
      AppLanguage.english: 'Create Care Plan',
      AppLanguage.urdu: 'نگہداشت منصوبہ بنائیں',
      AppLanguage.romanUrdu: 'Care Plan banayein',
    },
    'plan_actions': {
      AppLanguage.english: 'Plan actions',
      AppLanguage.urdu: 'منصوبے کی کارروائیاں',
      AppLanguage.romanUrdu: 'Plan actions',
    },
    'started_date': {
      AppLanguage.english: 'Started {date}',
      AppLanguage.urdu: 'شروع ہوا {date}',
      AppLanguage.romanUrdu: 'Started {date}',
    },
    'next_label': {
      AppLanguage.english: 'Next',
      AppLanguage.urdu: 'اگلا',
      AppLanguage.romanUrdu: 'Agla',
    },
    'single_document_care_plan_title': {
      AppLanguage.english: '{document} Care Plan',
      AppLanguage.urdu: '{document} Care Plan',
      AppLanguage.romanUrdu: '{document} Care Plan',
    },
    'combined_care_plan_title': {
      AppLanguage.english: 'Combined Care Plan',
      AppLanguage.urdu: 'Combined Care Plan',
      AppLanguage.romanUrdu: 'Combined Care Plan',
    },
    'demo_plan_post_discharge': {
      AppLanguage.english: 'Post-Discharge Care Plan',
      AppLanguage.urdu: 'Discharge کے بعد care plan',
      AppLanguage.romanUrdu: 'Discharge ke baad care plan',
    },
    'demo_plan_wound_care_follow_up': {
      AppLanguage.english: 'Wound Care Follow-Up',
      AppLanguage.urdu: 'Wound Care Follow-Up',
      AppLanguage.romanUrdu: 'Wound Care Follow-Up',
    },
    'demo_plan_blood_pressure_review': {
      AppLanguage.english: 'Blood Pressure Review Plan',
      AppLanguage.urdu: 'Blood Pressure Review Plan',
      AppLanguage.romanUrdu: 'Blood Pressure Review Plan',
    },
    'demo_plan_post_surgery_recovery': {
      AppLanguage.english: 'Post-Surgery Recovery Plan',
      AppLanguage.urdu: 'Surgery کے بعد recovery plan',
      AppLanguage.romanUrdu: 'Surgery ke baad recovery plan',
    },
    'demo_plan_next_dressing_tomorrow': {
      AppLanguage.english: 'Dressing — Tomorrow 10:00 AM',
      AppLanguage.urdu: 'Dressing — کل 10:00 AM',
      AppLanguage.romanUrdu: 'Dressing — kal 10:00 AM',
    },
    'upload_documents_to_continue': {
      AppLanguage.english: 'Upload documents to continue',
      AppLanguage.urdu: 'جاری رکھنے کے لیے documents upload کریں',
      AppLanguage.romanUrdu: 'Jari rakhne ke liye documents upload karein',
    },
    'plan_completed': {
      AppLanguage.english: 'Plan completed',
      AppLanguage.urdu: 'Plan مکمل ہو گیا',
      AppLanguage.romanUrdu: 'Plan complete ho gaya',
    },
    'not_started': {
      AppLanguage.english: 'Not started',
      AppLanguage.urdu: 'شروع نہیں ہوا',
      AppLanguage.romanUrdu: 'Shuru nahi hua',
    },
    'what_would_you_like_to_add': {
      AppLanguage.english: 'What would you like to add?',
      AppLanguage.urdu: 'آپ کیا شامل کرنا چاہیں گے؟',
      AppLanguage.romanUrdu: 'Aap kya add karna chahte hain?',
    },
    'select_document_types_subtitle': {
      AppLanguage.english:
          'Select every document type you have. You can add more later.',
      AppLanguage.urdu:
          'آپ کے پاس موجود تمام دستاویزات کی اقسام منتخب کریں۔ بعد میں مزید شامل کی جا سکتی ہیں۔',
      AppLanguage.romanUrdu:
          'Jo document types aap ke paas hain sab select karein. Baad mein aur add kar sakte hain.',
    },
    'new_plan_safety_note': {
      AppLanguage.english:
          'SehatMate organizes instructions that a healthcare professional has already given. It does not diagnose conditions or change treatment.',
      AppLanguage.urdu:
          'صحت میٹ پہلے سے دی گئی طبی ہدایات کو منظم کرتا ہے۔ یہ بیماری کی تشخیص یا علاج میں تبدیلی نہیں کرتا۔',
      AppLanguage.romanUrdu:
          'SehatMate healthcare professional ki pehle se di hui instructions ko organize karta hai. Yeh diagnosis ya treatment change nahi karta.',
    },
    'care_plan_create_failed': {
      AppLanguage.english: 'Care plan could not be created.',
      AppLanguage.urdu: 'نگہداشت منصوبہ نہیں بن سکا۔',
      AppLanguage.romanUrdu: 'Care plan create nahi ho saka.',
    },
    'prescription': {
      AppLanguage.english: 'Prescription',
      AppLanguage.urdu: 'نسخہ',
      AppLanguage.romanUrdu: 'Prescription',
    },
    'discharge_summary': {
      AppLanguage.english: 'Discharge Summary',
      AppLanguage.urdu: 'ڈسچارج خلاصہ',
      AppLanguage.romanUrdu: 'Discharge Summary',
    },
    'follow_up_instructions': {
      AppLanguage.english: 'Follow-Up Instructions',
      AppLanguage.urdu: 'فالو اَپ ہدایات',
      AppLanguage.romanUrdu: 'Follow-Up Instructions',
    },
    'lab_instructions': {
      AppLanguage.english: 'Lab Instructions',
      AppLanguage.urdu: 'لیب ہدایات',
      AppLanguage.romanUrdu: 'Lab Instructions',
    },
    'other_medical_instructions': {
      AppLanguage.english: 'Other Medical Instructions',
      AppLanguage.urdu: 'دیگر طبی ہدایات',
      AppLanguage.romanUrdu: 'Doosri Medical Instructions',
    },
    'prescription_description': {
      AppLanguage.english: 'Medicines, doses and timings.',
      AppLanguage.urdu: 'ادویات، خوراک اور اوقات۔',
      AppLanguage.romanUrdu: 'Medicines, doses aur timings.',
    },
    'discharge_description': {
      AppLanguage.english: 'Instructions after leaving hospital.',
      AppLanguage.urdu: 'ہسپتال سے گھر جانے کے بعد کی ہدایات۔',
      AppLanguage.romanUrdu: 'Hospital se ghar jane ke baad ki instructions.',
    },
    'followup_description': {
      AppLanguage.english: 'Next appointments and reviews.',
      AppLanguage.urdu: 'اگلی اپائنٹمنٹس اور جائزے۔',
      AppLanguage.romanUrdu: 'Agli appointments aur reviews.',
    },
    'lab_description': {
      AppLanguage.english: 'Tests and sample requirements.',
      AppLanguage.urdu: 'ٹیسٹس اور نمونوں کی ضروریات۔',
      AppLanguage.romanUrdu: 'Tests aur sample requirements.',
    },
    'other_medical_description': {
      AppLanguage.english: 'Anything else from your clinic.',
      AppLanguage.urdu: 'کلینک کی کوئی اور طبی ہدایت۔',
      AppLanguage.romanUrdu: 'Clinic ki koi aur medical instruction.',
    },


    // Calendar
    'calendar_subtitle': {
      AppLanguage.english:
          'The same real task outcomes used by Dashboard and each Care Plan.',
      AppLanguage.urdu:
          'یہ وہی حقیقی task outcomes ہیں جو Dashboard اور ہر Care Plan میں استعمال ہوتے ہیں۔',
      AppLanguage.romanUrdu:
          'Yeh wohi real task outcomes hain jo Dashboard aur har Care Plan mein use hote hain.',
    },
    'today': {
      AppLanguage.english: 'Today',
      AppLanguage.urdu: 'آج',
      AppLanguage.romanUrdu: 'Aaj',
    },
    'calendar_sign_in_required': {
      AppLanguage.english: 'Sign in to view your real care calendar.',
      AppLanguage.urdu: 'اپنا حقیقی نگہداشت کیلنڈر دیکھنے کے لیے سائن اِن کریں۔',
      AppLanguage.romanUrdu: 'Apna real care calendar dekhne ke liye sign in karein.',
    },
    'calendar_saved_offline': {
      AppLanguage.english:
          'Saved offline. This outcome will sync automatically.',
      AppLanguage.urdu:
          'آف لائن محفوظ ہو گیا۔ یہ نتیجہ خودکار طور پر سنک ہو جائے گا۔',
      AppLanguage.romanUrdu:
          'Offline save ho gaya. Yeh outcome automatically sync ho jayega.',
    },
    'calendar_conflict_restored': {
      AppLanguage.english:
          'Latest server status restored because this task changed elsewhere.',
      AppLanguage.urdu:
          'یہ task کہیں اور تبدیل ہوا تھا، اس لیے تازہ ترین server status بحال کر دیا گیا ہے۔',
      AppLanguage.romanUrdu:
          'Yeh task kahin aur change hua tha, is liye latest server status restore kar diya gaya hai.',
    },
    'calendar_offline_outcomes_waiting': {
      AppLanguage.english: 'Offline · {count} outcome(s) waiting to sync.',
      AppLanguage.urdu: 'آف لائن · {count} نتائج سنک ہونے کے منتظر ہیں۔',
      AppLanguage.romanUrdu: 'Offline · {count} outcomes sync hone ka wait kar rahe hain.',
    },
    'calendar_offline_saved_data': {
      AppLanguage.english: 'Offline · showing saved calendar data.',
      AppLanguage.urdu: 'آف لائن · محفوظ کیلنڈر ڈیٹا دکھایا جا رہا ہے۔',
      AppLanguage.romanUrdu: 'Offline · saved calendar data dikhaya ja raha hai.',
    },
    'calendar_syncing': {
      AppLanguage.english: 'Syncing…',
      AppLanguage.urdu: 'سنک ہو رہا ہے…',
      AppLanguage.romanUrdu: 'Sync ho raha hai…',
    },
    'calendar_outcomes_waiting': {
      AppLanguage.english: '{count} outcome(s) waiting to sync.',
      AppLanguage.urdu: '{count} نتائج سنک ہونے کے منتظر ہیں۔',
      AppLanguage.romanUrdu: '{count} outcomes sync hone ka wait kar rahe hain.',
    },
    'previous_week': {
      AppLanguage.english: 'Previous week',
      AppLanguage.urdu: 'پچھلا ہفتہ',
      AppLanguage.romanUrdu: 'Pichla hafta',
    },
    'next_week': {
      AppLanguage.english: 'Next week',
      AppLanguage.urdu: 'اگلا ہفتہ',
      AppLanguage.romanUrdu: 'Agla hafta',
    },
    'no_care_tasks_on_date': {
      AppLanguage.english: 'No care tasks on {date}',
      AppLanguage.urdu: '{date} کو کوئی نگہداشت task نہیں ہے',
      AppLanguage.romanUrdu: '{date} ko koi care task nahi hai',
    },
    'nothing_due_on_date': {
      AppLanguage.english:
          'Nothing from your current care schedules is due on this date.',
      AppLanguage.urdu:
          'آپ کے موجودہ نگہداشت شیڈول میں اس تاریخ کے لیے کچھ مقرر نہیں ہے۔',
      AppLanguage.romanUrdu:
          'Aap ke current care schedules mein is date ke liye kuch due nahi hai.',
    },
    'calendar_completed_summary': {
      AppLanguage.english: '{completed}/{total} completed',
      AppLanguage.urdu: '{completed}/{total} مکمل',
      AppLanguage.romanUrdu: '{completed}/{total} complete',
    },
    'calendar_week_range': {
      AppLanguage.english:
          '{startMonth} {startDay} – {endMonth} {endDay}, {year}',
      AppLanguage.urdu:
          '{startDay} {startMonth} – {endDay} {endMonth}، {year}',
      AppLanguage.romanUrdu:
          '{startMonth} {startDay} – {endMonth} {endDay}, {year}',
    },
    'calendar_full_date': {
      AppLanguage.english: '{weekday}, {day} {month} {year}',
      AppLanguage.urdu: '{weekday}، {day} {month} {year}',
      AppLanguage.romanUrdu: '{weekday}, {day} {month} {year}',
    },
    'mon_short': {
      AppLanguage.english: 'Mon',
      AppLanguage.urdu: 'پیر',
      AppLanguage.romanUrdu: 'Mon',
    },
    'tue_short': {
      AppLanguage.english: 'Tue',
      AppLanguage.urdu: 'منگل',
      AppLanguage.romanUrdu: 'Tue',
    },
    'wed_short': {
      AppLanguage.english: 'Wed',
      AppLanguage.urdu: 'بدھ',
      AppLanguage.romanUrdu: 'Wed',
    },
    'thu_short': {
      AppLanguage.english: 'Thu',
      AppLanguage.urdu: 'جمعرات',
      AppLanguage.romanUrdu: 'Thu',
    },
    'fri_short': {
      AppLanguage.english: 'Fri',
      AppLanguage.urdu: 'جمعہ',
      AppLanguage.romanUrdu: 'Fri',
    },
    'sat_short': {
      AppLanguage.english: 'Sat',
      AppLanguage.urdu: 'ہفتہ',
      AppLanguage.romanUrdu: 'Sat',
    },
    'sun_short': {
      AppLanguage.english: 'Sun',
      AppLanguage.urdu: 'اتوار',
      AppLanguage.romanUrdu: 'Sun',
    },
    'monday': {
      AppLanguage.english: 'Monday',
      AppLanguage.urdu: 'پیر',
      AppLanguage.romanUrdu: 'Monday',
    },
    'tuesday': {
      AppLanguage.english: 'Tuesday',
      AppLanguage.urdu: 'منگل',
      AppLanguage.romanUrdu: 'Tuesday',
    },
    'wednesday': {
      AppLanguage.english: 'Wednesday',
      AppLanguage.urdu: 'بدھ',
      AppLanguage.romanUrdu: 'Wednesday',
    },
    'thursday': {
      AppLanguage.english: 'Thursday',
      AppLanguage.urdu: 'جمعرات',
      AppLanguage.romanUrdu: 'Thursday',
    },
    'friday': {
      AppLanguage.english: 'Friday',
      AppLanguage.urdu: 'جمعہ',
      AppLanguage.romanUrdu: 'Friday',
    },
    'saturday': {
      AppLanguage.english: 'Saturday',
      AppLanguage.urdu: 'ہفتہ',
      AppLanguage.romanUrdu: 'Saturday',
    },
    'sunday': {
      AppLanguage.english: 'Sunday',
      AppLanguage.urdu: 'اتوار',
      AppLanguage.romanUrdu: 'Sunday',
    },
    'jan_short': {
      AppLanguage.english: 'Jan',
      AppLanguage.urdu: 'جنوری',
      AppLanguage.romanUrdu: 'Jan',
    },
    'feb_short': {
      AppLanguage.english: 'Feb',
      AppLanguage.urdu: 'فروری',
      AppLanguage.romanUrdu: 'Feb',
    },
    'mar_short': {
      AppLanguage.english: 'Mar',
      AppLanguage.urdu: 'مارچ',
      AppLanguage.romanUrdu: 'Mar',
    },
    'apr_short': {
      AppLanguage.english: 'Apr',
      AppLanguage.urdu: 'اپریل',
      AppLanguage.romanUrdu: 'Apr',
    },
    'may_short': {
      AppLanguage.english: 'May',
      AppLanguage.urdu: 'مئی',
      AppLanguage.romanUrdu: 'May',
    },
    'jun_short': {
      AppLanguage.english: 'Jun',
      AppLanguage.urdu: 'جون',
      AppLanguage.romanUrdu: 'Jun',
    },
    'jul_short': {
      AppLanguage.english: 'Jul',
      AppLanguage.urdu: 'جولائی',
      AppLanguage.romanUrdu: 'Jul',
    },
    'aug_short': {
      AppLanguage.english: 'Aug',
      AppLanguage.urdu: 'اگست',
      AppLanguage.romanUrdu: 'Aug',
    },
    'sep_short': {
      AppLanguage.english: 'Sep',
      AppLanguage.urdu: 'ستمبر',
      AppLanguage.romanUrdu: 'Sep',
    },
    'oct_short': {
      AppLanguage.english: 'Oct',
      AppLanguage.urdu: 'اکتوبر',
      AppLanguage.romanUrdu: 'Oct',
    },
    'nov_short': {
      AppLanguage.english: 'Nov',
      AppLanguage.urdu: 'نومبر',
      AppLanguage.romanUrdu: 'Nov',
    },
    'dec_short': {
      AppLanguage.english: 'Dec',
      AppLanguage.urdu: 'دسمبر',
      AppLanguage.romanUrdu: 'Dec',
    },

    'care_gaps_load_failed': {
  AppLanguage.english:
      'Care gaps could not be loaded.',
  AppLanguage.urdu:
      'نگہداشت کی کمیاں لوڈ نہیں ہو سکیں۔',
  AppLanguage.romanUrdu:
      'Care gaps load nahi ho sake.',
},


    // Progress
    'progress_subtitle': {
      AppLanguage.english:
          'Simple care-task progress from the same outcomes used across SehatMate.',
      AppLanguage.urdu:
          'SehatMate میں استعمال ہونے والے انہی حقیقی نتائج سے آپ کے care tasks کی سادہ پیش رفت۔',
      AppLanguage.romanUrdu:
          'SehatMate mein use hone wale inhi real outcomes se aap ke care tasks ki simple progress.',
    },
    'time_range': {
      AppLanguage.english: 'Time range',
      AppLanguage.urdu: 'مدت',
      AppLanguage.romanUrdu: 'Time range',
    },
    'last_days': {
      AppLanguage.english: 'Last {count} days',
      AppLanguage.urdu: 'گزشتہ {count} دن',
      AppLanguage.romanUrdu: 'Pichlay {count} din',
    },
    'progress_sign_in_required': {
      AppLanguage.english: 'Sign in to view real task progress.',
      AppLanguage.urdu: 'حقیقی task progress دیکھنے کے لیے سائن اِن کریں۔',
      AppLanguage.romanUrdu: 'Real task progress dekhne ke liye sign in karein.',
    },
    'recorded_automatically': {
      AppLanguage.english: 'Recorded automatically',
      AppLanguage.urdu: 'خودکار طور پر ریکارڈ ہوا',
      AppLanguage.romanUrdu: 'Automatically record hua',
    },
    'user_recorded': {
      AppLanguage.english: 'User-recorded',
      AppLanguage.urdu: 'صارف نے ریکارڈ کیا',
      AppLanguage.romanUrdu: 'User ne record kiya',
    },
    'not_decided_yet': {
      AppLanguage.english: 'Not decided yet',
      AppLanguage.urdu: 'ابھی فیصلہ نہیں ہوا',
      AppLanguage.romanUrdu: 'Abhi decide nahi hua',
    },
    'task_completion_by_day': {
      AppLanguage.english: 'Task completion by day',
      AppLanguage.urdu: 'روزانہ task completion',
      AppLanguage.romanUrdu: 'Rozana task completion',
    },
    'progress_safety_explanation': {
      AppLanguage.english:
          'This is task follow-through only. It is not a medical outcome or clinical-risk score.',
      AppLanguage.urdu:
          'یہ صرف care tasks پر عمل کی پیش رفت ہے۔ یہ طبی نتیجہ یا clinical-risk score نہیں ہے۔',
      AppLanguage.romanUrdu:
          'Yeh sirf care tasks follow karne ki progress hai. Yeh medical outcome ya clinical-risk score nahi hai.',
    },
    'no_task_outcomes_in_range': {
      AppLanguage.english:
          'No task outcomes are recorded in this range yet.',
      AppLanguage.urdu:
          'اس مدت میں ابھی کوئی task outcome ریکارڈ نہیں ہوا۔',
      AppLanguage.romanUrdu:
          'Is range mein abhi koi task outcome record nahi hua.',
    },
    'scheduled': {
      AppLanguage.english: 'Scheduled',
      AppLanguage.urdu: 'مقررہ',
      AppLanguage.romanUrdu: 'Scheduled',
    },
    'on_time': {
      AppLanguage.english: 'On time',
      AppLanguage.urdu: 'وقت پر',
      AppLanguage.romanUrdu: 'Waqt par',
    },
    'late': {
      AppLanguage.english: 'Late',
      AppLanguage.urdu: 'دیر سے',
      AppLanguage.romanUrdu: 'Late',
    },
    'progress_day_label': {
      AppLanguage.english: '{weekday} {day} {month}',
      AppLanguage.urdu: '{weekday} {day} {month}',
      AppLanguage.romanUrdu: '{weekday} {day} {month}',
    },
    'progress_day_outcomes': {
      AppLanguage.english:
          '{completed} completed · {missed} missed · {skipped} skipped',
      AppLanguage.urdu:
          '{completed} مکمل · {missed} رہ گئے · {skipped} چھوڑے گئے',
      AppLanguage.romanUrdu:
          '{completed} complete · {missed} missed · {skipped} skipped',
    },
    'progress_day_outcomes_with_pending': {
      AppLanguage.english:
          '{completed} completed · {missed} missed · {skipped} skipped · {pending} pending',
      AppLanguage.urdu:
          '{completed} مکمل · {missed} رہ گئے · {skipped} چھوڑے گئے · {pending} باقی',
      AppLanguage.romanUrdu:
          '{completed} complete · {missed} missed · {skipped} skipped · {pending} pending',
    },

    // Voice Agent foundation
    'voice_agent': {
      AppLanguage.english: 'SehatMate Voice',
      AppLanguage.urdu: 'صحت میٹ وائس',
      AppLanguage.romanUrdu: 'SehatMate Voice',
    },
    'talk_to_sehatmate': {
      AppLanguage.english: 'Talk to SehatMate',
      AppLanguage.urdu: 'صحت میٹ سے بات کریں',
      AppLanguage.romanUrdu: 'SehatMate se baat karein',
    },
    'listening': {
      AppLanguage.english: 'Listening…',
      AppLanguage.urdu: 'سن رہا ہوں…',
      AppLanguage.romanUrdu: 'Sun raha hoon…',
    },
    'thinking': {
      AppLanguage.english: 'Thinking…',
      AppLanguage.urdu: 'سمجھ رہا ہوں…',
      AppLanguage.romanUrdu: 'Samajh raha hoon…',
    },
    'speaking': {
      AppLanguage.english: 'Speaking…',
      AppLanguage.urdu: 'جواب دے رہا ہوں…',
      AppLanguage.romanUrdu: 'Jawab de raha hoon…',
    },
    'stop_conversation': {
      AppLanguage.english: 'Stop conversation',
      AppLanguage.urdu: 'گفتگو ختم کریں',
      AppLanguage.romanUrdu: 'Baat khatam karein',
    },
    'notification_medicine_reminder_title': {
      AppLanguage.english: 'Medicine reminder',
      AppLanguage.urdu: 'دوا کا ریمائنڈر',
      AppLanguage.romanUrdu: 'Medicine reminder',
    },
    'notification_care_plan_reminder_title': {
      AppLanguage.english: 'Care-plan reminder',
      AppLanguage.urdu: 'نگہداشت منصوبے کا ریمائنڈر',
      AppLanguage.romanUrdu: 'Care-plan reminder',
    },
    'notification_care_reminders_channel': {
      AppLanguage.english: 'Care reminders',
      AppLanguage.urdu: 'نگہداشت ریمائنڈرز',
      AppLanguage.romanUrdu: 'Care reminders',
    },
    'notification_care_reminders_channel_description': {
      AppLanguage.english: 'Confirmed medicine and care-plan reminders',
      AppLanguage.urdu: 'تصدیق شدہ دوا اور نگہداشت منصوبے کے ریمائنڈرز',
      AppLanguage.romanUrdu: 'Confirmed medicine aur care-plan reminders',
    },


  

  // Care Gaps
'care_gap_all': {
  AppLanguage.english: 'All',
  AppLanguage.urdu: 'تمام',
  AppLanguage.romanUrdu: 'Sab',
},

'care_gap_blocking': {
  AppLanguage.english: 'Blocking',
  AppLanguage.urdu: 'رکاوٹ',
  AppLanguage.romanUrdu: 'Blocking',
},

'care_gap_needs_attention': {
  AppLanguage.english: 'Needs attention',
  AppLanguage.urdu: 'توجہ درکار ہے',
  AppLanguage.romanUrdu: 'Tawajjo darkar hai',
},

'care_gap_in_progress': {
  AppLanguage.english: 'In Progress',
  AppLanguage.urdu: 'جاری ہے',
  AppLanguage.romanUrdu: 'Jari hai',
},

'back_to_simulation': {
  AppLanguage.english: 'Back to Simulation',
  AppLanguage.urdu: 'سیمیولیشن پر واپس جائیں',
  AppLanguage.romanUrdu: 'Simulation par wapas jayein',
},

'care_gaps_checking': {
  AppLanguage.english:
      'Checking your care plans for missing or unresolved items.',
  AppLanguage.urdu:
      'آپ کے نگہداشت کے منصوبوں میں نامکمل یا حل طلب چیزیں چیک کی جا رہی ہیں۔',
  AppLanguage.romanUrdu:
      'Aap ke care plans mein missing ya unresolved cheezen check ki ja rahi hain.',
},

'care_gaps_counts': {
  AppLanguage.english:
      '{open} open · {blocking} blocking',
  AppLanguage.urdu:
      '{open} کھلے · {blocking} رکاوٹ والے',
  AppLanguage.romanUrdu:
      '{open} open · {blocking} blocking',
},

'saved': {
  AppLanguage.english: 'Saved',
  AppLanguage.urdu: 'محفوظ ہو گیا',
  AppLanguage.romanUrdu: 'Save ho gaya',
},

'care_gaps_ready_title': {
  AppLanguage.english:
      'Everything currently looks ready',
  AppLanguage.urdu:
      'فی الحال سب کچھ تیار نظر آ رہا ہے',
  AppLanguage.romanUrdu:
      'Filhal sab kuch ready lag raha hai',
},

'care_gaps_empty_filter': {
  AppLanguage.english:
      'No care gaps match this filter right now.',
  AppLanguage.urdu:
      'فی الحال اس فلٹر سے کوئی نگہداشت کی کمی نہیں ملتی۔',
  AppLanguage.romanUrdu:
      'Filhal is filter se koi care gap match nahi karta.',
},

'resolve_blockers_first': {
  AppLanguage.english:
      'Resolve required blockers first',
  AppLanguage.urdu:
      'پہلے ضروری رکاوٹیں حل کریں',
  AppLanguage.romanUrdu:
      'Pehle zaroori blockers resolve karein',
},

'run_final_simulation': {
  AppLanguage.english:
      'Run Final Simulation',
  AppLanguage.urdu:
      'آخری سیمیولیشن چلائیں',
  AppLanguage.romanUrdu:
      'Final Simulation chalayein',
},

'care_gaps_safety_note': {
  AppLanguage.english:
      'Care gaps highlight missing or unresolved care-plan steps. They do not diagnose medical risk or change treatment.',
  AppLanguage.urdu:
      'نگہداشت کی کمیاں نگہداشت کے منصوبے کے نامکمل یا حل طلب مراحل دکھاتی ہیں۔ یہ طبی خطرے کی تشخیص نہیں کرتیں اور علاج میں تبدیلی نہیں کرتیں۔',
  AppLanguage.romanUrdu:
      'Care gaps care plan ke missing ya unresolved steps dikhate hain. Yeh medical risk diagnose nahi karte aur treatment change nahi karte.',
},

'current_issues_by_type': {
  AppLanguage.english:
      'Current issues by type',
  AppLanguage.urdu:
      'قسم کے مطابق موجودہ مسائل',
  AppLanguage.romanUrdu:
      'Type ke mutabiq current issues',
},

'care_gap_group_help': {
  AppLanguage.english:
      'Same-type problems are grouped so you can understand the plan without repeated cards.',
  AppLanguage.urdu:
      'ایک ہی قسم کے مسائل کو ایک ساتھ رکھا گیا ہے تاکہ بار بار کارڈ دکھائے بغیر منصوبہ سمجھنا آسان ہو۔',
  AppLanguage.romanUrdu:
      'Same type ke maslay group kiye gaye hain taa ke repeated cards ke baghair plan samajhna asan ho.',
},

'schedule_issues': {
  AppLanguage.english: 'Schedule issues',
  AppLanguage.urdu: 'شیڈول کے مسائل',
  AppLanguage.romanUrdu: 'Schedule issues',
},

'missing_information': {
  AppLanguage.english: 'Missing information',
  AppLanguage.urdu: 'معلومات نامکمل ہیں',
  AppLanguage.romanUrdu: 'Missing information',
},

'document_issues': {
  AppLanguage.english: 'Document issues',
  AppLanguage.urdu: 'دستاویزات کے مسائل',
  AppLanguage.romanUrdu: 'Document issues',
},

'verification': {
  AppLanguage.english: 'Verification',
  AppLanguage.urdu: 'تصدیق',
  AppLanguage.romanUrdu: 'Verification',
},



'care_coordination': {
  AppLanguage.english: 'Care coordination',
  AppLanguage.urdu: 'نگہداشت میں ہم آہنگی',
  AppLanguage.romanUrdu: 'Care coordination',
},

'care_gap_group_blocking_attention': {
  AppLanguage.english:
      '{blocking} blocking · {attention} attention',
  AppLanguage.urdu:
      '{blocking} رکاوٹ · {attention} توجہ طلب',
  AppLanguage.romanUrdu:
      '{blocking} blocking · {attention} attention',
},

'care_gap_current_issues_count': {
  AppLanguage.english:
      '{count} current issues',
  AppLanguage.urdu:
      '{count} موجودہ مسائل',
  AppLanguage.romanUrdu:
      '{count} current issues',
},

'care_gap_group_chip': {
  AppLanguage.english:
      '{count} {type}',
  AppLanguage.urdu:
      '{count} {type}',
  AppLanguage.romanUrdu:
      '{count} {type}',
},

'care_gap_group_chip_blocking': {
  AppLanguage.english:
      '{count} {type} · {blocking} blocking',
  AppLanguage.urdu:
      '{count} {type} · {blocking} رکاوٹ',
  AppLanguage.romanUrdu:
      '{count} {type} · {blocking} blocking',
},

'care_plan': {
  AppLanguage.english: 'Care Plan',
  AppLanguage.urdu: 'نگہداشت کا منصوبہ',
  AppLanguage.romanUrdu: 'Care Plan',
},

'why': {
  AppLanguage.english: 'Why',
  AppLanguage.urdu: 'وجہ',
  AppLanguage.romanUrdu: 'Wajah',
},

'care_gap_next_step_label': {
  AppLanguage.english: 'Next step',
  AppLanguage.urdu: 'اگلا مرحلہ',
  AppLanguage.romanUrdu: 'Agla step',
},

'demo_care_gaps': {
  AppLanguage.english: 'Demo care gaps',
  AppLanguage.urdu: 'ڈیمو نگہداشت کی کمیاں',
  AppLanguage.romanUrdu: 'Demo care gaps',
},
};
  static String get(
    String key,
    AppLanguage language, {
    Map<String, Object?> values = const {},
  }) {
    var text = _values[key]?[language] ??
        _values[key]?[AppLanguage.english] ??
        key;

    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }

    return text;
  }
}
