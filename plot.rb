
#require 'svg/svg'
require '/home/leon/Development/rubymath/svg/svg.rb'

PlotColors = ['aqua', 'gray', 'navy', 'green', 'olive', 'teal', 'blue', 'lime', 'purple', 'fuchsia', 'maroon', 'red', 'yellow']
CircleMarkers = PlotColors.collect do |color|
  m = SVG::Marker.new{
  self.id = "circlemarker#{color}"
  self.viewBox = '0 0 2 2'
  self.refX = '1'
  self.refY = '1'
  self.markerUnits = 'strokeWidth'
  self.orient = '0'}
  m << SVG::Circle.new(1,1,1){
  self.style = SVG::Style.new
  self.style.fill         = color
  self.style.stroke       = 'none'
  }
  m
end
MarkerStyles = PlotColors.collect{|color| SVG::Style.new(:fill => 'none', :stroke => 'none', :marker => "url(#circlemarker#{color})")}
PlotStyles = PlotColors.collect{|color| SVG::Style.new(:fill => 'none', :stroke => color, :stroke_width => 1)}

def plot2d(to_plot, xvar = nil, xrange = nil, yrange = nil)
  unless to_plot.is_a?(Array)
    to_plot = [to_plot]
  else #to_plot is an array
    if to_plot[0].is_a?(Array) and (not to_plot[0][0].is_a?(Array))
      #we're dealing with something of the form [[x1,x2...],[y1,y2...]]
      to_plot = [to_plot]                             
    end
  end
  plot = Plot2D.new
  plot.xrange = xrange
  plot.yrange = yrange
  
  to_plot.each do |tp|
    if tp.is_a?(Array) #plot data
      plot.add_points(tp)
    else #plot a function
      plot.add_function(tp,xvar)
    end
  end
  plot
end

class Plot
  def svg
    
  end
end

class Plot2D < Plot
  attr_reader :svg
  attr_reader :xrange, :yrange
  attr_writer :xrange, :yrange
  def initialize()
    @data_points = Array.new
    @fctns = Array.new
    @markers = Array.new
    @xrange = nil
    @yrange = nil
    @color_count = 0
  end
  
  #takes data of form [[x1,x2...],[y1,y2...]] or [[x0,y0],[x1,y1]...]
  def add_points(d,style = nil, marker = nil)
    #TODO: if no style given, make one
    unless style and marker
      style = MarkerStyles[@color_count]
      @markers << CircleMarkers[@color_count]
      @color_count += 1
    else
      @markers << marker
    end
    pd = d.transpose if d[0].size == 2 #po is of form [[x0,y0],[x1,y1]...]
    @data_points << {:x => d[0], :y => d[1], :style => style}
  end
  def add_function(fctn, xvar, style = nil)
    unless style 
      style = PlotStyles[@color_count]
      @color_count += 1
    end
    @fctns << {:fctn => fctn, :xvar => xvar, :style => style}
  end
  def svg
    x = Array.new
    y = Array.new
    styles = Array.new
    
    @data_points.each{|hsh| x << hsh[:x]; y << hsh[:y]; styles << hsh[:style]}

    #if @xrange hasn't been given, find the larest and smallest 'x's in the data points
    xmin, xmax = (@xrange == nil ? [x.flatten.min, x.flatten.max] : @xrange)
    
    @fctns.each do |hsh|
      x << linspace(xmin,xmax,100) #IS 100 STEPS ALWAYS GOOD?
      y << x[-1].collect{|xi| hsh[:fctn].subs(hsh[:xvar],xi)}      
      styles << hsh[:style]
    end
    
    #if @yrange isn't given, find the larest and smallest 'x's in all the points
    ymin, ymax = (@yrange == nil ? [y.flatten.min, y.flatten.max] : @yrange)
    
    width , height = xmax - xmin, ymax - ymin     
    pwidth = width > height ? 4.0 : 4.0 * width / height #is 4 inches allways a good value?
    pheight = width < height ? 4.0 : 4.0 * height / width
    
    #update the styles so that they have the right linewidth for the given height and width
    linewidth = [height,width].max / 100.0
    styles.each{|s| s.stroke_width = linewidth}
    #make the svg, group, and axies, add the markers
    @svg = SVG.new("#{pwidth}in", "#{pheight}in", "0 0 #{width} #{height}")
    @markers.each{|m|@svg.add_marker(m)}
    g = SVG::Group.new(){ self.transform = "translate(#{-xmin},#{ymax}) scale(1,-1)"}
    g << SVG::Line.new(xmin,0,xmax,0){ self.style = SVG::Style.new(:fill => 'none', :stroke => 'black', :stroke_width => linewidth)}
    g << SVG::Line.new(0,ymin,0,ymax){ self.style = SVG::Style.new(:fill => 'none', :stroke => 'black', :stroke_width => linewidth)}
    #add all the points
    x.zip(y,styles) do |xar,yar,s|
      points = xar.zip(yar).collect{|(xi,yi)| SVG::Point.new(xi,yi)}
      g << SVG::Polyline.new(points) { self.style = s} #EDIT STYLE
    end
    @svg << g
    return @svg
  end
end
