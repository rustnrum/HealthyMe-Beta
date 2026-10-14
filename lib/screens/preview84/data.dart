// Sample values that match the design mock-up. Replace with real device data later.
class Data {
  static const name = 'Alex';
  static const recovery = 82;
  static const recoveryLabel = 'Good';
  static const metrics = <List<String>>[
    ['Sleep', '88'],
    ['HRV', '76'],
    ['RHR', '82'],
    ['Body Battery', '78'],
    ['Activity Load', '70'],
  ];
  static const insightLine1 = 'Your recovery is up 15% vs. last week thanks to better sleep and higher HRV.';
  static const insightLine2 = "You're ready for a challenging workout today. Consider a lower-body strength session.";

  static const sleepHours = '7';
  static const sleepMins = '48';
  static const sleepScore = 'Score 88  ·  Restorative';
  static const sleepWindow = '10:32 PM – 6:20 AM';
  static const deep = '1h 42m';
  static const core = '4h 56m';
  static const rem = '1h 10m';

  static const rhr = '54';
  static const rhrDelta = '6% vs. last week';
  static const hrv = '72';
  static const hrvDelta = '12% vs. last week';
  static const battery = '78';
  static const steps = '8,432';
  static const stepsGoal = 'Goal 10,000';
  static const calories = '2,186';
  static const rmr = 'RMR 1,620';

  static const factors = <List<Object>>[
    ['Sleep', 0.95, '+28%', true],
    ['HRV', 0.70, '+18%', true],
    ['Resting Heart Rate', 0.42, '+12%', true],
    ['Activity Load', 0.18, '-6%', false],
    ['Skin Temperature', 0.14, '-4%', false],
  ];

  static const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String today() {
    final d = DateTime.now();
    return 'Today, ${months[d.month - 1]} ${d.day}';
  }

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 18) return 'Good afternoon,';
    return 'Good evening,';
  }
}
