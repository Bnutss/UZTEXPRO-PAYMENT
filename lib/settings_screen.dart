import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'confidentiality_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  final Map<String, bool> _expandedSections = {
    'account': false,
    'appearance': false,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        title: const Text(
          "Настройки",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () {
            Navigator.of(context).pop();
          },
          splashRadius: 24,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
            onPressed: () {
              _showAboutDialog();
            },
            tooltip: 'О приложении',
            splashRadius: 24,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _animation,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildProfileCard(),
            const SizedBox(height: 24),
            _buildSectionHeader("Основные настройки"),
            _buildSettingButton(
              Icons.notifications_active,
              "Уведомления",
              "Управление уведомлениями приложения",
              const Color(0xFF1976D2),
              onTap: () {},
            ),
            _buildSettingButton(
              Icons.security,
              "Безопасность",
              "Настройки безопасности и конфиденциальности",
              const Color(0xFF43A047),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfidentialityPage(),
                  ),
                );
              },
            ),
            _buildSettingButton(
              Icons.language,
              "Язык",
              "Выбор языка интерфейса приложения",
              const Color(0xFFEF6C00),
              onTap: () {
                _showLanguageDialog();
              },
            ),
            const SizedBox(height: 16),
            _buildSectionHeader("Внешний вид"),
            _buildExpandableSection(
              'appearance',
              [
                _buildSettingButton(
                  Icons.palette,
                  "Тема",
                  "Светлая или темная тема приложения",
                  const Color(0xFF7B1FA2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  onTap: () {},
                ),
                _buildSettingButton(
                  Icons.text_fields,
                  "Размер текста",
                  "Настройка размера шрифта приложения",
                  const Color(0xFF0097A7),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionHeader("Аккаунт"),
            _buildExpandableSection(
              'account',
              [
                _buildSettingButton(
                  Icons.person,
                  "Профиль",
                  "Управление данными профиля",
                  const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  onTap: () {},
                ),
                _buildSettingButton(
                  Icons.sync,
                  "Синхронизация",
                  "Настройки синхронизации данных",
                  const Color(0xFF5E35B1),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionHeader("Поддержка"),
            _buildSettingButton(
              Icons.help_outline,
              "Помощь",
              "Часто задаваемые вопросы и руководство",
              const Color(0xFFC62828),
              onTap: () {},
            ),
            _buildSettingButton(
              Icons.feedback,
              "Обратная связь",
              "Отправить отзыв разработчикам",
              const Color(0xFF455A64),
              onTap: () {},
            ),
            const SizedBox(height: 24),
            _buildVersionInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "U",
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "UZTEXPRO",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Платежная система",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  splashRadius: 24,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Бизнес-аккаунт",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection(String sectionKey, List<Widget> children) {
    bool isExpanded = _expandedSections[sectionKey] ?? false;

    return Column(
      children: [
        InkWell(
          onTap: () => _toggleSection(sectionKey),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.remove : Icons.add,
                  size: 20,
                  color: const Color(0xFFFF9800),
                ),
                const SizedBox(width: 8),
                Text(
                  isExpanded ? "Скрыть детали" : "Показать детали",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isExpanded ? null : 0,
          child: isExpanded ? Column(children: children) : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildSettingButton(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor, {
    required VoidCallback onTap,
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: 8),
  }) {
    return Padding(
      padding: padding,
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              "Версия приложения: 1.2.5",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF6C00).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.language,
                        color: Color(0xFFEF6C00),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "Выбор языка",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLanguageOption("Русский", "Русский язык", true),
                _buildLanguageOption("English", "English language", false),
                _buildLanguageOption("O'zbekcha", "O'zbek tili", false),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        "ОТМЕНА",
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      child: const Text(
                        "СОХРАНИТЬ",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
      String language, String description, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFF9800).withOpacity(0.1)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF9800) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: RadioListTile(
        title: Text(
          language,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFFFF9800) : Colors.black87,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        value: isSelected,
        groupValue: true,
        activeColor: const Color(0xFFFF9800),
        onChanged: (value) => Navigator.of(context).pop(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "U",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "UZTEXPRO PAYMENT",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Версия 1.2.5",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        "© 2025 UZTEXPRO MOBILE APP.",
                        style: TextStyle(fontSize: 13),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Все права защищены. Приложение предназначено для управления платежными договорами.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "ЗАКРЫТЬ",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
