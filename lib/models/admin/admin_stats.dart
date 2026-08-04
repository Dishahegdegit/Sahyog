class AdminStats {
  final int donorsCount;
  final int ngosCount;
  final int pendingNgosCount;
  final int volunteersCount;
  final double foodTons;
  final int totalBeneficiaries;
  final List<double> chartValues;
  final int lowStockCount;
  final List<Map<String, dynamic>> recentLogistics;
  final List<Map<String, dynamic>> activeOperations;
  final double? qualityScorePercent;

  AdminStats({
    this.donorsCount = 0,
    this.ngosCount = 0,
    this.pendingNgosCount = 0,
    this.volunteersCount = 0,
    this.foodTons = 0.0,
    this.totalBeneficiaries = 0,
    this.chartValues = const [],
    this.lowStockCount = 0,
    this.recentLogistics = const [],
    this.activeOperations = const [],
    this.qualityScorePercent,
  });
}
