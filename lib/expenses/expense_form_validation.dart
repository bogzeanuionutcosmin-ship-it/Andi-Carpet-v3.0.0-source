part of '../main.dart';

String? expenseDocumentNumberValidationError(String? value) =>
    value == null || value.trim().isEmpty
        ? 'Numărul documentului este obligatoriu.'
        : null;

String? expenseAmountValidationError(int? amountBani) => amountBani == null
    ? 'Introdu o sumă pozitivă, cu maximum 2 zecimale.'
    : null;

bool expenseDateExceedsFutureAllowance(DateTime documentDate, DateTime now) =>
    documentDate.isAfter(now.add(const Duration(days: 1)));
