require 'sinatra'
require 'sequel'
require 'sqlite3'

set :bind, '0.0.0.0'
set :host_authorization, {permitted_hosts: []}

enable :sessions
set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(32) }

ADMIN_PASSWORD = ENV.fetch('ADMIN_PASSWORD', 'admin')

helpers do
  def admin_authenticated?
    session[:admin] == true
  end

  def require_admin!
    redirect '/admin/login' unless admin_authenticated?
  end
end

# Database setup
DB = Sequel.sqlite(File.join(__dir__, 'db', 'wedding.sqlite3'))

# Run migrations
Sequel.extension :migration
Sequel::Migrator.run(DB, File.join(__dir__, 'db', 'migrate'))

# Routes
get '/' do
  erb :index
end

get '/registry' do
  erb :registry
end

get '/rsvp' do
  @guest = nil
  erb :rsvp
end

get '/rsvp/success' do
  @name = params[:name]
  erb :rsvp_success
end

get '/rsvp/:code' do
  @guest = DB[:guests].where(code: params[:code]).first
  halt 404, erb(:guest_not_found) unless @guest
  erb :rsvp
end

post '/rsvp' do
  rsvp_id = DB[:rsvps].insert(
    name: params[:name],
    attending: params[:attending] == 'yes',
    plus_one: params[:plus_one] == 'on',
    plus_one_name: params[:plus_one_name],
    meal_choice: params[:meal_choice],
    plus_one_meal_choice: params[:plus_one_meal_choice],
    dietary_restrictions: params[:dietary_restrictions]
  )

  if params[:guest_code] && !params[:guest_code].empty?
    DB[:guests].where(code: params[:guest_code]).update(rsvp_id: rsvp_id)
  end

  redirect "/rsvp/success?name=#{URI.encode_www_form_component(params[:name])}"
end

# Admin routes
get '/admin/login' do
  erb :admin_login
end

post '/admin/login' do
  if params[:password] == ADMIN_PASSWORD
    session[:admin] = true
    redirect '/admin'
  else
    @error = 'Invalid password'
    erb :admin_login
  end
end

get '/admin/logout' do
  session.clear
  redirect '/'
end

get '/admin' do
  require_admin!

  @rsvps = DB[:rsvps].order(Sequel.desc(:created_at)).all
  @total = @rsvps.count
  @attending = @rsvps.count { |r| r[:attending] }
  @declined = @rsvps.count { |r| !r[:attending] }
  @plus_ones = @rsvps.count { |r| r[:plus_one] }

  @meal_counts = @rsvps.each_with_object(Hash.new(0)) do |r, counts|
    counts[r[:meal_choice] || 'Not specified'] += 1 if r[:attending]
  end

  @total_guests = DB[:guests].count
  @responded_guests = DB[:guests].exclude(rsvp_id: nil).count

  erb :admin
end

post '/admin/rsvp/:id/delete' do
  require_admin!
  DB[:guests].where(rsvp_id: params[:id].to_i).update(rsvp_id: nil)
  DB[:rsvps].where(id: params[:id].to_i).delete
  redirect '/admin'
end
