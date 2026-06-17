class PokerEvalCard {
  final int rank;
  final String suit;

  const PokerEvalCard({
    required this.rank,
    required this.suit,
  });
}

class PokerHandEvaluation {
  final int category;
  final List<int> kickers;
  final String label;

  const PokerHandEvaluation({
    required this.category,
    required this.kickers,
    required this.label,
  });
}

PokerHandEvaluation evaluateBestPokerHand(List<PokerEvalCard> cards) {
  if (cards.isEmpty) {
    return const PokerHandEvaluation(
      category: 0,
      kickers: [0],
      label: 'High Card',
    );
  }

  final rankGroups = <int, List<PokerEvalCard>>{};
  final suitGroups = <String, List<PokerEvalCard>>{};
  for (final card in cards) {
    rankGroups.putIfAbsent(card.rank, () => []).add(card);
    suitGroups.putIfAbsent(card.suit, () => []).add(card);
  }

  final ranksDesc = rankGroups.keys.toList()..sort((a, b) => b.compareTo(a));

  PokerHandEvaluation? straightFlush;
  for (final suitedCards in suitGroups.values) {
    if (suitedCards.length < 5) {
      continue;
    }
    final straightHigh = _straightHigh(suitedCards);
    if (straightHigh != null) {
      if (straightFlush == null ||
          straightHigh > straightFlush.kickers.first) {
        straightFlush = PokerHandEvaluation(
          category: 8,
          kickers: [straightHigh],
          label: 'Straight Flush',
        );
      }
    }
  }
  if (straightFlush != null) {
    return straightFlush;
  }

  final quads = ranksDesc.where((rank) => rankGroups[rank]!.length >= 4).toList();
  if (quads.isNotEmpty) {
    final quadRank = quads.first;
    final kicker = ranksDesc.firstWhere((rank) => rank != quadRank, orElse: () => 0);
    return PokerHandEvaluation(
      category: 7,
      kickers: [quadRank, kicker],
      label: 'Four of a Kind',
    );
  }

  final trips = ranksDesc.where((rank) => rankGroups[rank]!.length >= 3).toList();
  final pairs = ranksDesc.where((rank) => rankGroups[rank]!.length >= 2).toList();
  if (trips.isNotEmpty && (pairs.length >= 2 || trips.length >= 2)) {
    final tripRank = trips.first;
    final pairRank = ranksDesc.firstWhere(
      (rank) => rank != tripRank && rankGroups[rank]!.length >= 2,
      orElse: () => 0,
    );
    if (pairRank > 0) {
      return PokerHandEvaluation(
        category: 6,
        kickers: [tripRank, pairRank],
        label: 'Full House',
      );
    }
  }

  for (final suitedCards in suitGroups.values) {
    if (suitedCards.length < 5) {
      continue;
    }
    final top = suitedCards.map((card) => card.rank).toList()
      ..sort((a, b) => b.compareTo(a));
    return PokerHandEvaluation(
      category: 5,
      kickers: top.take(5).toList(),
      label: 'Flush',
    );
  }

  final straightHigh = _straightHigh(cards);
  if (straightHigh != null) {
    return PokerHandEvaluation(
      category: 4,
      kickers: [straightHigh],
      label: 'Straight',
    );
  }

  if (trips.isNotEmpty) {
    final tripRank = trips.first;
    final kickers = ranksDesc.where((rank) => rank != tripRank).take(2).toList();
    return PokerHandEvaluation(
      category: 3,
      kickers: [tripRank, ...kickers],
      label: 'Three of a Kind',
    );
  }

  if (pairs.length >= 2) {
    final topPair = pairs[0];
    final secondPair = pairs[1];
    final kicker = ranksDesc.firstWhere(
      (rank) => rank != topPair && rank != secondPair,
      orElse: () => 0,
    );
    return PokerHandEvaluation(
      category: 2,
      kickers: [topPair, secondPair, kicker],
      label: 'Two Pair',
    );
  }

  if (pairs.isNotEmpty) {
    final pair = pairs.first;
    final kickers = ranksDesc.where((rank) => rank != pair).take(3).toList();
    return PokerHandEvaluation(
      category: 1,
      kickers: [pair, ...kickers],
      label: 'One Pair',
    );
  }

  final topRanks = cards.map((card) => card.rank).toList()
    ..sort((a, b) => b.compareTo(a));
  return PokerHandEvaluation(
    category: 0,
    kickers: topRanks.take(5).toList(),
    label: 'High Card',
  );
}

int comparePokerHands(PokerHandEvaluation left, PokerHandEvaluation right) {
  if (left.category != right.category) {
    return left.category.compareTo(right.category);
  }
  final maxLength = left.kickers.length > right.kickers.length
      ? left.kickers.length
      : right.kickers.length;
  for (var i = 0; i < maxLength; i++) {
    final leftValue = i < left.kickers.length ? left.kickers[i] : 0;
    final rightValue = i < right.kickers.length ? right.kickers[i] : 0;
    if (leftValue != rightValue) {
      return leftValue.compareTo(rightValue);
    }
  }
  return 0;
}

int? _straightHigh(List<PokerEvalCard> cards) {
  final ranks = <int>{};
  for (final card in cards) {
    ranks.add(card.rank);
    if (card.rank == 14) {
      ranks.add(1);
    }
  }
  final sorted = ranks.toList()..sort((a, b) => b.compareTo(a));
  for (final start in sorted) {
    var ok = true;
    for (var offset = 1; offset < 5; offset++) {
      if (!ranks.contains(start - offset)) {
        ok = false;
        break;
      }
    }
    if (ok) {
      return start;
    }
  }
  return null;
}
