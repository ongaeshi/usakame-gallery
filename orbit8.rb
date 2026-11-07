# GAME - CELESTIAL ORBIT 8
# A clean orbital motion sample with 8x8 sprites (items, humans, and animals).

config(
  width: 128,
  height: 128,
  scale: 4,
  title: "ORBIT 8 [8x8 SAMPLE]"
)

class App
  MODE_NAMES = ["CIRCLE", "WIDE OVAL", "TALL OVAL", "WAVE", "INFINITY", "3D GALAXY"]
  SPR_LIST = [:core, :ruby, :moon, :hero, :wizard, :cat, :rabbit, :turtle]

  def initialize
    @frame = 0
    @mode = 0
    @count = 8
    @radius = 38.0
    @base_angle = 0.0
    @speed = 0.025
    @zero_hold = 0
  end

  # Calculate orbital trajectory position
  def calc_pos(ang, r, mode)
    cx = 64.0
    cy = 60.0

    case mode
    when 0 # CIRCLE
      [cx + cos(ang) * r, cy + sin(ang) * r, 1.0]
    when 1 # WIDE OVAL
      [cx + cos(ang) * (r * 1.35), cy + sin(ang) * (r * 0.65), 1.0]
    when 2 # TALL OVAL
      [cx + cos(ang) * (r * 0.65), cy + sin(ang) * (r * 1.35), 1.0]
    when 3 # WAVE
      wr = r + sin(ang * 4.0 + @frame.to_f * 0.08) * 8.0
      [cx + cos(ang) * wr, cy + sin(ang) * wr, 1.0]
    when 4 # INFINITY
      scale = r * 1.15
      denom = 1.0 + sin(ang) * sin(ang)
      x = cx + (scale * cos(ang)) / denom
      y = cy + (scale * sin(ang) * cos(ang) * 1.4) / denom
      [x, y, 1.0]
    when 5 # 3D GALAXY
      rx = cos(ang) * r
      ry = sin(ang) * (r * 0.42)
      tilt = 0.38
      x = cx + rx * cos(tilt) - ry * sin(tilt)
      y = cy + rx * sin(tilt) + ry * cos(tilt)
      depth = 0.8 + (sin(ang) + 1.0) * 0.25
      [x, y, depth]
    else
      [cx + cos(ang) * r, cy + sin(ang) * r, 1.0]
    end
  end

  def update
    @frame += 1

    # Orbit rotation
    @base_angle = @base_angle + @speed

    # [Z] / Space: Cycle number of orbiting objects (8 -> 16 -> 24 -> 32 -> 8)
    if btnp(4)
      @count *= 2
      @count = 2 if @count > 256
      sfx(:select) if respond_to?(:sfx)
    end

    # [X] / Enter: Switch orbital trajectory mode
    if btnp(5)
      @mode = (@mode + 1) % MODE_NAMES.size
      sfx(:select) if respond_to?(:sfx)
    end

    # ARROWS UP / DOWN: Adjust orbit radius
    if btn(2)
      @radius = @radius + 0.35
      @radius = 48.0 if @radius > 48.0
    end
    if btn(3)
      @radius = @radius - 0.35
      @radius = 18.0 if @radius < 18.0
    end

    # ARROWS LEFT / RIGHT: Adjust rotation speed & spin direction
    # Snaps to 0.0 with a temporary hold buffer so the user clearly senses the stop point.
    accel = 0.0008
    if btn(0)
      if @speed > 0.0 && (@speed - accel) <= 0.0
        @speed = 0.0
        @zero_hold = 5
        sfx(:select) if respond_to?(:sfx)
      elsif @speed == 0.0 && @zero_hold > 0
        @zero_hold -= 1
      else
        @speed = @speed - accel
        @speed = -0.06 if @speed < -0.06
      end
    elsif btn(1)
      if @speed < 0.0 && (@speed + accel) >= 0.0
        @speed = 0.0
        @zero_hold = 5
        sfx(:select) if respond_to?(:sfx)
      elsif @speed == 0.0 && @zero_hold > 0
        @zero_hold -= 1
      else
        @speed = @speed + accel
        @speed = 0.06 if @speed > 0.06
      end
    else
      @zero_hold = 0
    end
  end

  def draw
    # High-contrast navy background for clear sprite visibility
    cls(1)

    # Center origin anchor
    pset(64, 60, 5)

    # Draw orbital guide track
    track_steps = 40
    (0..track_steps).each do |s|
      a = (s.to_f / track_steps.to_f) * Math::PI * 2.0
      px, py, _ = calc_pos(a, @radius, @mode)
      pset(px.to_i, py.to_i, (s % 2 == 0 ? 5 : 13))
    end

    # Calculate object positions along the orbit
    step = (Math::PI * 2.0) / @count.to_f
    objs = []
    (0...@count).each do |i|
      ang = @base_angle + step * i.to_f
      ox, oy, depth = calc_pos(ang, @radius, @mode)
      objs << {
        kind: SPR_LIST[i % 8],
        x: ox.to_i,
        y: oy.to_i,
        depth: depth
      }
    end

    # Depth sort for 3D Galaxy mode
    objs.sort_by! { |o| o[:y] } if @mode == 5

    # Draw 8x8 sprites centered on orbit
    objs.each do |o|
      kind = o[:kind]
      sx = o[:x] - 4
      sy = o[:y] - 4

      if kind == :core
        frame_idx = (@frame / 6) % 4
        cid = spr_id(:core, frame_idx)
        spr(cid, sx, sy)
      else
        spr(kind, sx, sy)
      end
    end

    # Bottom status & control guide
    rectfill(0, 110, 128, 18, 0)
    line(0, 110, 128, 110, 5)
    print_text("#{MODE_NAMES[@mode]} (N:#{@count})", 4, 112, 10)
    print_text("[Z]COUNT    [X]MODE", 4, 120, 6)
  end
