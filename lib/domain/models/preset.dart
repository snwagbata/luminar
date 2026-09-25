/// A named brightness and colour temperature for every light.
class Preset {
  final String name;

  /// 1–100 %.
  final int level;
  final int kelvin;
  const Preset(this.name, this.level, this.kelvin);
}

const presets = [
  Preset('Relax', 35, 2700),
  Preset('Read', 90, 4000),
  Preset('Daylight', 100, 6500),
  Preset('Night', 5, 2700),
];
