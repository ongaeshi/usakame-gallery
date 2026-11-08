# ==============================================================================
# PLATFORMER 8x8 SPRITE SET & INTERACTIVE PLAYABLE DEMO
# スプライト一覧:
#   :player     - プレイヤー (3フレーム: 待機 / 歩行 / ジャンプ)
#   :floor      - 床タイル (2フレーム: 芝生ブロック / 石レンガ)
#   :heal       - 体力回復アイテム (2フレーム: ハート)
#   :enemy      - 敵キャラ (2フレーム: ツノスライム歩行)
#   :hazard     - ダメージアイテム (2フレーム: トゲ爆弾コア)
#   :checkpoint - 中間ポイント (2フレーム: 未通過フラッグ / 起動フラッグ)
#   :goal       - ゴール (2フレーム: 輝くゴールゲート)
# ==============================================================================

class Platformer8Demo
  SPRITE_INFO = [
    { sym: :player,     label: "PLAYER",     jp: "プレイヤー",     frames: 3 },
    { sym: :floor,      label: "FLOOR",      jp: "床タイル",       frames: 2 },
    { sym: :heal,       label: "HEAL",       jp: "回復アイテム",   frames: 2 },
    { sym: :enemy,      label: "ENEMY",      jp: "敵",             frames: 2 },
    { sym: :hazard,     label: "HAZARD",     jp: "ダメージ物",     frames: 2 },
    { sym: :checkpoint, label: "CHECKPOINT", jp: "中間ポイント",   frames: 2 },
    { sym: :goal,       label: "GOAL",       jp: "ゴール",         frames: 2 }
  ]

  def initialize
    @t = 0
    @bg_dark = true
    reset_stage
  end

  def reset_stage
    @spawn_x = 20.0
    @spawn_y = 208.0
    @px = @spawn_x
    @py = @spawn_y
    @vx = 0.0
    @vy = 0.0
    @flip = false
    @on_ground = false
    @hp = 3
    @max_hp = 3
    @inv_timer = 0
    @checkpoint_active = false
    @goal_cleared = false
    @clear_timer = 0

    # ステージ内のアイテム・敵・ギミック配置 (8x8座標系)
    @heals = [
      { x: 80.0, y: 184.0, active: true },
      { x: 176.0, y: 168.0, active: true }
    ]
    @hazards = [
      { x: 64.0, y: 208.0 },
      { x: 152.0, y: 184.0 },
      { x: 196.0, y: 208.0 }
    ]
    @enemies = [
      { x: 104.0, y: 208.0, min_x: 88.0, max_x: 124.0, vx: 0.4 },
      { x: 168.0, y: 184.0, min_x: 160.0, max_x: 184.0, vx: -0.35 }
    ]
    @checkpoint_pos = { x: 136.0, y: 192.0 }
    @goal_pos = { x: 224.0, y: 176.0 }

    # 地面と足場ブロック (x, y, frame)
    @platforms = []
    # メイン床 (y = 216, 224)
    (2..29).each do |cx|
      # 途中に穴を作る (cx == 15..16)
      if cx != 15 && cx != 16
        @platforms << { x: cx * 8, y: 216, f: 0 }
        @platforms << { x: cx * 8, y: 224, f: 1 }
      end
    end
    # 浮遊足場1 (左中段)
    (9..12).each do |cx|
      @platforms << { x: cx * 8, y: 192, f: 0 }
    end
    # 浮遊足場2 (中間ポイント台座)
    (16..18).each do |cx|
      @platforms << { x: cx * 8, y: 200, f: 0 }
    end
    # 浮遊足場3 (右中段)
    (19..23).each do |cx|
      @platforms << { x: cx * 8, y: 192, f: 0 }
    end
    # ゴール台座 (右上段)
    (26..29).each do |cx|
      @platforms << { x: cx * 8, y: 184, f: 0 }
    end
  end

  def update
    @t += 1

    # [X] ボタンで背景色切り替え
    if btnp(5)
      @bg_dark = !@bg_dark
    end

    if @goal_cleared
      @clear_timer += 1
      if @clear_timer > 90 || btnp(4)
        reset_stage
      end
      return
    end

    @inv_timer -= 1 if @inv_timer > 0

    # 左右移動
    @vx = 0.0
    if btn(0)
      @vx = -1.2
      @flip = true
    elsif btn(1)
      @vx = 1.2
      @flip = false
    end

    # ジャンプ (上キー または Zボタン)
    if (btnp(2) || btnp(4)) && @on_ground
      @vy = -3.1
      @on_ground = false
    end

    # 重力
    @vy += 0.18
    @vy = 3.0 if @vy > 3.0

    # 水平移動と衝突
    @px += @vx
    @px = 16.0 if @px < 16.0
    @px = 232.0 if @px > 232.0

    # 垂直移動と床判定
    prev_bottom = @py + 8.0
    @py += @vy
    @on_ground = false

    if @vy >= 0.0
      @platforms.each do |pf|
        if (@px + 6.0 > pf[:x]) && (@px + 2.0 < pf[:x] + 8.0)
          if prev_bottom <= pf[:y] + 2.0 && (@py + 8.0) >= pf[:y]
            @py = pf[:y] - 8.0
            @vy = 0.0
            @on_ground = true
          end
        end
      end
    end

    # 落下ミス判定
    if @py > 240.0
      take_damage(true)
    end

    # 敵の移動
    @enemies.each do |e|
      e[:x] += e[:vx]
      if e[:x] < e[:min_x]
        e[:x] = e[:min_x]
        e[:vx] = -e[:vx]
      elsif e[:x] > e[:max_x]
        e[:x] = e[:max_x]
        e[:vx] = -e[:vx]
      end
    end

    # 回復アイテム取得判定
    @heals.each do |h|
      if h[:active] && overlap?(@px, @py, h[:x], h[:y])
        h[:active] = false
        @hp += 1 if @hp < @max_hp
      end
    end

    # 中間ポイント通過判定
    if !@checkpoint_active && overlap?(@px, @py, @checkpoint_pos[:x], @checkpoint_pos[:y])
      @checkpoint_active = true
      @spawn_x = @checkpoint_pos[:x]
      @spawn_y = @checkpoint_pos[:y]
    end

    # ダメージアイテム・敵との接触判定
    if @inv_timer == 0
      @hazards.each do |hz|
        if overlap_tight?(@px, @py, hz[:x], hz[:y])
          take_damage(false)
        end
      end
      @enemies.each do |e|
        if overlap_tight?(@px, @py, e[:x], e[:y])
          take_damage(false)
        end
      end
    end

    # ゴール到達判定
    if overlap?(@px, @py, @goal_pos[:x], @goal_pos[:y])
      @goal_cleared = true
      @clear_timer = 0
    end
  end

  def overlap?(ax, ay, bx, by)
    (ax - bx).abs < 6.0 && (ay - by).abs < 6.0
  end

  def overlap_tight?(ax, ay, bx, by)
    (ax - bx).abs < 5.0 && (ay - by).abs < 5.0
  end

  def take_damage(fell)
    @hp -= 1
    @inv_timer = 45
    @vy = -1.8
    if fell || @hp <= 0
      @hp = @max_hp if @hp <= 0
      @px = @spawn_x
      @py = @spawn_y
      @vy = 0.0
    end
  end

  def draw
    cls(@bg_dark ? 1 : 12)

    # ヘッダー
    rectfill(0, 0, 256, 14, 0)
    print_text("PLATFORMER 8x8 SPRITE SET (7 ITEMS)", 16, 3, 10)

    # --- カタログ表示エリア (y: 18..134) ---
    draw_catalog

    # --- ミニプラットフォーマー試遊エリア (y: 138..236) ---
    draw_playfield

    # フッター
    rectfill(0, 242, 256, 14, 0)
    print_text("MOVE:ARROWS  JUMP:Z/UP  BG:X", 40, 245, 7)
  end

  def draw_catalog
    # 7種類のスプライトをカード形式で並べる (上段4個 + 下段3個)
    SPRITE_INFO.each_with_index do |info, idx|
      row = idx / 4
      col = idx % 4
      card_w = (row == 0) ? 58 : 74
      card_h = 52
      cx = (row == 0) ? (6 + col * 62) : (13 + col * 79)
      cy = 18 + row * 56

      rectfill(cx, cy, card_w, card_h, @bg_dark ? 0 : 1)
      rect(cx, cy, card_w, card_h, 5)

      # ラベル
      print_text(info[:label], cx + 4, cy + 3, 10)

      # アニメーションフレーム
      anim_f = (@t / 20) % info[:frames]
      sid = spr_id(info[:sym], anim_f)

      # 1x (実寸 8x8)
      spr(sid, cx + 5, cy + 25)
      print_text("1x", cx + 3, cy + 39, 6)

      # 2x (16x16)
      spr_ext(sid, cx + 19, cy + 21, 0, 2.0, 2.0)
      print_text("2x", cx + 19, cy + 39, 6)

      # 全フレーム個別プレビュー (右側縦並びまたは横並び)
      (0...info[:frames]).each do |f|
        fid = spr_id(info[:sym], f)
        fx = cx + card_w - 11
        fy = cy + 14 + f * 11
        spr(fid, fx, fy)
      end
    end
  end

  def draw_playfield
    # ステージ枠
    rectfill(12, 138, 232, 98, @bg_dark ? 0 : 12)
    rect(12, 138, 232, 98, 5)
    print_text("LIVE 8x8 STAGE TEST", 16, 142, 6)

    # HP表示 (ハートアイコン :heal を使用)
    print_text("HP:", 168, 142, 7)
    (0...@max_hp).each do |i|
      if i < @hp
        spr(spr_id(:heal, 0), 188 + i * 10, 142)
      else
        rect(188 + i * 10, 142, 8, 8, 5)
      end
    end

    # 床タイル描画
    @platforms.each do |pf|
      spr(spr_id(:floor, pf[:f]), pf[:x], pf[:y])
    end

    # 中間ポイント描画
    cp_frame = @checkpoint_active ? 1 : 0
    spr(spr_id(:checkpoint, cp_frame), @checkpoint_pos[:x].to_i, @checkpoint_pos[:y].to_i)

    # ゴール描画
    goal_frame = (@t / 12) % 2
    spr(spr_id(:goal, goal_frame), @goal_pos[:x].to_i, @goal_pos[:y].to_i)

    # 回復アイテム描画 (ふわふわ浮遊)
    bob = ((@t / 15) % 2)
    @heals.each do |h|
      if h[:active]
        spr(spr_id(:heal, (@t / 20) % 2), h[:x].to_i, h[:y].to_i - bob)
      end
    end

    # ダメージアイテム描画
    hz_frame = (@t / 8) % 2
    @hazards.each do |hz|
      spr(spr_id(:hazard, hz_frame), hz[:x].to_i, hz[:y].to_i)
    end

    # 敵描画
    en_frame = (@t / 10) % 2
    @enemies.each do |e|
      eflip = e[:vx] > 0
      spr(spr_id(:enemy, en_frame), e[:x].to_i, e[:y].to_i, eflip)
    end

    # プレイヤー描画
    if @inv_timer == 0 || (@t % 4 < 2)
      p_frame = if !@on_ground
                  2
                elsif @vx.abs > 0.1
                  (@t / 6) % 2
                else
                  0
                end
      spr(spr_id(:player, p_frame), @px.to_i, @py.to_i, @flip)
    end

    # ゴール演出
    if @goal_cleared
      rectfill(68, 168, 120, 32, 0)
      rect(68, 168, 120, 32, 10)
      print_text("STAGE CLEAR!", 92, 174, 10)
      print_text("PRESS Z TO REPLAY", 78, 186, 7)
    end
  end
