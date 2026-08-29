require 'sinatra'
require 'sequel'
require 'sqlite3'

set :bind, '0.0.0.0'
set :host_authorization, { permitted_hosts: [] }

use Rack::Session::Cookie,
    key: 'rack.session',
    path: '/',
    secret: ENV.fetch('SESSION_SECRET') { SecureRandom.hex(32) },
    same_site: :lax,
    httponly: true

ADMIN_PASSWORD = ENV.fetch('ADMIN_PASSWORD', 'admin')

helpers do
  def admin_authenticated?
    session[:admin] == true
  end

  def require_admin!
    redirect '/admin/login' unless admin_authenticated?
  end

  # RSVP is disabled now that the wedding is over. Set RSVP_ENABLED=true to turn
  # it back on for a demo — no code needs to change.
  def rsvp_enabled?
    ENV.fetch('RSVP_ENABLED', 'false') == 'true'
  end
end

# Database setup
# The path can be overridden with WEDDING_DB (used by the test suite to run
# against a throwaway database).
DB = Sequel.sqlite(ENV.fetch('WEDDING_DB') { File.join(__dir__, 'db', 'wedding.sqlite3') })

# Run migrations
Sequel.extension :migration
Sequel::Migrator.run(DB, File.join(__dir__, 'db', 'migrate'))

# Block all /rsvp routes while the feature is disabled. The route handlers
# below are kept intact so RSVP can be re-enabled via rsvp_enabled? for a demo.
before '/rsvp*' do
  halt 404, erb(:guest_not_found) unless rsvp_enabled?
end

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
  DB.transaction do
    rsvp_id = DB[:rsvps].insert(
      name: params[:name],
      attending: params[:attending] == 'yes',
      plus_one: params[:plus_one] == 'on',
      plus_one_name: params[:plus_one_name],
      meal_choice: params[:meal_choice],
      plus_one_meal_choice: params[:plus_one_meal_choice],
      dietary_restrictions: params[:dietary_restrictions]
    )

    # Process kids if present
    if params[:kids].is_a?(Array)
      params[:kids].each do |kid|
        next if kid[:name].to_s.strip.empty?

        DB[:kids].insert(
          rsvp_id: rsvp_id,
          name: kid[:name].strip,
          meal_choice: kid[:meal_choice]
        )
      end
    end

    if params[:guest_code] && !params[:guest_code].empty?
      DB[:guests].where(code: params[:guest_code]).update(rsvp_id: rsvp_id)
    end
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

  # Fetch all kids grouped by rsvp_id
  @kids_by_rsvp = DB[:kids].all.group_by { |k| k[:rsvp_id] }
  @total_kids = DB[:kids].count

  @total = @rsvps.count
  @attending = @rsvps.count { |r| r[:attending] }
  @declined = @rsvps.count { |r| !r[:attending] }
  @plus_ones = @rsvps.count { |r| r[:plus_one] }

  # Update meal counts to include kids' meals
  @meal_counts = @rsvps.each_with_object(Hash.new(0)) do |r, counts|
    next unless r[:attending]

    counts[r[:meal_choice] || 'Not specified'] += 1

    # Add plus one meal
    counts[r[:plus_one_meal_choice]] += 1 if r[:plus_one] && r[:plus_one_meal_choice]

    # Add kids meals
    @kids_by_rsvp[r[:id]]&.each do |kid|
      counts[kid[:meal_choice] || 'Not specified'] += 1 if kid[:meal_choice]
    end
  end

  @total_guests = DB[:guests].count
  @responded_guests = DB[:guests].exclude(rsvp_id: nil).count

  erb :admin
end

post '/admin/rsvp/:id/delete' do
  require_admin!
  rsvp_id = params[:id].to_i
  DB[:guests].where(rsvp_id: rsvp_id).update(rsvp_id: nil)
  DB[:kids].where(rsvp_id: rsvp_id).delete
  DB[:rsvps].where(id: rsvp_id).delete
  redirect '/admin'
end
