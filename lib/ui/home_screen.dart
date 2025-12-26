import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart'; 
import '../features/auth/auth_service.dart';
import '../features/logging/log_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Mock settings for MVP
  final double hourlyWage = 1500; 
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'ja_JP', symbol: '¥');

  @override
  void initState() {
    super.initState();
    ref.read(authServiceProvider).signInAnonymously();
  }

  Future<void> _setWorkplace() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('work_lat', position.latitude);
    await prefs.setDouble('work_lng', position.longitude);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('勤務地を更新しました。エリア内での滞在を記録します。'), 
          backgroundColor: Color(0xFF1A237E),
        ), 
      );
    }
    
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      service.startService();
    }
  }

  Future<void> _onRecordLogPressed() async {
    final position = await Geolocator.getCurrentPosition();
    await ref.read(logRepositoryProvider).logEntry(
      latitude: position.latitude, 
      longitude: position.longitude, 
      isMock: position.isMocked,
      note: 'MANUAL_ENTRY'
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('勤務ログを記録しました。'), 
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onCashOutPressed() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('One-Click Action'),
        content: const Text('【請求書類自動生成】\n\n現在、あなたのログに基づいた「請求通知書」と「計算書」をプレビューする機能を準備中です。\n(法的効力のあるPDFをワンクリックで生成・郵送します)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logStream = ref.watch(logRepositoryProvider).getLogStream();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PAYBACK', 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _setWorkplace,
            tooltip: '勤務地設定',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Asset Card
                _buildAssetCard(logStream),

                const SizedBox(height: 32),

                // 2. Action Buttons
                _buildActionButtons(),

                const SizedBox(height: 32),
                
                // 3. Info / Cash Out
                _buildCashOutCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssetCard(Stream<dynamic> logStream) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26), // approx 0.1 opacity
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '推定未収残高',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder(
            stream: logStream,
            builder: (context, snapshot) {
              int amount = 0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                 final docs = snapshot.data!.docs;
                 double totalHours = docs.length * 0.25; 
                 amount = (totalHours * hourlyWage).round();
              }
              
              return Text(
                currencyFormat.format(amount),
                style: const TextStyle(
                  color: Color(0xFF1A237E), // Navy
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                  fontFamily: 'RobotoMono', // Ensure monospace-ish feel if available
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Silent Evidence (自動証拠収集) 稼働中',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _onRecordLogPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E), // Navy
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_task),
            label: const Text(
              '勤務ログを記録',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCashOutCard() {
    return InkWell(
      onTap: _onCashOutPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6), // Light Indigo
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC5CAE9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gavel, color: Color(0xFF1A237E)), // Gavel for Legal Action
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '請求書類を作成',
                    style: TextStyle(
                      color: Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'One-Click Action (弁護士監修PDF)',
                    style: TextStyle(
                      color: Color(0xFF3949AB),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF1A237E)),
          ],
        ),
      ),
    );
  }
}
