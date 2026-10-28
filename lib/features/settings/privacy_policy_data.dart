// Текст политики конфиденциальности с https://uztex.pro/privacy (редакция от
// 27 октября 2026). При изменении на сайте обновите и этот файл.

class PolicyItem {
  /// Жирное начало пункта (может быть пустым).
  final String lead;
  final String text;
  const PolicyItem(this.lead, this.text);
}

class PolicyClause {
  final String icon;
  final String title;
  final List<String> paragraphs;
  final List<PolicyItem> items;

  /// Важное примечание — выводится в выделенном блоке.
  final bool note;
  const PolicyClause({
    required this.icon,
    required this.title,
    this.paragraphs = const [],
    this.items = const [],
    this.note = false,
  });
}

class PolicyDoc {
  final String heroTitle;
  final String heroSub;
  final String updated;
  final String contactCta;
  final List<PolicyClause> clauses;
  const PolicyDoc({
    required this.heroTitle,
    required this.heroSub,
    required this.updated,
    required this.contactCta,
    required this.clauses,
  });
}

const String kPrivacyEmail = 'admin@uztex.uz';

const Map<String, PolicyDoc> kPrivacyPolicy = {
  'ru': PolicyDoc(
    heroTitle: "Политика конфиденциальности",
    heroSub:
        "Коротко и честно: какие данные обрабатывает приложение UztexPro, зачем и как они защищены.",
    updated: "Обновлено: 27 октября 2026",
    contactCta: "Написать нам",
    clauses: [
      PolicyClause(
        icon: "file",
        title: "Введение",
        paragraphs: [
          "UztexPro («мы») предоставляет мобильное приложение UztexPro (далее «Приложение»). Эта политика объясняет, какие данные обрабатывает Приложение, зачем это нужно и как они защищены.",
          "Приложение предназначено исключительно для сотрудников UztexPro. Для входа нужны корпоративные учётные данные, выданные компанией.",
        ],
      ),
      PolicyClause(
        icon: "list",
        title: "Какие данные мы обрабатываем",
        paragraphs: [
          "Приложение обрабатывает только то, что необходимо для его работы:",
        ],
        items: [
          PolicyItem(
            "Данные для входа.",
            " Корпоративный логин и пароль. Они хранятся на устройстве в защищённом хранилище (iOS Keychain / Android Keystore) для входа и биометрической аутентификации. Пароль передаётся по защищённому соединению только на сервер компании для получения токена.",
          ),
          PolicyItem(
            "Токен сессии.",
            " Ключ доступа, который поддерживает ваш вход в приложение.",
          ),
          PolicyItem(
            "Рабочие данные из систем компании.",
            " В зависимости от вашей роли: платежи и договоры, пропуска, заявки на подпись, бонусы, магазин, ваш табель (отработанные часы, время входа и выхода). Сотрудникам с доступом к посещаемости также показывается список людей на территории: ФИО, должность, номер телефона и фотография.",
          ),
          PolicyItem(
            "Локальный кэш.",
            " Копии недавно загруженных списков на устройстве, чтобы данные открывались быстрее.",
          ),
          PolicyItem(
            "Настройки.",
            " Выбранный язык и включена ли биометрия. Хранятся только на устройстве.",
          ),
        ],
      ),
      PolicyClause(
        icon: "ban",
        title: "Что мы не собираем",
        items: [
          PolicyItem("", "Геолокацию."),
          PolicyItem("", "Контакты, фотографии и файлы с устройства."),
          PolicyItem("", "Доступ к камере и микрофону."),
          PolicyItem("", "Рекламные идентификаторы."),
          PolicyItem(
            "",
            "Данные для сторонней аналитики, рекламы или отслеживания. В приложении нет рекламных и аналитических SDK.",
          ),
        ],
      ),
      PolicyClause(
        icon: "sliders",
        title: "Как мы используем данные",
        items: [
          PolicyItem(
            "",
            "Чтобы авторизовать вас и поддерживать вход в приложение.",
          ),
          PolicyItem(
            "",
            "Чтобы показывать рабочие данные из систем компании в соответствии с вашей ролью.",
          ),
          PolicyItem(
            "",
            "Чтобы сохранять настройки и кэш на вашем устройстве.",
          ),
          PolicyItem(
            "",
            "Чтобы проверять наличие обновлений приложения (на Android файл обновления загружается с сервера компании).",
          ),
        ],
      ),
      PolicyClause(
        icon: "sparkles",
        title: "ИИ-ассистент",
        paragraphs: [
          "Функция доступна только пользователям с расширенным доступом. Когда вы задаёте вопрос ассистенту, текст вопроса и данные склада, необходимые для ответа, передаются внешнему поставщику ИИ (OpenAI) для формирования ответа.",
          "Не вводите в чат личную и конфиденциальную информацию. Мы не используем эти данные для рекламы.",
        ],
        note: true,
      ),
      PolicyClause(
        icon: "lock",
        title: "Хранение и безопасность",
        items: [
          PolicyItem(
            "",
            "Данные для входа и токен хранятся в iOS Keychain / Android Keystore.",
          ),
          PolicyItem(
            "",
            "Все запросы идут по защищённому соединению (HTTPS) только на серверы UztexPro.",
          ),
          PolicyItem(
            "",
            "Доступ к данным определяется вашей ролью в системе. Рабочие данные хранятся на серверах компании, а не в приложении.",
          ),
          PolicyItem(
            "",
            "Приложение не отправляет ваш пароль никому, кроме сервера компании.",
          ),
        ],
      ),
      PolicyClause(
        icon: "face",
        title: "Биометрическая аутентификация",
        paragraphs: [
          "Приложение может по желанию использовать Face ID или Touch ID для быстрого входа. Биометрические данные обрабатывает только операционная система, приложение их не получает и не хранит. Мы видим лишь результат проверки: успешно или нет.",
        ],
      ),
      PolicyClause(
        icon: "share",
        title: "Передача третьим лицам",
        paragraphs: [
          "Мы не продаём и не передаём ваши данные третьим лицам в рекламных или аналитических целях. Данные остаются в инфраструктуре UztexPro, за исключением запросов к ИИ-ассистенту (см. раздел «ИИ-ассистент»).",
        ],
      ),
      PolicyClause(
        icon: "database",
        title: "Хранение и удаление данных",
        items: [
          PolicyItem(
            "",
            "Локальные данные приложения удаляются при его удалении с устройства.",
          ),
          PolicyItem(
            "",
            "Рабочие записи хранятся на серверах компании в соответствии с внутренними правилами и законодательством.",
          ),
          PolicyItem(
            "",
            "Учётные записи создаёт и удаляет компания. Чтобы изменить или удалить учётную запись, обратитесь к системному администратору.",
          ),
        ],
      ),
      PolicyClause(
        icon: "userCheck",
        title: "Ваши права",
        paragraphs: [
          "Вы можете запросить доступ к своим данным, их исправление или удаление, обратившись к системному администратору или в поддержку. Мы ответим в разумный срок.",
        ],
      ),
      PolicyClause(
        icon: "smile",
        title: "Конфиденциальность детей",
        paragraphs: [
          "Приложение не предназначено для детей. Оно используется только сотрудниками компании, и мы сознательно не собираем данные детей.",
        ],
      ),
      PolicyClause(
        icon: "refresh",
        title: "Изменения политики",
        paragraphs: [
          "Мы можем обновлять эту политику. Актуальная версия всегда доступна на этой странице с указанием даты обновления. Продолжая пользоваться приложением после изменений, вы принимаете обновлённую политику.",
        ],
      ),
    ],
  ),
  'en': PolicyDoc(
    heroTitle: "Privacy Policy",
    heroSub:
        "Short and honest: what data the UztexPro app processes, why, and how it is protected.",
    updated: "Last updated: October 27, 2026",
    contactCta: "Contact us",
    clauses: [
      PolicyClause(
        icon: "file",
        title: "Introduction",
        paragraphs: [
          "UztexPro (\"we\", \"our\", or \"us\") operates the UztexPro mobile application (the \"App\"). This policy explains what data the App processes, why, and how it is protected.",
          "The App is intended exclusively for UztexPro employees. Signing in requires valid corporate credentials issued by the company.",
        ],
      ),
      PolicyClause(
        icon: "list",
        title: "Information we process",
        paragraphs: ["The App processes only what it needs to work:"],
        items: [
          PolicyItem(
            "Sign-in data.",
            " Your corporate username and password. They are stored on your device in secure storage (iOS Keychain / Android Keystore) to enable sign-in and biometric authentication. The password is sent over a secure connection only to the company server to obtain a token.",
          ),
          PolicyItem(
            "Session token.",
            " An access key that keeps you signed in to the App.",
          ),
          PolicyItem(
            "Work data from company systems.",
            " Depending on your role: payments and contracts, passes, sign requests, bonuses, the shop, your timesheet (worked hours, entry and exit times). Staff with attendance access also see a list of people on site: name, position, phone number and photo.",
          ),
          PolicyItem(
            "Local cache.",
            " Copies of recently loaded lists on your device so data opens faster.",
          ),
          PolicyItem(
            "Preferences.",
            " Your language and whether biometrics are enabled. Stored on the device only.",
          ),
        ],
      ),
      PolicyClause(
        icon: "ban",
        title: "Information we do NOT collect",
        items: [
          PolicyItem("", "Location data."),
          PolicyItem("", "Device contacts, photos or files."),
          PolicyItem("", "Camera or microphone access."),
          PolicyItem("", "Advertising identifiers."),
          PolicyItem(
            "",
            "Data for third-party analytics, advertising or tracking. The App contains no advertising or analytics SDKs.",
          ),
        ],
      ),
      PolicyClause(
        icon: "sliders",
        title: "How we use information",
        items: [
          PolicyItem("", "To authenticate you and keep you signed in."),
          PolicyItem(
            "",
            "To display work data from company systems according to your role.",
          ),
          PolicyItem("", "To save preferences and cache on your device."),
          PolicyItem(
            "",
            "To check for App updates (on Android the update file is downloaded from the company server).",
          ),
        ],
      ),
      PolicyClause(
        icon: "sparkles",
        title: "AI assistant",
        paragraphs: [
          "This feature is available only to users with extended access. When you ask the assistant a question, the text of your question and the warehouse data needed to answer it are sent to an external AI provider (OpenAI) to generate the reply.",
          "Do not enter personal or confidential information in the chat. We do not use this data for advertising.",
        ],
        note: true,
      ),
      PolicyClause(
        icon: "lock",
        title: "Data storage & security",
        items: [
          PolicyItem(
            "",
            "Sign-in data and the session token are stored in the iOS Keychain / Android Keystore.",
          ),
          PolicyItem(
            "",
            "All requests go over a secure connection (HTTPS) and only to UztexPro servers.",
          ),
          PolicyItem(
            "",
            "Access to data depends on your role in the system. Work data is stored on company servers, not in the App.",
          ),
          PolicyItem(
            "",
            "The App does not send your password to anyone except the company server.",
          ),
        ],
      ),
      PolicyClause(
        icon: "face",
        title: "Biometric authentication",
        paragraphs: [
          "The App optionally supports Face ID and Touch ID for quick sign-in. Biometric data is processed entirely by the operating system and is never accessed or stored by the App. We only receive a success or failure result.",
        ],
      ),
      PolicyClause(
        icon: "share",
        title: "Third-party sharing",
        paragraphs: [
          "We do not sell or share your data with third parties for advertising or analytics. Data remains within UztexPro infrastructure, except for requests to the AI assistant (see \"AI assistant\").",
        ],
      ),
      PolicyClause(
        icon: "database",
        title: "Retention & deletion",
        items: [
          PolicyItem(
            "",
            "Local App data is removed when you uninstall the App.",
          ),
          PolicyItem(
            "",
            "Work records are kept on company servers in line with internal rules and applicable law.",
          ),
          PolicyItem(
            "",
            "Accounts are created and removed by the company. To change or delete an account, contact your system administrator.",
          ),
        ],
      ),
      PolicyClause(
        icon: "userCheck",
        title: "Your rights",
        paragraphs: [
          "You can request access to, correction of, or deletion of your data by contacting your system administrator or support. We will respond within a reasonable time.",
        ],
      ),
      PolicyClause(
        icon: "smile",
        title: "Children's privacy",
        paragraphs: [
          "The App is not intended for children. It is used only by company employees, and we do not knowingly collect children's data.",
        ],
      ),
      PolicyClause(
        icon: "refresh",
        title: "Changes to this policy",
        paragraphs: [
          "We may update this policy from time to time. The current version is always available on this page with the update date. Continued use of the App after changes means you accept the revised policy.",
        ],
      ),
    ],
  ),
  'uz': PolicyDoc(
    heroTitle: "Maxfiylik siyosati",
    heroSub:
        "Qisqa va ochiq: UztexPro ilovasi qanday ma'lumotlarni qayta ishlaydi, nima uchun va ular qanday himoyalanadi.",
    updated: "Yangilangan: 2026-yil 27-oktabr",
    contactCta: "Bizga yozing",
    clauses: [
      PolicyClause(
        icon: "file",
        title: "Kirish",
        paragraphs: [
          "UztexPro («biz») UztexPro mobil ilovasini («Ilova») taqdim etadi. Ushbu siyosat Ilova qanday ma'lumotlarni qayta ishlashi, bu nima uchun kerakligi va ular qanday himoyalanishini tushuntiradi.",
          "Ilova faqat UztexPro xodimlari uchun mo'ljallangan. Kirish uchun kompaniya bergan korporativ hisob ma'lumotlari kerak.",
        ],
      ),
      PolicyClause(
        icon: "list",
        title: "Qanday ma'lumotlarni qayta ishlaymiz",
        paragraphs: [
          "Ilova faqat ishlashi uchun zarur bo'lgan ma'lumotlarni qayta ishlaydi:",
        ],
        items: [
          PolicyItem(
            "Kirish ma'lumotlari.",
            " Korporativ login va parol. Ular kirish va biometrik autentifikatsiya uchun qurilmadagi himoyalangan xotirada (iOS Keychain / Android Keystore) saqlanadi. Parol himoyalangan ulanish orqali faqat kompaniya serveriga token olish uchun yuboriladi.",
          ),
          PolicyItem(
            "Sessiya tokeni.",
            " Ilovaga kirishingizni saqlab turuvchi kirish kaliti.",
          ),
          PolicyItem(
            "Kompaniya tizimlaridagi ish ma'lumotlari.",
            " Rolingizga qarab: to'lovlar va shartnomalar, ruxsatnomalar, imzo arizalari, bonuslar, do'kon, tabelingiz (ishlangan soatlar, kirish va chiqish vaqti). Davomatga ruxsati bor xodimlarga hududdagi odamlar ro'yxati ham ko'rsatiladi: F.I.Sh., lavozim, telefon raqami va surat.",
          ),
          PolicyItem(
            "Mahalliy kesh.",
            " Ma'lumotlar tezroq ochilishi uchun qurilmada yaqinda yuklangan ro'yxatlar nusxasi.",
          ),
          PolicyItem(
            "Sozlamalar.",
            " Tanlangan til va biometriya yoqilganligi. Faqat qurilmada saqlanadi.",
          ),
        ],
      ),
      PolicyClause(
        icon: "ban",
        title: "Nimalarni yig'maymiz",
        items: [
          PolicyItem("", "Geolokatsiya."),
          PolicyItem("", "Qurilmadagi kontaktlar, suratlar va fayllar."),
          PolicyItem("", "Kamera va mikrofonga kirish."),
          PolicyItem("", "Reklama identifikatorlari."),
          PolicyItem(
            "",
            "Uchinchi tomon tahlili, reklamasi yoki kuzatuvi uchun ma'lumotlar. Ilovada reklama va tahlil SDK'lari yo'q.",
          ),
        ],
      ),
      PolicyClause(
        icon: "sliders",
        title: "Ma'lumotlardan qanday foydalanamiz",
        items: [
          PolicyItem(
            "",
            "Sizni avtorizatsiya qilish va ilovaga kirishni saqlash uchun.",
          ),
          PolicyItem(
            "",
            "Kompaniya tizimlaridagi ish ma'lumotlarini rolingizga mos ravishda ko'rsatish uchun.",
          ),
          PolicyItem("", "Sozlamalar va keshni qurilmangizda saqlash uchun."),
          PolicyItem(
            "",
            "Ilova yangilanishlarini tekshirish uchun (Android'da yangilanish fayli kompaniya serveridan yuklanadi).",
          ),
        ],
      ),
      PolicyClause(
        icon: "sparkles",
        title: "AI yordamchi",
        paragraphs: [
          "Funksiya faqat kengaytirilgan ruxsati bor foydalanuvchilarga mavjud. Yordamchiga savol berganingizda, savol matni va javob uchun zarur ombor ma'lumotlari javob tayyorlash uchun tashqi AI provayderiga (OpenAI) yuboriladi.",
          "Chatga shaxsiy va maxfiy ma'lumotlarni kiritmang. Biz bu ma'lumotlardan reklama uchun foydalanmaymiz.",
        ],
        note: true,
      ),
      PolicyClause(
        icon: "lock",
        title: "Saqlash va xavfsizlik",
        items: [
          PolicyItem(
            "",
            "Kirish ma'lumotlari va token iOS Keychain / Android Keystore'da saqlanadi.",
          ),
          PolicyItem(
            "",
            "Barcha so'rovlar himoyalangan ulanish (HTTPS) orqali faqat UztexPro serverlariga yuboriladi.",
          ),
          PolicyItem(
            "",
            "Ma'lumotlarga kirish tizimdagi rolingiz bilan belgilanadi. Ish ma'lumotlari ilovada emas, kompaniya serverlarida saqlanadi.",
          ),
          PolicyItem(
            "",
            "Ilova parolingizni kompaniya serveridan boshqa hech kimga yubormaydi.",
          ),
        ],
      ),
      PolicyClause(
        icon: "face",
        title: "Biometrik autentifikatsiya",
        paragraphs: [
          "Ilova xohishingizga ko'ra tez kirish uchun Face ID yoki Touch ID'dan foydalanishi mumkin. Biometrik ma'lumotlarni faqat operatsion tizim qayta ishlaydi, ilova ularni olmaydi va saqlamaydi. Biz faqat tekshiruv natijasini ko'ramiz: muvaffaqiyatli yoki yo'q.",
        ],
      ),
      PolicyClause(
        icon: "share",
        title: "Uchinchi shaxslarga berish",
        paragraphs: [
          "Biz ma'lumotlaringizni sotmaymiz va reklama yoki tahlil maqsadida uchinchi shaxslarga bermaymiz. Ma'lumotlar UztexPro infratuzilmasida qoladi, AI yordamchiga so'rovlar bundan mustasno («AI yordamchi» bo'limiga qarang).",
        ],
      ),
      PolicyClause(
        icon: "database",
        title: "Ma'lumotlarni saqlash va o'chirish",
        items: [
          PolicyItem(
            "",
            "Ilovaning mahalliy ma'lumotlari uni qurilmadan o'chirganingizda o'chiriladi.",
          ),
          PolicyItem(
            "",
            "Ish yozuvlari kompaniya serverlarida ichki qoidalar va qonunchilikka muvofiq saqlanadi.",
          ),
          PolicyItem(
            "",
            "Hisoblarni kompaniya yaratadi va o'chiradi. Hisobni o'zgartirish yoki o'chirish uchun tizim administratoriga murojaat qiling.",
          ),
        ],
      ),
      PolicyClause(
        icon: "userCheck",
        title: "Sizning huquqlaringiz",
        paragraphs: [
          "Tizim administratoriga yoki qo'llab-quvvatlash xizmatiga murojaat qilib, ma'lumotlaringizga kirish, ularni tuzatish yoki o'chirishni so'rashingiz mumkin. Biz o'rinli muddatda javob beramiz.",
        ],
      ),
      PolicyClause(
        icon: "smile",
        title: "Bolalar maxfiyligi",
        paragraphs: [
          "Ilova bolalar uchun mo'ljallanmagan. Undan faqat kompaniya xodimlari foydalanadi va biz bolalar ma'lumotlarini ongli ravishda yig'maymiz.",
        ],
      ),
      PolicyClause(
        icon: "refresh",
        title: "Siyosatdagi o'zgarishlar",
        paragraphs: [
          "Biz ushbu siyosatni yangilashimiz mumkin. Joriy versiya doim shu sahifada yangilanish sanasi bilan mavjud. O'zgarishlardan keyin ilovadan foydalanishni davom ettirsangiz, yangilangan siyosatni qabul qilgan hisoblanasiz.",
        ],
      ),
    ],
  ),
};
