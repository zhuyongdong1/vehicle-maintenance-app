class Vehicle {
  final int? id;
  final String plateNumber;
  final String? vin;
  final String? brand;
  final String? model;
  final int? year;
  final String? color;
  final String? ownerName;
  final String? ownerPhone;
  final String? photoUrl;
  final String? inspectionDate;
  final String? insuranceDate;
  final String? createdAt;
  final String? updatedAt;
  final int? recordCount;
  final double? totalCost;
  final String? lastRecordDate;

  Vehicle({
    this.id,
    required this.plateNumber,
    this.vin,
    this.brand,
    this.model,
    this.year,
    this.color,
    this.ownerName,
    this.ownerPhone,
    this.photoUrl,
    this.inspectionDate,
    this.insuranceDate,
    this.createdAt,
    this.updatedAt,
    this.recordCount,
    this.totalCost,
    this.lastRecordDate,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      plateNumber: json['plate_number'] ?? '',
      vin: json['vin'],
      brand: json['brand'],
      model: json['model'],
      year: json['year'],
      color: json['color'],
      ownerName: json['owner_name'],
      ownerPhone: json['owner_phone'],
      photoUrl: json['photo_url'],
      inspectionDate: json['inspection_date'],
      insuranceDate: json['insurance_date'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      recordCount: json['record_count'],
      totalCost: json['total_cost'] != null
          ? (json['total_cost'] as num).toDouble()
          : null,
      lastRecordDate: json['last_record_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'plate_number': plateNumber,
      'vin': vin,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
      'photo_url': photoUrl,
      'inspection_date': inspectionDate,
      'insurance_date': insuranceDate,
    };
  }

  Vehicle copyWith({
    int? id,
    String? plateNumber,
    String? vin,
    String? brand,
    String? model,
    int? year,
    String? color,
    String? ownerName,
    String? ownerPhone,
    String? photoUrl,
    String? inspectionDate,
    String? insuranceDate,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      vin: vin ?? this.vin,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      photoUrl: photoUrl ?? this.photoUrl,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      insuranceDate: insuranceDate ?? this.insuranceDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
