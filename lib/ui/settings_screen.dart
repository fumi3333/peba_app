import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_picker_screen.dart';
import 'log_history_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _wageController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final wage = prefs.getInt('hourly_wage') ?? 1500;
    _wageController.text = wage.toString();
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final wage = int.tryParse(_wageController.text) ?? 1500;
    await prefs.setInt('hourly_wage', wage);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              _buildSectionHeader('基本設定'),
              ListTile(
                leading: const Icon(Icons.currency_yen),
                title: const Text('時給'),
                subtitle: const Text('残業代計算の基礎となる時給を設定します'),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _wageController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.end,
                    decoration: const InputDecoration(
                      suffixText: '円',
                      border: InputBorder.none,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('勤務地設定'),
                subtitle: const Text('地図上で勤務場所を指定します'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LocationPickerScreen()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('勤務記録履歴'),
                subtitle: const Text('過去のログと未収額の詳細を確認'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogHistoryScreen()),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('保存する'),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
