import 'dart:convert';

import 'data/local/local_database.dart';

class ReceiptProfile {
  const ReceiptProfile({
    required this.storeName,
    required this.registeredName,
    required this.registeredAddress,
    required this.tin,
    required this.branchCode,
    required this.taxMode,
    required this.posPermitStatus,
    required this.vatRate,
    required this.permitNumber,
    required this.machineIdentificationNumber,
    required this.logoPath,
  });

  final String storeName;
  final String registeredName;
  final String registeredAddress;
  final String tin;
  final String branchCode;
  final String taxMode;
  final String posPermitStatus;
  final double vatRate;
  final String permitNumber;
  final String machineIdentificationNumber;
  final String logoPath;

  String get displayName => storeName.isNotEmpty
      ? storeName
      : registeredName.isNotEmpty
          ? registeredName
          : 'STORE';

  static Future<ReceiptProfile> load(LocalDatabase database) async =>
      ReceiptProfile(
        storeName: await database.setting('store_name') ?? '',
        registeredName: await database.setting('registered_name') ?? '',
        registeredAddress: await database.setting('registered_address') ?? '',
        tin: await database.setting('tin') ?? '',
        branchCode: await database.setting('branch_code') ?? '',
        taxMode: await database.setting('tax_mode') ?? 'unregistered',
        posPermitStatus:
            await database.setting('pos_permit_status') ?? 'not_permitted',
        vatRate:
            double.tryParse(await database.setting('vat_rate') ?? '') ?? .12,
        permitNumber: await database.setting('permit_number') ?? '',
        machineIdentificationNumber:
            await database.setting('machine_identification_number') ?? '',
        logoPath: await database.setting('logo_path') ?? '',
      );

  Map<String, Object?> toMap() => {
        'store_name': storeName,
        'registered_name': registeredName,
        'registered_address': registeredAddress,
        'tin': tin,
        'branch_code': branchCode,
        'tax_mode': taxMode,
        'pos_permit_status': posPermitStatus,
        'vat_rate': vatRate,
        'permit_number': permitNumber,
        'machine_identification_number': machineIdentificationNumber,
        'logo_path': logoPath,
      };

  String toJson() => jsonEncode(toMap());

  factory ReceiptProfile.fromSale(Map<String, Object?> sale) {
    final raw = sale['receipt_profile'];
    if (raw == null || raw.toString().isEmpty) return ReceiptProfile.empty();
    final decoded = raw is Map<String, dynamic>
        ? raw
        : jsonDecode(raw.toString()) as Map<String, dynamic>;
    return ReceiptProfile(
      storeName: decoded['store_name']?.toString() ?? '',
      registeredName: decoded['registered_name']?.toString() ?? '',
      registeredAddress: decoded['registered_address']?.toString() ?? '',
      tin: decoded['tin']?.toString() ?? '',
      branchCode: decoded['branch_code']?.toString() ?? '',
      taxMode: decoded['tax_mode']?.toString() ?? 'unregistered',
      posPermitStatus:
          decoded['pos_permit_status']?.toString() ?? 'not_permitted',
      vatRate: (decoded['vat_rate'] as num?)?.toDouble() ?? .12,
      permitNumber: decoded['permit_number']?.toString() ?? '',
      machineIdentificationNumber:
          decoded['machine_identification_number']?.toString() ?? '',
      logoPath: decoded['logo_path']?.toString() ?? '',
    );
  }

  factory ReceiptProfile.empty() => const ReceiptProfile(
        storeName: '',
        registeredName: '',
        registeredAddress: '',
        tin: '',
        branchCode: '',
        taxMode: 'unregistered',
        posPermitStatus: 'not_permitted',
        vatRate: .12,
        permitNumber: '',
        machineIdentificationNumber: '',
        logoPath: '',
      );
}
