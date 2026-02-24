require 'sequel'
require 'sqlite3'

DB = Sequel.sqlite(File.join(__dir__, 'wedding.sqlite3'))

# Replace these with your real guest list
guests = [
  { name: "John & Jane Smith", code: "smith-family" },
  { name: "Michael Johnson",   code: "michael-johnson" },
  { name: "Emily & David Chen", code: "chen-family" },
  { name: "Sarah Williams",    code: "sarah-williams" },
]

guests.each do |guest|
  if DB[:guests].where(code: guest[:code]).count == 0
    DB[:guests].insert(name: guest[:name], code: guest[:code])
    puts "Added guest: #{guest[:name]} (#{guest[:code]})"
  else
    puts "Skipped (already exists): #{guest[:name]} (#{guest[:code]})"
  end
end

puts "Done. #{DB[:guests].count} total guests in database."
