import 'dart:async';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfexceptions.dart';

import '../repositories/mess_repository.dart';

class CashfreePaymentService {
  static Future<String> startCheckout({
    required String orderId,
    required String paymentSessionId,
    String environment = 'sandbox',
  }) async {
    final completer = Completer<String>();
    final cfService = CFPaymentGatewayService();

    void handleVerify(String verifiedOrderId) {
      if (!completer.isCompleted) {
        completer.complete(verifiedOrderId);
      }
    }

    void handleError(CFErrorResponse errorResponse, String failedOrderId) {
      if (!completer.isCompleted) {
        final msg = errorResponse.getMessage()?.trim();
        final code = errorResponse.getCode()?.trim() ?? 'payment_failed';
        completer.completeError(
          RepositoryException(
            (msg != null && msg.isNotEmpty)
                ? msg
                : 'Cashfree payment could not be completed.',
            code: code,
          ),
        );
      }
    }

    try {
      cfService.setCallback(handleVerify, handleError);

      final cfEnv = environment.toLowerCase() == 'production'
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;

      final session = CFSessionBuilder()
          .setEnvironment(cfEnv)
          .setOrderId(orderId)
          .setPaymentSessionId(paymentSessionId)
          .build();

      final theme = CFThemeBuilder()
          .setNavigationBarBackgroundColorColor('#111820')
          .setNavigationBarTextColor('#FFFFFF')
          .setButtonBackgroundColor('#FF6B1A')
          .setButtonTextColor('#FFFFFF')
          .setBackgroundColor('#FAF6EE')
          .setPrimaryTextColor('#111820')
          .setSecondaryTextColor('#64748B')
          .build();

      final webCheckout = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .setTheme(theme)
          .build();

      cfService.doPayment(webCheckout);
    } on CFException catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          RepositoryException(
            e.message.isNotEmpty
                ? e.message
                : 'Unable to open Cashfree Checkout.',
            code: 'cf_exception',
          ),
        );
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          RepositoryException(
            'Unable to start Cashfree payment: $e',
            code: 'cf_error',
          ),
        );
      }
    }

    return completer.future;
  }
}
