import 'dart:math';

/// The Rocket Launch easter egg: a tiny line that drifts through space at
/// each colour change. Each one is picked at random from lines this player
/// hasn't seen yet (remembered across runs); once they've seen them all,
/// the pool starts over. Add lines freely.
const List<String> whispers = [
  "don't read this",
  "please don't read this",
  'why are you still reading',
  "OMG don't read",
  'stop looking at me',
  'the asteroids are over there',
  'eyes on the rocks. please.',
  'fine. you win.',
  'this text is not here',
  "you didn't see anything",
  'nothing to see, keep flying',
  'ok maybe something',
  'psst… focus',
  'i said focus',
  'are you reading or dodging?',
  'multitasking legend',
  'hello? is this thing on',
  "the rocket can't read either",
  'we should stop meeting like this',
  'see you at the next level',
  'blink twice if you see this',
  "don't tell the asteroids",
  'this message will self-destruct',
  'reading is not a dodge move',
];

/// A random line [seen] doesn't contain, and the updated seen list (reset
/// once every line has been shown).
(String, List<String>) nextWhisper(List<String> seen, Random random) {
  var fresh = whispers.where((line) => !seen.contains(line)).toList();
  var history = seen;
  if (fresh.isEmpty) {
    fresh = whispers;
    history = const [];
  }
  final line = fresh[random.nextInt(fresh.length)];
  return (line, [...history, line]);
}
