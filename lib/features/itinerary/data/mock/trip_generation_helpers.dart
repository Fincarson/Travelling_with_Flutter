part of travel_agent_app;

GeneratedTripPlan _fallbackTripPlan({
  required PlaceSuggestion place,
  required DateTime startDate,
  required int budget,
  required List<String> preferences,
}) {
  final placeName = place.name.split(',').first;
  final wantsFood = preferences.any(
    (item) => item.toLowerCase().contains('food'),
  );
  final wantsNature = preferences.any(
    (item) =>
        item.toLowerCase().contains('nature') ||
        item.toLowerCase().contains('adventure'),
  );
  final wantsShopping = preferences.any(
    (item) => item.toLowerCase().contains('shopping'),
  );

  final items = [
    ItineraryItem(
      1,
      '09:30 AM',
      '$placeName arrival and neighborhood orientation',
      Icons.directions_walk_rounded,
      0,
    ),
    ItineraryItem(
      1,
      '12:30 PM',
      wantsFood ? '$placeName local food crawl' : 'Central cafe lunch stop',
      wantsFood ? Icons.restaurant_rounded : Icons.local_cafe_rounded,
      (budget * .03).round(),
    ),
    ItineraryItem(
      1,
      '03:00 PM',
      wantsShopping
          ? 'Market and boutique shopping route'
          : 'Historic district walk',
      wantsShopping ? Icons.shopping_bag_rounded : Icons.museum_rounded,
      (budget * .02).round(),
    ),
    ItineraryItem(
      2,
      '09:00 AM',
      wantsNature
          ? 'Scenic outdoor viewpoint and easy trail'
          : 'Signature landmark visit',
      wantsNature ? Icons.hiking_rounded : Icons.place_rounded,
      (budget * .02).round(),
    ),
    ItineraryItem(
      2,
      '06:00 PM',
      '$placeName evening dinner plan',
      Icons.restaurant_rounded,
      (budget * .04).round(),
    ),
  ];

  final bookings = [
    Booking(
      '$placeName stay placeholder',
      _dateKey(startDate),
      '15:00',
      'HOTEL-TBD',
      (budget * .28).round(),
      Icons.hotel_rounded,
    ),
    Booking(
      '$placeName transport placeholder',
      _dateKey(startDate),
      '09:00',
      'TRANSIT-TBD',
      (budget * .12).round(),
      Icons.train_rounded,
    ),
  ];

  final checklist = [
    const ChecklistCategory('Essentials', [
      'Passport or ID',
      'Wallet and payment cards',
      'Phone charger',
      'Travel adapter',
    ]),
    ChecklistCategory('Trip Style', [
      if (wantsNature) 'Comfortable walking shoes',
      if (wantsFood) 'Restaurant reservation notes',
      if (wantsShopping) 'Extra tote bag',
      'Reusable water bottle',
    ]),
  ];

  return GeneratedTripPlan(
    items: items,
    bookings: bookings,
    checklist: checklist,
  );
}

List<String> _imagesForDestination(String destination) {
  final lower = destination.toLowerCase();
  for (final option in destinations) {
    final optionName = option.name.toLowerCase();
    if (lower.contains(optionName.split(',').first) ||
        optionName.contains(lower.split(',').first)) {
      return [option.image, ...mockKyotoTrip.images.take(2)];
    }
  }
  return mockKyotoTrip.images;
}

List<BudgetCategory> _defaultBudgetCategories({
  required int budget,
  required int actual,
  required List<ItineraryItem> items,
  required List<Booking> bookings,
}) {
  final activityCost = items.fold<int>(0, (total, item) => total + item.cost);
  final transportCost = bookings
      .where(
        (item) =>
            item.icon == Icons.flight_takeoff_rounded ||
            item.icon == Icons.train_rounded,
      )
      .fold<int>(0, (total, item) => total + item.cost);
  final stayCost = bookings
      .where((item) => item.icon == Icons.hotel_rounded)
      .fold<int>(0, (total, item) => total + item.cost);
  final foodCost = items
      .where((item) => item.type == Icons.restaurant_rounded)
      .fold<int>(0, (total, item) => total + item.cost);
  final fallback = math.max(0, budget - transportCost - stayCost - foodCost);
  final otherActual = math.max(0, actual);

  return [
    BudgetCategory(
      id: 'transport',
      category: 'Transport',
      planned: math.max(transportCost, (budget * .25).round()),
      actual: 0,
    ),
    BudgetCategory(
      id: 'stay',
      category: 'Stay',
      planned: math.max(stayCost, (budget * .28).round()),
      actual: 0,
    ),
    BudgetCategory(
      id: 'food',
      category: 'Food',
      planned: math.max(foodCost, (budget * .18).round()),
      actual: 0,
    ),
    BudgetCategory(
      id: 'activities',
      category: 'Activities',
      planned: math.max(activityCost, fallback ~/ 2),
      actual: 0,
    ),
    BudgetCategory(
      id: 'other',
      category: 'Other',
      planned: math.max(0, budget ~/ 10),
      actual: otherActual,
    ),
  ];
}
