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

  String get menuProductModels => _t({
    'ru': 'Подтверждение моделей',
    'en': 'Model Confirmation',
    'uz': 'Modellarni tasdiqlash',
  });

  String get menuProductModelsDesc => _t({
    'ru': 'Подтверждение цен моделей',
    'en': 'Confirm model prices',
    'uz': 'Model narxlarini tasdiqlash',
  });

  // Dashboard
  String get dashboardOverview => _t({
    'ru': 'Обзор производства',
    'en': 'Production overview',
    'uz': "Ishlab chiqarish sharhi",
  });

  String get dashboardInTerritory =>
      _t({'ru': 'На территории', 'en': 'On-site', 'uz': 'Hududda'});

  String get attendanceTitle =>
      _t({'ru': 'Посещаемость', 'en': 'Attendance', 'uz': 'Davomat'});
  String get attendanceCameToday =>
      _t({'ru': 'Пришли сегодня', 'en': 'Came today', 'uz': 'Bugun kelganlar'});
  String get attendanceSearchHint => _t({
    'ru': 'Поиск по ФИО',
    'en': 'Search by name',
    'uz': 'FIO bo\'yicha qidirish',
  });
  String get attendanceAllFactories => _t({
    'ru': 'Все фабрики',
    'en': 'All factories',
    'uz': 'Barcha fabrikalar',
  });
  String get attendanceEmpty =>
      _t({'ru': 'Никого нет', 'en': 'Nobody here', 'uz': 'Hech kim yo\'q'});
  String get attendanceTotalEmployees => _t({
    'ru': 'Всего сотрудников',
    'en': 'Total employees',
    'uz': 'Jami xodimlar',
  });
  String get attendanceNoAccess => _t({
    'ru': 'Недостаточно прав',
    'en': 'Access denied',
    'uz': 'Ruxsat yo\'q',
  });
  String get attendanceFilterFactory =>
      _t({'ru': 'Фабрика', 'en': 'Factory', 'uz': 'Fabrika'});
  String get attendanceStatusOut => _t({
    'ru': 'Вне территории',
    'en': 'Off-site',
    'uz': 'Hududdan tashqarida',
  });
  String get attendanceFirstIn =>
      _t({'ru': 'Первый вход', 'en': 'First entry', 'uz': 'Birinchi kirish'});
  String get attendanceLastMark => _t({
    'ru': 'Последняя отметка',
    'en': 'Last check-in',
    'uz': 'Oxirgi belgi',
  });
  String get attendanceTabel =>
      _t({'ru': 'Табель №', 'en': 'Employee no.', 'uz': 'Tabel №'});
  String get attendancePhone =>
      _t({'ru': 'Телефон', 'en': 'Phone', 'uz': 'Telefon'});
  String get attendanceHired =>
      _t({'ru': 'Дата приёма', 'en': 'Hired on', 'uz': 'Qabul sanasi'});
  String get attendanceDepartment =>
      _t({'ru': 'Отдел', 'en': 'Department', 'uz': "Bo'lim"});
  String get attendancePosition =>
      _t({'ru': 'Должность', 'en': 'Position', 'uz': 'Lavozim'});
  String get attendanceLoadError => _t({
    'ru': 'Не удалось загрузить данные',
    'en': 'Failed to load data',
    'uz': "Ma'lumotlarni yuklab bo'lmadi",
  });

  String dashboardOutOf(int total) => _t({
    'ru': 'из $total чел.',
    'en': 'out of $total',
    'uz': "$total kishidan",
  });

  String get dashboardProductionYesterday => _t({
    'ru': 'Производство вчера',
    'en': 'Production yesterday',
    'uz': 'Kechagi ishlab chiqarish',
  });

  String get dashboardProductionShort =>
      _t({'ru': 'Произв.', 'en': 'Prod.', 'uz': 'Ishlab chiq.'});

  String get dashboardReportDate =>
      _t({'ru': 'Дата отчёта', 'en': 'Report date', 'uz': 'Hisobot sanasi'});

  String get dashboardProductionIndicators => _t({
    'ru': 'Производственные показатели',
    'en': 'Production indicators',
    'uz': "Ishlab chiqarish ko'rsatkichlari",
  });

  String get dashboardFactoriesDetail =>
      _t({'ru': 'Филиалы', 'en': 'Factories', 'uz': 'Filiallar'});

  String get dashboardPlan => _t({'ru': 'План', 'en': 'Plan', 'uz': 'Reja'});

  String get dashboardFact => _t({'ru': 'Факт', 'en': 'Fact', 'uz': 'Fakt'});

  String get dashboardFactoryTotal =>
      _t({'ru': 'Всего', 'en': 'Total', 'uz': 'Jami'});

  String get dashboardEntered =>
      _t({'ru': 'Вошли', 'en': 'Entered', 'uz': 'Kirdi'});

  // Bottom navigation
  String get navHome => _t({'ru': 'Главная', 'en': 'Home', 'uz': 'Asosiy'});

  String get navConfirmations =>
      _t({'ru': 'Подтверждения', 'en': 'Confirmations', 'uz': 'Tasdiqlashlar'});

  String get navProduction =>
      _t({'ru': 'Производство', 'en': 'Production', 'uz': "Ishlab chiqarish"});

  String get navShop => _t({'ru': 'Магазин', 'en': 'Shop', 'uz': "Do'kon"});

  String get navSettings =>
      _t({'ru': 'Настройки', 'en': 'Settings', 'uz': 'Sozlamalar'});

  // Shop (PVZ order pickup — view only, handover happens on the ПВЗ terminal)
  String get shopPickupTitle => _t({
    'ru': 'Заказы на выдачу',
    'en': 'Orders awaiting pickup',
    'uz': 'Topshirishni kutayotgan buyurtmalar',
  });

  String get shopPickupDesc => _t({
    'ru': 'Заказы, ожидающие выдачи в вашем магазине',
    'en': 'Orders waiting for pickup at your shop',
    'uz': "Do'koningizda topshirishni kutayotgan buyurtmalar",
  });

  String get shopPickupSearchHint => _t({
    'ru': 'Поиск по № заказа или покупателю',
    'en': 'Search by order № or buyer',
    'uz': "Buyurtma raqami yoki xaridor bo'yicha qidirish",
  });

  String get shopPickupEmpty => _t({
    'ru': 'Нет заказов, ожидающих выдачи',
    'en': 'No orders waiting for pickup',
    'uz': "Topshirishni kutayotgan buyurtmalar yo'q",
  });

  String get shopPickupPositions =>
      _t({'ru': 'поз.', 'en': 'items', 'uz': 'band'});

  String get shopPickupSeller =>
      _t({'ru': 'Продавец', 'en': 'Seller', 'uz': 'Sotuvchi'});

  String get shopPickupBuyer =>
      _t({'ru': 'Покупатель', 'en': 'Buyer', 'uz': 'Xaridor'});

  String shopPickupOrderTitle(int id) =>
      _t({'ru': 'Заказ №$id', 'en': 'Order №$id', 'uz': 'Buyurtma №$id'});

  String get shopPickupItemsHeader =>
      _t({'ru': 'Товары', 'en': 'Items', 'uz': 'Tovarlar'});

  String get shopPickupTotalLabel =>
      _t({'ru': 'Общая сумма', 'en': 'Total amount', 'uz': 'Umumiy summa'});

  String get shopPickupSalaryLabel => _t({
    'ru': 'Зарплата продавца',
    'en': "Seller's salary",
    'uz': 'Sotuvchi maoshi',
  });

  String get shopIssuedTitle => _t({
    'ru': 'Выданные заказы',
    'en': 'Issued orders',
    'uz': 'Topshirilgan buyurtmalar',
  });

  String get shopIssuedDesc => _t({
    'ru': 'Отчёт по выданным заказам за период',
    'en': 'Report on orders issued over a period',
    'uz': "Davr bo'yicha topshirilgan buyurtmalar hisoboti",
  });

  String get shopIssuedAllShops =>
      _t({'ru': 'Все магазины', 'en': 'All shops', 'uz': "Barcha do'konlar"});

  String get shopIssuedEmpty => _t({
    'ru': 'Нет выданных заказов за этот период',
    'en': 'No issued orders for this period',
    'uz': "Ushbu davr uchun topshirilgan buyurtmalar yo'q",
  });

  String get shopIssuedCountLabel =>
      _t({'ru': 'Заказов', 'en': 'Orders', 'uz': 'Buyurtmalar'});

  String get shopIssuedAmountLabel =>
      _t({'ru': 'Продано, шт', 'en': 'Sold, pcs', 'uz': 'Sotilgan, dona'});

  String get shopIssuedValueLabel =>
      _t({'ru': 'Сумма, сум', 'en': 'Amount, UZS', 'uz': "Summa, so'm"});

  String get shopIssuedToday =>
      _t({'ru': 'Сегодня', 'en': 'Today', 'uz': 'Bugun'});

  String get shopIssuedWeek =>
      _t({'ru': 'Неделя', 'en': 'Week', 'uz': 'Hafta'});

  String get shopIssuedMonth => _t({'ru': 'Месяц', 'en': 'Month', 'uz': 'Oy'});

  String get shopIssuedCustomPeriod =>
      _t({'ru': 'Свой период', 'en': 'Custom period', 'uz': "O'zi tanlagan"});

  String get shopIssuedShopFilterTitle =>
      _t({'ru': 'Магазин', 'en': 'Shop', 'uz': "Do'kon"});

  String get shopIssuedIssuedBy =>
      _t({'ru': 'Выдал', 'en': 'Issued by', 'uz': 'Topshirdi'});

  String get shopIssuedIssuedAt =>
      _t({'ru': 'Дата выдачи', 'en': 'Issued at', 'uz': 'Topshirilgan sana'});

  String get shopIssuedDateFrom => _t({'ru': 'От', 'en': 'From', 'uz': 'Dan'});

  String get shopIssuedDateTo => _t({'ru': 'До', 'en': 'To', 'uz': 'Gacha'});

  String get shopIssuedApply =>
      _t({'ru': 'Применить', 'en': 'Apply', 'uz': "Qo'llash"});

  String get shopIssuedStatusIssued =>
      _t({'ru': 'Выданные', 'en': 'Issued', 'uz': 'Topshirilgan'});

  String get shopIssuedStatusPending => _t({
    'ru': 'Ожидают выдачи',
    'en': 'Awaiting pickup',
    'uz': 'Topshirish kutilmoqda',
  });

  String get shopIssuedBadgeIssued =>
      _t({'ru': 'Выдан', 'en': 'Issued', 'uz': 'Topshirilgan'});

  String get shopIssuedWaitingBadge => _t({
    'ru': 'Ожидает выдачи',
    'en': 'Awaiting pickup',
    'uz': 'Topshirish kutilmoqda',
  });

  String get shopIssuedConfirmedAt =>
      _t({'ru': 'Подтверждён', 'en': 'Confirmed', 'uz': 'Tasdiqlangan'});

  String get shopAnalyticsTitle => _t({
    'ru': 'Аналитика товаров',
    'en': 'Product analytics',
    'uz': 'Mahsulotlar tahlili',
  });

  String get shopAnalyticsDesc => _t({
    'ru': 'Остатки, лидеры продаж, магазины и покупатели',
    'en': 'Stock, best sellers, shops and buyers',
    'uz': "Qoldiqlar, eng ko'p sotilganlar, do'konlar va xaridorlar",
  });

  String get shopAnalyticsTabProducts =>
      _t({'ru': 'Товары', 'en': 'Products', 'uz': 'Mahsulotlar'});

  String get shopAnalyticsTabShops =>
      _t({'ru': 'Магазины', 'en': 'Shops', 'uz': "Do'konlar"});

  String get shopAnalyticsTabBuyers =>
      _t({'ru': 'Покупатели', 'en': 'Buyers', 'uz': 'Xaridorlar'});

  String get shopAnalyticsTabStock =>
      _t({'ru': 'Остатки', 'en': 'Stock', 'uz': 'Qoldiqlar'});

  String get shopAnalyticsSoldSum =>
      _t({'ru': 'Сумма продаж', 'en': 'Sales amount', 'uz': 'Sotuv summasi'});

  String get shopAnalyticsStockQty =>
      _t({'ru': 'На складе, шт', 'en': 'In stock, pcs', 'uz': 'Omborda, dona'});

  String get shopAnalyticsStockValue => _t({
    'ru': 'Стоимость остатков',
    'en': 'Stock value',
    'uz': 'Qoldiq qiymati',
  });

  String get shopAnalyticsEmpty => _t({
    'ru': 'Нет данных за этот период',
    'en': 'No data for this period',
    'uz': "Ushbu davr uchun ma'lumot yo'q",
  });

  String get shopAnalyticsSearchHint => _t({
    'ru': 'Артикул, название, цвет',
    'en': 'Article, name, colour',
    'uz': 'Artikul, nomi, rangi',
  });

  String get shopIssuedSearchHint => _t({
    'ru': 'Покупатель, № заказа, товар',
    'en': 'Buyer, order no., product',
    'uz': 'Xaridor, buyurtma №, mahsulot',
  });

  String get shopAnalyticsPcs => _t({'ru': 'шт', 'en': 'pcs', 'uz': 'dona'});

  String get shopStockAllPeriod =>
      _t({'ru': 'Весь период', 'en': 'All time', 'uz': 'Barcha davr'});

  String get shopStockTitle => _t({
    'ru': 'Остатки товаров ПВЗ',
    'en': 'Pending pickup stock',
    'uz': 'PVZ qoldiqlari',
  });

  String get shopStockDesc => _t({
    'ru': 'Список неполученных заказов по клиентам',
    'en': 'Unclaimed orders broken down by client',
    'uz': "Xaridorlar bo'yicha olinmagan buyurtmalar",
  });

  String get shopStockEmpty => _t({
    'ru': 'Нет товаров, ожидающих выдачи в ПВЗ',
    'en': 'No goods waiting for pickup',
    'uz': "PVZda topshirishni kutayotgan tovarlar yo'q",
  });

  String get shopStockOverdueOnly => _t({
    'ru': 'Только просроченные',
    'en': 'Overdue only',
    'uz': 'Faqat muddati o\'tganlar',
  });

  String get shopStockOrdersLabel => _t({
    'ru': 'Заказов ожидает',
    'en': 'Orders pending',
    'uz': 'Kutilayotgan buyurtmalar',
  });

  String get shopStockQtyLabel =>
      _t({'ru': 'Товаров, шт', 'en': 'Items, pcs', 'uz': 'Tovarlar, dona'});

  String get shopStockOverdueLabel =>
      _t({'ru': 'Просрочено', 'en': 'Overdue', 'uz': "Muddati o'tgan"});

  String get shopStockBuyersLabel => _t({
    'ru': 'Клиентов ожидает',
    'en': 'Clients waiting',
    'uz': 'Kutayotgan xaridorlar',
  });

  String get shopStockWaitingSince =>
      _t({'ru': 'Ожидает с', 'en': 'Waiting since', 'uz': 'Kutmoqda'});

  String get shopStockDaysLabel =>
      _t({'ru': 'Дней ожидания', 'en': 'Days waiting', 'uz': 'Kutish kunlari'});

  String get shopStockStatusWaiting =>
      _t({'ru': 'В ожидании', 'en': 'Waiting', 'uz': 'Kutilmoqda'});

  String get shopStockStatusSoon => _t({
    'ru': 'Скоро просрочка',
    'en': 'Due soon',
    'uz': "Tez orada muddati o'tadi",
  });

  String get shopStockStatusOverdue =>
      _t({'ru': 'Просрочено', 'en': 'Overdue', 'uz': "Muddati o'tgan"});

  String get shopStockGroupBadge => _t({
    'ru': 'Есть просрочка',
    'en': 'Has overdue',
    'uz': "Muddati o'tgan bor",
  });

  String shopStockOrdersCount(int count) => _t({
    'ru': '$count заказ(ов)',
    'en': '$count order(s)',
    'uz': '$count ta buyurtma',
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
    'ru': 'Вход в UztexPro',
    'en': 'Sign in to UztexPro',
    'uz': 'UztexPro ga kirish',
  });

  String get pleaseWait => _t({
    'ru': 'Пожалуйста, подождите...',
    'en': 'Please wait...',
    'uz': 'Iltimos, kuting...',
  });

  String get loginSuccessTitle =>
      _t({'ru': 'Вход выполнен', 'en': 'Signed in', 'uz': 'Kirish bajarildi'});

  String get loginSuccessSubtitle => _t({
    'ru': 'Загрузка рабочего пространства',
    'en': 'Loading your workspace',
    'uz': 'Ish maydoni yuklanmoqda',
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

  String get biometricSignInLabel => _t({
    'ru': 'Войти по биометрии',
    'en': 'Sign in with biometrics',
    'uz': 'Biometriya orqali kirish',
  });

  String get notificationNow =>
      _t({'ru': 'сейчас', 'en': 'now', 'uz': 'hozir'});

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

  String get useFaceId => _t({
    'ru': 'Использовать Face ID для входа',
    'en': 'Use Face ID to sign in',
    'uz': 'Kirish uchun Face ID dan foydalaning',
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

  String get updating =>
      _t({'ru': 'Обновление…', 'en': 'Updating…', 'uz': 'Yangilanmoqda…'});

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

  String get copiedShort =>
      _t({'ru': 'Скопировано', 'en': 'Copied', 'uz': 'Nusxalandi'});

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

  String appVersionLabel(String version) => _t({
    'ru': 'Версия приложения: $version',
    'en': 'App version: $version',
    'uz': 'Ilova versiyasi: $version',
  });

  String get selectLanguage =>
      _t({'ru': 'Выбор языка', 'en': 'Select language', 'uz': 'Tilni tanlang'});

  String versionLabel(String version) => _t({
    'ru': 'Версия $version',
    'en': 'Version $version',
    'uz': 'Versiya $version',
  });

  String get allRightsReserved => _t({
    'ru':
        'Все права защищены. Приложение предназначено для управления производственными данными.',
    'en':
        'All rights reserved. The application is designed for managing production data.',
    'uz':
        "Barcha huquqlar himoyalangan. Ilova ishlab chiqarish ma'lumotlarini boshqarish uchun mo'ljallangan.",
  });

  // Confidentiality
  String get privacyTitle =>
      _t({'ru': 'Конфиденциальность', 'en': 'Privacy', 'uz': 'Maxfiylik'});

  String get privacyPolicy => _t({
    'ru': 'Политика конфиденциальности',
    'en': 'Privacy Policy',
    'uz': 'Maxfiylik siyosati',
  });

  String get privacyPolicyDesc => _t({
    'ru': 'Какие данные мы обрабатываем и как их защищаем',
    'en': 'What data we process and how we protect it',
    'uz': "Qanday ma'lumotlarni qayta ishlaymiz va himoyalaymiz",
  });

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

  // Product Models Page
  String get productModelsTitle => _t({
    'ru': 'Подтверждение моделей',
    'en': 'Model Confirmation',
    'uz': 'Modellarni tasdiqlash',
  });

  String get productModelsEmpty => _t({
    'ru': 'Модели не найдены',
    'en': 'No models found',
    'uz': 'Modellar topilmadi',
  });

  String get productModelSearchHint => _t({
    'ru': 'Артикул, название или заказчик',
    'en': 'Code, name or customer',
    'uz': "Artikul, nomi yoki mijoz",
  });

  String get firmLabel =>
      _t({'ru': 'Заказчик', 'en': 'Customer', 'uz': 'Mijoz'});

  String get vendorCodeLabel =>
      _t({'ru': 'Артикул', 'en': 'Vendor code', 'uz': 'Artikul'});

  String get priceLabel => _t({'ru': 'Цена', 'en': 'Price', 'uz': 'Narx'});

  String get priceConfirmed => _t({
    'ru': 'Цена подтверждена',
    'en': 'Price confirmed',
    'uz': 'Narx tasdiqlangan',
  });

  String get priceNotConfirmed => _t({
    'ru': 'Цена не подтверждена',
    'en': 'Price not confirmed',
    'uz': 'Narx tasdiqlanmagan',
  });

  String get confirmPriceTitle => _t({
    'ru': 'Подтвердить цену?',
    'en': 'Confirm price?',
    'uz': 'Narxni tasdiqlaysizmi?',
  });

  String get confirmPriceDesc => _t({
    'ru': 'Вы подтверждаете правильность цены модели',
    'en': 'You confirm that the model price is correct',
    'uz': "Model narxi to'g'riligini tasdiqlaysiz",
  });

  String get confirmPriceBtn =>
      _t({'ru': 'Подтвердить', 'en': 'Confirm', 'uz': 'Tasdiqlash'});

  String get confirmPriceSuccess => _t({
    'ru': 'Цена подтверждена',
    'en': 'Price confirmed',
    'uz': 'Narx tasdiqlandi',
  });

  String get unconfirmPriceTitle => _t({
    'ru': 'Снять подтверждение цены?',
    'en': 'Revoke price confirmation?',
    'uz': "Narx tasdig'ini bekor qilasizmi?",
  });

  String get unconfirmPriceDesc => _t({
    'ru': 'Подтверждение цены будет отменено',
    'en': 'The price confirmation will be revoked',
    'uz': "Narx tasdig'i bekor qilinadi",
  });

  String get unconfirmPriceBtn => _t({
    'ru': 'Снять подтверждение',
    'en': 'Revoke confirmation',
    'uz': "Tasdiqni bekor qilish",
  });

  String get unconfirmPriceSuccess => _t({
    'ru': 'Подтверждение снято',
    'en': 'Confirmation revoked',
    'uz': "Tasdiq bekor qilindi",
  });

  String get noPricePermission => _t({
    'ru': 'Нет прав для подтверждения цены',
    'en': 'No permission to confirm price',
    'uz': "Narxni tasdiqlashga ruxsat yo'q",
  });

  String get filterByStatus =>
      _t({'ru': 'Статус', 'en': 'Status', 'uz': 'Holat'});

  String get confirmedShort =>
      _t({'ru': 'Подтверждена', 'en': 'Confirmed', 'uz': 'Tasdiqlangan'});

  String get notConfirmedShort => _t({
    'ru': 'Не подтверждена',
    'en': 'Not confirmed',
    'uz': 'Tasdiqlanmagan',
  });

  String get selectCustomerTitle => _t({
    'ru': 'Выберите заказчика',
    'en': 'Select customer',
    'uz': 'Mijozni tanlang',
  });

  String get selectStatusTitle =>
      _t({'ru': 'Статус цены', 'en': 'Price status', 'uz': 'Narx holati'});

  String get searchCustomerHint => _t({
    'ru': 'Поиск заказчика',
    'en': 'Search customer',
    'uz': 'Mijozni qidirish',
  });

  String get noCustomersFound => _t({
    'ru': 'Заказчики не найдены',
    'en': 'No customers found',
    'uz': 'Mijozlar topilmadi',
  });

  String get noFilterResults => _t({
    'ru': 'Нет моделей по выбранным фильтрам',
    'en': 'No models match the selected filters',
    'uz': "Tanlangan filtrlar bo'yicha model topilmadi",
  });

  String get resetFilters => _t({
    'ru': 'Сбросить фильтры',
    'en': 'Reset filters',
    'uz': 'Filtrlarni tozalash',
  });

  String get productModelDetailTitle =>
      _t({'ru': 'Модель', 'en': 'Model', 'uz': 'Model'});

  String get seasonLabel => _t({'ru': 'Сезон', 'en': 'Season', 'uz': 'Mavsum'});

  String get categoryLabel =>
      _t({'ru': 'Категория', 'en': 'Category', 'uz': 'Kategoriya'});

  String get pricingSection => _t({
    'ru': 'Ценообразование',
    'en': 'Pricing',
    'uz': "Narx shakllantirish",
  });

  String get cuttingPriceLabel =>
      _t({'ru': 'Раскрой', 'en': 'Cutting', 'uz': 'Kesish'});

  String get transferPriceLabel =>
      _t({'ru': 'Трансфер', 'en': 'Transfer', 'uz': "O'tkazma"});

  String get printPriceLabel =>
      _t({'ru': 'Печать', 'en': 'Print', 'uz': 'Bosma'});

  String get embroideryPriceLabel =>
      _t({'ru': 'Вышивка', 'en': 'Embroidery', 'uz': 'Kashta'});

  String get accessoryCostLabel =>
      _t({'ru': 'Аксессуары', 'en': 'Accessories', 'uz': 'Aksessuarlar'});

  String get sewingLossLabel => _t({
    'ru': 'Потери на пошив, %',
    'en': 'Sewing loss, %',
    'uz': "Tikuvda yo'qotish, %",
  });

  String get otherExpensesLabel => _t({
    'ru': 'Прочие расходы, %',
    'en': 'Other expenses, %',
    'uz': 'Boshqa xarajatlar, %',
  });

  String get profitabilityLabel => _t({
    'ru': 'Рентабельность, %',
    'en': 'Profitability, %',
    'uz': 'Rentabellik, %',
  });

  String get commissionLabel =>
      _t({'ru': 'Комиссия, %', 'en': 'Commission, %', 'uz': 'Komissiya, %'});

  String get discountLabel =>
      _t({'ru': 'Скидка, %', 'en': 'Discount, %', 'uz': 'Chegirma, %'});

  String get discountCostLabel => _t({
    'ru': 'Цена со скидкой',
    'en': 'Discounted price',
    'uz': 'Chegirmali narx',
  });

  String get confirmationSection => _t({
    'ru': 'Подтверждение цены',
    'en': 'Price confirmation',
    'uz': "Narx tasdig'i",
  });

  String materialsCountLabel(int count) => _t({
    'ru': 'Материалы ($count)',
    'en': 'Materials ($count)',
    'uz': 'Materiallar ($count)',
  });

  String get noMaterials => _t({
    'ru': 'Материалы не указаны',
    'en': 'No materials specified',
    'uz': "Materiallar ko'rsatilmagan",
  });

  String get fabricLabel => _t({'ru': 'Полотно', 'en': 'Fabric', 'uz': 'Mato'});

  String get fabricColorLabel =>
      _t({'ru': 'Цвет', 'en': 'Color', 'uz': 'Rang'});

  String get packingTypeLabel =>
      _t({'ru': 'Тип упаковки', 'en': 'Packing type', 'uz': "Qadoqlash turi"});

  String get materialWeightLabel =>
      _t({'ru': 'Вес', 'en': 'Weight', 'uz': "Og'irlik"});

  String get pricePerKgLabel => _t({
    'ru': 'Цена (за кг)',
    'en': 'Price (per kg)',
    'uz': 'Narx (kg uchun)',
  });

  String get pricePerPieceLabel => _t({
    'ru': 'Цена (за шт)',
    'en': 'Price (per piece)',
    'uz': 'Narx (dona uchun)',
  });

  String accessoriesCountLabel(int count) => _t({
    'ru': 'Аксессуары ($count)',
    'en': 'Accessories ($count)',
    'uz': 'Aksessuarlar ($count)',
  });

  String get noAccessories => _t({
    'ru': 'Аксессуары не указаны',
    'en': 'No accessories specified',
    'uz': "Aksessuarlar ko'rsatilmagan",
  });

  String get noPricingData => _t({
    'ru': 'Данные о ценообразовании не заполнены',
    'en': 'Pricing details not filled in',
    'uz': "Narx shakllantirish ma'lumotlari kiritilmagan",
  });

  // Forward
  String get chatMenuForward =>
      _t({'ru': 'Переслать', 'en': 'Forward', 'uz': 'Yuborish'});
  String get forwardTitle =>
      _t({'ru': 'Переслать', 'en': 'Forward', 'uz': 'Yuborish'});
  String get forwardSearch =>
      _t({'ru': 'Поиск', 'en': 'Search', 'uz': 'Qidirish'});
  String get forwardChats =>
      _t({'ru': 'Чаты', 'en': 'Chats', 'uz': 'Chatlar'});
  String get forwardContacts =>
      _t({'ru': 'Контакты', 'en': 'Contacts', 'uz': 'Kontaktlar'});
  String forwardSendTo(int n) => _t({
    'ru': n == 1 ? 'Переслать' : 'Переслать ($n)',
    'en': n == 1 ? 'Forward' : 'Forward ($n)',
    'uz': n == 1 ? 'Yuborish' : 'Yuborish ($n)',
  });
  String forwardedFrom(String name) => _t({
    'ru': 'Переслано от $name',
    'en': 'Forwarded from $name',
    'uz': '$name dan yuborilgan',
  });
  String get chatShowInChat => _t({
    'ru': 'Показать в чате',
    'en': 'Show in Chat',
    'uz': 'Chatda ko‘rsatish',
  });
  String get forwardDone =>
      _t({'ru': 'Переслано', 'en': 'Forwarded', 'uz': 'Yuborildi'});
  String forwardDoneChats(int n) => _t({
    'ru': 'Чатов: $n',
    'en': '$n chats',
    'uz': '$n ta chat',
  });
  String get forwardFailed => _t({
    'ru': 'Не удалось переслать',
    'en': 'Could not forward',
    'uz': 'Yuborib bo‘lmadi',
  });
  String get forwardPartFailed => _t({
    'ru':
        'Часть сообщений переслать не удалось: файла уже нет ни на сервере, ни на этом телефоне.',
    'en':
        'Some messages could not be forwarded: the file is gone from the server and from this phone.',
    'uz':
        'Ba’zi xabarlarni yuborib bo‘lmadi: fayl serverda ham, bu telefonda ham yo‘q.',
  });

  // Server-side push settings and timed mute
  String get notifPush => _t({
    'ru': 'Уведомления о сообщениях',
    'en': 'Message Notifications',
    'uz': 'Xabar bildirishnomalari',
  });
  String get notifPrivateChats =>
      _t({'ru': 'Личные чаты', 'en': 'Private Chats', 'uz': 'Shaxsiy chatlar'});
  String get notifGroups =>
      _t({'ru': 'Группы', 'en': 'Groups', 'uz': 'Guruhlar'});
  String get notifAlert =>
      _t({'ru': 'Уведомления', 'en': 'Show Notifications', 'uz': 'Bildirishnomalar'});
  String get notifShowText => _t({
    'ru': 'Показывать текст',
    'en': 'Message Preview',
    'uz': 'Matnni ko‘rsatish',
  });
  String get notifPushSound =>
      _t({'ru': 'Звук', 'en': 'Sound', 'uz': 'Ovoz'});
  String get notifPushHint => _t({
    'ru':
        'Эти настройки работают и когда приложение закрыто, на всех ваших устройствах.',
    'en': 'These settings work when the app is closed, on all your devices.',
    'uz': 'Bu sozlamalar ilova yopiq bo‘lganda ham, barcha qurilmalaringizda amal qiladi.',
  });
  String get notifPushError => _t({
    'ru': 'Не удалось сохранить настройки',
    'en': 'Could not save the settings',
    'uz': 'Sozlamalarni saqlab bo‘lmadi',
  });
  String get notifPushLoadError => _t({
    'ru': 'Не удалось загрузить настройки уведомлений',
    'en': 'Could not load the notification settings',
    'uz': 'Bildirishnoma sozlamalarini yuklab bo‘lmadi',
  });
  String get muteTitle => _t({
    'ru': 'Отключить уведомления',
    'en': 'Mute Notifications',
    'uz': 'Bildirishnomalarni o‘chirish',
  });
  String get mute1h => _t({
    'ru': 'Отключить на 1 час',
    'en': 'Mute for 1 hour',
    'uz': '1 soatga o‘chirish',
  });
  String get mute8h => _t({
    'ru': 'Отключить на 8 часов',
    'en': 'Mute for 8 hours',
    'uz': '8 soatga o‘chirish',
  });
  String get mute2d => _t({
    'ru': 'Отключить на 2 дня',
    'en': 'Mute for 2 days',
    'uz': '2 kunga o‘chirish',
  });
  String get muteForever => _t({
    'ru': 'Отключить навсегда',
    'en': 'Mute forever',
    'uz': 'Doimiy o‘chirish',
  });

  // Data and storage
  String get dataTitle =>
      _t({'ru': 'Данные и память', 'en': 'Data and Storage', 'uz': 'Ma’lumot va xotira'});
  String get dataAutoDownload => _t({
    'ru': 'Автозагрузка медиа',
    'en': 'Automatic Media Download',
    'uz': 'Avtomatik yuklash',
  });
  String get dataMobile =>
      _t({'ru': 'Мобильная сеть', 'en': 'Mobile Data', 'uz': 'Mobil tarmoq'});
  String get dataWifi => _t({'ru': 'Wi-Fi', 'en': 'Wi-Fi', 'uz': 'Wi-Fi'});
  String get dataPhotos => _t({'ru': 'Фото', 'en': 'Photos', 'uz': 'Rasmlar'});
  String get dataVideos => _t({'ru': 'Видео', 'en': 'Videos', 'uz': 'Videolar'});
  String get dataFiles => _t({'ru': 'Файлы', 'en': 'Files', 'uz': 'Fayllar'});
  String get dataAutoHint => _t({
    'ru':
        'Чужие фото, видео и файлы скачиваются сами, пока вы в приложении. Что не включено, скачивается по нажатию.',
    'en':
        'Photos, videos and files others send are downloaded by themselves while you are in the app. Anything switched off is downloaded on a tap.',
    'uz':
        'Boshqalar yuborgan rasm, video va fayllar ilovada bo‘lganingizda o‘zi yuklanadi. O‘chirilganlari bosganda yuklanadi.',
  });
  String get dataStorage =>
      _t({'ru': 'Хранение', 'en': 'Storage', 'uz': 'Saqlash'});
  String get dataKeep =>
      _t({'ru': 'Хранить медиа', 'en': 'Keep Media', 'uz': 'Saqlash muddati'});
  String get dataKeepForever =>
      _t({'ru': 'Всегда', 'en': 'Forever', 'uz': 'Doim'});
  String get dataKeep3Days =>
      _t({'ru': '3 дня', 'en': '3 days', 'uz': '3 kun'});
  String get dataKeepWeek =>
      _t({'ru': 'Неделю', 'en': '1 week', 'uz': '1 hafta'});
  String get dataKeepMonth =>
      _t({'ru': 'Месяц', 'en': '1 month', 'uz': '1 oy'});
  String get dataKeepHint => _t({
    'ru':
        'Файлы старше выбранного срока удаляются с телефона. Если сервер уже удалил оригинал, скачать его снова не получится, поэтому по умолчанию файлы хранятся всегда.',
    'en':
        'Files older than the chosen time are deleted from this phone. If the server has already removed an original it cannot be downloaded again, so files are kept forever by default.',
    'uz':
        'Tanlangan muddatdan eski fayllar telefondan o‘chiriladi. Server asl nusxani allaqachon o‘chirgan bo‘lsa, uni qayta yuklab bo‘lmaydi, shuning uchun odatda fayllar doim saqlanadi.',
  });
  String get dataUsed =>
      _t({'ru': 'Занято на телефоне', 'en': 'Used on This Phone', 'uz': 'Telefonda band'});
  String get dataClear => _t({
    'ru': 'Очистить память чата',
    'en': 'Clear Chat Storage',
    'uz': 'Chat xotirasini tozalash',
  });

  // Chat appearance
  String get appearanceTitle => _t({
    'ru': 'Оформление чата',
    'en': 'Chat Appearance',
    'uz': 'Chat ko‘rinishi',
  });
  String get appearanceTextSize =>
      _t({'ru': 'Размер текста', 'en': 'Text Size', 'uz': 'Matn o‘lchami'});
  String get appearanceWallpaper =>
      _t({'ru': 'Фон чата', 'en': 'Chat Background', 'uz': 'Chat foni'});
  String get appearancePreviewIn => _t({
    'ru': 'Привет! Как дела?',
    'en': 'Hi! How are you?',
    'uz': 'Salom! Ishlar qalay?',
  });
  String get appearancePreviewOut => _t({
    'ru': 'Всё хорошо, спасибо 👍',
    'en': 'All good, thanks 👍',
    'uz': 'Hammasi yaxshi, rahmat 👍',
  });
  String get appearanceReset => _t({
    'ru': 'Сбросить оформление',
    'en': 'Reset Appearance',
    'uz': 'Ko‘rinishni tiklash',
  });
  String get appearanceHint => _t({
    'ru': 'Размер текста и фон действуют во всех чатах и группах.',
    'en': 'Text size and background apply to all chats and groups.',
    'uz': 'Matn o‘lchami va fon barcha chat va guruhlarda amal qiladi.',
  });

  // Devices
  String get devicesTitle =>
      _t({'ru': 'Устройства', 'en': 'Devices', 'uz': 'Qurilmalar'});
  String get devicesThis => _t({
    'ru': 'Это устройство',
    'en': 'This Device',
    'uz': 'Shu qurilma',
  });
  String get devicesOthers => _t({
    'ru': 'Другие устройства',
    'en': 'Other Devices',
    'uz': 'Boshqa qurilmalar',
  });
  String get devicesHint => _t({
    'ru':
        'Уведомления о сообщениях приходят на эти телефоны. Отключите те, которыми вы больше не пользуетесь.',
    'en':
        'Message notifications are sent to these phones. Disconnect the ones you no longer use.',
    'uz':
        'Xabar bildirishnomalari shu telefonlarga keladi. Endi foydalanmaydiganlarini o‘chiring.',
  });
  String get devicesUnknown =>
      _t({'ru': 'Устройство', 'en': 'Device', 'uz': 'Qurilma'});
  String devicesAdded(String date) => _t({
    'ru': 'Добавлено $date',
    'en': 'Added $date',
    'uz': 'Qo‘shilgan: $date',
  });
  String devicesActive(String date) => _t({
    'ru': 'Был(а) активен $date',
    'en': 'Last active $date',
    'uz': 'Oxirgi faollik: $date',
  });
  String get devicesRemoveTitle => _t({
    'ru': 'Отключить устройство?',
    'en': 'Disconnect this device?',
    'uz': 'Qurilma o‘chirilsinmi?',
  });
  String devicesRemoveMessage(String name) => _t({
    'ru':
        'На «$name» перестанут приходить уведомления. Они вернутся, когда вы снова войдёте в приложение на этом устройстве.',
    'en':
        '"$name" will stop getting notifications. They come back when you sign in to the app on that device again.',
    'uz':
        '«$name» qurilmasiga bildirishnomalar kelmay qoladi. Ilovaga o‘sha qurilmada qayta kirsangiz, ular qaytadi.',
  });
  String get devicesRemove =>
      _t({'ru': 'Отключить', 'en': 'Disconnect', 'uz': 'O‘chirish'});
  String get devicesLoadError => _t({
    'ru': 'Не удалось загрузить устройства',
    'en': 'Could not load the devices',
    'uz': 'Qurilmalarni yuklab bo‘lmadi',
  });
  String get devicesRemoveError => _t({
    'ru': 'Не удалось отключить устройство',
    'en': 'Could not disconnect the device',
    'uz': 'Qurilmani o‘chirib bo‘lmadi',
  });
  String get devicesRetry =>
      _t({'ru': 'Повторить', 'en': 'Retry', 'uz': 'Qayta urinish'});

  // Notifications and sounds (chat settings)
  String get notifTitle => _t({
    'ru': 'Уведомления и звуки',
    'en': 'Notifications and Sounds',
    'uz': 'Bildirishnomalar va ovozlar',
  });
  String get notifInApp =>
      _t({'ru': 'В приложении', 'en': 'In-App', 'uz': 'Ilova ichida'});
  String get notifInAppSounds => _t({
    'ru': 'Звуки в приложении',
    'en': 'In-App Sounds',
    'uz': 'Ilova ichidagi ovozlar',
  });
  String get notifInAppVibrate => _t({
    'ru': 'Вибрация в приложении',
    'en': 'In-App Vibrate',
    'uz': 'Ilova ichidagi tebranish',
  });
  String get notifInAppPreview => _t({
    'ru': 'Предпросмотр в приложении',
    'en': 'In-App Preview',
    'uz': 'Ilova ichida ko‘rsatish',
  });
  String get notifInAppPreviewHint => _t({
    'ru':
        'Сообщение из другого чата появляется баннером сверху на любом экране приложения.',
    'en':
        'A message from another chat slides down from the top on any screen of the app.',
    'uz':
        'Boshqa chatdan kelgan xabar ilovaning istalgan ekranida tepadan banner bo‘lib chiqadi.',
  });
  String get notifSounds =>
      _t({'ru': 'Звуки', 'en': 'Sounds', 'uz': 'Ovozlar'});
  String get notifSoundIncoming => _t({
    'ru': 'Входящее сообщение',
    'en': 'Incoming Message',
    'uz': 'Kiruvchi xabar',
  });
  String get notifSoundSent => _t({
    'ru': 'Отправка сообщения',
    'en': 'Sent Message',
    'uz': 'Xabar yuborish',
  });
  String get notifSoundsHint => _t({
    'ru': 'Эти звуки работают, пока приложение открыто. Выключить звук отдельного чата можно в его профиле.',
    'en': 'These sounds play while the app is open. A single chat can be muted in its profile.',
    'uz': 'Bu ovozlar ilova ochiq paytida eshitiladi. Alohida chatni uning profilida o‘chirish mumkin.',
  });
  String get notifSoundStandard =>
      _t({'ru': 'Стандартный', 'en': 'Default', 'uz': 'Standart'});
  String get notifSoundTelegram =>
      _t({'ru': 'Телеграм', 'en': 'Telegram', 'uz': 'Telegram'});
  String get notifSoundDice =>
      _t({'ru': 'Кубик', 'en': 'Dice', 'uz': 'Kub'});
  String get notifSoundSystem =>
      _t({'ru': 'Системный', 'en': 'System', 'uz': 'Tizim'});
  String get notifSoundNone =>
      _t({'ru': 'Без звука', 'en': 'None', 'uz': 'Ovozsiz'});
  String get notifReset => _t({
    'ru': 'Сбросить все настройки',
    'en': 'Reset All Notifications',
    'uz': 'Barcha sozlamalarni tiklash',
  });
  String get notifResetMessage => _t({
    'ru': 'Все настройки уведомлений и звуков вернутся к значениям по умолчанию.',
    'en': 'All notification and sound settings will return to their defaults.',
    'uz': 'Barcha bildirishnoma va ovoz sozlamalari odatiy holatga qaytadi.',
  });
  String get notifResetBtn =>
      _t({'ru': 'Сбросить', 'en': 'Reset', 'uz': 'Tiklash'});

  // Chat
  String get chatTitle => _t({'ru': 'Чаты', 'en': 'Chats', 'uz': 'Chatlar'});

  String get chatUpdating => _t({
    'ru': 'Обновление...',
    'en': 'Updating...',
    'uz': 'Yangilanmoqda...',
  });

  String get contactsTitle =>
      _t({'ru': 'Контакты', 'en': 'Contacts', 'uz': 'Kontaktlar'});

  String get chatsEmpty => _t({
    'ru': 'Чатов пока нет',
    'en': 'No chats yet',
    'uz': 'Hozircha chatlar yo‘q',
  });

  String get chatsSearchHint => _t({
    'ru': 'Поиск чатов',
    'en': 'Search chats',
    'uz': 'Chatlarni qidirish',
  });

  String get contactsSearchHint => _t({
    'ru': 'Поиск контактов',
    'en': 'Search contacts',
    'uz': 'Kontaktlarni qidirish',
  });

  String get chatLoadError => _t({
    'ru': 'Не удалось загрузить. Потяните, чтобы повторить',
    'en': 'Could not load. Pull to retry',
    'uz': 'Yuklab bo‘lmadi. Qayta urinish uchun torting',
  });

  String get chatTyping =>
      _t({'ru': 'печатает…', 'en': 'typing…', 'uz': 'yozmoqda…'});

  String get chatMedia => _t({'ru': 'Медиа', 'en': 'Media', 'uz': 'Media'});
  String get chatVoice =>
      _t({'ru': 'Голосовые', 'en': 'Voice', 'uz': 'Ovozli'});
  String get chatNothingYet => _t({
    'ru': 'Пока пусто',
    'en': 'Nothing here yet',
    'uz': 'Hozircha bo‘sh',
  });

  String chatMembersCount(int n) {
    final ru = n % 10 == 1 && n % 100 != 11
        ? 'участник'
        : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 12 || n % 100 > 14))
        ? 'участника'
        : 'участников';
    return _t({'ru': '$n $ru', 'en': '$n members', 'uz': '$n ta a’zo'});
  }

  String chatTypingNames(List<String> names) {
    if (names.length == 1) {
      return _t({
        'ru': '${names[0]} печатает…',
        'en': '${names[0]} is typing…',
        'uz': '${names[0]} yozmoqda…',
      });
    }
    if (names.length == 2) {
      return _t({
        'ru': '${names[0]}, ${names[1]} печатают…',
        'en': '${names[0]}, ${names[1]} are typing…',
        'uz': '${names[0]}, ${names[1]} yozmoqda…',
      });
    }
    return _t({
      'ru': 'Несколько человек печатают…',
      'en': 'Several people are typing…',
      'uz': 'Bir necha kishi yozmoqda…',
    });
  }

  String get chatMemberFallback =>
      _t({'ru': 'Участник', 'en': 'Member', 'uz': 'A’zo'});

  /// A service line of a group, from what the server sent. [actor] / [user]
  /// are names, with "You" already put in for me ([actorIsMe] / [userIsMe]
  /// pick the verb form).
  String chatSystemLine({
    required String event,
    required String actor,
    required bool actorIsMe,
    required String user,
    required bool userIsMe,
    required String title,
    required String fallback,
  }) {
    switch (event) {
      case 'created':
        return _t({
          'ru': actorIsMe
              ? 'Вы создали группу «$title»'
              : '$actor создал(а) группу «$title»',
          'en': '$actor created the group “$title”',
          'uz': '$actor “$title” guruhini yaratdi',
        });
      case 'added':
        return _t({
          'ru': actorIsMe
              ? 'Вы добавили $user'
              : '$actor добавил(а) ${userIsMe ? 'Вас' : user}',
          'en': '$actor added $user',
          'uz': '$actor $user ni qo‘shdi',
        });
      case 'removed':
        return _t({
          'ru': actorIsMe
              ? 'Вы удалили $user'
              : '$actor удалил(а) ${userIsMe ? 'Вас' : user}',
          'en': '$actor removed $user',
          'uz': '$actor $user ni chiqarib yubordi',
        });
      case 'left':
        return _t({
          'ru': userIsMe ? 'Вы покинули группу' : '$user покинул(а) группу',
          'en': '$user left the group',
          'uz': '$user guruhni tark etdi',
        });
      case 'renamed':
        return _t({
          'ru': actorIsMe
              ? 'Вы изменили название на «$title»'
              : '$actor изменил(а) название на «$title»',
          'en': '$actor renamed the group to “$title”',
          'uz': '$actor guruh nomini “$title” ga o‘zgartirdi',
        });
      case 'photo':
        return _t({
          'ru': actorIsMe
              ? 'Вы изменили фото группы'
              : '$actor изменил(а) фото группы',
          'en': '$actor changed the group photo',
          'uz': '$actor guruh rasmini o‘zgartirdi',
        });
    }
    return fallback;
  }

  String get chatAddMembers =>
      _t({'ru': 'Добавить', 'en': 'Add', 'uz': 'Qo‘shish'});
  String get chatAddMembersTitle => _t({
    'ru': 'Добавить участников',
    'en': 'Add members',
    'uz': 'A’zolarni qo‘shish',
  });
  String get chatEditGroup =>
      _t({'ru': 'изменить', 'en': 'edit', 'uz': 'tahrirlash'});
  String get chatMoreShort => _t({'ru': 'ещё', 'en': 'more', 'uz': 'yana'});
  String get chatAddShort =>
      _t({'ru': 'добавить', 'en': 'add', 'uz': 'qo‘shish'});
  String get chatMembers =>
      _t({'ru': 'Участники', 'en': 'Members', 'uz': 'A’zolar'});
  String get chatRoleOwner =>
      _t({'ru': 'владелец', 'en': 'owner', 'uz': 'egasi'});
  String get chatRoleAdmin => _t({'ru': 'админ', 'en': 'admin', 'uz': 'admin'});
  String get chatMakeAdmin =>
      _t({'ru': 'Сделать админом', 'en': 'Make admin', 'uz': 'Admin qilish'});
  String get chatRemoveAdmin => _t({
    'ru': 'Снять с админов',
    'en': 'Remove as admin',
    'uz': 'Adminlikdan olish',
  });
  String get chatRemoveFromGroup => _t({
    'ru': 'Удалить из группы',
    'en': 'Remove from group',
    'uz': 'Guruhdan chiqarish',
  });
  String get chatLeaveTitle => _t({
    'ru': 'Покинуть группу?',
    'en': 'Leave the group?',
    'uz': 'Guruhdan chiqasizmi?',
  });
  String get chatLeaveConfirm =>
      _t({'ru': 'Покинуть', 'en': 'Leave', 'uz': 'Chiqish'});
  String get chatDeleteGroup => _t({
    'ru': 'Удалить группу',
    'en': 'Delete group',
    'uz': 'Guruhni o‘chirish',
  });
  String get chatDeleteGroupTitle => _t({
    'ru': 'Удалить группу для всех?',
    'en': 'Delete the group for everybody?',
    'uz': 'Guruh hamma uchun o‘chirilsinmi?',
  });
  String get chatRename =>
      _t({'ru': 'Название группы', 'en': 'Group name', 'uz': 'Guruh nomi'});
  String get chatChangePhoto => _t({
    'ru': 'Изменить фото',
    'en': 'Change photo',
    'uz': 'Rasmni o‘zgartirish',
  });
  String get chatRemovePhoto => _t({
    'ru': 'Удалить фото',
    'en': 'Remove photo',
    'uz': 'Rasmni o‘chirish',
  });
  String get chatActionFailed => _t({
    'ru': 'Не удалось. Попробуйте ещё раз',
    'en': 'Failed. Try again',
    'uz': 'Amalga oshmadi. Qayta urinib ko‘ring',
  });

  String get chatNewGroup =>
      _t({'ru': 'Новая группа', 'en': 'New group', 'uz': 'Yangi guruh'});
  String get chatCreate =>
      _t({'ru': 'Создать', 'en': 'Create', 'uz': 'Yaratish'});
  String get chatGroupName =>
      _t({'ru': 'Название группы', 'en': 'Group name', 'uz': 'Guruh nomi'});
  String get chatNext => _t({'ru': 'Далее', 'en': 'Next', 'uz': 'Keyingi'});

  String get chatMuteAction =>
      _t({'ru': 'Выключить звук', 'en': 'Mute', 'uz': 'Ovozsiz qilish'});
  String get chatUnmuteAction =>
      _t({'ru': 'Включить звук', 'en': 'Unmute', 'uz': 'Ovozni yoqish'});
  String get chatMuteShort =>
      _t({'ru': 'Без звука', 'en': 'Mute', 'uz': 'Ovozsiz'});
  String get chatUnmuteShort =>
      _t({'ru': 'Со звуком', 'en': 'Unmute', 'uz': 'Ovozli'});
  String get chatDeleteChatAction =>
      _t({'ru': 'Удалить чат', 'en': 'Delete chat', 'uz': 'Chatni o‘chirish'});
  String get chatLeaveGroupAction => _t({
    'ru': 'Выйти из группы',
    'en': 'Leave group',
    'uz': 'Guruhdan chiqish',
  });
  String get chatDeleteShort =>
      _t({'ru': 'Удалить', 'en': 'Delete', 'uz': 'O‘chirish'});
  String get chatLeaveShort =>
      _t({'ru': 'Выйти', 'en': 'Leave', 'uz': 'Chiqish'});

  String get chatNoMessagesYet => _t({
    'ru': 'Сообщений пока нет',
    'en': 'No messages yet',
    'uz': 'Hozircha xabar yo‘q',
  });

  String get chatMenuReply =>
      _t({'ru': 'Ответить', 'en': 'Reply', 'uz': 'Javob berish'});
  String chatReplyTo(String name) =>
      _t({'ru': 'Ответ $name', 'en': 'Reply to $name', 'uz': '$name ga javob'});

  String get chatMenuCopy =>
      _t({'ru': 'Скопировать', 'en': 'Copy', 'uz': 'Nusxalash'});
  String get chatMenuEdit =>
      _t({'ru': 'Изменить', 'en': 'Edit', 'uz': 'Tahrirlash'});
  String get chatMenuDelete =>
      _t({'ru': 'Удалить', 'en': 'Delete', 'uz': 'O‘chirish'});
  String get chatMenuDeleteForMe => _t({
    'ru': 'Удалить у меня',
    'en': 'Delete for me',
    'uz': 'Menda o‘chirish',
  });
  String get chatMenuDeleteForAll => _t({
    'ru': 'Удалить у всех',
    'en': 'Delete for everyone',
    'uz': 'Hammada o‘chirish',
  });
  String get chatEditing =>
      _t({'ru': 'Изменение', 'en': 'Editing', 'uz': 'Tahrirlash'});
  String get chatEdited => _t({'ru': 'изм.', 'en': 'edited', 'uz': 'tahr.'});

  String get chatSound => _t({'ru': 'звук', 'en': 'sound', 'uz': 'ovoz'});
  String get chatSoundOff =>
      _t({'ru': 'без звука', 'en': 'muted', 'uz': 'ovozsiz'});
  String get chatDelete =>
      _t({'ru': 'удалить', 'en': 'delete', 'uz': 'o‘chirish'});
  String get chatDeleteTitle => _t({
    'ru': 'Удалить чат?',
    'en': 'Delete chat?',
    'uz': 'Chat o‘chirilsinmi?',
  });
  String get chatDeleteMessage => _t({
    'ru': 'Это действие нельзя отменить.',
    'en': 'This cannot be undone.',
    'uz': 'Bu amalni bekor qilib bo‘lmaydi.',
  });
  String chatDeleteForBoth(String name) => _t({
    'ru': 'Удалить у меня и у $name',
    'en': 'Delete for me and $name',
    'uz': 'Menda va $name da o‘chirish',
  });
  String get chatDeleteForMe => _t({
    'ru': 'Удалить только у себя',
    'en': 'Delete only for me',
    'uz': 'Faqat menda o‘chirish',
  });

  String get chatCall => _t({'ru': 'звонок', 'en': 'call', 'uz': 'qo‘ng‘iroq'});
  String get chatVoiceMessage => _t({
    'ru': 'Голосовое сообщение',
    'en': 'Voice message',
    'uz': 'Ovozli xabar',
  });
  String get chatVoiceFailed => _t({
    'ru': 'Не удалось воспроизвести голосовое',
    'en': 'Could not play the voice message',
    'uz': 'Ovozli xabarni ijro etib bo‘lmadi',
  });
  String get chatGoToMessage => _t({
    'ru': 'Перейти к сообщению',
    'en': 'Go to message',
    'uz': 'Xabarga o‘tish',
  });
  String get chatNoVoice => _t({
    'ru': 'Голосовых пока нет',
    'en': 'No voice messages yet',
    'uz': 'Ovozli xabarlar yo‘q',
  });
  String get chatShowMore =>
      _t({'ru': 'Показать ещё', 'en': 'Show more', 'uz': 'Yana ko‘rsatish'});
  String get chatAttachGallery => _t({
    'ru': 'Фото или видео',
    'en': 'Photo or video',
    'uz': 'Rasm yoki video',
  });
  String get chatAttachCamera =>
      _t({'ru': 'Сделать фото', 'en': 'Take a photo', 'uz': 'Rasmga olish'});
  String get chatAttachVideoCamera =>
      _t({'ru': 'Снять видео', 'en': 'Record a video', 'uz': 'Video olish'});
  String get chatAttachFile => _t({'ru': 'Файл', 'en': 'File', 'uz': 'Fayl'});
  String get chatPhoto => _t({'ru': 'Фото', 'en': 'Photo', 'uz': 'Rasm'});
  String get chatVideo => _t({'ru': 'Видео', 'en': 'Video', 'uz': 'Video'});
  String get chatPreparing =>
      _t({'ru': 'Подготовка…', 'en': 'Preparing…', 'uz': 'Tayyorlanmoqda…'});
  String get chatFileGone => _t({
    'ru': 'Файл удалён с сервера',
    'en': 'File was removed from the server',
    'uz': 'Fayl serverdan o‘chirilgan',
  });
  String get chatDownloadFailed => _t({
    'ru': 'Не удалось скачать. Нажмите, чтобы повторить',
    'en': 'Download failed. Tap to retry',
    'uz': 'Yuklab bo‘lmadi. Qayta urinish uchun bosing',
  });
  String get chatAttachTooLarge => _t({
    'ru':
        'Файл слишком большой: фото до 10 МБ, видео до 50 МБ, документы до 20 МБ',
    'en': 'File too large: photos up to 10 MB, videos 50 MB, documents 20 MB',
    'uz': 'Fayl juda katta: rasm 10 MB, video 50 MB, hujjat 20 MB gacha',
  });
  String get chatAttachBadType => _t({
    'ru': 'Этот тип файла не поддерживается',
    'en': 'This file type is not supported',
    'uz': 'Bu fayl turi qo‘llab-quvvatlanmaydi',
  });
  String get chatAttachFailed => _t({
    'ru': 'Не удалось подготовить файл',
    'en': 'Could not prepare the file',
    'uz': 'Faylni tayyorlab bo‘lmadi',
  });
  String get chatRecents =>
      _t({'ru': 'Недавние', 'en': 'Recents', 'uz': 'So‘nggilar'});
  String get chatGalleryTab =>
      _t({'ru': 'Галерея', 'en': 'Gallery', 'uz': 'Galereya'});
  String get chatCameraTab =>
      _t({'ru': 'Камера', 'en': 'Camera', 'uz': 'Kamera'});
  String get chatSendMedia =>
      _t({'ru': 'Отправить', 'en': 'Send', 'uz': 'Yuborish'});
  String get chatPhotosDenied => _t({
    'ru': 'Нет доступа к фото. Разрешите доступ в настройках',
    'en': 'No access to photos. Allow it in Settings',
    'uz': 'Rasmlarga ruxsat yo‘q. Sozlamalarda ruxsat bering',
  });
  String get chatOpenSettings =>
      _t({'ru': 'Настройки', 'en': 'Settings', 'uz': 'Sozlamalar'});
  String get chatCaptionHint => _t({
    'ru': 'Добавить подпись…',
    'en': 'Add a caption…',
    'uz': 'Izoh qo‘shish…',
  });
  String get chatNoMedia => _t({
    'ru': 'Фото и видео пока нет',
    'en': 'No photos or videos yet',
    'uz': 'Rasm va videolar yo‘q',
  });
  String get chatStorageTitle =>
      _t({'ru': 'Память чата', 'en': 'Chat storage', 'uz': 'Chat xotirasi'});
  String chatStorageSubtitle(String size) => _t({
    'ru': 'Фото, видео и файлы: $size',
    'en': 'Photos, videos and files: $size',
    'uz': 'Rasm, video va fayllar: $size',
  });
  String get chatStorageClearTitle => _t({
    'ru': 'Очистить память чата?',
    'en': 'Clear chat storage?',
    'uz': 'Chat xotirasi tozalansinmi?',
  });
  String get chatStorageClearMessage => _t({
    'ru':
        'Фото, видео и файлы чата будут удалены с телефона. Если сервер уже удалил оригинал, скачать его снова не получится.',
    'en':
        'Photos, videos and files of the chat will be deleted from this phone. If the server has already removed an original, it cannot be downloaded again.',
    'uz':
        'Chatdagi rasm, video va fayllar telefondan o‘chiriladi. Server asl nusxani allaqachon o‘chirgan bo‘lsa, uni qayta yuklab bo‘lmaydi.',
  });
  String get chatStorageClear =>
      _t({'ru': 'Очистить', 'en': 'Clear', 'uz': 'Tozalash'});
  String get chatStorageCleared => _t({
    'ru': 'Память очищена',
    'en': 'Storage cleared',
    'uz': 'Xotira tozalandi',
  });
  String get chatSlideToCancel => _t({
    'ru': 'Влево — отмена',
    'en': 'Slide to cancel',
    'uz': 'Bekor qilish — chapga',
  });
  String get chatMicDenied => _t({
    'ru': 'Нет доступа к микрофону. Разрешите его в настройках',
    'en': 'No microphone access. Allow it in Settings',
    'uz': 'Mikrofonga ruxsat yo‘q. Sozlamalarda ruxsat bering',
  });
  String get chatHoldToRecord => _t({
    'ru': 'Удерживайте, чтобы записать голосовое',
    'en': 'Hold to record a voice message',
    'uz': 'Ovoz yozish uchun bosib turing',
  });
  String get chatWrite =>
      _t({'ru': 'написать', 'en': 'message', 'uz': 'yozish'});
  String get chatCancel =>
      _t({'ru': 'Отмена', 'en': 'Cancel', 'uz': 'Bekor qilish'});
  String get chatCopied => _t({
    'ru': 'Номер скопирован',
    'en': 'Number copied',
    'uz': 'Raqam nusxalandi',
  });

  String get chatOnline => _t({'ru': 'в сети', 'en': 'online', 'uz': 'onlayn'});

  /// "last seen today at 14:05" / "yesterday at …" / "12.10 at …".
  String chatLastSeen(DateTime? at) {
    if (at == null) {
      return _t({
        'ru': 'был(а) недавно',
        'en': 'last seen recently',
        'uz': 'yaqinda edi',
      });
    }
    final now = DateTime.now();
    final day = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two(at.hour)}:${two(at.minute)}';
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return _t({
        'ru': 'был(а) в $time',
        'en': 'last seen at $time',
        'uz': '$time da edi',
      });
    }
    final when = diff == 1
        ? _t({'ru': 'вчера', 'en': 'yesterday', 'uz': 'kecha'})
        : '${two(at.day)}.${two(at.month)}';
    return _t({
      'ru': 'был(а) $when',
      'en': 'last seen $when',
      'uz': '$when edi',
    });
  }

  String get chatConnecting =>
      _t({'ru': 'Соединение…', 'en': 'Connecting…', 'uz': 'Ulanmoqda…'});

  String get chatToday => _t({'ru': 'Сегодня', 'en': 'Today', 'uz': 'Bugun'});

  String get chatInputHint =>
      _t({'ru': 'Сообщение', 'en': 'Message', 'uz': 'Xabar'});

  String get chatNoMessages => _t({
    'ru': 'Сообщений пока нет.\nНапишите первым',
    'en': 'No messages yet.\nWrite first',
    'uz': 'Hozircha xabarlar yo‘q.\nBirinchi yozing',
  });

  String get chatNotSent => _t({
    'ru': 'Не отправлено. Нажмите, чтобы повторить',
    'en': 'Not sent. Tap to retry',
    'uz': 'Yuborilmadi. Qayta urinish uchun bosing',
  });

  String get chatNoAccess => _t({
    'ru': 'Нет доступа к чату',
    'en': 'No access to the chat',
    'uz': 'Chatga ruxsat yo‘q',
  });

  String get chatOpenError => _t({
    'ru': 'Не удалось открыть чат',
    'en': 'Could not open the chat',
    'uz': 'Chatni ochib bo‘lmadi',
  });

  String get chatYesterday =>
      _t({'ru': 'Вчера', 'en': 'Yesterday', 'uz': 'Kecha'});

  String get chatYou => _t({'ru': 'Вы', 'en': 'You', 'uz': 'Siz'});

  String get chatNothingFound => _t({
    'ru': 'Ничего не найдено',
    'en': 'Nothing found',
    'uz': 'Hech narsa topilmadi',
  });

  String get contactsEmpty => _t({
    'ru': 'Контактов пока нет',
    'en': 'No contacts yet',
    'uz': 'Hozircha kontaktlar yo‘q',
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

  // Passes Status Labels
  String get passStatusCancelled =>
      _t({'ru': 'Отменён', 'en': 'Cancelled', 'uz': 'Bekor qilindi'});

  String get passStatusNew => _t({'ru': 'Новый', 'en': 'New', 'uz': 'Yangi'});

  String get passStatusIssuedReleased => _t({
    'ru': 'Выдан (Отпустил подписал)',
    'en': 'Issued (Released)',
    'uz': 'Berildi (Chiqarildi)',
  });

  String get passStatusIssued =>
      _t({'ru': 'Выдан', 'en': 'Issued', 'uz': 'Berildi'});

  String get passStatusSignedByAccountant => _t({
    'ru': 'Подписан гл. бухгалтером',
    'en': 'Signed by chief accountant',
    'uz': 'Bosh buxgalter tomonidan imzolangan',
  });

  String get passStatusAccountant =>
      _t({'ru': 'Бухгалтер', 'en': 'Accountant', 'uz': 'Buxgalter'});

  String get passStatusSignedByDirector => _t({
    'ru': 'Подписан руководителем',
    'en': 'Signed by director',
    'uz': 'Rahbar tomonidan imzolangan',
  });

  String get passStatusDirector =>
      _t({'ru': 'Руководитель', 'en': 'Director', 'uz': 'Rahbar'});

  String get passStatusCompleted =>
      _t({'ru': 'Завершён', 'en': 'Completed', 'uz': 'Tugallangan'});

  String get passStatusShortDir =>
      _t({'ru': 'Рук-ль', 'en': 'Dir.', 'uz': 'Rah.'});

  String passStatusWithCode(String code) =>
      _t({'ru': 'Статус $code', 'en': 'Status $code', 'uz': 'Holat $code'});

  // Passes Dialog Actions
  String get confirmPass => _t({
    'ru': 'Подтвердить пропуск',
    'en': 'Confirm pass',
    'uz': 'Ruxsatnomani tasdiqlash',
  });

  String confirmPassNumber(String number) => _t({
    'ru': 'Подтвердить $number?',
    'en': 'Confirm $number?',
    'uz': '$number ni tasdiqlash?',
  });

  String get cancelPass => _t({
    'ru': 'Отменить пропуск',
    'en': 'Cancel pass',
    'uz': 'Ruxsatnomani bekor qilish',
  });

  String cancelPassMessage(String number) => _t({
    'ru': '$number будет отменён. Только создатель может отменить.',
    'en': '$number will be cancelled. Only the creator can cancel.',
    'uz': '$number bekor qilinadi. Faqat yaratuvchi bekor qila oladi.',
  });

  String cancelPassMessageShort(String number) => _t({
    'ru': '$number будет отменён.',
    'en': '$number will be cancelled.',
    'uz': '$number bekor qilinadi.',
  });

  String get cancelBtn =>
      _t({'ru': 'Отменить', 'en': 'Cancel', 'uz': 'Bekor qilish'});

  String get rejectPass => _t({
    'ru': 'Отклонить пропуск',
    'en': 'Reject pass',
    'uz': 'Ruxsatnomani rad etish',
  });

  String get rejectionReasonHint => _t({
    'ru': 'Причина отклонения...',
    'en': 'Rejection reason...',
    'uz': 'Rad etish sababi...',
  });

  String get passRejected => _t({
    'ru': 'Пропуск отклонён',
    'en': 'Pass rejected',
    'uz': 'Ruxsatnoma rad etildi',
  });

  String get passCancelled => _t({
    'ru': 'Пропуск отменён',
    'en': 'Pass cancelled',
    'uz': 'Ruxsatnoma bekor qilindi',
  });

  String get passConfirmed => _t({
    'ru': 'Пропуск подтверждён',
    'en': 'Pass confirmed',
    'uz': 'Ruxsatnoma tasdiqlandi',
  });

  // Passes Action Buttons
  String get issue => _t({'ru': 'Выдать', 'en': 'Issue', 'uz': 'Chiqarish'});

  String get accountantSign => _t({
    'ru': 'Бухгалтер: подписать',
    'en': 'Accountant: sign',
    'uz': 'Buxgalter: imzolash',
  });

  String get directorSign => _t({
    'ru': 'Руководитель: подписать',
    'en': 'Director: sign',
    'uz': 'Rahbar: imzolash',
  });

  String get securitySign => _t({
    'ru': 'Охрана: подписать',
    'en': 'Security: sign',
    'uz': 'Xavfsizlik: imzolash',
  });

  String get signAccountant => _t({
    'ru': 'Подписать (Бухгалтер)',
    'en': 'Sign (Accountant)',
    'uz': 'Imzolash (Buxgalter)',
  });

  String get signDirector => _t({
    'ru': 'Подписать (Руководитель)',
    'en': 'Sign (Director)',
    'uz': 'Imzolash (Rahbar)',
  });

  String get signSecurity => _t({
    'ru': 'Подписать (Охрана)',
    'en': 'Sign (Security)',
    'uz': 'Imzolash (Xavfsizlik)',
  });

  // Passes Info Labels
  String get client => _t({'ru': 'Клиент', 'en': 'Client', 'uz': 'Mijoz'});

  String get factoryLabel2 =>
      _t({'ru': 'Фабрика', 'en': 'Factory', 'uz': 'Fabrika'});

  String get createdByLabel2 =>
      _t({'ru': 'Создал', 'en': 'Created by', 'uz': 'Yaratdi'});

  String get reasonLabel =>
      _t({'ru': 'Причина', 'en': 'Reason', 'uz': 'Sabab'});

  String get passTitle =>
      _t({'ru': 'Пропуск', 'en': 'Pass', 'uz': 'Ruxsatnoma'});

  String get retry =>
      _t({'ru': 'Повторить', 'en': 'Retry', 'uz': 'Qayta urinish'});

  String reasonWithText(String text) =>
      _t({'ru': 'Причина: $text', 'en': 'Reason: $text', 'uz': 'Sabab: $text'});

  // Passes View Tabs
  String get forSigning =>
      _t({'ru': 'На подпись', 'en': 'For signing', 'uz': 'Imzo uchun'});

  String get my => _t({'ru': 'Мои', 'en': 'My', 'uz': 'Mening'});

  // Passes Detail Labels
  String get information =>
      _t({'ru': 'Информация', 'en': 'Information', 'uz': "Ma'lumot"});

  String get numberLabel => _t({'ru': 'Номер', 'en': 'Number', 'uz': 'Raqam'});

  String get dateLabel2 => _t({'ru': 'Дата', 'en': 'Date', 'uz': 'Sana'});

  String get typeLabel => _t({'ru': 'Тип', 'en': 'Type', 'uz': 'Turi'});

  String get warehouseLabel =>
      _t({'ru': 'Склад', 'en': 'Warehouse', 'uz': 'Ombor'});

  String get createdLabel =>
      _t({'ru': 'Создан', 'en': 'Created', 'uz': 'Yaratilgan'});

  String get kppLabel => _t({'ru': 'КПП', 'en': 'Checkpoint', 'uz': 'Karaxon'});

  String get autoIncoming =>
      _t({'ru': 'Авто-приход', 'en': 'Auto incoming', 'uz': 'Avtokirish'});

  String get autoOutgoing =>
      _t({'ru': 'Авто-расход', 'en': 'Auto outgoing', 'uz': 'Avtoketish'});

  String itemsCountLabel(int count) => _t({
    'ru': 'Позиции ($count)',
    'en': 'Items ($count)',
    'uz': 'Pozitsiyalar ($count)',
  });

  String get noItems =>
      _t({'ru': 'Нет позиций', 'en': 'No items', 'uz': "Pozitsiyalar yo'q"});

  String get releasedBy =>
      _t({'ru': 'Отпустил', 'en': 'Released by', 'uz': 'Chiqardi'});

  String get chiefAccountant => _t({
    'ru': 'Гл. бухгалтер',
    'en': 'Chief accountant',
    'uz': 'Bosh buxgalter',
  });

  String get signatureHistory => _t({
    'ru': 'История подписей',
    'en': 'Signature history',
    'uz': 'Imzo tarixi',
  });

  String get notesSection =>
      _t({'ru': 'Примечания', 'en': 'Notes', 'uz': 'Izohlar'});

  String get noteSingle => _t({'ru': 'Примечание', 'en': 'Note', 'uz': 'Izoh'});

  String get rejectionReason => _t({
    'ru': 'Причина отклонения',
    'en': 'Rejection reason',
    'uz': 'Rad etish sababi',
  });

  String get arrivalDate =>
      _t({'ru': 'Дата прихода', 'en': 'Arrival date', 'uz': 'Kelish sanasi'});

  // Passes Progress Steps
  String get progressNew => _t({'ru': 'Новый', 'en': 'New', 'uz': 'Yangi'});

  String get progressIssued =>
      _t({'ru': 'Выдан', 'en': 'Issued', 'uz': 'Berildi'});

  String get progressCompleted =>
      _t({'ru': 'Завершён', 'en': 'Completed', 'uz': 'Tugallangan'});

  // Sign Requests
  String get searchHintSignRequests => _t({
    'ru': 'Поиск по заявке, заявителю, отделу...',
    'en': 'Search by request, applicant, department...',
    'uz': "Ariza, arizachi, bo'lim bo'yicha qidirish...",
  });

  String get filterForSigning =>
      _t({'ru': 'На подписи', 'en': 'For signing', 'uz': 'Imzo uchun'});

  String get positions =>
      _t({'ru': 'позиций', 'en': 'items', 'uz': 'pozitsiya'});

  String get awaitingLabel =>
      _t({'ru': 'ожидают', 'en': 'awaiting', 'uz': 'kutilmoqda'});

  String get quantity =>
      _t({'ru': 'Количество', 'en': 'Quantity', 'uz': 'Miqdor'});

  String get costLabel => _t({'ru': 'Стоимость', 'en': 'Cost', 'uz': 'Narx'});

  String get tapToViewMaterials => _t({
    'ru': 'Нажмите для просмотра материалов',
    'en': 'Tap to view materials',
    'uz': "Materiallarni ko'rish uchun bosing",
  });

  String get requestInfo => _t({
    'ru': 'Информация о заявке',
    'en': 'Request information',
    'uz': 'Ariza haqida malumot',
  });

  // Bonuses Status Labels
  String get bonusStatusNew => _t({'ru': 'Новый', 'en': 'New', 'uz': 'Yangi'});

  String get bonusStatusUnderReview =>
      _t({'ru': 'На проверке', 'en': 'Under review', 'uz': 'Tekshirilmoqda'});

  String get bonusStatusReview =>
      _t({'ru': 'Проверка', 'en': 'Review', 'uz': 'Tekshirish'});

  String get bonusStatusApproved =>
      _t({'ru': 'Одобрен', 'en': 'Approved', 'uz': 'Tasdiqlangan'});

  String get bonusStatusConfirmed =>
      _t({'ru': 'Утверждён', 'en': 'Confirmed', 'uz': 'Tasdiqlangan'});

  String get bonusStatusPaid =>
      _t({'ru': 'Оплачен', 'en': 'Paid', 'uz': "To'langan"});

  // Bonuses
  String get bonusSearchHint => _t({
    'ru': 'Фабрика, месяц, создатель',
    'en': 'Factory, month, creator',
    'uz': "Fabrika, oy, yaratuvchi",
  });

  String get noRecordsForSigning => _t({
    'ru': 'Нет записей, требующих подписи',
    'en': 'No records requiring signature',
    'uz': "Imzo talab qilinadigan yozuvlar yo'q",
  });

  String get bonusListEmpty => _t({
    'ru': 'Список премий пуст',
    'en': 'Bonus list is empty',
    'uz': "Mukofotlar ro'yxati bo'sh",
  });

  String employeesCountLabel(int count) => _t({
    'ru': 'Сотрудники ($count)',
    'en': 'Employees ($count)',
    'uz': 'Xodimlar ($count)',
  });

  String get noEmployees => _t({
    'ru': 'Нет сотрудников',
    'en': 'No employees',
    'uz': "Xodimlar yo'q",
  });

  String get verifiedBy =>
      _t({'ru': 'Проверил', 'en': 'Verified by', 'uz': 'Tekshirdi'});

  String get approvedByDeputy => _t({
    'ru': 'Одобрил (зам.)',
    'en': 'Approved (deputy)',
    'uz': "Tasdiqladi (o'rinbosar)",
  });

  String get confirmedByGeneral => _t({
    'ru': 'Утвердил (ген.)',
    'en': 'Confirmed (general)',
    'uz': 'Tasdiqladi (bosh)',
  });

  String get paidBy => _t({'ru': 'Оплатил', 'en': 'Paid by', 'uz': "To'ladi"});

  String withTaxAmount(String amount) => _t({
    'ru': 'С нал.: $amount',
    'en': 'With tax: $amount',
    'uz': 'Soliq bilan: $amount',
  });

  String tabNumberLabel(String number) =>
      _t({'ru': 'Таб: $number', 'en': 'Card: $number', 'uz': 'Karta: $number'});

  // Menu / Access
  String get accessRestricted => _t({
    'ru': 'Доступ ограничен',
    'en': 'Access restricted',
    'uz': "Kirish cheklangan",
  });

  String get noAccessMessage => _t({
    'ru':
        'У вас нет доступа ни к одному разделу.\nОбратитесь к администратору.',
    'en': "You don't have access to any section.\nContact the administrator.",
    'uz':
        "Hech qanday bo'limga kirish huquqingiz yo'q.\nAdministrator bilan bog'laning.",
  });

  // Main Page tooltips
  String get openTooltip => _t({'ru': 'Открыть', 'en': 'Open', 'uz': 'Ochish'});

  String get copyTooltip =>
      _t({'ru': 'Копировать', 'en': 'Copy', 'uz': 'Nusxalash'});

  // Error messages
  String errorWithCode(int code) =>
      _t({'ru': 'Ошибка ($code)', 'en': 'Error ($code)', 'uz': 'Xato ($code)'});

  String errorWithMessage(String e) =>
      _t({'ru': 'Ошибка: $e', 'en': 'Error: $e', 'uz': 'Xato: $e'});

  String connectionErrorMessage(String e) => _t({
    'ru': 'Ошибка подключения:\n$e',
    'en': 'Connection error:\n$e',
    'uz': 'Ulanish xatosi:\n$e',
  });

  // App self-update (Android sideload, outside Google Play)
  String get appUpdateAvailableTitle => _t({
    'ru': 'Доступно обновление',
    'en': 'Update available',
    'uz': 'Yangilanish mavjud',
  });

  String appUpdateVersionLabel(String version) => _t({
    'ru': 'Версия $version',
    'en': 'Version $version',
    'uz': 'Versiya $version',
  });

  String get appUpdateCriticalNotice => _t({
    'ru':
        'Это обновление обязательно — без него дальнейшая работа с приложением невозможна',
    'en':
        'This update is mandatory — the app cannot be used further without it',
    'uz':
        "Bu yangilanish majburiy — usiz ilova bilan ishlashni davom ettirib bo'lmaydi",
  });

  String get appUpdateDownloadButton => _t({
    'ru': 'Скачать и установить',
    'en': 'Download & install',
    'uz': "Yuklab olish va o'rnatish",
  });

  String get appUpdateOpenStoreButton =>
      _t({'ru': 'Обновить', 'en': 'Update', 'uz': 'Yangilash'});

  String get appUpdateStoreOpenFailed => _t({
    'ru':
        'Не удалось открыть App Store. Обновите приложение в App Store вручную',
    'en': 'Could not open the App Store. Please update the app there manually',
    'uz': "App Store'ni ochib bo'lmadi. Ilovani App Store'da qo'lda yangilang",
  });

  String get appUpdateDownloadFailed => _t({
    'ru': 'Не удалось скачать обновление. Проверьте подключение к интернету',
    'en': 'Failed to download the update. Check your internet connection',
    'uz': "Yangilanishni yuklab bo'lmadi. Internet ulanishini tekshiring",
  });

  String get appUpdateInstallPermissionDenied => _t({
    'ru':
        'Разрешите установку из этого источника в настройках телефона и попробуйте снова',
    'en':
        'Allow installs from this source in your phone settings and try again',
    'uz':
        "Telefon sozlamalarida ushbu manbadan o'rnatishga ruxsat bering va qayta urinib ko'ring",
  });

  String get appUpdateInstallFailed => _t({
    'ru': 'Не удалось запустить установку',
    'en': 'Failed to start the installation',
    'uz': "O'rnatishni boshlab bo'lmadi",
  });

  // My timesheet (individual attendance calendar)
  String get timesheetTitle =>
      _t({'ru': 'Мой табель', 'en': 'My timesheet', 'uz': 'Mening tabelim'});
  String get timesheetDesc => _t({
    'ru': 'Отработанные часы и дни по месяцам',
    'en': 'Worked hours and days by month',
    'uz': 'Oylar kesimida ishlangan soat va kunlar',
  });
  String get timesheetHours => _t({'ru': 'Часов', 'en': 'Hours', 'uz': 'Soat'});
  String get timesheetDays => _t({'ru': 'Дней', 'en': 'Days', 'uz': 'Kun'});
  String get timesheetAbsent =>
      _t({'ru': 'Прогулы', 'en': 'Absences', 'uz': 'Kelmagan kunlar'});
  String get timesheetLegendWorked =>
      _t({'ru': 'Отработано', 'en': 'Worked', 'uz': 'Ishlangan'});
  String get timesheetLegendPresent => _t({
    'ru': 'Нет выхода',
    'en': 'No exit mark',
    'uz': 'Chiqish belgisi yo\'q',
  });
  String get timesheetLegendAbsent =>
      _t({'ru': 'Нет отметок', 'en': 'No marks', 'uz': 'Belgi yo\'q'});
  String get timesheetLegendOff =>
      _t({'ru': 'Выходной', 'en': 'Day off', 'uz': 'Dam olish'});
  String get timesheetEntry => _t({'ru': 'Вход', 'en': 'In', 'uz': 'Kirish'});
  String get timesheetExit => _t({'ru': 'Выход', 'en': 'Out', 'uz': 'Chiqish'});
  String get timesheetNight =>
      _t({'ru': 'Ночных', 'en': 'Night', 'uz': 'Tungi'});
  String get timesheetDayShift =>
      _t({'ru': 'Дневных', 'en': 'Day', 'uz': 'Kunduzgi'});
  String get timesheetEdit =>
      _t({'ru': 'Изменить', 'en': 'Edit', 'uz': 'Tahrirlash'});
  String get timesheetSave =>
      _t({'ru': 'Сохранить', 'en': 'Save', 'uz': 'Saqlash'});
  String get timesheetEditTitle => _t({
    'ru': 'Правка посещаемости',
    'en': 'Edit attendance',
    'uz': 'Davomatni tahrirlash',
  });
  String get timesheetExitBeforeEntry => _t({
    'ru': 'Выход должен быть позже входа',
    'en': 'Exit must be later than entry',
    'uz': 'Chiqish kirishdan keyin bo‘lishi kerak',
  });
  String get timesheetTimeFormat => _t({
    'ru': 'Введите время как ЧЧ:ММ, например 09:05',
    'en': 'Enter time as HH:MM, e.g. 09:05',
    'uz': 'Vaqtni SS:DD ko‘rinishida kiriting, masalan 09:05',
  });
  String get timesheetSaveError => _t({
    'ru': 'Не удалось сохранить',
    'en': 'Could not save',
    'uz': 'Saqlab bo‘lmadi',
  });
  String get timesheetNoEmployee => _t({
    'ru': 'Ваш пользователь не привязан к сотруднику',
    'en': 'Your user is not linked to an employee',
    'uz': 'Foydalanuvchingiz xodimga biriktirilmagan',
  });
  static const _monthsRu = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  static const _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _monthsUz = [
    'Yanvar',
    'Fevral',
    'Mart',
    'Aprel',
    'May',
    'Iyun',
    'Iyul',
    'Avgust',
    'Sentabr',
    'Oktabr',
    'Noyabr',
    'Dekabr',
  ];
  static const _weekdaysRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _weekdaysEn = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  static const _weekdaysUz = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  /// [month] is 1-based.
  String monthName(int month) => _t({
    'ru': _monthsRu[month - 1],
    'en': _monthsEn[month - 1],
    'uz': _monthsUz[month - 1],
  });

  /// [weekday] is 0-based, Monday first.
  String weekdayShort(int weekday) => _t({
    'ru': _weekdaysRu[weekday],
    'en': _weekdaysEn[weekday],
    'uz': _weekdaysUz[weekday],
  });
}
