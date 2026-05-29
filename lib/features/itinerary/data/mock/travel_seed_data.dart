part of travel_agent_app;

const destinations = [
  Destination(
    'Kyoto, Japan',
    'Bustling city meets serene temples and gardens.',
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=900',
    ['Culture', 'Zen'],
  ),
  Destination(
    'Tokyo, Japan',
    'Neon neighborhoods, food alleys, temples, and day trips.',
    'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?q=80&w=900',
    ['Food', 'City'],
  ),
  Destination(
    'Seoul, South Korea',
    'Palaces, cafes, street markets, skincare, and late-night food.',
    'https://images.unsplash.com/photo-1538485399081-7191377e8241?q=80&w=900',
    ['Culture', 'Shopping'],
  ),
  Destination(
    'Taipei, Taiwan',
    'Night markets, mountain views, hot springs, and easy transit.',
    'https://images.unsplash.com/photo-1470004914212-05527e49370b?q=80&w=900',
    ['Food', 'Nature'],
  ),
  Destination(
    'Bangkok, Thailand',
    'Temples, river boats, markets, rooftop views, and bold food.',
    'https://images.unsplash.com/photo-1508009603885-50cf7c579365?q=80&w=900',
    ['Food', 'Culture'],
  ),
  Destination(
    'Singapore',
    'Clean transit, gardens, hawker centers, and waterfront views.',
    'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?q=80&w=900',
    ['Food', 'City'],
  ),
  Destination(
    'Bali, Indonesia',
    'Beaches, rice terraces, temples, waterfalls, and slow mornings.',
    'https://images.unsplash.com/photo-1537996194471-e657df975ab4?q=80&w=900',
    ['Relax', 'Nature'],
  ),
  Destination(
    'Paris, France',
    'Museums, cafes, gardens, architecture, and classic walks.',
    'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?q=80&w=900',
    ['Museums', 'Romantic'],
  ),
  Destination(
    'London, United Kingdom',
    'Museums, markets, parks, theatre, and historic neighborhoods.',
    'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?q=80&w=900',
    ['Museums', 'City'],
  ),
  Destination(
    'New York City, USA',
    'Iconic sights, food neighborhoods, parks, museums, and shows.',
    'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?q=80&w=900',
    ['City', 'Food'],
  ),
  Destination(
    'Los Angeles, USA',
    'Beaches, studios, museums, hikes, and neighborhood food scenes.',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?q=80&w=900',
    ['Scenic', 'City'],
  ),
  Destination(
    'Hong Kong',
    'Harbor views, dense streets, dim sum, hikes, and island escapes.',
    'https://images.unsplash.com/photo-1536599018102-9f803c140fc1?q=80&w=900',
    ['Food', 'Scenic'],
  ),
  Destination(
    'Osaka, Japan',
    'Street food, castles, shopping arcades, and easy Kansai day trips.',
    'https://images.unsplash.com/photo-1590559899731-a382839e5549?q=80&w=900',
    ['Food', 'Shopping'],
  ),
  Destination(
    'Amalfi Coast',
    'Vertical villages, cliffs, and turquoise water.',
    'https://images.unsplash.com/photo-1533929736458-ca588d08c8be?q=80&w=900',
    ['Relax', 'Scenic'],
  ),
  Destination(
    'Santorini',
    'Whitewashed homes above the caldera.',
    'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=900',
    ['Romantic', 'Sunset'],
  ),
];

class Destination {
  const Destination(this.name, this.description, this.image, this.tags);
  final String name;
  final String description;
  final String image;
  final List<String> tags;
}

const mockKyotoTrip = Trip(
  id: 't1',
  destination: 'Kyoto, Japan',
  startDate: '2026-04-16',
  endDate: '2026-04-27',
  budget: 3500,
  spent: 450,
  groupType: 'Friends',
  status: TripStatus.ongoing,
  currency: 'USD',
  preferences: ['Culture', 'Food', 'Walking'],
  images: [
    'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=900',
    'https://images.unsplash.com/photo-1554797589-7241bb691973?q=80&w=900',
    'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?q=80&w=900',
  ],
  items: [
    ItineraryItem(
      1,
      '10:00 AM',
      'Arrive at Kyoto Station',
      Icons.train_rounded,
      0,
    ),
    ItineraryItem(
      1,
      '12:30 PM',
      'Nishiki Market Food Tour',
      Icons.restaurant_rounded,
      45,
    ),
    ItineraryItem(
      1,
      '02:00 PM',
      'Fushimi Inari-taisha Hike',
      Icons.hiking_rounded,
      0,
    ),
    ItineraryItem(
      2,
      '09:00 AM',
      'Kinkaku-ji Golden Pavilion',
      Icons.temple_buddhist_rounded,
      15,
    ),
    ItineraryItem(
      2,
      '05:30 PM',
      'Gion District Walk',
      Icons.directions_walk_rounded,
      0,
    ),
  ],
  bookings: [
    Booking(
      'JAL Flight 402',
      '2026-04-16',
      '08:30',
      'JL402-TPEKIX',
      850,
      Icons.flight_takeoff_rounded,
    ),
    Booking(
      'Kyoto Granbell Hotel',
      '2026-04-16',
      '15:00',
      'KGH-4821',
      420,
      Icons.hotel_rounded,
    ),
  ],
  checklist: [
    ChecklistCategory('Essentials', [
      'Passport',
      'Travel adapter',
      'Power bank',
    ]),
    ChecklistCategory('Clothing', [
      'Comfortable walking shoes',
      'Light rain jacket',
    ]),
  ],
  budgetCategories: [
    BudgetCategory(
      id: 'transport',
      category: 'Transport',
      planned: 1000,
      actual: 850,
    ),
    BudgetCategory(id: 'stay', category: 'Stay', planned: 900, actual: 420),
    BudgetCategory(id: 'food', category: 'Food', planned: 650, actual: 45),
    BudgetCategory(
      id: 'activities',
      category: 'Activities',
      planned: 550,
      actual: 15,
    ),
  ],
);
