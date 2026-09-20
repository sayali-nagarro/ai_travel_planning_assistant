namespace :knowledge do
  desc "Import the Singapore knowledge base"
  task import: :environment do
    Knowledge::Importer.new.call
    puts "Imported Singapore knowledge base."
  end
end
