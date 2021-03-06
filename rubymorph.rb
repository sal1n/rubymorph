# RubyMorph.rb - Biomorphs in the land of Ruby / Gosu.
#
# 2010 Steve Andrews [steve[at]salin[dot]org]
# 
# @changes
# 1.  Included changes from apillet, thank you!
#
# @todo
# 1.  Implement load functionality for saved RubyMorphs.
# 2.  Keep track of generations.
# 3.  Store each generation in memory so all selections can be reversed.
# 4.  Implement segmentation.
# 5.  Implement branch thickness.

begin
  # in case you use Gosu via RubyGems
  require 'rubygems'
rescue
  # in case you don't
end

require 'gosu'
require 'yaml'

module RubyMorph

  WIDTH  = 1220
  HEIGHT = 660
  COLORS = [Gosu::Color.new(0xffffffff),
            Gosu::Color.new(0xffffff00),
            Gosu::Color.new(0xff0000ff),
            Gosu::Color.new(0xff00ff00),
            Gosu::Color.new(0xffffffff)]

  TEXT_SIZE = 14
  TEXT_MARGIN = 5
  DEFAULT_COLOR = Gosu::Color.new(0xffff0000)

  # The main application class, subclasses Gosu::Window, initialises everything
  # and handles events and drawing.
  #
  class RubyMorph < Gosu::Window
    def initialize
      super(WIDTH, HEIGHT, false, 20)
      self.caption = "RubyMorph | Biomorphs in the land of Ruby / Gosu"
      @cursor = Gosu::Image.new(self, "cursor.png")
      @font = Gosu::Font.new(self, Gosu.default_font_name, TEXT_SIZE)
      
      # initial selection from default parent gene
      select(Gene.new)
    end

    # from a given selected parent, reproduce and redisplay
    def select(parent)
      x = 0
      y = 0
      width = WIDTH / 4
      height = HEIGHT / 3
      genes = parent.reproduce(11)

      @panels = Array.new
      12.times do |i|
        x = width * (i % 4)
        if i % 4 == 0 && i != 0
          x = 0
          y += height
        end

       @panels << Panel.new(x, y, width, height, genes[i])
      end
    end

    def draw
      @cursor.draw(mouse_x, mouse_y, 5.0, 0.75,0.75)
      @panels.each do |canvas|
        render(canvas)
      end
    end

    def render(panel)
      draw_box(*panel.box_opts)
      draw_tree(*panel.tree_opts)

      if panel.below?(mouse_x, mouse_y)
        draw_quad(*panel.quad_opts)
        @font.draw(*panel.info_opts)
      end
    end

    # recursive tree drawing method
    def draw_tree(x, y, length, dir, dx, dy)
      if dir < 0
        dir = dir + 8
      elsif dir >= 8
        dir = dir - 8
      end

      xnew = x + (length * dx[dir])
      ynew = y - (length * dy[dir])
      color = branch_color(length)

      draw_line(x, y, color, xnew, ynew, color, 1.0)

      # recurse
      if length > 0
        draw_tree(xnew, ynew, length - 1, dir - 1, dx, dy)
        draw_tree(xnew, ynew, length - 1, dir + 1, dx, dy)
      end
    end

    def button_down(id)
      select(panel.gene) if id == Gosu::MsLeft || id == Gosu::MsRight
      save(panel.gene)   if id == Gosu::KbS
      close              if id == Gosu::KbEscape
    end

    def panel
      @panels.detect {|panel| panel.below?(mouse_x, mouse_y) }
    end

    def file_label
      Time.now.strftime('gene_%Y%m%d_%H%M%S.yaml')
    end

    def save gene
      File.open(file_label, "w") do |file|
        YAML.dump(gene.to_yaml, file)
      end
    end

    # draws a box on screen
    def draw_box(x, y, width, height, color, z = 0.0)
      draw_line(x, y, color, x + width, y, color, z)
      draw_line(x + width, y, color, x + width, y + height, color, z)
      draw_line(x, y, color, x, y + height, color, z)
      draw_line(x, y + height, color, x + width, y + height, color, z)
    end

    # returns a Gosu::Color for a given length
    # @todo encode color as genes
    def branch_color(length)
      COLORS.fetch(length) { DEFAULT_COLOR }
    end
  end

  # A panel which displays a given gene.
  #
  class Panel
    BOX_COLOR = Gosu::Color.new(0xff808080)
    QUAD_COLOR = Gosu::Color.new(0xff808080)

    attr_reader :x, :y, :width, :height
    attr_accessor :gene

    def initialize(x, y, width, height, gene)
      @x      = x
      @y      = y
      @width  = width
      @height = height
      @gene   = gene
    end

    def below?(x, y)
      x >= @x && x <= @x + @width and y >= @y && y <= @y + @height
    end

    # Used in draw_quad
    def quad_opts
      [@x, @y, QUAD_COLOR,
       @x + @width, @y, QUAD_COLOR,
       @x + @width, @y + @height, QUAD_COLOR,
       @x, @y + @height, QUAD_COLOR]
     end

    # Used in draw_box
    def box_opts
      [@x, @y, @width, @height, BOX_COLOR, 1.0]
    end

    # Used in draw_tree
    def tree_opts
      [@x + (@width / 2), @y + (@height / 2)] + @gene.options
    end

    def info_opts
      [@gene, @x + TEXT_MARGIN, @y + @height - TEXT_SIZE - TEXT_MARGIN, 10]
    end
  end

  class Gene < Array
    def initialize
      self[0..10] = [5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 6]
    end

    def length
      self[9]
    end

    def direction
      self[10]
    end

    # Used in draw_tree
    def options
      [length, direction, dx, dy]
    end

    # drawing x deltas
    def dx
      dx = Array.new(8)
      dx[3] = self[0]
      dx[4] = self[1]
      dx[5] = self[2]
      dx[1] = -dx[3]
      dx[0] = -dx[4]
      dx[7] = -dx[5]
      dx[2] = 0
      dx[6] = 0
      dx
    end

    # drawing y deltas
    def dy
      dy = Array.new(8)
      dy[2] = self[4]
      dy[3] = self[5]
      dy[4] = self[6]
      dy[5] = self[7]
      dy[6] = self[8]
      dy[0] = dy[4]
      dy[1] = dy[3]
      dy[7] = dy[5]
      dy
    end

    # mutate a given gene
    # @todo investigate the mutation rates
    def mutate(gene)
      if gene == 9  # length, only minor mutations
        self[gene] += 1
      elsif gene == 10
        self[gene] += 1
        if self[gene] > 8
          self[gene] = 0
        end
      else # do something completely random
        self[gene] += -10 + rand(20)
      end
    end

    # asexually reproduce a given amount of times, note that the parent
    # is preserved in the children array
    def reproduce(amount)
      children = Array.new
      children << self
      amount.times do |i|
        child = self.clone
        child.mutate(i)
        children << child
      end
      children
    end
  end
end

if $0 == __FILE__
  RubyMorph::RubyMorph.new.show
  puts("I for one welcome our new biomorphic overlords...thanks and goodbye!")
end