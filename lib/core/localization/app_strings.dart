import 'locale_notifier.dart';

class S {
  final String _lang;

  const S._(this._lang);

  static S of(context) => S._(localeNotifier.value.languageCode);

  String _t(Map<String, String> m) => m[_lang] ?? m['ru']!;

  // Common
  String get cancel =>
      _t({'ru': 'ОТМЕНА', 'en': 'CANCEL', 'uz': 'BEKOR QILISH'});

  String get save => _t({'ru': 'СОХРАНИТЬ', 'en': 'SAVE', 'uz': 'SAQLASH'});

  String get close => _t({'ru': 'ЗАКРЫТЬ', 'en': 'CLOSE', 'uz': 'YOPISH'});

  String get confirm =>
      _t({'ru': 'ПОДТВЕРДИТЬ', 'en': 'CONFIRM', 'uz': 'TASDIQLASH'});

  String get noData =>
      _t({'ru': 'Нет данных', 'en': 'No data', 'uz': "Ma'lumot yo'q"});

  String get paymentSystem => _t({
    'ru': 'Производственная платформа',
    'en': 'Production platform',
    'uz': "Ishlab chiqarish platformasi",
  });

  // Menu Page
  String get menuPayments =>
      _t({'ru': 'Платежи', 'en': 'Payments', 'uz': "To'lovlar"});

  String get menuPaymentsDesc => _t({
    'ru': 'Платежные договоры',
    'en': 'Payment agreements',
    'uz': "To'lov shartnomalari",
  });

  String get menuPasses =>
      _t({'ru': 'Пропуски', 'en': 'Passes', 'uz': 'Ruxsatnomalar'});

  String get menuPassesDesc => _t({
    'ru': 'Управление пропусками',
    'en': 'Manage passes',
    'uz': 'Ruxsatnomalarni boshqarish',
  });

  String get menuSignRequests => _t({
    'ru': 'Подпись заявок',
    'en': 'Sign Requests',
    'uz': 'Arizalarni imzolash',
  });

  String get menuSignRequestsDesc => _t({
    'ru': 'Подпись и согласование заявок',
    'en': 'Sign and approve requests',
    'uz': "Arizalarni imzolash va tasdiqlash",
  });

  String get menuBonuses =>
      _t({'ru': 'Премии', 'en': 'Bonuses', 'uz': 'Mukofotlar'});

  String get menuBonusesDesc => _t({
    'ru': 'Утверждение премий',
    'en': 'Bonus approval',
    'uz': 'Mukofotlarni tasdiqlash',
  });

  // Sign Requests Page
  String get signRequestsTitle => _t({
    'ru': 'Подпись заявок',
    'en': 'Sign Requests',
    'uz': 'Arizalarni imzolash',
  });

  String get signRequestsEmpty => _t({
    'ru': 'Нет заявок для подписи',
    'en': 'No requests to sign',
    'uz': 'Imzolash uchun arizalar yo\'q',
  });

  String get signRequestsEmptyDesc => _t({
    'ru': 'Все заявки обработаны',
    'en': 'All requests have been processed',
    'uz': 'Barcha arizalar ko\'rib chiqildi',
  });

  String get requestNumber =>
      _t({'ru': 'Заявка №', 'en': 'Request #', 'uz': 'Ariza №'});

  String get requestDate => _t({'ru': 'Дата', 'en': 'Date', 'uz': 'Sana'});

  String get requestAmount =>
      _t({'ru': 'Сумма', 'en': 'Amount', 'uz': 'Summa'});

  String get requestApplicant =>
      _t({'ru': 'Заявитель', 'en': 'Applicant', 'uz': 'Ariza beruvchi'});

  String get requestDepartment =>
      _t({'ru': 'Отдел', 'en': 'Department', 'uz': "Bo'lim"});

  String get approve =>
      _t({'ru': 'Подписать', 'en': 'Approve', 'uz': 'Imzolash'});

  String get reject =>
      _t({'ru': 'Отклонить', 'en': 'Reject', 'uz': 'Rad etish'});

  String get approveConfirmTitle => _t({
    'ru': 'Подтверждение подписи',
    'en': 'Confirm Signature',
    'uz': 'Imzoni tasdiqlash',
  });

  String get approveConfirmDesc => _t({
    'ru': 'Вы уверены, что хотите подписать эту заявку?',
    'en': 'Are you sure you want to approve this request?',
    'uz': 'Bu arizani imzolashni xohlaysizmi?',
  });

