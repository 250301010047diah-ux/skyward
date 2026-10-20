import 'dart:math';

/// Directions in the original artwork, before canvas transforms.
/// A left-facing sprite needs the opposite flip from a right-facing one.
const _leftFacingEnemies = {
  'scout_drone_hover',
  'machine_scarab_dash',
  'archer_clone_shoot',
  'sky_sentinel_descend',
  'blind_bat_swoop',
  'crystal_worm_spiral',
  'fire_rock_fall',
  'ember_imp_throw',
  'lava_mite_burst',
  'storm_crow_circle',
  'wind_manta_glide',
  'gargoyle_meteor',
  'magma_bat_breath',
  'harpy_volley',
  'wind_dragon_attack',
  'flying_knight_attack',
  'laser_golem_lock',
  'stone_angel_dive',
  'mutant_frog_leap',
  'carnivore_tongue',
  'slime_king_attack',
  'wild_pegasus_charge',
  'cloud_rider_strike',
  'fallen_angel_strike',
  'champion_echo_attack',
  'mirror_clone',
  'glass_bat',
  'prism_scarab',
  'sand_wyvern',
  'bone_whelp',
  'soul_flame',
  'rib_crawler',
  'magnet_drone',
  'anvil_mite',
  'plasma_serpent',
  'tick_drone',
  'gear_hound',
  'pendulum_eye',
  'moth_sprite',
  'vine_fox',
  'bone_drake',
  'soul_collector',
  'elder_dragon_skeleton',
  'crystal_djinn',
  'dune_roc',
  'siren_eel',
  'sky_leviathan',
  'time_thief',
  'pendulum_knight',
  'shard_witch',
  'mirror_knight',
  'realm_clone',
  'licorice_worm',
  'storm_gull',
  'wave_wisp',
  'thunder_crab',
  'rain_serpent',
  'paper_raven',
  'quill_knight',
  'hourglass_wisp',
  'page_sorcerer',
  'frost_chronomancer',
  'memory_eater',
  'lucid_guardian',
  'plasma_foreman',
  'sugar_witch',
  'wish_thief',
  'carpet_colossus',
  'volcano_salamander',
  'sanctuary_kirin',
  'clock_cuckoo',
  'moon_rabbit',
  'grave_vulture',
  'mirror_hound',
  'dream_elephant',
  'forge_hammerhead',
  'genesis_dove',
  'infinity_chimera',
};

int enemyArtworkFacing(String animation, int frameIndex) {
  // These falling/bouncing animations turn around within their own sheet.
  if (animation == 'caterpillar_fall') {
    return const [1, -1, -1, -1, -1][frameIndex % 5];
  }
  if (animation == 'horn_beetle_bounce') {
    return const [1, -1, -1, 1, 1][frameIndex % 5];
  }
  return _leftFacingEnemies.contains(animation) ? -1 : 1;
}

bool enemyFlipTowardHero(
  String animation,
  int frameIndex,
  double enemyX,
  double heroX,
) => heroX == enemyX
    ? false
    : enemyArtworkFacing(animation, frameIndex) != (heroX < enemyX ? -1 : 1);

/// Null denotes non-projectile artwork (pillars, swirls, radial flashes).
/// Those skins use a tinted arrow drawn by the renderer instead.
double? arrowArtworkHeading(int skinIndex) => switch (skinIndex) {
  0 || 3 || 6 || 9 || 18 => 0,
  2 => pi / 8,
  4 => pi / 4,
  5 => -pi / 4,
  8 || 15 => 3 * pi / 4,
  13 => -pi / 3,
  14 => pi / 4,
  _ => null,
};

double arrowRotation(double vx, double vy, double artworkHeading) =>
    atan2(vy, vx) - artworkHeading;

/// The release frames in the supplied sheets overlap the next character.
/// Use the intact draw/recovery poses and show release via the flying arrow.
int heroShootFrame(double remaining) => remaining > 0.06 ? 1 : 0;
