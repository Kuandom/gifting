require 'rubygems'
require 'sinatra'
require 'erb'
require 'amazon/ecs'
require 'model'

enable :sessions

def cache_control
  headers['Cache-Control'] = 'max-age=900, public'
end

get '/' do
  @tags = repository(:default).adapter.query("SELECT tags.*, COUNT(tags.id) AS tags_count FROM tags
  INNER JOIN taggings ON tags.id = taggings.tag_id
  INNER JOIN surveys ON taggings.taggable_id = surveys.id
  WHERE surveys.like = 't'
  GROUP BY tags.id ORDER BY tags_count DESC LIMIT 30")
  @surveys = Survey.all(:like => true, :order => [:id.desc], :limit => 20)
  erb :index
end

def start_over
  if params[:so]
    session[:seen] = ['--empty--']    
  end
end

def sort_by_random(collection)
    collection.sort{|a,b| rand <=> rand }
end

get '/search' do
  start_over
  good_asins = ['xxx']
  bad_asins = ['xxx']
  params[:tags].split(",").each do |tag|
    if Tag.first(:name => tag)
      @surveys = Survey.tagged_with(tag, :like => true) 
      good_asins << @surveys.collect{|x| x.item.asin }
      @surveys = Survey.tagged_with(tag, :like => false) 
      bad_asins << @surveys.collect{|x| x.item.asin }
    end
  end
  @item_list = sort_by_random(Item.all(:asin.in => good_asins.first, :asin.not => session[:seen]))
  @item_list += sort_by_random(Item.all(:asin.not => good_asins.first, :asin.not => bad_asins.first, :asin.not => session[:seen]))
  @item_list += sort_by_random(Item.all(:asin.in => bad_asins.first, :asin.not => session[:seen]))
  @item = @item_list.uniq.first
  redirect '/' unless @item
  redirect '/give/' + @item.asin + '?tags=' + params[:tags]
end

get '/give/:asin' do
  start_over
  @item = Item.first(:asin => params[:asin])  
  session[:seen] << @item.asin
  erb :give
end

get '/vote' do
  if params[:submit] == "i don't want to get this"
    create_survey(false)
  else
    create_survey(true)
  end
  redirect '/search?tags=' + params[:tags] 
end

def create_survey(like)
  Survey.create(:tag_list => params[:tags], :item => Item.first(:asin => params[:asin]), :like => like)    
end