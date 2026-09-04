import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/config/backend_config.dart';
import '../../../shared/services/supabase_auth_service.dart';

/// Payment status states.
enum PaymentStatus {
  pending,
  processing,
  successful,
  failed,
  refunded,
  cancelled,
}

/// A payment transaction record.
class PaymentTransaction {
  final String id;
  final String orderId;
  final double amount;
  final String currency;
  final String method; // 'upi', 'card', 'netbanking', 'cash'
  final PaymentStatus status;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? razorpaySignature;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? completedAt;

  const PaymentTransaction({
    required this.id,
    required this.orderId,
    required this.amount,
    this.currency = 'INR',
    required this.method,
    required this.status,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.razorpaySignature,
    this.failureReason,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'orderId': orderId,
        'amount': amount,
        'currency': currency,
        'method': method,
        'status': status.name,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpaySignature': razorpaySignature,
        'failureReason': failureReason,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) => PaymentTransaction(
        id: map['id'] ?? '',
        orderId: map['orderId'] ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        currency: map['currency'] ?? 'INR',
        method: map['method'] ?? 'cash',
        status: PaymentStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => PaymentStatus.pending,
        ),
        razorpayPaymentId: map['razorpayPaymentId'],
        razorpayOrderId: map['razorpayOrderId'],
        razorpaySignature: map['razorpaySignature'],
        failureReason: map['failureReason'],
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        completedAt: map['completedAt'] != null ? DateTime.tryParse(map['completedAt']) : null,
      );
}

/// Result of a payment operation.
class PaymentResult {
  final bool success;
  final String message;
  final PaymentTransaction? transaction;

  const PaymentResult({
    required this.success,
    required this.message,
    this.transaction,
  });
}

/// Payment Gateway Service for processing online payments.
///
/// Supports:
/// - Razorpay integration for UPI/Card/Net-Banking
/// - Cash payment recording
/// - Payment status tracking
/// - Receipt generation
///
/// To use Razorpay:
/// 1. Add `razorpay_flutter` to pubspec.yaml
/// 2. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET in .env
/// 3. Initialize with `PaymentGatewayService.instance.configure(razorpayKey: '...')`
class PaymentGatewayService {
  PaymentGatewayService._();

  static final PaymentGatewayService instance = PaymentGatewayService._();

  bool _isConfigured = false;

  /// Configures the payment gateway with API keys.
  void configure({String? razorpayKey}) {
    _isConfigured = razorpayKey != null && razorpayKey.isNotEmpty;
  }

  bool get isConfigured => _isConfigured;

  /// Creates a Razorpay order for a given amount.
  ///
  /// Returns the order ID to be used in the frontend checkout.
  Future<PaymentResult> createOrder({
    required double amount,
    required String receiptId,
    String currency = 'INR',
  }) async {
    if (!_isConfigured) {
      return const PaymentResult(
        success: false,
        message: 'Payment gateway not configured. Contact administrator.',
      );
    }

    try {
      final anonKey = BackendConfig.supabaseAnonKey ?? '';
      final jwtToken = await SupabaseAuthService.instance.getValidAccessToken();

      if (jwtToken == null) {
        return const PaymentResult(
          success: false,
          message: 'Authentication required. Please log in again.',
        );
      }

      // Call Supabase Edge Function to create Razorpay order
      // (server-side to keep API secret secure)
      final res = await http.post(
        Uri.parse('${BackendConfig.supabaseUrl}/functions/v1/create-razorpay-order'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': (amount * 100).toInt(), // Razorpay expects paise
          'currency': currency,
          'receipt': receiptId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final orderId = data['id'] as String?;

        if (orderId != null) {
          final transaction = PaymentTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            orderId: orderId,
            amount: amount,
            currency: currency,
            method: 'online',
            status: PaymentStatus.pending,
            createdAt: DateTime.now(),
          );

          return PaymentResult(
            success: true,
            message: 'Order created successfully',
            transaction: transaction,
          );
        }
      }

      return PaymentResult(
        success: false,
        message: 'Failed to create order (${res.statusCode})',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Order creation failed: $e',
      );
    }
  }

  /// Verifies a payment after Razorpay checkout completes.
  ///
  /// Called from the frontend after Razorpay returns success.
  Future<PaymentResult> verifyPayment({
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    try {
      final anonKey = BackendConfig.supabaseAnonKey ?? '';
      final jwtToken = await SupabaseAuthService.instance.getValidAccessToken();

      if (jwtToken == null) {
        return const PaymentResult(
          success: false,
          message: 'Authentication required.',
        );
      }

      final res = await http.post(
        Uri.parse('${BackendConfig.supabaseUrl}/functions/v1/verify-razorpay-payment'),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_signature': razorpaySignature,
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final verified = data['verified'] as bool? ?? false;

        if (verified) {
          final transaction = PaymentTransaction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            orderId: razorpayOrderId,
            amount: (data['amount'] as num?)?.toDouble() ?? 0,
            method: 'online',
            status: PaymentStatus.successful,
            razorpayPaymentId: razorpayPaymentId,
            razorpayOrderId: razorpayOrderId,
            razorpaySignature: razorpaySignature,
            createdAt: DateTime.now(),
            completedAt: DateTime.now(),
          );

          return PaymentResult(
            success: true,
            message: 'Payment verified successfully',
            transaction: transaction,
          );
        }
      }

      return const PaymentResult(
        success: false,
        message: 'Payment verification failed',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'Verification failed: $e',
      );
    }
  }

  /// Records a cash payment (no gateway involved).
  PaymentTransaction recordCashPayment({
    required double amount,
    required String receiptId,
  }) {
    return PaymentTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: 'CASH-$receiptId',
      amount: amount,
      method: 'cash',
      status: PaymentStatus.successful,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
  }

  /// Generates a receipt string for a payment.
  String generateReceipt(PaymentTransaction transaction, {
    required String studentName,
    required String className,
    String? instituteName,
  }) {
    final sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════');
    sb.writeln('       ${instituteName ?? 'Omega Education Centre'}');
    sb.writeln('          FEE PAYMENT RECEIPT');
    sb.writeln('═══════════════════════════════════════');
    sb.writeln();
    sb.writeln('Receipt No: ${transaction.orderId}');
    sb.writeln('Date: ${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}');
    sb.writeln();
    sb.writeln('Student: $studentName');
    sb.writeln('Class: $className');
    sb.writeln();
    sb.writeln('Amount: ₹${transaction.amount.toStringAsFixed(2)}');
    sb.writeln('Payment Method: ${transaction.method.toUpperCase()}');
    sb.writeln('Status: ${transaction.status.name.toUpperCase()}');
    if (transaction.razorpayPaymentId != null) {
      sb.writeln('Transaction ID: ${transaction.razorpayPaymentId}');
    }
    sb.writeln();
    sb.writeln('═══════════════════════════════════════');
    sb.writeln('      This is a computer-generated receipt');
    sb.writeln('═══════════════════════════════════════');

    return sb.toString();
  }
}
