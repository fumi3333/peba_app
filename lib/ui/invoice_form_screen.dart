import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'invoice_generator.dart';
import 'package:printing/printing.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form Fields
  final _companyNameController = TextEditingController();
  final _bossNameController = TextEditingController(); // Representative
  final _userNameController = TextEditingController();
  
  // Settings
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('請求書類作成')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('請求先情報'),
              TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(
                  labelText: '会社名',
                  hintText: '株式会社ブラック興業',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? '必須項目です' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bossNameController,
                decoration: const InputDecoration(
                  labelText: '代表者名 (社長など)',
                  hintText: '代表取締役 山田 太郎',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? '必須項目です' : null,
              ),

              const SizedBox(height: 32),
              _buildHeader('あなたの情報'),
              TextFormField(
                controller: _userNameController,
                decoration: const InputDecoration(
                  labelText: '氏名',
                  hintText: '鈴木 一郎',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? '必須項目です' : null,
              ),

              const SizedBox(height: 32),
              _buildHeader('請求対象期間'),
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      label: '開始日', 
                      date: _startDate, 
                      onPicked: (d) => setState(() => _startDate = d),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.arrow_forward),
                  ),
                  Expanded(
                    child: _buildDatePicker(
                      label: '終了日', 
                      date: _endDate, 
                      onPicked: (d) => setState(() => _endDate = d),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: _generateAndPreview,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('書類を生成してプレビュー'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title, 
        style: TextStyle(
          color: Theme.of(context).primaryColor, 
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildDatePicker({
    required String label, 
    required DateTime date, 
    required ValueChanged<DateTime> onPicked
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(DateFormat('yyyy/MM/dd').format(date)),
      ),
    );
  }

  Future<void> _generateAndPreview() async {
    if (_formKey.currentState!.validate()) {
      // Show loading
      showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()));

      try {
        // Collect Data
        final invoiceData = InvoiceData(
          companyName: _companyNameController.text,
          bossName: _bossNameController.text,
          userName: _userNameController.text,
          startDate: _startDate,
          endDate: _endDate,
        );

        // Generate PDF
        final bytes = await InvoiceGenerator.generate(invoiceData); // Logic to implement next

        Navigator.pop(context); // Close loading

        // Preview
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: '請求通知書_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        );

      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    }
  }
}

// Data Model
class InvoiceData {
  final String companyName;
  final String bossName;
  final String userName;
  final DateTime startDate;
  final DateTime endDate;

  InvoiceData({
    required this.companyName,
    required this.bossName,
    required this.userName,
    required this.startDate,
    required this.endDate,
  });
}
