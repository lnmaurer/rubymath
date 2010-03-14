require '/home/leon/Development/symbolic/lib/symbolic.rb'
require 'numeric'
require 'plot'
require 'yaml'
require 'rubygems'
#require 'symbolic'
require 'haml'
require 'sinatra'
require 'coderay'
include Symbolic::Math #so that we have easy access to exp, cos, etc.
include Symbolic::Constants

class Worksheet
  attr_reader :in, :out
  def initialize
    @in = Array.new
    @out = Array.new
    @binding = Kernel.binding
  end
  def eval(cmd,index=nil)
    index = @in.size unless index #if we're making a new entry, set index accordingly
    @in[index] = cmd
    begin
      @out[index], @binding = Kernel.eval('[' + cmd + ',Kernel.binding]',@binding)
    rescue Exception => e
      #if there's an error in the command, save it an the backtrace in @out
      @out[index] = "ERROR:\n" + e.message + "\n" + e.backtrace[0..4].join("\n")
      puts @out[index]
      raise
    end
  end
  def size
    @in.size
  end
end

def to_html(ob)
  case ob
  when Plot then "\n" + ob.svg.inline
  #otherwise we want to display it as text with syntax highlighting and retruns
  else CodeRay.scan(ob.to_s, :ruby).span.gsub("\n",'<br />')
  end
end

$worksheets = Array.new

get '/' do
  #make new worksheet
  $worksheets << Worksheet.new
  #redirect to new worksheet
  redirect "/worksheet/#{$worksheets.size - 1}/disp#bottom"
end

get '/worksheet/:num/:command' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @command = params[:command]
  haml :worksheet
end

post '/worksheet/:num/:command' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @command = params[:command]
  if @command == 'newcommand'
    begin
      $worksheets[@num].eval(params[:newcommand])
      redirect "/worksheet/#{@num}/disp#bottom"
    rescue
      #if there's an error, let the user correct it
      redirect "/worksheet/#{@num}/edit/#{$worksheets[@num].size - 1}"
    end
  elsif @command == 'load'
    #are we loading it in to the current worksheet or a new one?
    @num = params[:ws] == 'current' ? params[:num].to_i : $worksheets.size
    $worksheets[@num] = Worksheet.new
    YAML.load(params[:file][:tempfile].read).each{|c| $worksheets[@num].eval(c)}
    redirect "/worksheet/#{@num}/disp#bottom"
  elsif @command == 'clear'
    $worksheets[@num] = Worksheet.new
    redirect "/worksheet/#{@num}/disp#bottom"    
  end
end

get '/worksheet/:num/edit/:index' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @index = params[:index].to_i 
  haml :edit
end

post '/worksheet/:num/edit/:index' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @index = params[:index].to_i 
  @editedcommand = params[:editedcommand]
  begin
    $worksheets[@num].eval(@editedcommand,@index)
    redirect "/worksheet/#{@num}/disp#bottom"
  rescue
    #if there's an error, let the user correct it  
    redirect "/worksheet/#{@num}/edit/#{@index}"
  end
end

get '/worksheet/:num/save/worksheet.rbmw' do
  content_type 'text/x-yaml'
  @num = params[:num].to_i
  $worksheets[@num].in.to_yaml
end

__END__

@@ worksheet
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title="Worksheet #{@num}"
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out).each_with_index do |(input,output),index|
        %li
          %a{:href => "/worksheet/#{@num}/edit/#{index}#edit"}="In #{index}:" 
          = "#{to_html(input)}"
          %br
          = "Out #{index}: #{to_html(output)}"
    %hr
    %form{:method => 'post', :action => "/worksheet/#{@num}/newcommand"}
      %p
        %textarea{:cols =>'80', :rows => '5', :name=>'newcommand'}
        %input{:type => :submit, :value => "Calculate"}
    %hr
    %p{:id => "#{@command == 'disp' ? 'bottom' : ''}"}
      %a{:href => "/worksheet/#{@num}/save/worksheet.rbmw"}="Save"
      %a{:href => "/worksheet/#{@num}/load#bottom"}="Load"
      %a{:href => "/", :target=>'_blank'}="New"
      %a{:href => "/worksheet/#{@num}/clear#bottom"}="Clear"
      - if $worksheets.size > 1
        Open Worksheets:
        - $worksheets.size.times do |i|
          - if i != @num
            %a{:href => "/worksheet/#{i}/disp#bottom"}="#{i}"
          -else
            ="#{i}"
        %a{:href => "/worksheet/#{@num}/disp#bottom"}="Refresh Current Page"
    - if @command == 'load'
      %form{:action=>"/worksheet/#{@num}/load",:method=>"post",:enctype=>"multipart/form-data"}
        %p='Do you want the loaded worksheet to overwrite the current one or to open in a new worksheet?'
        %input{:type => :radio, :name => 'ws', :value => 'current', :checked => 'checked'}
        Current Worksheet
        %input{:type => :radio, :name => 'ws', :value => 'new'}
        New Worksheet
        %p="Please select a file, then hit 'Upload':"
        %input{:type => :file, :name => 'file'}
        %br
        %input{:type=>:submit,:value=>"Upload"}
    - if @command == 'clear'
      %form{:action=>"/worksheet/#{@num}/clear",:method=>"post"}
        %p='Do you really want to clear the worksheet? Your work will not be saved.'
        %input{:type=>"submit",:value=>"Clear Worksheet"}
    -if @command != 'disp'
      %p{:id=>'bottom'}
        %a{:href => "/worksheet/#{@num}/disp#bottom"}="Cancel"
	
@@ edit
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title="Editing Worksheet #{@num}, Line #{@index}"
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out).each_with_index do |(input,output),index|
        %li{:id => "#{index == @index ? 'edit' : ''}"}
          %a{:href => "/worksheet/#{@num}/edit/#{index}#edit"}="In #{index}:"
          - if index != @index
            = "#{to_html(input)}"
          - else
            %form{:method => 'post', :action => "/worksheet/#{@num}/edit/#{index}"}
              %p
                %textarea{:cols =>'80', :rows => '5', :name=>'editedcommand'}="#{input}"
                %input{:type => :submit, :value => "Edit"}	      
          %br
          = "Out #{index}: #{to_html(output)}"
