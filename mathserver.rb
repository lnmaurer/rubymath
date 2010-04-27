# require '/home/leon/Development/symbolic/lib/symbolic.rb'
require '/home/leon/Development/symbolic/lib/symbolic.rb'
require 'numeric'
require 'physical_constants'
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
  attr_accessor :name, :hidden, :comments
  def initialize(hsh = nil)
    @name = (hsh == nil ? '' : hsh['Worksheet_Name'])
    @in = Array.new
    @out = Array.new
    @hidden = Array.new
    @comments = (hsh == nil ? Array.new : hsh['Comments'])
    @binding = Kernel.binding
    if hsh != nil
      hsh['Input'].each{|c| self.eval(c)}
      hsh['Hidden'].each{|i| self.hidden[i] = true}
    end
  end
  def eval(cmd,index=nil)
    index = @in.size unless index #if we're making a new entry, set index accordingly
    @in[index] = cmd
    begin
      @out[index] = Kernel.eval(cmd,@binding)
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
  def to_yaml
    hsh = Hash.new
    hsh['Worksheet_Name'] = self.name
    hsh['Input'] = self.in
    hsh['Hidden'] = Array.new
    self.hidden.each_with_index{|h,i| hsh['Hidden'] << i if h}
    hsh['Comments'] = self.comments
    hsh.to_yaml
  end
  def insert(index)
    @in = @in.insert(index,'')
    @out = @out.insert(index,'')
    @hiden = @hidden.insert(index,nil)
    @comments = @comments.insert(index,'')
  end
  def comment(index,comment)
    comment = nil if comment == ''
    @comments[index] = comment
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
    hsh = YAML.load(params[:file][:tempfile].read)
    $worksheets[@num] = Worksheet.new(hsh)
    redirect "/worksheet/#{@num}/disp#bottom"
  elsif @command == 'clear'
    $worksheets[@num] = Worksheet.new
    redirect "/worksheet/#{@num}/disp#bottom" 
  elsif @command == 'name'
    $worksheets[@num].name = params[:name]
    redirect "/worksheet/#{@num}/disp#bottom"    
  end
end

get '/worksheet/:num/insert/:index' do
  @num = params[:num].to_i
  @index = params[:index].to_i
  $worksheets[@num].insert(@index)
  redirect "/worksheet/#{@num}/edit/#{@index}#edit"
end

get '/worksheet/:num/comment/:index' do
  @num = params[:num].to_i
  @index = params[:index].to_i
  haml :comment
end

post '/worksheet/:num/comment/:index' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @index = params[:index].to_i 
  @comment = params[:c]
  $worksheets[@num].comment(@index,@comment)
  redirect "/worksheet/#{@num}/disp##{@index}c"
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
    redirect "/worksheet/#{@num}/disp##{@index}in"
  rescue
    #if there's an error, let the user correct it  
    redirect "/worksheet/#{@num}/edit/#{@index}#edit"
  end
end

get '/worksheet/:num/save/:wsname' do
  content_type 'text/x-yaml'
  @num = params[:num].to_i
  $worksheets[@num].to_yaml
end

get '/print/:num' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  haml :print
end

get '/worksheet/:num/hide/:index' do
  @num = params[:num].to_i
  @index = params[:index].to_i 
  $worksheets[@num].hidden[@index] = ! $worksheets[@num].hidden[@index]
  redirect "/worksheet/#{@num}/disp##{@index}out"
end

#TODO
get '/help' do

end

__END__

