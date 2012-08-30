require 'chipmunk'
require 'gosu'
require 'pry'
require 'matrix'

module Vectors
  ORIGIN = CP::Vec2.new 0,0
  GRAVITY = CP::Vec2.new 0, 100
end

class PolyRenderer
  attr_reader :shape

  def initialize(shape)
    @shape = shape
  end

  def body
    shape.body
  end

  def pos
    body.pos
  end

  def rot
    body.rot
  end

  def verts
    (0..shape.num_verts-1).map do |i|
      v = shape.vert(i)
      [v.x, v.y]
    end
  end

  def rot_matrix
    cos = body.rot.x
    sin = body.rot.y
    Matrix[
      [cos, -sin],
      [sin,  cos]
    ]
  end

  def rot_points
    verts.map do |x, y|
      (rot_matrix * Matrix[[x], [y]]).to_a
    end.map do |(dx), (dy)|
      [pos.x + dx, pos.y + dy]
    end
  end

  def draw(window, color)
    r = rot_points
    (0..r.count-1).each do |i|
      x1, y1 = r[i]
      x2, y2 = r[(i+1) % r.count]
      window.draw_triangle(pos.x, pos.y, color,
                           x2, y2, color,
                           x1, y1, color)
    end
  end
end

class Block
  attr_accessor :body, :shape, :radius

  def initialize(mass, radius, elasticity = 0.8)
    @radius = radius
    moi = CP.moment_for_poly(mass, vertices, Vectors::ORIGIN)

    @body = CP::Body.new(mass, moi)

    @shape = CP::Shape::Poly.new(@body, vertices, Vectors::ORIGIN)
    @shape.collision_type = :block
    @shape.e = elasticity
  end

  def vertices
    nth_roots_of_unity(6).map do |x, y|
      CP::Vec2.new(x*radius, y*radius)
    end
  end

  def draw(window)
    PolyRenderer.new(shape).draw(window, 0xff00ffff)
  end
end

def nth_roots_of_unity(n)
  (0..n-1).map { |k| Complex.polar(1, 2 * Math::PI * k / n) }.map(&:rect).reverse
end

class Window < Gosu::Window
  SUBSTEPS = 1
  STEP_DELTA = 1.0 / 60.0

  def initialize
    super 800, 600, false
    self.caption = 'Blocks'

    @space = CP::Space.new

    #@space.add_collision_func :ball, :ball do |a, b|
    #a.body.apply_force CP::Vec2.new(10, 0), Vectors::ORIGIN
    #end

    [
      [[0, 0], [0, 600]],
      [[0, 0], [800, 0]],
      [[0, 600], [800, 600]],
      [[800, 0], [800, 600]]
    ].each do |start, finish|
      add_bounding_plane start, finish
    end


    @blocks = (1..100).map do
      ball = Block.new(5, 10)

      x = rand 800
      y = rand 600
      ball.body.p = CP::Vec2.new x, y

      @space.add_body(ball.shape.body)
      @space.add_shape(ball.shape)
      #ball.body.apply_force(Vectors::GRAVITY, Vectors::ORIGIN)

      ball
    end

  end


  def add_bounding_plane(start, finish)
    ground_body = CP::Body.new(Float::INFINITY, Float::INFINITY)
    ground_body.p = Vectors::ORIGIN
    ground_shape = CP::Shape::Segment.new(ground_body, CP::Vec2.new(*start), CP::Vec2.new(*finish), 1.0)
    ground_shape.e = 1.0

    @space.add_static_shape(ground_shape)
  end

  def button_down(id)
    close if id == Gosu::KbEscape

    if id = Gosu::MsLeft
      @tracking = true
      @selected = @blocks.select do |b|
        b.shape.contains?(CP::Vec2.new mouse_x, mouse_y)
      end.first
      @cur_position = [ mouse_x, mouse_y ]
    end
  end

  def button_up(id)
    if id = Gosu::MsLeft
      @tracking = false
      @selected = nil
    end
  end

  def draw
    @blocks.each { |b| b.draw(self) }
    draw_mouse
  end

  def update
    if @tracking && @selected
      prev_x, prev_y = *@cur_position
      @cur_position = [ mouse_x, mouse_y ]

      if prev_x && prev_y
        dx = mouse_x - prev_x
        dy = mouse_y - prev_y
        @selected.body.apply_force(CP::Vec2.new(dx, dy),
                                  Vectors::ORIGIN)
      end
    end

    SUBSTEPS.times do
      @space.step(STEP_DELTA / SUBSTEPS)
    end
  end

  def draw_mouse
    color = 0xffff0000

    draw_line(
      mouse_x - 10, mouse_y, color,
      mouse_x + 10, mouse_y, color
    )
    draw_line(
      mouse_x, mouse_y - 10, color,
      mouse_x, mouse_y + 10, color
    )
  end
end

Window.new.show