end

run Platformer8Demo.new

__END__
# ==============================================================================
# 1. プレイヤー (:player 8x8, 3 frames: 待機 / 歩行 / ジャンプ)
# ==============================================================================
@SPRITE :player 8x8
..8888..
.888887.
.4FFFF0.
.4FFFFF.
..CCCC..
.FCCCCF.
..11.11.
.44..44.
---
..8888..
.888887.
.4FFFF0.
.4FFFFF.
.FCCCF..
..CCCC..
.11..11.
44....44
---
..8888..
.888887.
F4FFFF0F
.4FFFFF.
..CCCC..
..1111..
.44..44.
........

# ==============================================================================
# 2. 床タイル (:floor 8x8, 2 frames: 芝生ブロック / 石レンガブロック)
# ==============================================================================
@SPRITE :floor 8x8
BBBBBBBB
BB7BB7BB
33B333B3
44344344
94444944
44494444
49444494
00400040
---
66676660
55555550
56655650
00000000
66066676
55055555
65056655
00000000

# ==============================================================================
# 3. 体力が回復するアイテム (:heal 8x8, 2 frames: 輝くハート)
# ==============================================================================
@SPRITE :heal 8x8
.88..88.
87E88E88
87EEEE88
8EEEEEE2
.8EEEE2.
..8EE2..
...82...
........
---
.88..88.
87788E88
87EEEE88
8EEEEEE2
.8EEEE2.
..8EE2..
...82...
........