end

run App.new

__END__
# Sprite 1: Animated Core (Item, 4 frames, 8x8)
@SPRITE :core 8x8
..CCCC..
.C7EE7C.
C7EEEE7C
CEEEEEEC
CEEEEEEC
C7EEEE7C
.C7EE7C.
..CCCC..
---
..AAAA..
.A7777A.
A7AAAA7A
A7AAAA7A
A7AAAA7A
A7AAAA7A
.A7777A.
..AAAA..
---
.E....E.
..EEEE..
.E7EE7E.
.EEEEEE.
.EEEEEE.
.E7EE7E.
..EEEE..
.E....E.
---
..CCCC..
.C7AA7C.
C7AAAA7C
CAAAAAAC
CAAAAAAC
C7AAAA7C
.C7AA7C.
..CCCC..

# Sprite 2: Faceted Ruby Gem (Item, 8x8)
@SPRITE :ruby 8x8
..8888..
.8EEEE8.
8E7777E8
88EEEE88
.888888.
..8888..
...88...
....8...

# Sprite 3: Silver Crescent Moon (Item, 8x8)
@SPRITE :moon 8x8
...666..
..6776..
.677....
.67.....
.67.....
.677....
..6776..
...666..

# Sprite 4: Hero Knight (Human, 8x8)
@SPRITE :hero 8x8
..4444..
.444444.
.4FFFF4.
.40F0F4.
..FFFF..
.88C888.
.8CCCC8.
..5..5..

# Sprite 5: Wizard Mage (Human, 8x8)
@SPRITE :wizard 8x8
...DD...
..DDDD..
.DDDDDD.
DDDDDDDD
.FFFFFF.
.F0FF0F.
.D7DD7D.
.DD..DD.

# Sprite 6: Cat (Animal, 8x8)
@SPRITE :cat 8x8
.9....9.
.99..99.
.9FFFF9.
.90F0F9.
.9FEEF9.
..9999..
..9..9..
.9999...

# Sprite 7: Rabbit (Animal, 8x8)
@SPRITE :rabbit 8x8
.77..77.
.7E..E7.
.77..77.
.777777.
.707707.
.77EE77.
.777777.
.77..77.

# Sprite 8: Turtle (Animal, 8x8)
@SPRITE :turtle 8x8
...BB...
..B00B..
.3BBBB3.
3B3333B3
3BBBBBB3
.3BBBB3.
3......3
...33...
