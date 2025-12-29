import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'features/tracking/tracking_service.dart';
import 'ui/home_screen.dart';
import 'firebase_options.dart';

/// アプリのエントリーポイント（開始地点）です。
void main() async {
  // Flutterのウィジェットシステムとエンジンを結合（バインド）し、初期化します。
  // これを呼び出さないと、非同期処理やプラットフォームチャネル（ネイティブ機能へのアクセス）が使えません。
  WidgetsFlutterBinding.ensureInitialized();
  
  String? errorMessage;
  
  // 1. Firebaseの初期化を試みます (タイムアウト5秒)
  // FirebaseはGoogleが提供するバックエンドサービス（データベースや認証など）です。
  try {
    await Firebase.initializeApp(
      // 現在のプラットフォーム（Android/iOS/Webなど）に合わせた設定を使用します。
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    errorMessage = "Firebase 初期化失敗: $e";
  }
  
  // 2. バックグラウンドサービスの初期化を試みます
  // Firebaseが成功した場合のみ実行します。ログ保存にFirebaseが必要なためです。
  if (errorMessage == null) {
      try {
        // TrackingServiceは位置情報などをバックグラウンド（アプリが閉じていても）で記録する自作クラスです。
        await TrackingService.initialize().timeout(const Duration(seconds: 3));
      } catch (e) {
        // サービス起動失敗はUI表示には致命的ではないため、警告ログを出して続行します。
        print("WARNING: Background Service Init Failed: $e");
      }
  }

  if (errorMessage != null) {
      print("CRITICAL: $errorMessage");
      print("Bypassing error to show UI...");
  }
  
  // デザイン確認のためにUIを強制的に起動します。
  // ProviderScope: Riverpod（状態管理ライブラリ）の管理範囲を定義するラッパー（包むもの）です。
  // これがないと、アプリ内でRiverpodを使ったデータの受け渡しができません。
  runApp(const ProviderScope(child: PebaApp()));
}

/// エラー発生時に表示する、簡易的なエラー画面のウィジェット（UI部品）です。
///
/// [StatelessWidget]: 状態を持たない（動的に変化しない）静的なウィジェットの基底クラス（親クラス）です。
/// 一度描画されたら、親から新しい情報をもらわない限り変化しません。
class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  // buildメソッド: ウィジェットの見た目（UI）を構築して返すメソッドです。
  // [BuildContext]: ウィジェットツリー（UIの階層構造）内での、このウィジェットの位置情報を持つオブジェクトです。
  Widget build(BuildContext context) {
    // MaterialApp: マテリアルデザイン（Google推奨のデザインシステム）の機能を提供するルートウィジェットです。
    return MaterialApp(
      // Scaffold: アプリの標準的なレイアウト構造（AppBar, Body, FloatingActionButtonなど）を提供する土台となるウィジェットです。
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center( // Center: 子要素を中央揃えにするレイアウト用ウィジェットです。
          child: Padding( // Padding: 余白（隙間）を作るためのウィジェットです。
            padding: const EdgeInsets.all(24.0),
            child: Column( // Column: 子要素を縦方向に並べるレイアウト用ウィジェットです。
              mainAxisAlignment: MainAxisAlignment.center, // 縦方向の中央に配置します。
              children: [
                // Icon: アイコンを表示するウィジェットです。
                const Icon(Icons.error_outline, size: 64, color: Colors.white),
                // SizedBox: 固定サイズの空白（スペース）を作るウィジェットです。ここでは高さ16の隙間を作っています。
                const SizedBox(height: 16),
                // Text: 文字列を表示するウィジェットです。
                const Text("初期化エラー", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), 
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// アプリ全体のルート（根幹）となるウィジェットです。
class PebaApp extends StatelessWidget {
  const PebaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PAYBACK',
      // ThemeData: アプリ全体のテーマ（色、フォント、ボタンスタイルなど）を一括定義するデータです。
      theme: ThemeData(
        brightness: Brightness.light, // ライトモード（明るい画面）を指定
        primaryColor: const Color(0xFF1A237E), // メインカラー：Indigo 900 (Navy)
        scaffoldBackgroundColor: const Color(0xFFF5F5F7), // 背景色：Light Grey (macOS/iOS風)
        // ColorScheme: アプリで使用する色のセットを定義します。
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF1A237E), 
          secondary: const Color(0xFF3949AB),
        ),
        // AppBarTheme: ヘッダーバー（AppBar）のスタイル定義です。
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A237E),
          elevation: 0, // 影をなくしてフラットにします。
        ),
        useMaterial3: true, // 最新のマテリアルデザイン3（M3）を有効にします。
      ),
      home: const HomeScreen(), // 最初に表示する画面を指定します。
    );
  }
}