  String get rejectConfirmTitle => _t({
    'ru': 'Отклонение заявки',
    'en': 'Reject Request',
    'uz': 'Arizani rad etish',
  });

  String get rejectConfirmDesc => _t({
    'ru': 'Вы уверены, что хотите отклонить эту заявку?',
    'en': 'Are you sure you want to reject this request?',
    'uz': 'Bu arizani rad etishni xohlaysizmi?',
  });

  String get rejectReason => _t({
    'ru': 'Причина отклонения',
    'en': 'Rejection reason',
    'uz': 'Rad etish sababi',
  });

  String get enterRejectReason => _t({
    'ru': 'Введите причину отклонения...',
    'en': 'Enter rejection reason...',
    'uz': 'Rad etish sababini kiriting...',
  });

  String get approved =>
      _t({'ru': 'Подписано', 'en': 'Approved', 'uz': 'Imzolandi'});

  String get rejected =>
      _t({'ru': 'Отклонено', 'en': 'Rejected', 'uz': 'Rad etildi'});

  String get pending =>
      _t({'ru': 'Ожидает', 'en': 'Pending', 'uz': 'Kutilmoqda'});

  String get approveSuccess => _t({
    'ru': 'Заявка успешно подписана',
    'en': 'Request successfully approved',
    'uz': 'Ariza muvaffaqiyatli imzolandi',
  });

  String get rejectSuccess => _t({
    'ru': 'Заявка отклонена',
    'en': 'Request rejected',
    'uz': 'Ariza rad etildi',
  });

  String get signError => _t({
    'ru': 'Ошибка при обработке заявки',
    'en': 'Error processing request',
    'uz': 'Arizani qayta ishlashda xato',
  });

  String get filterAll => _t({'ru': 'Все', 'en': 'All', 'uz': 'Barchasi'});

  String get filterPending =>
      _t({'ru': 'Ожидают', 'en': 'Pending', 'uz': 'Kutilmoqda'});

  String get filterApproved =>
      _t({'ru': 'Подписаны', 'en': 'Approved', 'uz': 'Imzolangan'});

  String get filterRejected =>
      _t({'ru': 'Отклонены', 'en': 'Rejected', 'uz': 'Rad etilgan'});

  String get signAll =>
      _t({'ru': 'Подписать все', 'en': 'Sign all', 'uz': 'Hammasini imzolash'});

  String get rejectAll => _t({
    'ru': 'Отклонить все',
    'en': 'Reject all',
    'uz': 'Hammasini rad etish',
  });

  String get materials =>
      _t({'ru': 'Материалы', 'en': 'Materials', 'uz': 'Materiallar'});

  String get inDevelopment => _t({
    'ru': 'Раздел в разработке',
    'en': 'Under development',
    'uz': 'Ishlab chiqilmoqda',
  });

  String get inDevelopmentDesc => _t({
    'ru':
        'Этот раздел находится в разработке и будет доступен в ближайшее время.',
    'en': 'This section is under development and will be available soon.',
    'uz': "Bu bo'lim ishlab chiqilmoqda va yaqin orada mavjud bo'ladi.",
  });

  String get comingSoon => _t({
    'ru': 'Скоро будет доступно',
    'en': 'Coming soon',
    'uz': 'Tez orada',
  });

  // Login
  String get enterUztexpro => _t({
    'ru': 'Вход в UZTEXPRO',
    'en': 'Sign in to UZTEXPRO',
    'uz': 'UZTEXPRO ga kirish',
  });

  String get pleaseWait => _t({
    'ru': 'Пожалуйста, подождите...',
    'en': 'Please wait...',
    'uz': 'Iltimos, kuting...',
  });

  String get welcome =>
      _t({'ru': 'Добро пожаловать', 'en': 'Welcome', 'uz': 'Xush kelibsiz'});

  String get signInAccount => _t({
    'ru': 'Войдите в свой аккаунт',
    'en': 'Sign in to your account',
    'uz': 'Hisobingizga kiring',
  });

  String get loginField => _t({'ru': 'Логин', 'en': 'Login', 'uz': 'Login'});

  String get passwordField =>
      _t({'ru': 'Пароль', 'en': 'Password', 'uz': 'Parol'});

  String get signIn => _t({'ru': 'ВОЙТИ', 'en': 'SIGN IN', 'uz': 'KIRISH'});

