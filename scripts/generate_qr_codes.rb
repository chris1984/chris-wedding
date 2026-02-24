require 'bundler/setup'
require 'sequel'
require 'sqlite3'
require 'rqrcode'
require 'fileutils'

base_url = ARGV[0]
unless base_url
  puts "Usage: bundle exec ruby scripts/generate_qr_codes.rb <base_url>"
  puts "Example: bundle exec ruby scripts/generate_qr_codes.rb http://localhost:4567"
  exit 1
end

base_url = base_url.chomp('/')

DB = Sequel.sqlite(File.join(__dir__, '..', 'db', 'wedding.sqlite3'))

output_dir = File.join(__dir__, '..', 'qr_codes')
FileUtils.mkdir_p(output_dir)

guests = DB[:guests].all

if guests.empty?
  puts "No guests found. Run 'bundle exec ruby db/seed_guests.rb' first."
  exit 1
end

guests.each do |guest|
  url = "#{base_url}/rsvp/#{guest[:code]}"
  qr = RQRCode::QRCode.new(url)
  png = qr.as_png(size: 400, border_modules: 2)

  filepath = File.join(output_dir, "#{guest[:code]}.png")
  File.binwrite(filepath, png.to_s)
  puts "Generated: #{filepath} -> #{url}"
end

puts "Done. #{guests.length} QR codes saved to #{output_dir}/"