# ==============================================================================
# 4. 敵 (:enemy 8x8, 2 frames: ツノモンスター歩行)
# ==============================================================================
@SPRITE :enemy 8x8
.A....A.
..2222..
.2EEEE2.
2E70E702
2EEEEEE2
22888822
.22..22.
22....22
---
........
.A.22.A.
.2EEEE2.
2E70E702
2EEEEEE2
22888822
..2222..
.22..22.

# ==============================================================================
# 5. 当たるとダメージを受けるアイテム (:hazard 8x8, 2 frames: トゲ爆弾コア)
# ==============================================================================
@SPRITE :hazard 8x8
..7..7..
.508805.
70899807
.89AA98.
.89AA98.
70899807
.508805.
..7..7..
---
..8..8..
.50AA05.
80A77A08
.A7887A.
.A7887A.
80A77A08
.50AA05.
..8..8..

# ==============================================================================
# 6. 中間ポイント (:checkpoint 8x8, 2 frames: 未通過フラッグ / 起動フラッグ)
# ==============================================================================
@SPRITE :checkpoint 8x8
.7......
.6CC....
.6CCC...
.6DD....
.6......
.5......
.5......
565.....
---
.7..A...
.6AAAA..
.6A799A.
.69988..
.6......
.5......
.5......
A7A.....

# ==============================================================================
# 7. ゴール (:goal 8x8, 2 frames: 黄金のゴールゲート)
# ==============================================================================
@SPRITE :goal 8x8
..AAAA..
.A7AA7A.
A9CCCC9A
A9CAAC9A
A9CAAC9A
A9CCCC9A
99444499
44444444
---
..7AA7..
.AAAAAA.
A9C77C9A
A9CAAC9A
A9C77C9A
A9CCCC9A
99444499
44444444
