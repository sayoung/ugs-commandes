import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../i18n/app_i18n.dart';

class OrderModel {
  final int id;
  final String ref;
  final DateTime? date;
  final double totalTtc;
  final int status;
  final Map<String, dynamic> raw;

  const OrderModel({
    required this.id,
    required this.ref,
    this.date,
    required this.totalTtc,
    required this.status,
    this.raw = const <String, dynamic>{},
  });

  bool get isDraft => status == 0;

  static OrderModel? tryFromMap(dynamic data) {
    if (data is! Map) return null;

    final map = <String, dynamic>{};
    data.forEach((dynamic k, dynamic v) {
      if (k != null) {
        map[k.toString()] = v;
      }
    });

    final idVal = map['id'];
    int parsedId = 0;
    if (idVal is int) {
      parsedId = idVal;
    } else if (idVal is num) {
      parsedId = idVal.toInt();
    } else if (idVal != null) {
      parsedId = int.tryParse(idVal.toString()) ?? 0;
    }

    final refVal = map['ref'];
    final ref = (refVal != null && refVal.toString().trim().isNotEmpty)
        ? refVal.toString().trim()
        : (parsedId > 0 ? parsedId.toString() : '');

    final dateTs = map['date_commande'] ?? map['date'] ?? map['date_creation'];
    DateTime? date;
    if (dateTs is int) {
      date = DateTime.fromMillisecondsSinceEpoch(dateTs * 1000);
    } else if (dateTs != null) {
      final str = dateTs.toString().trim();
      if (str.isNotEmpty) {
        final intVal = int.tryParse(str);
        if (intVal != null) {
          date = DateTime.fromMillisecondsSinceEpoch(intVal * 1000);
        } else {
          date = DateTime.tryParse(str);
        }
      }
    }

    final totalVal = map['total_ttc'];
    double total = 0.0;
    if (totalVal is double) {
      total = totalVal;
    } else if (totalVal is num) {
      total = totalVal.toDouble();
    } else if (totalVal != null) {
      total = double.tryParse(totalVal.toString()) ?? 0.0;
    }

    final statusVal = map['statut'] ?? map['status'];
    int status = 0;
    if (statusVal is int) {
      status = statusVal;
    } else if (statusVal is num) {
      status = statusVal.toInt();
    } else if (statusVal != null) {
      status = int.tryParse(statusVal.toString()) ?? 0;
    }

    return OrderModel(
      id: parsedId,
      ref: ref,
      date: date,
      totalTtc: total,
      status: status,
      raw: map,
    );
  }

  String formattedDate() {
    final d = date;
    if (d == null) return '';
    return DateFormat('dd/MM/yyyy').format(d);
  }

  String getStatusLabel([String? locale]) {
    switch (status) {
      case -1:
        return AppI18n.t('status_cancelled', locale: locale);
      case 0:
        return AppI18n.t('status_draft', locale: locale);
      case 1:
        return AppI18n.t('status_validated', locale: locale);
      case 2:
        return AppI18n.t('status_shipped', locale: locale);
      case 3:
        return AppI18n.t('status_delivered', locale: locale);
      default:
        return AppI18n.t('status_unknown', locale: locale);
    }
  }

  Color get statusColor {
    switch (status) {
      case -1:
        return Colors.red;
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.purple;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
