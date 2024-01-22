def show_autosave_warn_screen(newgame = false)
  return false if !SaveSettings::SHOW_AUTOSAVE_WARNING
  vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
  vp.z = 99999
  bg  = Sprite.new(vp)
  bg.bitmap   = Bitmap.new(Graphics.width, Graphics.height)
  bg.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
  spr = Sprite.new(vp)
  spr.bitmap  = Bitmap.new(SaveSettings::SAVING_ICON_PATH)
  spr.zoom_x  = 1.5
  spr.zoom_y  = 1.5
  spr.x       = Graphics.width / 2
  spr.y       = Graphics.height / 2 - 8
  spr.ox      = spr.width / 2
  spr.oy      = spr.height
  spr.opacity = 0
  spr.bitmap.play if spr.bitmap&.animated?
  txt         = BitmapSprite.new(Graphics.width, Graphics.height / 2, vp)
  txt.y       = Graphics.height / 2
  txt.opacity = 0
  textpos     = []
  base_color  = Color.new(248, 248, 248)
  shad_color  = Color.new(108, 108, 108, 0)
  pbSetSystemFont(txt.bitmap)
  textpos.push([_INTL("This game has an autosave feature."), Graphics.width / 2, 8, 2, base_color, shad_color])
  textpos.push([_INTL("Do not close the game when you see this icon."), Graphics.width / 2, 40, 2, base_color, shad_color])
  textpos.push([_INTL("This can be turned off in the Options screen."), Graphics.width / 2, 72, 2, base_color, shad_color])
  pbDrawTextPositions(txt.bitmap, textpos)
  duration = (IntroEventScene::FADE_TICKS / 20.0).ceil
  t_start = System.uptime
  loop do
	timer = System.uptime - t_start
	timer = duration if timer >= duration
	factor = timer / duration.to_f
    spr.update
    txt.update
    spr.opacity = 255 * factor
    txt.opacity = 255 * factor
	break if timer >= duration
  end
  counter   = 0
  inc_opac  = 1
  duration = (IntroEventScene::SECONDS_PER_SPLASH * 2).ceil
  t_start = System.uptime
  loop do
	timer = System.uptime - t_start
	timer = duration if timer >= duration
	factor = timer / duration.to_f
    Input.update
    spr.update
    txt.update
	break if timer >= duration
    break if (Input.press?(Input::USE) || Input.press?(Input::BACK)) && SaveData.exists?
  end
  duration = (IntroEventScene::FADE_TICKS / 20.0).ceil
  t_start = System.uptime
  loop do
	timer = System.uptime - t_start
	timer = duration if timer >= duration
	factor = timer / duration.to_f
    spr.update
    txt.update
    spr.opacity = 255 * (1 - factor)
    txt.opacity = 255 * (1 - factor)
	break if timer >= duration
  end
  spr.dispose
  txt.dispose
  bg.dispose
  vp.dispose
end

class IntroEventScene
  alias __saving__open_title_screen open_title_screen unless method_defined?(:__saving__open_title_screen)
  def open_title_screen(*args)
    show_autosave_warn_screen(true)
    __saving__open_title_screen(*args)
  end
end

#===============================================================================
#  Class used for selector sprite
#===============================================================================
if !defined?(SelectorSprite)
  class SelectorSprite < Sprite
    attr_accessor :filename, :anchor, :speed
    #---------------------------------------------------------------------------
    #  initializes sprite sheet
    #---------------------------------------------------------------------------
    def initialize(viewport, frames = 1)
      @frames     = frames
      self.speed  = 0.15
      @frame_time = System.uptime
      @vertical   = false
      super(viewport)
    end
    #---------------------------------------------------------------------------
    #  sets sheet bitmap
    #---------------------------------------------------------------------------
    def render(rect, file = nil, vertical = false)
      @filename       = file if @filename.nil? && !file.nil?
      file            = @filename if file.nil? && !@filename.nil?
      @frame_time     = 0
      self.src_rect.x = 0
      self.src_rect.y = 0
      self.set_bitmap(sel_bmp(@filename, rect), vertical)
      self.ox = self.src_rect.width / 2
      self.oy = self.src_rect.height / 2
    end
    #---------------------------------------------------------------------------
    #  target sprite with selector
    #---------------------------------------------------------------------------
    def target(sprite, offset = 0)
      return if !sprite || !sprite.respond_to?(:bitmap)
      self.render(Rect.new(0, 0, sprite.src_rect.width - offset, sprite.src_rect.height - offset))
      self.anchor = sprite
      update
    end
    #---------------------------------------------------------------------------
    #  sets sheet bitmap
    #---------------------------------------------------------------------------
    def set_bitmap(file, vertical = false)
      self.bitmap = file.is_a?(Bitmap) ? file : RPG::Cache.load_bitmap("", file)
      @vertical = vertical
      if @vertical
        self.src_rect.height /= @frames
      else
        self.src_rect.width /= @frames
      end
    end
    #---------------------------------------------------------------------------
    #  update sprite
    #---------------------------------------------------------------------------
    def update
      return if !self.bitmap
      if (System.uptime - @frame_time) >= @speed
        if @vertical
          self.src_rect.y += self.src_rect.height
          self.src_rect.y = 0 if self.src_rect.y >= self.bitmap.height
        else
          self.src_rect.x += self.src_rect.width
          self.src_rect.x = 0 if self.src_rect.x >= self.bitmap.width
        end
        @frame_time = System.uptime
      end
      return if !self.anchor || self.anchor.disposed?
      self.x       = self.anchor.x - self.anchor.ox + self.anchor.src_rect.width / 2
      self.y       = self.anchor.y - self.anchor.oy + self.anchor.src_rect.height / 2 - 2
      self.z       = self.anchor.z + 1 
      self.opacity = self.anchor.opacity
      self.visible = self.anchor.visible
    end
    #---------------------------------------------------------------------------
    def sel_bmp(name, rect)
      bmp = RPG::Cache.load_bitmap("", name)
      qw = bmp.width / 2
      qh = bmp.height / 2
      max_w = rect.width + (qw * 2) - 8
      max_h = rect.height + (qh * 2) - 8
      full = Bitmap.new(max_w * 4, max_h)
      # draws 4 frames where corners of selection get closer to bounding rect
      4.times do |i|
        4.times do |j|
          m = (i < 3) ? i : (i - 2)
          x = (j % 2 == 0 ? 2 : -2) * m + max_w * i + (j % 2 == 0 ? 0 : max_w - qw)
          y = (j / 2 == 0 ? 2 : -2) * m + (j / 2 == 0 ? 0 : max_h - qh)
          full.blt(x, y, bmp, Rect.new(qw * (j % 2), qh * (j / 2), qw, qh))
        end
      end
      return full
    end
    #---------------------------------------------------------------------------
  end
end
