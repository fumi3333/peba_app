import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../features/logging/log_repository.dart';

class LogHistoryScreen extends ConsumerWidget {
  const LogHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logStream = ref.watch(logRepositoryProvider).getLogStream();

    return Scaffold(
      appBar: AppBar(title: const Text('記録履歴')),
      body: StreamBuilder(
        stream: logStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text('まだ記録がありません'));
          }

          final docs = snapshot.data!.docs;
          // Group by Date (YYYY-MM-DD)
          final Map<String, List<DocumentSnapshot>> grouped = {};
          
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
            
            if (grouped[dateKey] == null) grouped[dateKey] = [];
            grouped[dateKey]!.add(doc);
          }

          final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // Descending

          return ListView.builder(
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final dateKey = sortedKeys[index];
              final dayLogs = grouped[dateKey]!;
              
              // Calculate daily summary
              final hours = dayLogs.length * 0.25; // 15 min per log
              
              // Calculate money using each log's hourlyWage if available
              int totalMoney = 0;
              for (var log in dayLogs) {
                 final data = log.data() as Map<String, dynamic>;
                 final wage = data['hourly_wage'] as int? ?? 1500; // Fallback
                 totalMoney += (wage * 0.25).round();
              }
              
              final dateLabel = DateFormat('M月d日 (E)', 'ja_JP').format(DateTime.parse(dateKey));

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 1,
                child: ExpansionTile(
                  title: Text(
                    dateLabel, 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('稼働: ${hours.toStringAsFixed(2)}h / 推定: ¥$totalMoney'),
                  children: dayLogs.map((log) {
                     final data = log.data() as Map<String, dynamic>;
                     final time = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                     final note = data['note'] ?? '';
                     final wage = data['hourly_wage'] ?? 1500;
                     
                     return ListTile(
                       dense: true,
                       leading: const Icon(Icons.access_time, size: 16),
                       title: Text(DateFormat('HH:mm').format(time)),
                       subtitle: Text('$note (時給 @$wage)'),
                       trailing: const Icon(Icons.check_circle, size: 14, color: Colors.green),
                     );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
