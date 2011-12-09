require 'open-uri'
require 'nokogiri'

module Logaling
  class GnomeProject < ExternalGlossary
    def import
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://www.gnome.gr.jp/l10n/trans-terms.html", "r"))
        doc.css('table tr')[1..-1].each do |tr|
          csv << [tr.children[0].text, tr.children[1].text]
        end
      end
      File.open("gnome_project.en.ja.csv", "w") {|f| f.write(buffer) }
    end
  end
end