  String get biometricAuth => _t({
    'ru': 'Биометрическая аутентификация',
    'en': 'Biometric authentication',
    'uz': 'Biometrik autentifikatsiya',
  });

  String get useFingerprint => _t({
    'ru': 'Использовать отпечаток пальца для входа',
    'en': 'Use fingerprint to sign in',
    'uz': 'Kirish uchun barmoq izidan foydalaning',
  });

  String get signInBiometric => _t({
    'ru': 'ВОЙТИ С БИОМЕТРИЕЙ',
    'en': 'SIGN IN WITH BIOMETRICS',
    'uz': 'BIOMETRIYA BILAN KIRISH',
  });

  String get enterLoginPassword => _t({
    'ru': 'Введите логин и пароль',
    'en': 'Enter login and password',
    'uz': 'Login va parol kiriting',
  });

  String get wrongCredentials => _t({
    'ru': 'Неверный логин или пароль',
    'en': 'Incorrect login or password',
    'uz': "Noto'g'ri login yoki parol",
  });

  String get connectionError => _t({
    'ru': 'Ошибка подключения. Проверьте интернет.',
    'en': 'Connection error. Check internet.',
    'uz': 'Ulanish xatosi. Internetni tekshiring.',
  });

  String get biometricNotSupported => _t({
    'ru': 'Биометрия не поддерживается на этом устройстве',
    'en': 'Biometrics not supported on this device',
    'uz': "Bu qurilmada biometriya qo'llab-quvvatlanmaydi",
  });

  String get loginError => _t({
    'ru': 'Ошибка входа. Проверьте учетные данные или подключение.',
    'en': 'Login error. Check credentials or connection.',
    'uz': 'Kirish xatosi. Hisobni yoki ulanishni tekshiring.',
  });

  String get credentialsNotFound => _t({
    'ru': 'Учетные данные не найдены. Войдите вручную.',
    'en': 'Credentials not found. Sign in manually.',
    'uz': "Hisob ma'lumotlari topilmadi. Qo'lda kiring.",
  });

  // Main Page
  String get paymentAgreements => _t({
    'ru': 'Платежные договоры',
    'en': 'Payment agreements',
    'uz': "To'lov shartnomalari",
  });

  String get settingsTooltip =>
      _t({'ru': 'Настройки', 'en': 'Settings', 'uz': 'Sozlamalar'});

  String get exitTooltip => _t({'ru': 'Выйти', 'en': 'Exit', 'uz': 'Chiqish'});

  String get noContracts => _t({
    'ru': 'Нет доступных платежных договоров',
    'en': 'No payment agreements available',
    'uz': "Mavjud to'lov shartnomasi yo'q",
  });

  String get refresh =>
      _t({'ru': 'Обновить', 'en': 'Refresh', 'uz': 'Yangilash'});

  String get contract =>
      _t({'ru': 'Договор', 'en': 'Contract', 'uz': 'Shartnoma'});

  String get subject => _t({'ru': 'Предмет', 'en': 'Subject', 'uz': 'Mavzu'});

  String get applicant =>
      _t({'ru': 'Заявитель', 'en': 'Applicant', 'uz': 'Ariza beruvchi'});

  String get paymentType =>
      _t({'ru': 'Тип оплаты', 'en': 'Payment type', 'uz': "To'lov turi"});

  String get contractAmount => _t({
    'ru': 'Сумма договора',
    'en': 'Contract amount',
    'uz': 'Shartnoma summasi',
  });

  String get toPay =>
      _t({'ru': 'К оплате', 'en': 'To pay', 'uz': "To'lash uchun"});

  String get currency =>
      _t({'ru': 'Валюта', 'en': 'Currency', 'uz': 'Valyuta'});

  String get statusLabel =>
      _t({'ru': 'Статус', 'en': 'Status', 'uz': 'Status'});

  String get available =>
      _t({'ru': 'Доступно', 'en': 'Available', 'uz': 'Mavjud'});

  String get tapToChangeStatus => _t({
    'ru': 'Нажмите для изменения статуса',
    'en': 'Tap to change status',
    'uz': "Statusni o'zgartirish uchun bosing",
  });

  String get unnamed =>
      _t({'ru': 'Без названия', 'en': 'Unnamed', 'uz': 'Nomsiz'});

  String get notSpecified =>
      _t({'ru': 'Не указан', 'en': 'Not specified', 'uz': "Ko'rsatilmagan"});

  String get logOut =>
      _t({'ru': 'Выход из системы', 'en': 'Log out', 'uz': 'Tizimdan chiqish'});

