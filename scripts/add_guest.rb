require 'sequel'
require 'sqlite3'

DB = Sequel.sqlite(File.join(__dir__, '..', 'db', 'wedding.sqlite3'))

def generate_code(name)
  name.downcase
      .gsub(/&/, '')
      .gsub(/[^a-z0-9\s]/, '')
      .strip
      .gsub(/\s+/, '-')
end

def add_guest(name, code = nil)
  code ||= generate_code(name)

  if DB[:guests].where(code: code).count > 0
    puts "Error: A guest with code '#{code}' already exists."
    return false
  end

  DB[:guests].insert(name: name, code: code)
  puts "Added: #{name} (#{code})"
  true
end

if ARGV.empty?
  puts "Usage:"
  puts "  bundle exec ruby scripts/add_guest.rb \"Guest Name\""
  puts "  bundle exec ruby scripts/add_guest.rb \"Guest Name\" custom-code"
  puts ""
  puts "Examples:"
  puts "  bundle exec ruby scripts/add_guest.rb \"Tom & Lisa Park\""
  puts "  bundle exec ruby scripts/add_guest.rb \"Dr. Robert Lee\" dr-bob"
  puts ""
  puts "Current guests:"
  DB[:guests].each do |g|
    rsvp_status = g[:rsvp_id] ? " [RSVP'd]" : ""
    puts "  #{g[:name]} (#{g[:code]})#{rsvp_status}"
  end
  puts "Total: #{DB[:guests].count}"
  exit
end

name = ARGV[0]
code = ARGV[1]
add_guest(name, code)
puts "Total guests: #{DB[:guests].count}"