@@ worksheet
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title="Worksheet #{@num}#{$worksheets[@num].name == '' ? '' : ' (' + $worksheets[@num].name + ')'}"
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out,$worksheets[@num].comments,$worksheets[@num].hidden).each_with_index do |(input,output,comment,hidden),index|
        %li
          %a{:href => "/worksheet/#{@num}/insert/#{index}"}='I'
          - if comment == nil
            %a{:href => "/worksheet/#{@num}/comment/#{index}#comment"}='C'
          - else
            %a{:href => "/worksheet/#{@num}/comment/#{index}#comment"}="Comment #{index}"
            =": #{comment}"
            %br
          %a{:href => "/worksheet/#{@num}/edit/#{index}#edit", :id=>"#{index}in"}="In #{index}" 
          =": #{to_html(input)}"
          %br
          %a{:href => "/worksheet/#{@num}/hide/#{index}", :id=>"#{index}out"}="Out #{index}"
          =": #{hidden ? '' : to_html(output)}"
    %hr
    %form{:method => 'post', :action => "/worksheet/#{@num}/newcommand"}
      %p
        %textarea{:cols =>'80', :rows => '5', :name=>'newcommand'}
        %input{:type => :submit, :value => "Calculate"}
    %hr
    %p{:id => "#{@command == 'disp' ? 'bottom' : ''}"}
      %a{:href => "/worksheet/#{@num}/name#bottom"}="(re)Name Worksheet"
      %a{:href => "/worksheet/#{@num}/save/#{$worksheets[@num].name == '' ? "worksheet#{@num}" : $worksheets[@num].name}.rbmw"}="Save"
      %a{:href => "/worksheet/#{@num}/load#bottom"}="Load"
      %a{:href => "/", :target=>'_blank'}="New"
      %a{:href => "/worksheet/#{@num}/clear#bottom"}="Clear"
      %a{:href => "/print/#{@num}"}="Print"      
      %a{:href => "/help"}="HELP"
      - if $worksheets.size > 1
        Open Worksheets:
        - $worksheets.size.times do |i|
          - if i != @num
            %a{:href => "/worksheet/#{i}/disp#bottom"}="#{i}#{$worksheets[i].name == '' ? '' : ' (' + $worksheets[i].name + ')'}"
          -else
            ="#{i}#{$worksheets[i].name == '' ? '' : ' (' + $worksheets[i].name + ')'}"
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
    - if @command == 'name'
      %form{:action=>"/worksheet/#{@num}/name",:method=>"post"}
        %p='Enter a name for this worksheet:'
        %input{:type=>'text', :size=>'40', :name=>'name'}
        %input{:type=>'submit',:value=>'Enter'}
    -if @command != 'disp'
      %p{:id=>'bottom'}
        %a{:href => "/worksheet/#{@num}/disp#bottom"}="Cancel"
	
@@ edit
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title="Editing Worksheet #{@num}#{$worksheets[@num].name == '' ? '' : ' (' + $worksheets[@num].name + ')'}, Line #{@index}"
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out,$worksheets[@num].comments,$worksheets[@num].hidden).each_with_index do |(input,output,comment,hidden),index|
        %li{:id => "#{index == @index ? 'edit' : ''}"}
          - if comment != nil
            ="Comment #{index}: #{comment}"
          ="In #{index}:"
          - if index != @index
            = "#{to_html(input)}"
          - else
            %form{:method => 'post', :action => "/worksheet/#{@num}/edit/#{index}"}
              %p
                %textarea{:cols =>'80', :rows => '5', :name=>'editedcommand'}="#{input}"
                %input{:type => :submit, :value => "Edit"}	      
          %br
          = "Out #{index}: #{to_html(output)}"

@@ comment
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title="Commenting Worksheet #{@num}#{$worksheets[@num].name == '' ? '' : ' (' + $worksheets[@num].name + ')'}, Line #{@index}"
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out,$worksheets[@num].comments,$worksheets[@num].hidden).each_with_index do |(input,output,comment,hidden),index|
        %li{:id => "#{index == @index ? 'comment' : ''}"}
          - if @index == index
            %form{:method => 'post', :action => "/worksheet/#{@num}/comment/#{index}"}
              %p
                %textarea{:cols =>'80', :rows => '5', :name=>'c'}="#{comment}"
                %input{:type => :submit, :value => "Comment"}
          - elsif comment != nil
            ="Comment: #{comment}"
            %br
          = "In #{index}: #{to_html(input)}"	      
          %br
          = "Out #{index}: #{to_html(output)}"

@@ print
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title="Print Worksheet #{@num}#{$worksheets[@num].name == '' ? '' : ' (' + $worksheets[@num].name + ')'}"
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out,$worksheets[@num].comments,$worksheets[@num].hidden).each_with_index do |(input,output,comment,hidden),index|
        %li
          - if comment != nil
            ="Comment #{index}: #{comment}"
            %br
          ="In #{index}: #{to_html(input)}"
          %br
          - unless hidden
            ="Out #{index}: #{to_html(output)}"