  String get logOutConfirm => _t({
    'ru': 'Вы уверены, что хотите выйти из учетной записи?',
    'en': 'Are you sure you want to log out?',
    'uz': 'Hisobingizdan chiqishni xohlaysizmi?',
  });

  String get logOutBtn => _t({'ru': 'ВЫЙТИ', 'en': 'LOG OUT', 'uz': 'CHIQISH'});

  String get changeStatus => _t({
    'ru': 'Изменение статуса',
    'en': 'Change status',
    'uz': "Statusni o'zgartirish",
  });

  String get confirmAction => _t({
    'ru': 'Подтверждение действия',
    'en': 'Confirm action',
    'uz': 'Amalni tasdiqlash',
  });

  String get changePaymentStatusTo => _t({
    'ru': 'Изменить статус платежа на:',
    'en': 'Change payment status to:',
    'uz': "To'lov statusini o'zgartirish:",
  });

  String get noteColon =>
      _t({'ru': 'Примечание:', 'en': 'Note:', 'uz': 'Izoh:'});

  String get partialAmountColon => _t({
    'ru': 'Сумма частичной оплаты:',
    'en': 'Partial payment amount:',
    'uz': "Qisman to'lov miqdori:",
  });

  String get paymentStatus => _t({
    'ru': 'Статус платежа',
    'en': 'Payment status',
    'uz': "To'lov holati",
  });

  String get selectPaymentStatus => _t({
    'ru': 'Выберите статус платежа',
    'en': 'Select payment status',
    'uz': "To'lov statusini tanlang",
  });

  String get partialAmountLabel => _t({
    'ru': 'Сумма частичной оплаты',
    'en': 'Partial payment amount',
    'uz': "Qisman to'lov miqdori",
  });

  String get enterAmount => _t({
    'ru': 'Введите сумму',
    'en': 'Enter amount',
    'uz': 'Summani kiriting',
  });

  String get noteLabel => _t({'ru': 'Примечание', 'en': 'Note', 'uz': 'Izoh'});

  String get addComment => _t({
    'ru': 'Добавьте комментарий...',
    'en': 'Add comment...',
    'uz': "Izoh qo'shing...",
  });

  String get contractColon =>
      _t({'ru': 'Договор:', 'en': 'Contract:', 'uz': 'Shartnoma:'});

  String get subjectColon =>
      _t({'ru': 'Предмет:', 'en': 'Subject:', 'uz': 'Mavzu:'});

  String get amountColon =>
      _t({'ru': 'Сумма:', 'en': 'Amount:', 'uz': 'Summa:'});

  String get updating => _t({
    'ru': 'Обновление...',
    'en': 'Updating...',
    'uz': 'Yangilanmoqda...',
  });

  String get noPermission => _t({
    'ru': 'У вас нет прав на изменение статуса',
    'en': "You don't have permission to change status",
    'uz': "Statusni o'zgartirish huquqingiz yo'q",
  });

  String get selectStatusFirst => _t({
    'ru': 'Пожалуйста, выберите статус',
    'en': 'Please select a status',
    'uz': 'Iltimos, statusni tanlang',
  });

  String get loadStatusError => _t({
    'ru': 'Ошибка при загрузке статусов',
    'en': 'Error loading statuses',
    'uz': 'Statuslarni yuklashda xato',
  });

  String get loadDataError => _t({
    'ru': 'Ошибка при загрузке данных',
    'en': 'Error loading data',
    'uz': "Ma'lumotlarni yuklashda xato",
  });

  String get fileOpenError => _t({
    'ru': 'Не удалось открыть файл',
    'en': 'Could not open file',
    'uz': "Faylni ochib bo'lmadi",
  });

  String get urlCopied => _t({
    'ru': 'URL скопирован в буфер обмена',
    'en': 'URL copied to clipboard',
    'uz': 'URL nusxalandi',
  });

  String get fileError => _t({
    'ru': 'Ошибка при открытии файла',
    'en': 'Error opening file',
    'uz': 'Faylni ochishda xato',
  });

  String get urlCopiedShort =>
      _t({'ru': 'URL скопирован', 'en': 'URL copied', 'uz': 'URL nusxalandi'});

  String get statusUpdated => _t({
    'ru': 'Статус платежа успешно обновлен',
    'en': 'Payment status successfully updated',
    'uz': "To'lov holati muvaffaqiyatli yangilandi",
  });

