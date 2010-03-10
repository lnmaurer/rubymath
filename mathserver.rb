require 'rubygems'
require 'haml'
require 'sinatra'
require 'coderay'
require 'numeric'
#require 'symbolic'
require 'plot'
require '/home/leon/Development/symbolic/lib/symbolic.rb'

#following function is here as a quick hack
  def linspace(start,stop,num = 100)
    step = (stop - start)/(num - 1.0)
    (0..(num-1)).to_a.collect{|n| start + n * step}
  end

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
    @out[index], @binding = Kernel.eval('[' + cmd + ',Kernel.binding]',@binding)
  end
end

def to_html(ob)
  case ob
  when Plot then "\n" + ob.svg.inline
  else CodeRay.scan(ob.to_s, :ruby).span
  end
end

$worksheets = Array.new

get '/' do
  #make new worksheet
  $worksheets << Worksheet.new
  #redirect to new worksheet
  redirect "/worksheet/#{$worksheets.size - 1}#entry"
end

get '/worksheet/:num' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  haml :worksheet
end

post '/worksheet/:num/newcommand' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @newcommand = params[:newcommand]
  $worksheets[@num].eval(@newcommand)
  redirect "/worksheet/#{@num}#entry"
end

post '/worksheet/:num/edit/:index' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @index = params[:index].to_i 
  @editedcommand = params[:editedcommand]
  $worksheets[@num].eval(@editedcommand,@index)
  redirect "/worksheet/#{@num}"
end

get '/worksheet/:num/edit/:index' do
  content_type 'application/xml', :charset => 'utf-8'
  @num = params[:num].to_i
  @index = params[:index].to_i 
  haml :edit
end

__END__

@@ worksheet
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Entry
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out).each_with_index do |(input,output),index|
        %li
          %a{:href => "/worksheet/#{@num}/edit/#{index}#edit"}="In #{index}:" 
          = "#{to_html(input)}"
          %br
          = "Out #{index}: #{to_html(output)}"
    %hr
    %form{:method => 'post', :action => "/worksheet/#{@num}/newcommand", :id => 'entry'}
      %textarea{:cols =>'80', :rows => '5', :name=>'newcommand'}
      %input{:type => :submit, :value => "Calculate"}

@@ edit
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Editing Worksheet #{@num}, Line #{@index}
  %body
    %ul
      - $worksheets[@num].in.zip($worksheets[@num].out).each_with_index do |(input,output),index|
        %li
          %a{:href => "/worksheet/#{@num}/edit/#{index}#edit"}="In #{index}:"
          - if index != @index
            = "#{to_html(input)}"
          - else
            %form{:method => 'post', :action => "/worksheet/#{@num}/edit/#{index}", :id => 'edit'}
              %textarea{:cols =>'80', :rows => '5', :name=>'editedcommand'}
                =" #{input}"
              %input{:type => :submit, :value => "Edit"}	      
          %br
          = "Out #{index}: #{to_html(output)}"
    %hr
    %form{:method => 'post', :action => "/worksheet/#{@num}/newcommand", :id => 'entry'}
      %textarea{:cols =>'80', :rows => '5', :name=>'newcommand'}
      %input{:type => :submit, :value => "Calculate"}
