import 'dart:math';

/// One reminder's copy. Deliberately emoji-free: the notification tray is
/// already noisy, and plain text reads as a message rather than an ad.
class ReminderCopy {
  const ReminderCopy(this.title, this.body);

  final String title;
  final String body;
}

/// Copy for the two scheduled reminders.
///
/// The pools are separate on purpose. At 24 hours the player is still warm,
/// so the nudge is small and low-friction ("two minutes"). At 7 days they
/// have drifted, so the line has to re-sell the game and reassure them their
/// progress survived. The same sentence cannot do both jobs.
abstract final class NotificationContent {
  /// Fires 24 hours after the last time the app was opened.
  static const daily = <ReminderCopy>[
    ReminderCopy('A fresh picture is ready',
        'One quick level, then get on with your day.'),
    ReminderCopy('Your bottles are waiting',
        'There is a picture here that will not drain itself.'),
    ReminderCopy('Two minutes, one puzzle', 'Just enough to reset your brain.'),
    ReminderCopy("Today's board is set", 'Come and pick the right bottle.'),
    ReminderCopy('The machine is idle', 'Give it something to drink.'),
    ReminderCopy('Ready when you are', 'A new picture, a new order to solve.'),
    ReminderCopy('One level before bed',
        'Watch a picture disappear, colour by colour.'),
    ReminderCopy('Something colourful is waiting',
        'Open Coloro and take it apart.'),
    ReminderCopy('Beat yesterday', 'The next picture is harder. Barely.'),
    ReminderCopy('Pick up where you stopped',
        'Your next level is unlocked and waiting.'),
    ReminderCopy('A picture needs draining', 'It takes about two minutes.'),
    ReminderCopy('Your next level is unlocked',
        'See how fast you can empty it.'),
  ];

  /// Fires 7 days after the last open — the win-back.
  static const weekly = <ReminderCopy>[
    ReminderCopy('Your pictures are still here',
        'Coloro kept your progress exactly where you left it.'),
    ReminderCopy('It has been a week',
        'A few hundred pixels are waiting to be drained.'),
    ReminderCopy('Still unsolved',
        'That level you walked away from has not moved.'),
    ReminderCopy('Your machine has been quiet',
        'Come back and jam it properly.'),
    ReminderCopy('Nothing has changed',
        'Except the number of levels you have not played yet.'),
    ReminderCopy('One picture, start to finish',
        'That is all it takes to get back into it.'),
    ReminderCopy('Your progress is safe',
        'Open Coloro and carry on from the level you stopped at.'),
    ReminderCopy('Come back for one level',
        'No timers, no lives. Just you and the picture.'),
    ReminderCopy('Unfinished business',
        'There are levels in here you have never seen.'),
    ReminderCopy('A week of untouched puzzles',
        'Start with one and see what happens.'),
    ReminderCopy('Remember Coloro',
        'Ten quiet minutes and a picture that falls apart beautifully.'),
    ReminderCopy('The colours are waiting',
        'Pick a bottle, drain a picture, feel a little better.'),
  ];

  /// Picks one line from each pool. Called at schedule time rather than once
  /// at startup, so a player who opens the app daily sees the message rotate
  /// instead of receiving the same sentence every evening.
  static ({ReminderCopy daily, ReminderCopy weekly}) pickPair(Random rnd) => (
        daily: NotificationContent.daily[rnd.nextInt(NotificationContent.daily.length)],
        weekly:
            NotificationContent.weekly[rnd.nextInt(NotificationContent.weekly.length)],
      );
}