  String get updateError => _t({
    'ru': 'Ошибка при обновлении',
    'en': 'Update error',
    'uz': 'Yangilashda xato',
  });

  // Settings
  String get settingsTitle =>
      _t({'ru': 'Настройки', 'en': 'Settings', 'uz': 'Sozlamalar'});

  String get aboutApp =>
      _t({'ru': 'О приложении', 'en': 'About', 'uz': 'Ilova haqida'});

  String get generalSettings => _t({
    'ru': 'Основные настройки',
    'en': 'General settings',
    'uz': 'Asosiy sozlamalar',
  });

  String get security =>
      _t({'ru': 'Безопасность', 'en': 'Security', 'uz': 'Xavfsizlik'});

  String get securityDesc => _t({
    'ru': 'Настройки безопасности и конфиденциальности',
    'en': 'Security and privacy settings',
    'uz': 'Xavfsizlik va maxfiylik sozlamalari',
  });

  String get language => _t({'ru': 'Язык', 'en': 'Language', 'uz': 'Til'});

  String get languageDesc => _t({
    'ru': 'Выбор языка интерфейса приложения',
    'en': 'Select app interface language',
    'uz': 'Ilova interfeysi tilini tanlang',
  });

  String get appearance =>
      _t({'ru': 'Внешний вид', 'en': 'Appearance', 'uz': "Ko'rinish"});

  String get theme => _t({'ru': 'Тема', 'en': 'Theme', 'uz': 'Mavzu'});

  String get darkTheme =>
      _t({'ru': 'Тёмная тема', 'en': 'Dark theme', 'uz': 'Qora mavzu'});

  String get lightTheme =>
      _t({'ru': 'Светлая тема', 'en': 'Light theme', 'uz': 'Ochiq mavzu'});

  String appVersionLabel(String version) => _t({
    'ru': 'Версия приложения: $version',
    'en': 'App version: $version',
    'uz': 'Ilova versiyasi: $version',
  });

  String get selectLanguage =>
      _t({'ru': 'Выбор языка', 'en': 'Select language', 'uz': 'Tilni tanlang'});

  String versionLabel(String version) =>
      _t({'ru': 'Версия $version', 'en': 'Version $version', 'uz': 'Versiya $version'});

  String get allRightsReserved => _t({
    'ru':
        'Все права защищены. Приложение предназначено для управления платежными договорами.',
    'en':
        'All rights reserved. The application is designed for managing payment agreements.',
    'uz':
        "Barcha huquqlar himoyalangan. Ilova to'lov shartnomalari boshqarish uchun mo'ljallangan.",
  });

  // Confidentiality
  String get privacyTitle =>
      _t({'ru': 'Конфиденциальность', 'en': 'Privacy', 'uz': 'Maxfiylik'});

  String get privacySettings => _t({
    'ru': 'Настройки конфиденциальности',
    'en': 'Privacy settings',
    'uz': 'Maxfiylik sozlamalari',
  });

  String get useBiometric => _t({
    'ru': 'Использовать биометрическую аутентификацию',
    'en': 'Use biometric authentication',
    'uz': 'Biometrik autentifikatsiyadan foydalaning',
  });

  String get biometricRequired => _t({
    'ru':
        'Пожалуйста, пройдите биометрическую аутентификацию для доступа к настройкам конфиденциальности.',
    'en':
        'Please complete biometric authentication to access privacy settings.',
    'uz':
        'Maxfiylik sozlamalariga kirish uchun biometrik autentifikatsiyani bajaring.',
  });

  String get authenticate => _t({
    'ru': 'Аутентификация',
    'en': 'Authenticate',
    'uz': 'Autentifikatsiya',
  });

  String get authReason => _t({
    'ru': 'Используйте биометрию для доступа к настройкам конфиденциальности',
    'en': 'Use biometrics to access privacy settings',
    'uz': 'Maxfiylik sozlamalariga kirish uchun biometriyadan foydalaning',
  });

  String get authLoginReason => _t({
    'ru': 'Используйте биометрию для входа в приложение',
    'en': 'Use biometrics to sign in to the app',
    'uz': 'Ilovaga kirish uchun biometriyadan foydalaning',
  });

  // Bonuses Page
  String get bonusesTitle =>
      _t({'ru': 'Премии', 'en': 'Bonuses', 'uz': 'Mukofotlar'});

  String get bonusesEmpty => _t({
    'ru': 'Список премий пуст',
    'en': 'Bonus list is empty',
    'uz': "Mukofotlar ro'yxati bo'sh",
  });

  String get bonusNumber =>
      _t({'ru': 'Премия №', 'en': 'Bonus #', 'uz': 'Mukofot №'});

  String get recordsCount =>
      _t({'ru': 'Записей', 'en': 'Records', 'uz': 'Yozuvlar'});

  String get factoryLabel =>
      _t({'ru': 'Фабрика', 'en': 'Factory', 'uz': 'Fabrika'});

  String get monthLabel => _t({'ru': 'Месяц', 'en': 'Month', 'uz': 'Oy'});

  String get createdByLabel =>
      _t({'ru': 'Создал', 'en': 'Created by', 'uz': 'Yaratdi'});

  String get dateLabel => _t({'ru': 'Дата', 'en': 'Date', 'uz': 'Sana'});

  String get totalLabel => _t({'ru': 'Итого', 'en': 'Total', 'uz': 'Jami'});

  String get approvedByLabel =>
      _t({'ru': 'Согласовал', 'en': 'Approved by', 'uz': 'Kelishdi'});

  String get confirmedByLabel =>
      _t({'ru': 'Утвердил', 'en': 'Confirmed by', 'uz': 'Tasdiqladi'});

  String get bonusApproveTitle => _t({
    'ru': 'Утверждение премии',
    'en': 'Approve Bonus',
    'uz': 'Mukofotni tasdiqlash',
  });

  String get bonusApproveDesc => _t({
    'ru': 'Вы уверены, что хотите утвердить эту премию?',
    'en': 'Are you sure you want to approve this bonus?',
    'uz': 'Bu mukofotni tasdiqlamoqchimisiz?',
  });

  String get bonusApproveBtn =>
      _t({'ru': 'Утвердить', 'en': 'Approve', 'uz': 'Tasdiqlash'});

  String get bonusApproveSuccess => _t({
    'ru': 'Премия успешно утверждена',
    'en': 'Bonus successfully approved',
    'uz': 'Mukofot muvaffaqiyatli tasdiqlandi',
  });

  String get bonusDeleteTitle => _t({
    'ru': 'Удаление премии',
    'en': 'Delete Bonus',
    'uz': "Mukofotni o'chirish",
  });

  String get bonusDeleteDesc => _t({
    'ru': 'Вы уверены, что хотите удалить эту запись?',
    'en': 'Are you sure you want to delete this record?',
    'uz': "Bu yozuvni o'chirmoqchimisiz?",
  });

  String get deleteBtn =>
      _t({'ru': 'Удалить', 'en': 'Delete', 'uz': "O'chirish"});

  String get bonusDeleteSuccess => _t({
    'ru': 'Запись удалена',
    'en': 'Record deleted',
    'uz': "Yozuv o'chirildi",
  });

  String get timeoutError => _t({
    'ru': 'Превышено время ожидания. Попробуйте ещё раз.',
    'en': 'Request timed out. Please try again.',
    'uz': "Kutish vaqti tugadi. Qayta urinib ko'ring.",
  });

  // Passes Page
  String get passSearchHint => _t({
    'ru': 'Номер или клиент',
    'en': 'Number or client',
    'uz': 'Raqam yoki mijoz',
  });

  String get passViewMy => _t({'ru': 'Мои', 'en': 'Mine', 'uz': 'Mening'});

  String get passViewAll => _t({'ru': 'Все', 'en': 'All', 'uz': 'Barchasi'});

  String get passesEmpty => _t({
    'ru': 'Нет пропусков',
    'en': 'No passes',
    'uz': "Ruxsatnomalar yo'q",
  });

  String get passesEmptyDesc => _t({
    'ru': 'Список пропусков пуст',
    'en': 'The passes list is empty',
    'uz': "Ruxsatnomalar ro'yxati bo'sh",
  });

  // Payment Page Search & Filter
  String get paymentSearchHint => _t({
    'ru': 'Поиск по ID',
    'en': 'Search by ID',
    'uz': 'ID bo\'yicha qidirish',
  });

  String get paymentNoResults => _t({
    'ru': 'По запросу ничего не найдено',
    'en': 'Nothing found for your query',
    'uz': "So'rov bo'yicha hech narsa topilmadi",
  });

  String get paymentResetFilters => _t({
    'ru': 'Сбросить фильтры',
    'en': 'Reset filters',
    'uz': "Filtrlarni tozalash",
  });
}
